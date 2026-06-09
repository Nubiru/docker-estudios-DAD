# Ejemplo 3 — WordPress + MariaDB con red propia y volúmenes

**Materia:** DAD
**Fecha:** 2026-05-12
**Repositorio base:** https://github.com/joseluisgs/docker-tutorial/tree/master (carpeta `ejemplos/ejem03`)

> Nota: este ejercicio se realizó con **Podman** (no con Docker). Los comandos `docker ...` del `run.sh` original se reemplazaron por `podman ...`. Además, fue necesario corregir **dos diferencias de sintaxis** entre Docker y Podman — se documentan abajo.

---

## Objetivo

Levantar una pila multi-contenedor formada por:

1. Un contenedor **MariaDB 10.3.9** (base de datos).
2. Un contenedor **WordPress 4.9.8** (frontend/CMS).

Ambos comparten una **red propia** (`mi-network`) que les permite resolverse mutuamente por nombre. Los datos persisten en un **volumen con nombre** (`wordpress-db`) para la base de datos, y en un **bind mount** (`./wordpress`) para los archivos de WordPress.

> Aclaración importante: este ejercicio **NO usa Docker Compose**. Son dos comandos `run` independientes orquestados manualmente con una red compartida. Compose llega más adelante en el tutorial.

---

## Errores encontrados y soluciones

Durante la ejecución del `run.sh` original aparecieron **dos errores**, ambos por diferencias entre Docker y Podman.

### Error 1 — Sintaxis de `--mount` sin `type=`

El script original incluye:

```bash
--mount source=wordpress-db,target=/var/lib/mysql
```

Docker acepta esta forma corta e infiere `type=volume` cuando `source` es un nombre y no una ruta. **Podman no lo infiere** y devuelve:

```
Error: incorrect mount format: should be --mount type=<bind|glob|tmpfs|volume>,[src=<host-dir|volume-name>,]target=<ctr-dir>[,options]
```

**Solución:** declarar `type=volume` explícitamente.

```diff
- --mount source=wordpress-db,target=/var/lib/mysql
+ --mount type=volume,source=wordpress-db,target=/var/lib/mysql
```

### Error 2 — `--link` no soportado en Podman

El script original conecta WordPress con la DB usando:

```bash
--link wordpress-db:mysql
```

Podman responde directamente:

```
Error: unknown flag: --link
```

#### Causa

`--link` es una funcionalidad de Docker **deprecada desde hace años**, pensada para la "red por defecto" (`bridge` legacy) donde los contenedores no se resolvían entre sí por DNS. En **redes user-defined** (como nuestra `mi-network`), Docker y Podman incluyen un DNS interno: cada contenedor es resoluble por su nombre. Podman optó por no implementar `--link` en absoluto.

#### Solución

Eliminar `--link` y pasarle a WordPress la dirección de la DB con la variable de entorno `WORDPRESS_DB_HOST`, usando el nombre del contenedor de la DB como hostname.

```diff
- --link wordpress-db:mysql
+ -e WORDPRESS_DB_HOST=wordpress-db
+ -e WORDPRESS_DB_NAME=wordpress
```

Funciona porque ambos contenedores comparten `mi-network`, y `wordpress-db` resuelve por DNS a la IP interna del contenedor de MariaDB.

---

## Comandos finales (corregidos para Podman)

```bash
# 0. Carpeta para el bind mount de WordPress
mkdir wordpress

# 1. Red propia donde van a vivir los contenedores
podman network create mi-network

# 2. MariaDB — datos persistentes en un volumen con nombre
podman run -d --name wordpress-db \
    --net=mi-network \
    --mount type=volume,source=wordpress-db,target=/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_DATABASE=wordpress \
    -e MYSQL_USER=manager \
    -e MYSQL_PASSWORD=secret \
    mariadb:10.3.9

# 3. WordPress — archivos en un bind mount, conectado a la DB por DNS interno
podman run -d --name wordpress \
    --net=mi-network \
    --mount type=bind,source="$(pwd)"/wordpress,target=/var/www/html \
    -e WORDPRESS_DB_HOST=wordpress-db \
    -e WORDPRESS_DB_USER=manager \
    -e WORDPRESS_DB_PASSWORD=secret \
    -e WORDPRESS_DB_NAME=wordpress \
    -p 8080:80 \
    wordpress:4.9.8
```

Una vez corriendo, abrir `http://localhost:8080` en el navegador y completar el wizard de instalación de WordPress.

---

## Conceptos nuevos respecto al Ejemplo 1

| Concepto | Qué hace | Por qué importa |
|---|---|---|
| **Red user-defined** (`podman network create`) | Crea una red bridge aislada con DNS interno | Los contenedores conectados se ven entre sí por nombre, sin exponer puertos al host |
| **Volumen con nombre** (`type=volume,source=...`) | Almacenamiento gestionado por Podman, persiste aunque borres el contenedor | Ideal para datos de bases de datos: sobrevive a `podman rm` |
| **Bind mount** (`type=bind,source=...`) | Mapea una carpeta del host dentro del contenedor | Editás archivos desde el host y se reflejan en el contenedor (y viceversa) |
| **Multi-contenedor** | Dos `run` independientes en la misma red | Cada servicio en su contenedor — la base de la arquitectura de microservicios |

---

## Verificación / comandos útiles

```bash
# Estado de los contenedores
podman ps

# Logs en vivo
podman logs -f wordpress
podman logs -f wordpress-db

# Verificar que WP responde (302 redirect al wizard de instalación)
curl -I http://localhost:8080

# Confirmar que el bind mount se llenó con los archivos de WordPress
ls wordpress/

# Inspeccionar la red y ver qué containers están conectados
podman network inspect mi-network

# Entrar al contenedor de WP para inspeccionar
podman exec -it wordpress bash

# Desde dentro de WP, probar resolución DNS hacia la DB
podman exec -it wordpress bash -c "getent hosts wordpress-db"
```

---

## Detener y limpiar

```bash
# Parar y borrar contenedores
podman stop wordpress wordpress-db
podman rm wordpress wordpress-db

# Borrar la red
podman network rm mi-network

# Borrar el volumen de la DB (¡destruye los datos!)
podman volume rm wordpress-db

# Borrar la carpeta del bind mount (¡destruye los archivos de WP!)
rm -rf wordpress/

# (Opcional) borrar las imágenes
podman rmi docker.io/library/wordpress:4.9.8 docker.io/library/mariadb:10.3.9
```

---

## Capturas de pantalla

> Las imágenes están en la carpeta `screenshots/`.

<!-- Agregar capturas a medida que se generen, ej:
### 1. Containers corriendo
![podman ps](screenshots/01-ps.png)

### 2. Wizard de instalación de WordPress
![WP installer](screenshots/02-wp-installer.png)
-->
