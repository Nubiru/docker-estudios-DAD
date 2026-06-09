#!/bin/bash
# Version adaptada a Podman del run.sh original (ver run.sh).
# Cambios respecto al original de Docker:
#   - docker  -> podman
#   - --mount source=... -> --mount type=volume,source=...  (Podman no infiere el type)
#   - --link sigue funcionando en Podman, pero es LEGACY (ver README, Ejemplo 3 usa red propia)

# 1) Contenedor de la base de datos (MariaDB) con volumen con nombre.
podman run -d --name wordpress-db \
    --mount type=volume,source=wordpress-db,target=/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_DATABASE=wordpress \
    -e MYSQL_USER=manager \
    -e MYSQL_PASSWORD=secret \
    mariadb:10.3.9

# 2) Contenedor de WordPress enlazado a la DB con --link (alias de red "mysql").
podman run -d --name wordpress \
    --link wordpress-db:mysql \
    --mount type=bind,source="$(pwd)"/wordpress,target=/var/www/html \
    -e WORDPRESS_DB_USER=manager \
    -e WORDPRESS_DB_PASSWORD=secret \
    -p 8080:80 \
    wordpress:4.9.8
