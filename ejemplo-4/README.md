# Ejemplo 4 — WordPress + MariaDB con Docker Compose

**Materia:** DAD
**Fecha:** 2026-05-12
**Repositorio base:** https://github.com/joseluisgs/docker-tutorial/tree/master (carpeta `ejemplos/ejem04`)

> Nota: este ejercicio se realizó con **Podman** + **podman-compose** (no con Docker ni docker-compose). El archivo `docker-compose.yaml` es exactamente el mismo del tutorial — Compose es un formato declarativo y podman-compose lo interpreta sin cambios.

---

## Objetivo

Levantar la **misma pila** del Ejemplo 3 (WordPress + MariaDB) pero declarándola como código en un único archivo `docker-compose.yaml`, en lugar de ejecutar comandos `run` imperativos uno por uno.

El punto pedagógico es comparar los dos enfoques:

| Aspecto | Ejemplo 3 (run imperativo) | Ejemplo 4 (compose declarativo) |
|---|---|---|
| Definición | Comandos en `run.sh`, uno por contenedor | Un solo `docker-compose.yaml` |
| Estado | Implícito (lo que está corriendo ahora) | Explícito (lo que dice el YAML) |
| Red propia | `podman network create mi-network` a mano | Compose la crea automáticamente (`<proyecto>_default`) |
| Volumen con nombre | `--mount type=volume,source=...` por container | Sección `volumes:` al final del YAML |
| Orden de arranque | Hay que respetarlo manualmente (DB antes que WP) | `depends_on` lo declara |
| Levantar todo | Dos `podman run` largos | `podman-compose up -d` |
| Bajar todo | `stop` + `rm` + `network rm` + `volume rm` | `podman-compose down -v` |
| Idempotente | No (hay que cuidar duplicados) | Sí (compose reconcilia con el estado) |

---

## Archivo `docker-compose.yaml`

```yaml
version: '3'

services:
  db:
    image: mariadb:10.3.9
    container_name: mariadb
    volumes:
      - data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=secret
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=manager
      - MYSQL_PASSWORD=secret
  web:
    image: wordpress:4.9.8
    container_name: wordpress
    depends_on:
      - db
    volumes:
      - ./wordpress:/var/www/html
    environment:
      - WORDPRESS_DB_USER=manager
      - WORDPRESS_DB_PASSWORD=secret
      - WORDPRESS_DB_HOST=db
    ports:
      - 8080:80

volumes:
  data:
```

Cosas a notar leyendo el YAML:

- **`services:`** — cada entrada define un contenedor. Los nombres `db` y `web` también funcionan como **alias DNS** dentro de la red de Compose. Por eso `WORDPRESS_DB_HOST=db` resuelve correctamente: no hace falta el `wordpress-db` literal del Ejemplo 3.
- **`container_name:`** — fuerza el nombre del contenedor (sin esto, Compose usa `<proyecto>_<servicio>_<n>`).
- **`depends_on:`** — Compose levanta `db` antes que `web`. Importante: esto **solo garantiza el orden de arranque**, no que la DB esté lista para conexiones. Para eso real, WordPress reintenta la conexión hasta que funciona.
- **`volumes:` en cada servicio** — dos formatos:
  - `data:/var/lib/mysql` — volumen con nombre (definido al final del YAML como `volumes: data:`)
  - `./wordpress:/var/www/html` — bind mount relativo al directorio del `docker-compose.yaml`
- **`version: '3'`** — etiqueta de la versión del esquema. En las versiones modernas del Compose Spec ya no es necesaria y es ignorada, pero queda por compatibilidad con el archivo original del tutorial.

---

## Errores encontrados

**Ninguno.** A diferencia del Ejemplo 3 (que necesitó corregir `--mount` sin `type=` y reemplazar `--link`), Compose es un formato **abstracto** que oculta esas diferencias entre Docker y Podman. `podman-compose` interpreta el YAML y emite por debajo los `podman run` con la sintaxis correcta para Podman.

Esto deja claro **por qué Compose es preferible** para definir stacks: el mismo archivo funciona en distintos motores de contenedores sin tocarlo.

---

## Pasos ejecutados

Antes de empezar fue necesario **detener el stack del Ejemplo 3** para liberar el puerto 8080 y el nombre `wordpress`, ya que ejem04 reusa ambos:

```bash
podman stop wordpress wordpress-db
podman rm wordpress wordpress-db
podman network rm mi-network
podman volume rm wordpress-db
```

Luego:

```bash
# Desde la carpeta que contiene el docker-compose.yaml
cd ejemplo-4

# Levantar la pila completa en segundo plano
podman-compose up -d
```

Salida resumida — podman-compose tradujo el YAML a comandos `podman` concretos:

```
podman volume create ejemplo-4_data
podman network create ejemplo-4_default
podman run --name=mariadb ... -v ejemplo-4_data:/var/lib/mysql --net ejemplo-4_default ... mariadb:10.3.9
podman run --name=wordpress --requires=mariadb ... --net ejemplo-4_default -p 8080:80 ... wordpress:4.9.8
```

Notar cómo Compose **prefija con el nombre del proyecto** (`ejemplo-4`, tomado del nombre de la carpeta) el volumen y la red. Esto evita colisiones entre distintos proyectos compose en la misma máquina.

---

## Conceptos nuevos respecto al Ejemplo 3

| Concepto | Qué hace | Por qué importa |
|---|---|---|
| **Infraestructura como código (IaC)** | El stack está definido en un archivo versionable | Reproducibilidad: cualquiera que clone el repo levanta lo mismo |
| **Project scoping** | Compose prefija recursos con el nombre del proyecto | Permite tener múltiples stacks en la misma máquina sin colisiones |
| **`depends_on`** | Orden de arranque declarativo | Reemplaza el orden imperativo del `run.sh` |
| **DNS por nombre de servicio** | `db` en lugar de `wordpress-db` | El nombre del servicio en el YAML actúa como hostname dentro de la red del proyecto |
| **Tear-down con un comando** | `podman-compose down` baja todo el stack | Reemplaza la lista de `stop` + `rm` + `network rm` + `volume rm` |

---

## Verificación / comandos útiles

```bash
# Estado de los containers del proyecto compose
podman-compose ps
# o, equivalente sin compose
podman ps --filter "label=io.podman.compose.project=ejemplo-4"

# Logs en vivo de un servicio puntual
podman-compose logs -f web
podman-compose logs -f db

# Logs de todos los servicios juntos
podman-compose logs -f

# Verificar que WP responde (302 al wizard de instalación)
curl -I http://localhost:8080

# Confirmar que el bind mount tiene los archivos de WP
ls wordpress/

# Inspeccionar la red creada por compose
podman network inspect ejemplo-4_default

# Verificar el DNS interno: 'db' debe resolver desde el container web
podman exec -it wordpress bash -c "getent hosts db"

# Abrir un shell en un servicio
podman-compose exec web bash
podman-compose exec db bash
```

---

## Detener y limpiar

```bash
# Bajar containers + red (mantiene volumen e imágenes)
podman-compose down

# Bajar TODO, incluyendo el volumen con nombre — ¡destruye los datos de la DB!
podman-compose down -v

# Borrar también la carpeta del bind mount (los archivos de WordPress)
rm -rf wordpress/

# (Opcional) borrar las imágenes
podman rmi docker.io/library/wordpress:4.9.8 docker.io/library/mariadb:10.3.9
```

---

## Capturas de pantalla

> Las imágenes están en la carpeta `screenshots/`.

<!-- Agregar capturas a medida que se generen, ej:
### 1. Salida de `podman-compose up -d`
![compose up](screenshots/01-compose-up.png)

### 2. Containers corriendo (`podman-compose ps`)
![compose ps](screenshots/02-compose-ps.png)

### 3. Wizard de instalación de WordPress
![WP installer](screenshots/03-wp-installer.png)
-->
