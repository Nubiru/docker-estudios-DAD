#!/bin/bash

# Raíz del ejemplo (ejem07), calculada a partir de la ubicación de este script
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Creo la imagen (el Dockerfile está junto a este script)
podman build -t joseluisgs/php-fpm "$(dirname "$0")"

# Lanzo el contenedor
podman run -itd --name php7 \
    --link mariadb \
    -v "$ROOT/config/php":/usr/local/etc/php \
    -v "$ROOT/code/myapp":/var/www/html/myapp \
    joseluisgs/php-fpm

# Lo lanzo por si estaba parado
podman start php7
