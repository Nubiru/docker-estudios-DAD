#!/bin/bash

# Raíz del ejemplo (ejem07), calculada a partir de la ubicación de este script
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Creo el contenedor
podman run -itd --name nginx \
    -v "$ROOT/config/nginx":/etc/nginx/conf.d \
    -v "$ROOT/code/myapp":/var/www/html/myapp \
    -v "$ROOT/logs":/var/log/nginx \
    -p 8080:80 \
    --link php7 nginx

# Lo lanzo por si estaba parado
podman start nginx
