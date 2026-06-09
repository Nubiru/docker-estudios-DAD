# docker-estudios-DAD

Estudios y prácticas de **Docker / Podman** para la materia **DAD** (Desarrollo de Aplicaciones Distribuidas).

**Autor:** Nubiru
**Materia:** DAD
**Repositorio base de los ejercicios:** https://github.com/joseluisgs/docker-tutorial

---

## Sobre el entorno

Todos los ejercicios se realizan con **Podman** (no Docker). Podman es compatible con la sintaxis de Dockerfile y los registros de imágenes, por lo que cada comando `docker ...` se reemplaza por `podman ...` sin cambios adicionales.

```bash
# Verificar versión
podman --version
```

---

## Ejercicios

| Carpeta | Tema | Estado |
|---|---|---|
| [`ejemplo-1/`](./ejemplo-1/) | Apache + PHP, edición de archivos dentro del contenedor en ejecución (`podman exec`), instalación de vim y corrección del Dockerfile | ✅ Completado |
| [`ejemplo-2/`](./ejemplo-2/) | Interpretación y ejecución manual de `run.sh` (WordPress + MariaDB con `--link` legacy) | ✅ Completado |
| [`ejemplo-3/`](./ejemplo-3/) | WordPress + MariaDB con red propia, volúmenes con nombre y bind mounts (multi-contenedor) | ✅ Completado |
| [`ejemplo-4/`](./ejemplo-4/) | Mismo stack que el Ejemplo 3 pero declarado con Docker Compose (`docker-compose.yaml`) | ✅ Completado |
| [`ejemplo-7/`](./ejemplo-7/) | Pila LEMP con Compose: Nginx + PHP-FPM (contenedores separados, FastCGI) + MariaDB (con seed `init-db.sql`) + phpMyAdmin | ✅ Completado |

Cada carpeta `ejemplo-N/` contiene su propio `README.md` con el detalle del ejercicio, los errores encontrados, las decisiones tomadas y las capturas de pantalla.

---

## Estructura del repositorio

```
docker/
├── README.md           ← este archivo
├── .gitignore
├── ejemplo-1/          Apache + PHP (Dockerfile, podman exec)
│   ├── README.md
│   └── screenshots/
├── ejemplo-2/          Interpretación de run.sh (WordPress + MariaDB, --link)
│   ├── README.md
│   ├── run.sh          original (Docker)
│   └── run-podman.sh   versión adaptada a Podman
├── ejemplo-3/          WordPress + MariaDB con red propia y volúmenes
│   ├── README.md
│   └── wordpress/
├── ejemplo-4/          Mismo stack con Docker Compose
│   ├── README.md
│   ├── docker-compose.yaml
│   └── wordpress/
└── ejemplo-7/          Pila LEMP (Nginx + PHP-FPM + MariaDB + phpMyAdmin)
    ├── README.md
    ├── code/myapp/     app PHP (index.php)
    ├── config/         configs de nginx y php
    ├── mariadb/sql/    init-db.sql (seed de la BD)
    └── docker/         docker-compose.yml, Dockerfile de PHP y scripts .sh
```
