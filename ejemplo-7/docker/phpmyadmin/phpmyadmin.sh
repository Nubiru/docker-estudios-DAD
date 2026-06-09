#!/bin/bash

# Lanzo el contenedor
podman run -d --name phpmyadmin \
    --link mariadb:db \
    -e PMA_HOST=mariadb \
    -e PMA_PORT=3306 \
    -p 8081:80 \
    phpmyadmin/phpmyadmin

# Lo lanzo por si estaba parado
podman start phpmyadmin
