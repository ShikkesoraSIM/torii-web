<?php

// torii: las tablas que osu-web lee de Torii son vistas, no tablas, y una vista
// no tiene indices propios. Cualquier FORCE INDEX contra una de ellas revienta
// con "Key 'rank_score' doesn't exist in table 'osu_user_stats'", que es
// exactamente lo que tiraba la pagina de rankings.
//
// Upstream usa esas pistas para que el optimizador no se traiga la tabla de
// usuarios entera antes de ordenar. Contra una vista no hay pista que dar: el
// plan lo arma MySQL sobre las tablas de abajo, que si tienen sus indices, y en
// las consultas que importa (scores por usuario, eventos, mas jugados) el plan
// medido usa el mismo indice que usaba antes.
//
// Asi que la pista se saltea si el destino es una vista y se deja tal cual si
// es una tabla de verdad, que es el caso de todo lo que osu-web se guarda para
// si mismo. Eso hace que este archivo sea correcto en las dos configuraciones y
// que no haya que acordarse de nada al sincronizar con upstream.

declare(strict_types=1);

namespace App\Libraries\Torii;

use Illuminate\Support\Facades\DB;

class QueryHints
{
    private static ?array $views = null;

    /**
     * Devuelve el fragmento de FROM con la pista de indice, o el nombre pelado
     * si el destino es una vista.
     */
    public static function forceIndex(string $table, string $index): string
    {
        return static::isView($table) ? $table : "{$table} FORCE INDEX ({$index})";
    }

    public static function isView(string $table): bool
    {
        // Se consulta una sola vez por worker. Es informacion de esquema: si
        // cambia hay que reiniciar octane igual, por el cache de metadatos.
        static::$views ??= array_flip(array_column(
            DB::select(
                "SELECT TABLE_NAME AS name
                 FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'VIEW'"
            ),
            'name'
        ));

        return isset(static::$views[$table]);
    }
}
