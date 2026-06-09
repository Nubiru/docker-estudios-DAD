# Ejemplo 2 — Interpretación y ejecución manual de `run.sh`

**Materia:** DAD
**Repositorio base:** https://github.com/joseluisgs/docker-tutorial/tree/master (carpeta `ejemplos/ejem02`)

> Nota: este ejercicio se realizó con **Podman** (no con Docker). Los comandos `docker ...` del `run.sh` original se reemplazan por `podman ...`. La versión adaptada está en [`run-podman.sh`](./run-podman.sh); el original sin tocar, en [`run.sh`](./run.sh).

---

## Objetivo

A diferencia de los otros ejercicios (que parten de un `Dockerfile`), aquí el material es un **script `run.sh`** que levanta una pila **WordPress + MariaDB**. El objetivo es **interpretar línea por línea** qué hace el script y **ejecutarlo manualmente**, entendiendo cada flag antes de automatizarlo.

Este ejemplo es el **precursor conceptual del Ejemplo 3**: monta el mismo stack, pero usando el mecanismo **`--link`** (heredado/legacy) en lugar de una red propia. Por eso el Ejemplo 3 "corrige" este enfoque con `podman network`.

---

## El script original

```bash
# 1) Contenedor de la base de datos
docker run -d --name wordpress-db \
    --mount source=wordpress-db,target=/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_DATABASE=wordpress \
    -e MYSQL_USER=manager \
    -e MYSQL_PASSWORD=secret \
    mariadb:10.3.9

# 2) Contenedor de WordPress
docker run -d --name wordpress \
    --link wordpress-db:mysql \
    --mount type=bind,source="$(pwd)"/wordpress,target=/var/www/html \
    -e WORDPRESS_DB_USER=manager \
    -e WORDPRESS_DB_PASSWORD=secret \
    -p 8080:80 \
    wordpress:4.9.8
```

---

## Interpretación línea por línea

### Contenedor 1 — MariaDB (`wordpress-db`)

| Flag | Qué hace |
|---|---|
| `-d` | *Detached*: el contenedor corre en segundo plano y devuelve la terminal. |
| `--name wordpress-db` | Le da un nombre fijo al contenedor (en vez de uno aleatorio), para poder referenciarlo después (en el `--link`). |
| `--mount source=wordpress-db,target=/var/lib/mysql` | Monta un **volumen con nombre** (`wordpress-db`) en el directorio de datos de MariaDB. Así los datos **persisten** aunque se borre el contenedor. |
| `-e MYSQL_ROOT_PASSWORD=secret` | Contraseña del usuario `root` de MySQL/MariaDB (obligatoria para arrancar la imagen). |
| `-e MYSQL_DATABASE=wordpress` | Crea automáticamente una base de datos vacía llamada `wordpress` al iniciar. |
| `-e MYSQL_USER=manager` / `-e MYSQL_PASSWORD=secret` | Crea un usuario `manager` con permisos sobre esa base. |
| `mariadb:10.3.9` | Imagen y tag a usar. |

### Contenedor 2 — WordPress (`wordpress`)

| Flag | Qué hace |
|---|---|
| `-d` / `--name wordpress` | Igual que antes: segundo plano + nombre fijo. |
| `--link wordpress-db:mysql` | **(El punto clave)** Enlaza este contenedor con `wordpress-db` y le da el **alias de red `mysql`**. Dentro del contenedor de WordPress, el host `mysql` resuelve a la IP de la base de datos. |
| `--mount type=bind,source="$(pwd)"/wordpress,target=/var/www/html` | **Bind mount**: expone la carpeta `./wordpress` del host dentro del contenedor, en la raíz web de Apache. Permite ver/editar los archivos de WordPress desde el host. |
| `-e WORDPRESS_DB_USER=manager` / `-e WORDPRESS_DB_PASSWORD=secret` | Credenciales con las que WordPress se conecta a la base (coinciden con las del contenedor 1). |
| `-p 8080:80` | Publica el puerto 80 del contenedor en el **8080 del host** → WordPress queda accesible en `http://localhost:8080`. |
| `wordpress:4.9.8` | Imagen y tag. |

> **Detalle importante:** el script **no** define `WORDPRESS_DB_HOST`. La imagen de WordPress usa `mysql` como host por defecto — y justamente por eso el `--link` le pone el alias `mysql` a la base. Si se quitara el `--link` sin más, WordPress no encontraría la DB.

---

## Adaptación a Podman

Dos ajustes respecto al original (los mismos criterios que en el Ejemplo 3):

1. **`--mount` necesita `type=`.** Docker infiere `type=volume` cuando `source` es un nombre; Podman no. Hay que escribir `--mount type=volume,source=wordpress-db,target=/var/lib/mysql`.
2. **`--link` es *legacy*.** Funciona en Podman dentro de la red por defecto, pero está **deprecado** tanto en Docker como en Podman. El enfoque moderno es crear una **red de usuario** donde los contenedores se resuelven por nombre automáticamente — que es exactamente lo que hace el **Ejemplo 3**.

La versión lista para correr está en [`run-podman.sh`](./run-podman.sh).

---

## Ejecución manual (paso a paso)

```bash
# 1. Levantar la base de datos
podman run -d --name wordpress-db \
    --mount type=volume,source=wordpress-db,target=/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret -e MYSQL_DATABASE=wordpress \
    -e MYSQL_USER=manager -e MYSQL_PASSWORD=secret \
    mariadb:10.3.9

# 2. Esperar unos segundos a que MariaDB inicialice, luego levantar WordPress
podman run -d --name wordpress \
    --link wordpress-db:mysql \
    --mount type=bind,source="$(pwd)"/wordpress,target=/var/www/html \
    -e WORDPRESS_DB_USER=manager -e WORDPRESS_DB_PASSWORD=secret \
    -p 8080:80 \
    wordpress:4.9.8

# 3. Verificar
podman ps                      # ambos contenedores "Up"
# Navegar a http://localhost:8080 -> instalador de WordPress

# 4. Limpieza
podman stop wordpress wordpress-db
podman rm   wordpress wordpress-db
podman volume rm wordpress-db   # opcional: borra los datos persistidos
```

---

## Conclusión

`run.sh` automatiza, en dos comandos, lo que de otro modo serían muchos pasos manuales. La pieza pedagógica central es el **`--link`**: entender que crea un **alias de red** (`mysql`) entre contenedores. Como `--link` quedó obsoleto, el siguiente ejercicio ([Ejemplo 3](../ejemplo-3/)) reemplaza este mecanismo por una **red propia** (`podman network create`), y el [Ejemplo 4](../ejemplo-4/) lo lleva a **Docker Compose**.
