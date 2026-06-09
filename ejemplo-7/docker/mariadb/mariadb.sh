#!/bin/bash

# Raíz del ejemplo (ejem07), calculada a partir de la ubicación de este script
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Lanzo el contenedor
podman run -d --name mariadb -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD=password \
    -e MYSQL_DATABASE=docker_sample \
    -v "$ROOT/mariadb/data:/var/lib/mysql" \
    -v "$ROOT/mariadb/sql:/docker-entrypoint-initdb.d" \
    mariadb:latest

# Lo lanzo por si estaba parado
podman start mariadb

# Si queremos un cliente por consola
#podman run -it --link mariadb --rm mariadb sh -c 'exec mysql
#    -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT"
#   -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'
