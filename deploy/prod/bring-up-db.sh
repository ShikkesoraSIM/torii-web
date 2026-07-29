#!/bin/bash
# torii: arma el esquema de osu-web adentro del mysql de g0v0. Se corre UNA vez,
# desde /home/toriiadm/torii-web en torii-eu.
#
#   ./deploy/prod/bring-up-db.sh
#
# Por que un script y no comandos a mano: son nueve pasos con un orden que
# importa, y el paso 5 mueve 25 tablas de lugar. Escrito, se revisa antes de
# correrlo y se puede volver a correr sabiendo que hace.
#
# NO es destructivo para osu_api: todo lo que crea va en el esquema osu, y sobre
# osu_api solo lee. El unico que escribe en osu_api es la app en caliente
# (favoritos, amigos, pins, perfil), no este script.
#
# Igual: antes de correrlo tiene que haber un dump fresco. Se verifica abajo.

set -euo pipefail
cd "$(dirname "$0")/../.."

COMPOSE="docker compose -f compose.yaml -f deploy/prod/compose.prod.yml"
SRC=osu_api
MYSQL="docker exec -i osu_api_mysql mysql -uroot -ppassword --default-character-set=utf8mb4"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------- 0 ----
say "0. hay un dump reciente?"
ULTIMO=$(ls -t /home/toriiadm/.backups/db-osu_api-*.sql.gz 2>/dev/null | head -1 || true)
if [ -z "$ULTIMO" ]; then
    echo "NO hay ningun dump de osu_api. Abortando." >&2
    echo "  docker exec osu_api_mysql mysqldump -uroot -ppassword --single-transaction \\" >&2
    echo "    --no-tablespaces osu_api | gzip > /home/toriiadm/.backups/db-osu_api-\$(date +%Y%m%d-%H%M%S).sql.gz" >&2
    exit 1
fi
echo "  $ULTIMO ($(du -h "$ULTIMO" | cut -f1), $(( ($(date +%s) - $(stat -c %Y "$ULTIMO")) / 3600 ))h)"

# ---------------------------------------------------------------------- 1 ----
say "1. migraciones de osu-web en el esquema osu"
# db:create crea los esquemas satelite; migrate levanta las ~191 tablas propias.
# --force porque APP_ENV=production le hace pedir confirmacion interactiva.
$COMPOSE run --rm --no-deps php artisan db:create
$COMPOSE run --rm --no-deps php artisan migrate --force

# ---------------------------------------------------------------------- 2 ----
say "2. columnas que hay que ensanchar"
# Los ids de beatmapset de Torii pasan de los 800.000.000 y osu-web los declara
# mediumint, que corta en 16.777.215.
$MYSQL < torii-schema-widen.sql

# ---------------------------------------------------------------------- 3 ----
say "3. catalogo de medallas y de grupos"
# Las medallas salen del codigo de g0v0, no de su base, asi que van como catalogo.
$MYSQL < torii-medals.sql
$MYSQL < torii-groups.sql

# ---------------------------------------------------------------------- 4 ----
say "4. mover las tablas proyectadas a osu_bak"
# Las 25 tablas que van a pasar a ser vistas se mudan en vez de borrarse: sirve
# para comparar contra lo que habia y para volver atras con un RENAME.
# Tambien salva el catalogo de paises, que es dato de osu-web y no de Torii.
$MYSQL < torii-views-swap.sql

# ---------------------------------------------------------------------- 5 ----
say "5. las tablas de cache (lo que no puede ser vista)"
# Agregados caros: plays por mapa, favoritos, nombres de difficulties, el
# grafico de fails y los primeros puestos. Tarda un rato.
TORII_SOURCE_SCHEMA=$SRC ./torii-render.sh torii-cache.sql | $MYSQL

# ---------------------------------------------------------------------- 6 ----
say "6. generar y crear las vistas"
# El tercer argumento es de donde leer las columnas que cada vista tiene que
# exponer: osu_bak, porque las tablas se acaban de mudar ahi.
$COMPOSE run --rm --no-deps php php /app/torii-views.php "$SRC" osu osu_bak > /tmp/torii-views-prod.sql
grep -c 'CREATE VIEW' /tmp/torii-views-prod.sql
$MYSQL < /tmp/torii-views-prod.sql
rm -f /tmp/torii-views-prod.sql

# ---------------------------------------------------------------------- 7 ----
say "7. la pagina de perfil de cada jugador"
# Vive en phpbb_posts porque es de donde la lee osu-web; la fuente sigue siendo
# lazer_users.page.
$COMPOSE run --rm --no-deps php php /app/torii-userpages.php

# ---------------------------------------------------------------------- 8 ----
say "8. indices de elasticsearch"
# El de scores es el que decide si los leaderboards de mapas y el Best
# Performance de los perfiles tienen algo adentro. Sin esto la web no se cae:
# muestra todo vacio y dice que cada score es #1 del mundo.
$COMPOSE run --rm --no-deps php php /app/torii-index-scores.php
$COMPOSE run --rm --no-deps php sh -c 'echo yes | php artisan es:index --yes' || true
$COMPOSE run --rm --no-deps php sh -c 'echo yes | php artisan es:index-wiki'

# ---------------------------------------------------------------------- 9 ----
say "9. control"
$MYSQL -N -e "
SELECT 'vistas en osu', COUNT(*) FROM information_schema.tables
  WHERE table_schema='osu' AND table_type='VIEW'
UNION ALL SELECT 'tablas en osu', COUNT(*) FROM information_schema.tables
  WHERE table_schema='osu' AND table_type='BASE TABLE'
UNION ALL SELECT 'jugadores', COUNT(*) FROM osu.phpbb_users
UNION ALL SELECT 'scores', COUNT(*) FROM osu.scores
UNION ALL SELECT 'beatmapsets', COUNT(*) FROM osu.osu_beatmapsets
UNION ALL SELECT 'grupos de torii', COUNT(*) FROM osu.phpbb_groups WHERE identifier LIKE 'torii-%'
UNION ALL SELECT 'osu_api INTACTO (usuarios)', COUNT(*) FROM ${SRC}.lazer_users;"

say "listo"
echo "Falta, y va aparte porque toca cosas de fuera de este stack:"
echo "  - la conf de nginx del host  (deploy/prod/nginx-host-torii-web.shikkesora.com.conf)"
echo "  - el dominio en el Caddyfile (deploy/prod/caddy-torii-web.snippet)"
echo "  - los cron de refresco       (deploy/prod/crontab.snippet)"
