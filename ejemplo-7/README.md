# Ejemplo 7 — Pila LEMP (Nginx + PHP-FPM + MariaDB + phpMyAdmin) con Docker Compose

**Materia:** DAD
**Fecha:** 2026-06-09
**Repositorio base:** https://github.com/joseluisgs/docker-tutorial/tree/master (carpeta `ejemplos/ejem07`)

> Nota: este ejercicio se realizó con **Podman** + **podman compose** (no con Docker). El `docker-compose.yml` es declarativo y podman lo interpreta sin cambios, pero **sí** hubo que corregir el archivo original del tutorial (ver _Errores encontrados_).

---

## Objetivo

Levantar una pila **LEMP** completa multi-contenedor, declarada con Docker Compose:

- **L**inux (la imagen base de cada contenedor)
- **E** = Nginx (servidor web / proxy hacia PHP-FPM)
- **M**ariaDB (base de datos)
- **P**HP-FPM (intérprete PHP por FastCGI)

Más un contenedor extra de **phpMyAdmin** para administrar la base de datos por web.

A diferencia del Ejemplo 4 (WordPress, una sola app), aquí Nginx y PHP están **separados en dos contenedores** y se comunican por FastCGI, que es el patrón real de producción para una pila LEMP.

---

## Arquitectura

```
                       red: lemp-network (bridge)
  ┌───────────┐  :8080  ┌───────────┐  fastcgi   ┌───────────┐
  │ navegador │ ──────► │   nginx   │ ─────────► │   php7    │
  └───────────┘   80    │ (estático │  php7:9000 │ (php-fpm) │
                        │  + proxy) │            └─────┬─────┘
                        └───────────┘                  │ PDO
  ┌───────────┐  :8081  ┌───────────┐                  │ mariadb:3306
  │ navegador │ ──────► │phpmyadmin │ ─────────────────┤
  └───────────┘   80    └───────────┘                  ▼
                                                 ┌───────────┐
                                                 │  mariadb  │
                                                 │  :3306    │
                                                 └───────────┘
```

Flujo de una petición a `http://localhost:8080/`:

1. Nginx recibe la petición. Su `root` es `/var/www/html/myapp`.
2. Para un `.php`, Nginx **no lo ejecuta**: lo reenvía por FastCGI a `php7:9000` (el contenedor PHP-FPM, resuelto por DNS de la red de Compose).
3. PHP-FPM ejecuta `index.php`, que se conecta por **PDO** al host `mariadb` (nombre del servicio) y consulta la tabla `usuarios`.
4. La respuesta vuelve por la misma cadena hasta el navegador.

### Servicios (`docker/docker-compose.yml`)

| Servicio | Imagen | Puerto host | Rol |
|---|---|---|---|
| `php7` | build local desde `docker/php/Dockerfile` (`php:8.2-fpm` + `mysqli pdo pdo_mysql`) | — (interno) | Intérprete PHP por FastCGI |
| `nginx` | `nginx` | `8080:80` | Servidor web / proxy FastCGI |
| `mariadb` | `mariadb:latest` | `3306:3306` | Base de datos |
| `phpmyadmin` | `phpmyadmin/phpmyadmin` | `8081:80` | Administración web de la BD |

### Estructura de carpetas

```
ejemplo-7/
├── README.md
├── code/myapp/index.php          app PHP: conecta a MariaDB y lista usuarios
├── config/
│   ├── nginx/myapp.conf          server block de Nginx (root + proxy FastCGI)
│   └── php/php.ini               config de PHP montada en el contenedor
├── mariadb/
│   ├── sql/init-db.sql           crea tabla 'usuarios' y la rellena (seed)
│   └── data/                     datos de MariaDB (gitignored, runtime)
├── logs/                         logs de Nginx (gitignored, runtime)
└── docker/
    ├── docker-compose.yml        la pila completa
    ├── run.sh                    alternativa imperativa (orquesta los .sh)
    ├── php/Dockerfile            imagen PHP-FPM
    ├── php/php.sh                arranque manual del contenedor PHP
    ├── nginx/nginx.sh            arranque manual de Nginx
    ├── mariadb/mariadb.sh        arranque manual de MariaDB
    └── phpmyadmin/phpmyadmin.sh  arranque manual de phpMyAdmin
```

---

## Errores encontrados (y corregidos respecto al tutorial)

El `ejem07` original **no levanta tal cual**. Hubo cuatro correcciones:

### 1. La tabla `usuarios` nunca se creaba — el error principal

`index.php` hace `SELECT nombre, email FROM usuarios`, y el repo incluye `mariadb/sql/init-db.sql` que crea y rellena esa tabla… **pero el `docker-compose.yml` original nunca montaba ese SQL en ninguna parte**. Resultado: la app conectaba a la BD pero fallaba con _"Table doesn't exist"_.

La imagen oficial de MariaDB ejecuta automáticamente cualquier `.sql`/`.sh` que encuentre en `/docker-entrypoint-initdb.d` **la primera vez** que arranca (cuando el directorio de datos está vacío). La corrección fue montar el SQL ahí:

```yaml
  mariadb:
    volumes:
      - ../mariadb/data:/var/lib/mysql
      - ../mariadb/sql:/docker-entrypoint-initdb.d   # ← faltaba
```

> Ojo: el seed solo corre con el directorio `data/` **vacío**. Para re-sembrar: `podman compose down` y luego `rm -rf mariadb/data/*` antes de volver a levantar.

### 2. Rutas absolutas hardcodeadas a la máquina del profesor

Tanto el `docker-compose.yml` como los `*.sh` usaban rutas tipo
`/home/informatica/Dropbox/Puertollano 2020-2021/DAW/Temario/...` que no existen en mi equipo.

- En el compose se reemplazaron por **rutas relativas** al archivo (`../config/php`, `../code/myapp`, etc.).
- En los scripts `.sh` se calcula la raíz del ejemplo desde la propia ubicación del script: `ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`, de modo que funcionan sin importar desde dónde se ejecuten.

### 3. Adaptación a Podman

Como en los ejemplos anteriores, en los scripts `.sh` se reemplazó `docker` → `podman`. El `docker-compose.yml` no necesitó este cambio (Compose es agnóstico al motor), pero se levanta con `podman compose` en lugar de `docker compose`.

### 4. Modernización y arreglos menores

- **PHP `7.4-fpm` → `8.2-fpm`** en el `Dockerfile` (misma actualización que en el Ejemplo 1).
- **phpMyAdmin**: el `links: mariadb:db` original es frágil. Se sustituyó por las variables de entorno `PMA_HOST=mariadb` / `PMA_PORT=3306`, que es la forma soportada por la imagen oficial.
- En `phpmyadmin.sh` el contenedor estaba mal escrito (`phmyadmin`) y la línea `--link mariadb:db\` no tenía espacio; corregido.

---

## Pasos ejecutados

```bash
# Desde la carpeta que contiene el compose
cd ejemplo-7/docker

# Validar que las rutas relativas resuelven, sin levantar nada
podman compose config

# Construir la imagen de PHP y levantar la pila completa
podman compose up -d --build
```

Esto:

1. Construye la imagen `localhost/docker_php7` desde `docker/php/Dockerfile`.
2. Descarga `nginx`, `mariadb:latest` y `phpmyadmin/phpmyadmin`.
3. Crea la red `docker_lemp-network` y arranca los cuatro contenedores respetando `depends_on` (mariadb → php7 → nginx).
4. MariaDB ejecuta `init-db.sql` al inicializarse por primera vez.

---

## Verificación

```bash
# Estado de los contenedores
podman compose ps

# La app: lista los usuarios sembrados desde init-db.sql
curl -s http://localhost:8080/
```

Salida obtenida (✅ pila funcionando de extremo a extremo):

```html
<h1>HOLA</h1><h3>He montado LEMP</h3>Conexión Realizada con éxito
<p>Jose - Vue<p>Victor - Aparejador<p>Soraya - Angular<p>Luis - Docker
```

- `Conexión Realizada con éxito` → PHP-FPM se conectó a MariaDB por la red de Compose.
- Las cuatro filas → la tabla `usuarios` se creó y rellenó desde `init-db.sql` (la corrección nº 1).

> **Importante sobre la URL:** es `http://localhost:8080/` (o `/index.php`), **no** `/myapp/...`. El `root` de Nginx ya apunta a `/var/www/html/myapp`, así que la app vive en la raíz web. Pedir `/myapp/index.php` da 404 (buscaría `.../myapp/myapp/index.php`).

**phpMyAdmin:** http://localhost:8081 → servidor `mariadb`, usuario `root`, contraseña `password`.

---

## Conceptos nuevos respecto al Ejemplo 4

| Concepto | Qué hace | Por qué importa |
|---|---|---|
| **Nginx + PHP-FPM separados** | El servidor web y el intérprete PHP son dos contenedores que hablan por FastCGI | Patrón real de producción LEMP; permite escalar PHP y web por separado |
| **FastCGI (`fastcgi_pass php7:9000`)** | Nginx delega la ejecución de `.php` al contenedor PHP-FPM | Nginx no ejecuta PHP; solo sirve estáticos y hace de proxy |
| **`/docker-entrypoint-initdb.d`** | MariaDB ejecuta SQL de inicialización al primer arranque | Forma estándar de sembrar datos sin entrar al contenedor a mano |
| **`build:` en un servicio** | Compose construye una imagen local desde un Dockerfile | Combina imágenes de registro (`nginx`, `mariadb`) con imágenes propias |
| **Rutas relativas en el compose** | Bind mounts relativos al archivo YAML | El proyecto es portable: se clona y funciona sin editar rutas |

---

## Detener y limpiar

```bash
# Desde ejemplo-7/docker
# Bajar contenedores + red (mantiene la imagen de PHP y los datos en mariadb/data/)
podman compose down

# Re-sembrar la base de datos desde cero (borra los datos persistidos)
rm -rf ../mariadb/data/*

# (Opcional) borrar la imagen local de PHP construida
podman rmi localhost/docker_php7
```

---

## Capturas de pantalla

> Las imágenes están en la carpeta `screenshots/`.

<!-- Agregar capturas a medida que se generen, ej:
### 1. `podman compose up -d --build`
![compose up](screenshots/01-compose-up.png)

### 2. App en :8080 listando usuarios
![app](screenshots/02-app.png)

### 3. phpMyAdmin en :8081
![phpmyadmin](screenshots/03-phpmyadmin.png)
-->
