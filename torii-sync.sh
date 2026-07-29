#!/bin/bash
# torii: copia archivos del repo al contenedor.
#
# /app es un volumen de docker y no un bind mount de Windows, porque el bind
# mount hace que php tarde 430 veces mas en leer cada archivo (medido: 16.9s
# contra 0.039s para abrir 2000 archivos). El precio es que editar aca no se
# refleja solo, hay que empujarlo.
#
#   ./torii-sync.sh app/Models/User.php resources/css/colors.less
#   ./torii-sync.sh --all                 # todo lo que git ve como cambiado
#   ./torii-sync.sh --restart app/...     # ademas reinicia octane
#
# Octane tiene el codigo cargado en memoria, asi que cualquier cambio en php
# necesita reinicio. Los assets los recompila el contenedor `assets` solo.

set -euo pipefail
cd "$(dirname "$0")"

restart=0
files=()

for arg in "$@"; do
    case "$arg" in
        --restart) restart=1 ;;
        --all) mapfile -t -O "${#files[@]}" files < <(git status --porcelain | awk '{print $NF}' | grep -vE '^torii-') ;;
        *) files+=("$arg") ;;
    esac
done

if [ ${#files[@]} -eq 0 ]; then
    echo "nada que copiar" >&2
    exit 1
fi

php=$(docker compose ps -q php)
assets=$(docker compose ps -q assets)

for f in "${files[@]}"; do
    [ -e "$f" ] || { echo "no existe: $f" >&2; continue; }
    dir=$(dirname "$f")
    # El mkdir va adentro de sh -c a proposito: Git Bash convierte cualquier
    # argumento que arranque con barra a una ruta de Windows, y /app/... llega
    # al contenedor como C:/... Metido en la cadena de sh no lo toca.
    docker exec "$php" sh -c "mkdir -p '/app/$dir'"
    docker cp "$f" "$php:/app/$f" >/dev/null
    if [ -n "$assets" ]; then
        docker exec "$assets" sh -c "mkdir -p '/app/$dir'" || true
        docker cp "$f" "$assets:/app/$f" >/dev/null
    fi
    echo "-> $f"
done

if [ "$restart" -eq 1 ]; then
    docker compose restart php >/dev/null
    echo "octane reiniciado"
fi
