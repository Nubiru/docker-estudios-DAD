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
| `ejemplo-2/` | Interpretación y ejecución manual de `run.sh` | ⏳ Pendiente |
| `ejemplo-3/` | — | ⏳ Pendiente |

Cada carpeta `ejemplo-N/` contiene su propio `README.md` con el detalle del ejercicio, los errores encontrados, las decisiones tomadas y las capturas de pantalla.

---

## Estructura del repositorio

```
docker/
├── README.md           ← este archivo
├── .gitignore
└── ejemplo-1/
    ├── README.md       ← detalle del ejercicio 1
    └── screenshots/    ← capturas de pantalla del proceso
```
