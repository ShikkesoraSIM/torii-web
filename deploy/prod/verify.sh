#!/bin/bash
# torii: control de que el sitio esta sano. Se corre despues de cada deploy.
#
#   ./deploy/prod/verify.sh              contra el contenedor (127.0.0.1:8090)
#   ./deploy/prod/verify.sh https://torii-web.shikkesora.com
#
# No alcanza con mirar codigos de estado: la mitad de los defectos que encontro
# la auditoria devolvian 200. Las paginas legales daban 200 con el cuerpo
# diciendo "not found", y todos los leaderboards daban 200 con cero scores
# adentro porque el indice de elasticsearch estaba vacio. Asi que aca se mira el
# CONTENIDO.

set -uo pipefail
cd "$(dirname "$0")/../.."

BASE="${1:-http://127.0.0.1:8090}"
HOST_HEADER=()
if [[ "$BASE" == http://127.0.0.1* ]]; then
    # Sin el Host, nginx del contenedor entra por el default_server y Laravel
    # arma las urls con APP_URL igual, pero el chequeo de origen se queja.
    HOST_HEADER=(-H "Host: torii-web.shikkesora.com")
fi

MYSQL="docker exec -i osu_api_mysql mysql -uroot -ppassword -N --default-character-set=utf8mb4"
fallos=0

ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mMAL\033[0m  %s\n' "$*"; fallos=$((fallos + 1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

get() { curl -s --max-time 30 "${HOST_HEADER[@]}" "$BASE$1"; }
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "${HOST_HEADER[@]}" "$BASE$1"; }

# --------------------------------------------------------------- paginas -----
head_ "paginas"
for u in / /rankings/osu/global "/rankings/osu/global?variant=rx" /rankings/points \
         /rankings/osu/country /beatmapsets /community/forums /wiki/en/Main_page \
         /wiki/en/Rules /home/download; do
    c=$(code "$u")
    [ "$c" = "200" ] && ok "$u" || bad "$u devolvio $c"
done

# --------------------------------------------------- contenido, no estado ----
head_ "que las paginas tengan algo adentro"

n=$(get / | grep -oE '[0-9,]+ registered players' | head -1)
[ -n "$n" ] && ok "portada: $n" || bad "portada: no aparece el contador de jugadores"

filas=$(get /rankings/osu/global | grep -c 'ranking-page-table__row')
[ "$filas" -ge 40 ] && ok "ranking global: $filas filas" || bad "ranking global: solo $filas filas"

filas=$(get "/rankings/osu/global?variant=rx" | grep -c 'ranking-page-table__row')
[ "$filas" -ge 10 ] && ok "ranking de relax: $filas filas" || bad "ranking de relax: solo $filas filas"

filas=$(get /rankings/points | grep -c 'ranking-page-table__row')
[ "$filas" -ge 10 ] && ok "ranking de puntos: $filas filas" || bad "ranking de puntos: solo $filas filas"

# Las legales devuelven 200 con el cuerpo de "not found" cuando faltan del repo
# de la wiki. Es el caso que se le escapa a cualquier chequeo por estado.
for u in /legal/en/Terms /legal/en/Privacy /legal/en/Copyright; do
    if get "$u" | grep -q 'could not be found'; then
        bad "$u da 200 pero dice not found"
    else
        ok "$u"
    fi
done

palabras=$(get /wiki/en/Rules | sed 's/<[^>]*>/ /g' | wc -w)
[ "$palabras" -ge 300 ] && ok "wiki Rules: $palabras palabras" || bad "wiki Rules: solo $palabras palabras"

# ------------------------------------------------------- elasticsearch -------
head_ "elasticsearch (de aca salen los leaderboards y el Best Performance)"

docs=$(docker compose -f compose.yaml -f deploy/prod/compose.prod.yml exec -T elasticsearch \
        curl -s 'localhost:9200/scores/_count' 2>/dev/null | grep -oE '"count":[0-9]+' | cut -d: -f2)
docs=${docs:-0}
if [ "$docs" -gt 1000 ]; then
    ok "indice de scores: $docs documentos"
else
    bad "indice de scores: $docs documentos. Con el indice vacio la web no se cae, MIENTE:"
    bad "  leaderboards vacios, Best Performance vacio, y cada score diciendo que es #1"
fi

# Un leaderboard de verdad, del mapa mas jugado.
mapa=$($MYSQL -e "SELECT beatmap_id FROM osu.scores WHERE ranked=1 AND preserve=1 AND passed=1
                  GROUP BY beatmap_id ORDER BY COUNT(*) DESC LIMIT 1;" 2>/dev/null)
if [ -n "$mapa" ]; then
    sc=$(get "/beatmaps/$mapa/scores?type=global&mode=osu" | grep -oE '"score_count":[0-9]+' | cut -d: -f2)
    [ "${sc:-0}" -gt 0 ] && ok "leaderboard del mapa $mapa: ${sc} scores" \
                         || bad "leaderboard del mapa $mapa: vacio (la base tiene scores)"
fi

# ------------------------------------------------------------- las vistas ----
head_ "las vistas contra la fuente"
$MYSQL -e "
SELECT CONCAT(t.q, ': vista=', t.v, ' fuente=', t.f, IF(t.v = t.f, '  ok', '  DIFIERE'))
FROM (
  SELECT 'jugadores' q, (SELECT COUNT(*) FROM osu.phpbb_users) v,
         (SELECT COUNT(*) FROM osu_api.lazer_users WHERE username IS NOT NULL AND username <> '') f
  UNION ALL
  SELECT 'scores', (SELECT COUNT(*) FROM osu.scores),
         (SELECT COUNT(*) FROM osu_api.scores WHERE gamemode IN ('OSU','TAIKO','FRUITS','MANIA'))
  UNION ALL
  SELECT 'equipos', (SELECT COUNT(*) FROM osu.teams), (SELECT COUNT(*) FROM osu_api.teams)
  UNION ALL
  SELECT 'favoritos', (SELECT COUNT(*) FROM osu.osu_favouritemaps),
         (SELECT COUNT(*) FROM osu_api.favourite_beatmapset)
) t;" 2>/dev/null | sed 's/^/  /'

paises=$($MYSQL -e "SELECT COUNT(*) FROM osu.torii_country_catalog;" 2>/dev/null)
[ "${paises:-0}" -gt 100 ] && ok "catalogo de paises: $paises" \
   || bad "catalogo de paises: ${paises:-0}. Sin el, el ranking por pais queda vacio (falta artisan db:seed)"

# ------------------------------------------------------ que no se rompio -----
head_ "que el servidor de juego siga entero"
u=$($MYSQL -e "SELECT COUNT(*) FROM osu_api.lazer_users;" 2>/dev/null)
s=$($MYSQL -e "SELECT COUNT(*) FROM osu_api.scores;" 2>/dev/null)
ok "osu_api: $u usuarios, $s scores"

conn=$($MYSQL -e "SELECT COUNT(*) FROM performance_schema.processlist WHERE user='toriiweb';" 2>/dev/null)
ok "conexiones de la web abiertas ahora: ${conn:-?} (tope 40)"

# -------------------------------------------------------------- errores ------
head_ "errores en el log"
errs=$(docker compose -f compose.yaml -f deploy/prod/compose.prod.yml exec -T php \
        sh -c 'tail -400 /app/storage/logs/laravel.log 2>/dev/null | grep -ac "production.ERROR"' 2>/dev/null)
[ "${errs:-0}" -eq 0 ] && ok "sin errores en las ultimas 400 lineas" \
   || bad "${errs} errores en las ultimas 400 lineas del log"

printf '\n'
if [ "$fallos" -eq 0 ]; then
    printf '\033[32mtodo bien\033[0m\n'
else
    printf '\033[31m%s cosas mal\033[0m\n' "$fallos"
    exit 1
fi
