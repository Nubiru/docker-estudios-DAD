# Ejemplo 9 — Proxy inverso con Nginx (Nginx + Apache detrás) con Docker Compose

**Materia:** DAD
**Fecha:** 2026-06-16
**Repositorio base:** https://github.com/joseluisgs/docker-tutorial/tree/master (carpeta `ejemplos/ejem09`)

> Nota: este ejercicio se realizó con **Podman** + **podman compose** (no con Docker). El `docker-compose.yml` es declarativo y podman lo interpreta sin cambios de motor, pero **sí** hubo que corregir el archivo original del tutorial para que arranque limpio (ver _Errores encontrados_).

---

## Objetivo

Montar un **proxy inverso (reverse proxy)** con Nginx que es la única puerta de entrada desde el host y reparte el tráfico hacia **dos servidores web backend distintos**:

- Un sitio servido por **Nginx** (`site1`).
- Un sitio servido por **Apache / httpd** (`site2`).

Los backends **no publican puertos al host**: solo son accesibles a través del proxy, por la red interna de Compose. Es el patrón base de cualquier despliegue real (un único punto de entrada que enruta a varios servicios).

A diferencia del Ejemplo 7 (donde Nginx hacía de proxy *FastCGI* hacia PHP-FPM), aquí Nginx hace de **proxy HTTP** (`proxy_pass`) hacia otros servidores web completos.

---

## Arquitectura

```
                          red: mi-red (bridge)

   navegador :8080 ─┐                        ┌──► upstream docker-nginx
                    │   ┌────────────────┐   │    ┌───────────┐
                    ├──►│  reverseproxy  │───┤    │   nginx   │  (site1)
                    │   │ (nginx:alpine) │   │    │   :80     │
   navegador :8081 ─┘   │ listen 8080/81 │   │    └───────────┘
                        └────────────────┘   │
                                             └──► upstream docker-apache
                                                  ┌───────────┐
                                                  │  apache   │  (site2)
                                                  │   :80     │
                                                  └───────────┘
```

Flujo de una petición:

1. El navegador pide `http://localhost:8080/` → llega al `reverseproxy`.
2. El bloque `server { listen 8080; }` hace `proxy_pass http://docker-nginx`, que es el `upstream` apuntando a `nginx:80` (resuelto por DNS de la red de Compose).
3. El contenedor `nginx` (site1) devuelve su `index.html`.
4. Igual con `:8081` → `proxy_pass http://docker-apache` → contenedor `apache` (site2).

### Servicios (`docker-compose.yml`)

| Servicio | Imagen | Puerto host | Rol |
|---|---|---|---|
| `reverseproxy` | build local desde `reverse/Dockerfile` (`nginx:alpine` + `nginx.conf`) | `8080:8080`, `8081:8081` | Proxy inverso / único punto de entrada |
| `nginx` | build local desde `site1/Dockerfile` (`nginx:alpine`) | — (interno) | Backend 1 (sitio estático) |
| `apache` | build local desde `site2/Dockerfile` (`httpd:alpine`) | — (interno) | Backend 2 (sitio estático) |

### Estructura de carpetas

```
ejemplo-9/
├── README.md
├── docker-compose.yml        la pila completa (proxy + 2 backends + red)
├── reverse/
│   ├── Dockerfile            FROM nginx:alpine + copia nginx.conf
│   └── nginx.conf            upstreams + 2 server blocks (8080 y 8081)
├── site1/
│   ├── Dockerfile            FROM nginx:alpine + copia src/
│   └── src/index.html        "site1.example.com"
├── site2/
│   ├── Dockerfile            FROM httpd:alpine + copia src/
│   └── src/index.html        "site2.example.com"
└── screenshots/
```

---

## Errores encontrados (y corregidos respecto al tutorial)

El `ejem09` original **parece funcionar, pero arranca roto** y solo se "cura" por casualidad. Hubo dos correcciones:

### 1. `depends_on` invertido — el proxy arrancaba antes que sus backends (el error principal)

En el `docker-compose.yml` original, **`nginx` y `apache` declaraban `depends_on: reverseproxy`**. Es decir, el orden de arranque era:

```
reverseproxy  →  nginx  →  apache      (orden ORIGINAL, incorrecto)
```

El problema: Nginx **resuelve los nombres de los `upstream` al cargar la configuración**, no en cada petición. Si los backends todavía no existen, aborta el arranque. Al levantar la pila original, el proxy moría con:

```
[emerg] host not found in upstream "apache:80" in /etc/nginx/nginx.conf:14
```

¿Por qué entonces "funcionaba"? Porque el servicio tiene `restart: always`: el proxy se reiniciaba en bucle hasta que, ya con `nginx` y `apache` arriba, un reinicio conseguía resolver los nombres. Se ve en el contador de reinicios:

```bash
podman inspect reverseproxy --format '{{.RestartCount}}'   # → 1 (¡arrancó fallando!)
```

**Corrección:** invertir la dependencia para que el proxy arranque **el último**:

```yaml
  reverseproxy:
    depends_on:
      - nginx
      - apache
```

Orden de arranque corregido:

```
nginx  →  apache  →  reverseproxy       (CORRECTO)
```

Tras el cambio, `RestartCount` queda en `0` y no aparece el `host not found in upstream`.

> Nota: `depends_on` solo espera a que el contenedor **arranque**, no a que el servicio esté "listo". Para estáticos basta; en un caso real con servicios lentos se añadiría un `healthcheck` o un `resolver` en Nginx para re-resolver los upstreams en caliente.

### 2. Clave `version:` obsoleta

El archivo empezaba con `version: '3.7'`. En Compose v2 / `podman-compose` esa clave está **obsoleta** y solo genera un warning. Se eliminó.

### Sobre Podman

A diferencia del Ejemplo 7, **este ejercicio no trae scripts `.sh`** con comandos `docker` que adaptar: todo es declarativo. Por tanto la única "adaptación a Podman" es levantarlo con **`podman compose`** en lugar de `docker compose`. `podman compose` delega en `podman-compose` (1.0.6), que traduce el `depends_on` a `--requires=nginx,apache` en el `podman run` del proxy — exactamente el orden que buscábamos.

---

## Pasos ejecutados

```bash
cd ejemplo-9

# Construir las 3 imágenes locales y levantar la pila
podman compose up -d --build
```

Esto:

1. Construye `ejemplo-9_reverseproxy` (desde `reverse/`), `ejemplo-9_nginx` (desde `site1/`) y `ejemplo-9_apache` (desde `site2/`).
2. Crea la red `ejemplo-9_mi-red` (bridge).
3. Arranca los contenedores respetando el `depends_on` corregido: `nginx` y `apache` primero, `reverseproxy` al final.

---

## Verificación

```bash
# Estado de los 3 contenedores
podman ps --filter label=io.podman.compose.project=ejemplo-9 \
          --format "table {{.Names}}\t{{.Status}}"

# El proxy no falló al arrancar (debe ser 0)
podman inspect reverseproxy --format '{{.RestartCount}}'

# Backend Nginx a través del proxy
curl -s http://localhost:8080/

# Backend Apache a través del proxy
curl -s http://localhost:8081/
```

Salida obtenida (✅ proxy enrutando a los dos backends):

```html
<!-- http://localhost:8080/ -->
<title>site1.example.com</title> ... <h1>site1.example.com</h1>

<!-- http://localhost:8081/ -->
<title>site2.example.com</title> ... <h1>site2.example.com</h1>
```

- `:8080` devuelve **site1** → el proxy resolvió el upstream `docker-nginx` (`nginx:80`).
- `:8081` devuelve **site2** → el proxy resolvió el upstream `docker-apache` (`apache:80`).
- `RestartCount = 0` → con el `depends_on` corregido el proxy arranca limpio a la primera.

---

## Conceptos nuevos respecto al Ejemplo 7

| Concepto | Qué hace | Por qué importa |
|---|---|---|
| **Proxy inverso (`proxy_pass`)** | Nginx reenvía peticiones HTTP completas a otro servidor web | Patrón de entrada único que enruta a varios servicios backend |
| **`upstream`** | Define un grupo de servidores backend al que apuntar | Base para balanceo de carga (se añaden más `server` al bloque) |
| **Backends sin puerto publicado** | `nginx` y `apache` no exponen puertos al host | Solo el proxy es accesible; los servicios quedan en la red interna |
| **Orden de arranque (`depends_on`)** | Controla qué contenedor arranca antes | Nginx resuelve upstreams al inicio; el orden importa o falla |
| **`proxy_set_header`** | Reenvía `Host`, `X-Real-IP`, `X-Forwarded-For`… al backend | El backend conoce la IP/host reales del cliente, no los del proxy |

---

## Detener y limpiar

```bash
# Desde ejemplo-9 — baja contenedores + red
podman compose down

# (Opcional) borrar las imágenes locales construidas
podman rmi localhost/ejemplo-9_reverseproxy \
           localhost/ejemplo-9_nginx \
           localhost/ejemplo-9_apache
```

---

## Capturas de pantalla

> Las imágenes están en la carpeta `screenshots/`.

<!-- Agregar capturas a medida que se generen, ej:
### 1. `podman compose up -d --build`
![compose up](screenshots/01-compose-up.png)

### 2. site1 a través del proxy (:8080)
![site1](screenshots/02-site1.png)

### 3. site2 a través del proxy (:8081)
![site2](screenshots/03-site2.png)
-->
