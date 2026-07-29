#!/bin/bash
# torii: resuelve el nombre del esquema de g0v0 en un .sql y lo escribe a stdout.
#
# El esquema se llama distinto en cada lado: torii en la maquina local, osu_api
# en produccion. Los archivos que lo referencian lo llevan como @@SRC@@ y esto
# lo reemplaza, asi que hay UN solo camino para los dos entornos en vez de un
# archivo que anda local y falla a mitad de un deploy.
#
#   ./torii-render.sh torii-cache.sql                 # usa $TORII_SOURCE_SCHEMA o torii
#   TORII_SOURCE_SCHEMA=osu_api ./torii-render.sh torii-cache.sql
set -euo pipefail

src="${TORII_SOURCE_SCHEMA:-torii}"

if ! [[ "$src" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "nombre de esquema invalido: $src" >&2
    exit 1
fi

for f in "$@"; do
    [ -f "$f" ] || { echo "no existe: $f" >&2; exit 1; }
    sed "s/@@SRC@@/${src}/g" "$f"
done
