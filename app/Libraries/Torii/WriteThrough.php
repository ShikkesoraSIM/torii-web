<?php

// torii: escribir sobre las vistas.
//
// Las tablas que osu-web comparte con el juego son vistas sobre el esquema de
// g0v0. Leer anda solo; escribir no siempre. MySQL acepta un DELETE o un UPDATE
// contra una vista de una sola tabla, pero rechaza cualquier columna que sea
// una expresion (un CASE, un UNIX_TIMESTAMP) con "Column 'x' is not updatable",
// y rechaza el INSERT entero si alguna columna lo es. Tampoco tiene triggers
// INSTEAD OF, asi que la traduccion la tiene que hacer alguien en php.
//
// Eso es esto. Se engancha en Model::performInsert, performUpdate y
// performDeleteOnModel, y por cada tabla mapeada hace la escritura equivalente
// contra la tabla real de g0v0.
//
// Lo que NO pasa por aca y anda igual:
//
//   - Los DELETE donde borrar la fila de la vista es exactamente lo que se
//     quiere (favoritos, amigos, miembros de equipo). MySQL los propaga solo.
//   - Todo lo que osu-web se guarda para si (foro, comentarios, chat, oauth,
//     sesiones), que siguen siendo tablas de verdad.
//
// Las columnas que cambian y no estan en el mapa se descartan con una
// advertencia en el log en vez de tirar el request abajo: una columna sin
// mapear no vale una pagina en blanco, y el log dice cual falta.

declare(strict_types=1);

namespace App\Libraries\Torii;

use App\Models\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class WriteThrough
{
    private static ?array $map = null;

    /**
     * tabla de osu-web => como escribir en g0v0.
     *
     *   table    tabla de g0v0 destino de los UPDATE declarativos
     *   key      columna de osu-web => columna de g0v0, para el WHERE
     *   columns  columna de osu-web => [columna de g0v0, transformacion]
     *   drop     columnas que se descartan en silencio
     *   insert   closure que hace el alta y devuelve true si la hizo
     *   delete   closure que hace la baja y devuelve true si la hizo
     */
    private static function map(): array
    {
        return static::$map ??= [
            'phpbb_users' => [
                'table' => 'lazer_users',
                'key' => ['user_id' => 'id'],
                'columns' => [
                    'user_lastvisit' => ['last_visit', 'from_unixtime'],
                    'user_interests' => ['interests', null],
                    'user_occ' => ['occupation', null],
                    'user_from' => ['location', null],
                    'user_website' => ['website', null],
                    'user_twitter' => ['twitter', null],
                    'user_colour' => ['profile_colour', null],
                    'country_acronym' => ['country_code', null],
                    'osu_playmode' => ['playmode', 'playmode'],
                    'osu_playstyle' => ['playstyle', 'playstyle'],
                    'user_password' => ['pw_bcrypt', null],
                    'user_email' => ['email', null],
                ],
                'drop' => [
                    // La vista se lo asigna sola a quien no tiene portada propia.
                    'cover_preset_id',
                    // La vista lo deriva del id del usuario.
                    'userpage_post_id',
                    // Contadores del foro de osu-web. El foro es de osu-web y
                    // vive en sus propias tablas.
                    'user_lastmark', 'user_lastpost_time', 'user_last_search',
                    'user_new_privmsg', 'user_unread_privmsg', 'user_last_privmsg',
                    'user_login_attempts', 'user_last_confirm_key',
                    'user_passchg', 'user_posts',
                ],
            ],

            // Amigos y bloqueados. osu-web los guarda como una fila con dos
            // banderas; Torii como dos tipos de la misma relacion, asi que el
            // alta hay que traducirla. La baja no: es un DELETE sobre una vista
            // de una sola tabla y MySQL lo propaga tal cual.
            'phpbb_zebra' => [
                'insert' => function (Model $model): bool {
                    $a = $model->getAttributes();

                    DB::insert(
                        'INSERT INTO `'.static::schema().'`.`relationship` (user_id, target_id, type) VALUES (?, ?, ?)',
                        [$a['user_id'], $a['zebra_id'], ($a['foe'] ?? 0) ? 'BLOCK' : 'FOLLOW']
                    );

                    return true;
                },
            ],

            'osu_favouritemaps' => [
                'insert' => function (Model $model): bool {
                    $a = $model->getAttributes();

                    DB::insert(
                        'INSERT INTO `'.static::schema().'`.`favourite_beatmapset` (user_id, beatmapset_id, date) VALUES (?, ?, NOW())',
                        [$a['user_id'], $a['beatmapset_id']]
                    );

                    return true;
                },
            ],

            // Un pin no es una fila propia en Torii: es la columna pinned_order
            // del score. Por eso el alta y la baja son un UPDATE sobre scores y
            // no un INSERT o un DELETE. Ver el comentario de la vista en
            // torii-views.php: si fuera borrable, despinnear borraria la play.
            'score_pins' => [
                'insert' => function (Model $model): bool {
                    $a = $model->getAttributes();

                    DB::update(
                        'UPDATE `'.static::schema().'`.`scores` SET pinned_order = ? WHERE id = ?',
                        [$a['display_order'] ?? 1, $a['score_id']]
                    );

                    return true;
                },
                'delete' => function (Model $model): bool {
                    DB::update(
                        'UPDATE `'.static::schema().'`.`scores` SET pinned_order = 0 WHERE id = ?',
                        [$model->getAttributes()['score_id']]
                    );

                    return true;
                },
                'table' => 'scores',
                'key' => ['score_id' => 'id'],
                'columns' => [
                    'display_order' => ['pinned_order', null],
                ],
                'drop' => ['created_at', 'updated_at', 'user_id', 'ruleset_id'],
            ],

            // favourite_count y play_count son contadores denormalizados que
            // viven en la cache, no en Torii. osu-web los mueve de a uno
            // (favourite_count = favourite_count + 1) al marcar un favorito, y
            // una vista con LEFT JOIN no acepta UPDATE de ninguna columna.
            //
            // En vez de replicar el incremento se recalcula ese set y nada mas:
            // es una cuenta sobre las pocas filas de ese mapa, sale exacta, y
            // no puede quedar corrida si dos favoritos entran a la vez.
            'osu_beatmapsets' => [
                'update' => function (Model $model, array $dirty): array {
                    if (!array_key_exists('favourite_count', $dirty)) {
                        return array_keys($dirty);
                    }

                    $id = $model->getAttributes()['beatmapset_id'];

                    DB::update(
                        'UPDATE `torii_cache_beatmapset` SET favourite_count =
                            (SELECT COUNT(*) FROM `'.static::schema().'`.`favourite_beatmapset` f
                             WHERE f.beatmapset_id = ?)
                         WHERE beatmapset_id = ?',
                        [$id, $id]
                    );

                    return array_keys($dirty);
                },
            ],
        ];
    }

    public static function schema(): string
    {
        return $GLOBALS['cfg']['torii']['source_schema'];
    }

    /**
     * Devuelve true si el alta ya se hizo contra g0v0 y Eloquent no tiene que
     * hacer nada mas.
     */
    public static function insert(Model $model): bool
    {
        $config = static::configFor($model);

        return isset($config['insert']) ? $config['insert']($model) : false;
    }

    /**
     * Devuelve true si la baja ya se hizo contra g0v0.
     */
    public static function delete(Model $model): bool
    {
        $config = static::configFor($model);

        return isset($config['delete']) ? $config['delete']($model) : false;
    }

    /**
     * Saca de la lista de cambios pendientes todo lo que se pueda escribir
     * contra g0v0, y lo escribe.
     */
    public static function update(Model $model): void
    {
        $config = static::configFor($model);
        $dirty = $model->getDirty();

        if ($config === [] || $dirty === []) {
            return;
        }

        $set = [];
        $bindings = [];
        $handled = [];

        // Las tablas con logica propia la resuelven ellas y devuelven que
        // columnas se dieron por atendidas.
        if (isset($config['update'])) {
            foreach ($config['update']($model, $dirty) as $column) {
                $model->syncOriginalAttribute($column);
                unset($dirty[$column]);
            }
        }

        if (!isset($config['table'])) {
            return;
        }

        foreach ($dirty as $column => $value) {
            if (in_array($column, $config['drop'] ?? [], true)) {
                $handled[] = $column;
                continue;
            }

            $spec = $config['columns'][$column] ?? null;

            if ($spec === null) {
                Log::warning('torii: columna sin mapa de escritura, se descarta', [
                    'table' => $model->getTable(),
                    'column' => $column,
                ]);
                $handled[] = $column;
                continue;
            }

            [$target, $transform] = $spec;

            $set[] = "`{$target}` = ".($transform === 'from_unixtime' ? 'FROM_UNIXTIME(?)' : '?');
            $bindings[] = static::transform($transform, $value);
            $handled[] = $column;
        }

        if ($set !== []) {
            $where = [];

            foreach ($config['key'] as $from => $to) {
                $where[] = "`{$to}` = ?";
                $bindings[] = $model->getAttributes()[$from];
            }

            DB::update(
                'UPDATE `'.static::schema()."`.`{$config['table']}` SET ".implode(', ', $set)
                    .' WHERE '.implode(' AND ', $where),
                $bindings
            );
        }

        // Marcarlas como guardadas es lo que evita que Eloquent las mande
        // tambien a la vista y se coma el error.
        foreach ($handled as $column) {
            $model->syncOriginalAttribute($column);
        }
    }

    private static function configFor(Model $model): array
    {
        $table = $model->getTable();
        $config = static::map()[$table] ?? null;

        // La segunda condicion es lo que hace que este archivo sea inofensivo
        // en una instalacion sin la capa de vistas: si la tabla es una tabla de
        // verdad, no se toca nada.
        return $config !== null && QueryHints::isView($table) ? $config : [];
    }

    private static function transform(?string $transform, $value)
    {
        return match ($transform) {
            // osu-web guarda el modo como entero y Torii como texto.
            'playmode' => ['osu', 'taiko', 'fruits', 'mania'][(int) $value] ?? 'osu',
            // osu-web lo empaqueta en un bitfield y Torii guarda la lista.
            'playstyle' => json_encode(array_values(array_filter(
                ['mouse', 'keyboard', 'tablet', 'touch'],
                fn ($_, $i) => ((int) $value & (1 << $i)) !== 0,
                ARRAY_FILTER_USE_BOTH
            ))),
            default => $value,
        };
    }
}
