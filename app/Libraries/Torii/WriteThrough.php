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
// contra la tabla real de g0v0. Los update y delete de query builder, que no
// pasan por el modelo, los desvia WriteThroughBuilder.
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
//
// Las que si sabemos que Torii no tiene donde guardar van en 'reject' y cortan
// el request con un mensaje. Es a proposito: un ajuste que se guarda con tilde
// verde y vuelve solo al recargar es peor que uno que dice que no se puede.

declare(strict_types=1);

namespace App\Libraries\Torii;

use App\Exceptions\InvariantException;
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
     *   reject   columna => mensaje, para lo que no tiene donde guardarse
     *   insert   closure que hace el alta y devuelve true si la hizo
     *   delete   closure que hace la baja y devuelve true si la hizo
     *   update   closure para lo que no se puede escribir columna por columna;
     *            devuelve la lista de columnas que se dio por atendidas
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
                    // El discord es user_jabber en el esquema del foro: el
                    // campo de ajustes escribe ahi via setUserDiscordAttribute.
                    'user_jabber' => ['discord', 'presence'],
                    // El tono del perfil. osu-web guarda 0 para "sin tono" y
                    // Torii nulo, y no es lo mismo: con 0 el cliente pintaria
                    // todo rojo.
                    'user_style' => ['profile_hue', 'hue'],
                    // Las dos banderas son la misma opcion al reves: osu-web
                    // guarda "permite mensajes", Torii "solo de amigos".
                    'user_allow_pm' => ['pm_friends_only', 'invert'],
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
                'reject' => [
                    // 'user_avatar' ya no se rechaza: subir una foto ahora se
                    // resuelve contra la api del juego (Torii\ProfileMedia) y
                    // AvatarHelper ni siquiera toca la columna, asi que por aca
                    // no pasa nada que bloquear. La vista la deriva sola de
                    // lazer_users.avatar_url.
                    // No hay columna en lazer_users para esto. Ver el detalle
                    // en el comentario de abajo de la clase.
                    'user_allow_viewonline' => 'Hiding your online presence is not supported on Torii.',
                    'user_notify' => 'Forum email notifications are not supported on Torii.',
                    'user_sig' => 'Forum signatures are not supported on Torii.',
                    'user_sig_bbcode_uid' => 'Forum signatures are not supported on Torii.',
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
                // Bloquear a alguien a quien ya seguias no da de alta nada: da
                // vuelta las dos banderas de la fila que ya existe. Las dos son
                // la misma columna en Torii, asi que el update tambien hay que
                // traducirlo o el bloqueo se pierde y la relacion se queda en
                // FOLLOW (devolvia 200 y todo).
                'update' => function (Model $model, array $dirty): array {
                    $handled = array_values(array_intersect(['friend', 'foe'], array_keys($dirty)));

                    if ($handled === []) {
                        return [];
                    }

                    $a = $model->getAttributes();

                    DB::update(
                        'UPDATE `'.static::schema().'`.`relationship` SET type = ? WHERE user_id = ? AND target_id = ?',
                        [($a['foe'] ?? 0) ? 'BLOCK' : 'FOLLOW', $a['user_id'], $a['zebra_id']]
                    );

                    return $handled;
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

            // Pinear una play marca el score como preservado, y eso Torii si lo
            // tiene: es la misma columna con el mismo significado. Va por aca
            // porque en la vista es un COALESCE y una expresion no se escribe.
            'scores' => [
                'table' => 'scores',
                'key' => ['id' => 'id'],
                'columns' => [
                    'preserve' => ['preserve', null],
                    'ranked' => ['ranked', null],
                ],
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

            // Los equipos existen en Torii con otros nombres de columna y con
            // las imagenes como url entera en vez de nombre de archivo.
            'teams' => [
                'insert' => function (Model $model): bool {
                    $a = $model->getAttributes();

                    DB::insert(
                        'INSERT INTO `'.static::schema().'`.`teams`
                            (name, short_name, description, website, playmode, leader_id, created_at)
                         VALUES (?, ?, ?, ?, ?, ?, COALESCE(?, NOW()))',
                        [
                            $a['name'],
                            $a['short_name'] ?? '',
                            $a['description'] ?? null,
                            presence($a['url'] ?? null),
                            static::transform('playmode', $a['default_ruleset_id'] ?? 0),
                            $a['leader_id'],
                            $a['created_at'] ?? null,
                        ]
                    );

                    // El id lo pone la tabla real y hace falta ya: con la fila
                    // recien creada el alta sigue metiendo al lider como
                    // miembro y despues redirige a la pagina del equipo.
                    $model->setAttribute('id', (int) DB::getPdo()->lastInsertId());

                    return true;
                },
                'table' => 'teams',
                'key' => ['id' => 'id'],
                'columns' => [
                    'name' => ['name', null],
                    'short_name' => ['short_name', null],
                    'description' => ['description', null],
                    'url' => ['website', 'presence'],
                    'default_ruleset_id' => ['playmode', 'playmode'],
                    'leader_id' => ['leader_id', null],
                ],
                'drop' => [
                    // Torii no tiene canal de chat por equipo y la vista
                    // devuelve 0 fijo. Ver el comentario en Team.php.
                    'channel_id',
                    // Tampoco tiene equipos cerrados: la vista devuelve
                    // is_open = 1 y todos aceptan solicitudes.
                    'is_open',
                    // torii.teams tiene created_at y nada mas; la vista usa esa
                    // misma fecha para las dos columnas.
                    'created_at', 'updated_at',
                ],
                'reject' => [
                    // Misma historia que el avatar: la bandera y la portada las
                    // sirve la api de Torii. La vista ademas expone solo el
                    // nombre de archivo (SUBSTRING_INDEX de flag_url), asi que
                    // escribir de vuelta obligaria a rearmar la url; no se hace
                    // porque el archivo que subio la web esta en el storage de
                    // osu-web y esa url daria 404. Reescribirla es peor que no
                    // tocarla: deja al equipo sin la imagen que ya tenia.
                    'flag_file' => 'Team flags are stored by the game server and can not be uploaded from the website.',
                    'header_file' => 'Team covers are stored by the game server and can not be uploaded from the website.',
                ],
            ],

            // La vista tiene created_at y updated_at como expresiones y eso
            // alcanza para que MySQL rechace el INSERT entero, que es lo que
            // rompia aceptar una solicitud y crear un equipo.
            'team_members' => [
                'insert' => function (Model $model): bool {
                    $a = $model->getAttributes();

                    DB::insert(
                        'INSERT INTO `'.static::schema().'`.`team_members` (team_id, user_id, joined_at)
                         VALUES (?, ?, COALESCE(?, NOW()))',
                        [$a['team_id'], $a['user_id'], $a['created_at'] ?? null]
                    );

                    return true;
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
     * Devuelve true si la baja ya se hizo contra g0v0. La closure que la hace
     * tiene que hacerla siempre: si devolviera false, Eloquent mandaria el
     * DELETE a la vista y WriteThroughBuilder lo desviaria de vuelta para aca.
     */
    public static function delete(Model $model): bool
    {
        $config = static::configFor($model);

        return isset($config['delete']) ? $config['delete']($model) : false;
    }

    /**
     * Si una operacion masiva sobre esta tabla tiene que resolverse fila por
     * fila en vez de irse compilada contra la vista. Lo consulta
     * WriteThroughBuilder.
     */
    public static function needsInstances(Model $model, string $operation): bool
    {
        $config = static::configFor($model);

        return match ($operation) {
            // El delete solo se desvia donde borrar la fila de la vista NO es
            // lo que se quiere. Donde no hay closure (favoritos, amigos,
            // miembros de equipo) MySQL lo propaga solo y esta bien asi.
            'delete' => isset($config['delete']),
            // El update se desvia en cualquier tabla mapeada: si la columna se
            // traduce, ir crudo contra la vista la pierde o revienta.
            'update' => $config !== [],
        };
    }

    /**
     * Deja de un SET solo las columnas que la vista si acepta.
     *
     * Hace falta porque WriteThrough::update no es la ultima palabra: corre
     * desde Model::performUpdate, y despues de eso Eloquent vuelve a meter mano.
     * updated_at es el caso: performUpdate lo remarca sucio con
     * updateTimestamps y Builder::update lo agrega de nuevo por su cuenta, ya
     * calificado con el nombre de la tabla ("teams`.`updated_at"). Por eso se
     * compara el nombre pelado.
     */
    public static function stripNonViewColumns(Model $model, array $values): array
    {
        $config = static::configFor($model);

        if ($config === []) {
            return $values;
        }

        foreach (array_keys($values) as $column) {
            $bare = last(explode('.', (string) $column));

            if (isset($config['reject'][$bare])
                || isset($config['columns'][$bare])
                || in_array($bare, $config['drop'] ?? [], true)
            ) {
                unset($values[$column]);
            }
        }

        return $values;
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

        foreach ($dirty as $column => $value) {
            if (isset($config['reject'][$column])) {
                throw new InvariantException($config['reject'][$column]);
            }

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
            // osu-web deja cadena vacia o cero donde Torii deja nulo, y el
            // cliente distingue: con cadena vacia dibuja el campo vacio en vez
            // de esconderlo.
            'presence' => presence($value === null ? null : trim((string) $value)),
            'hue' => ((int) $value) === 0 ? null : (int) $value,
            'invert' => (int) !$value,
            default => $value,
        };
    }
}

// Lo que no tiene donde guardarse y por que, para no volver a averiguarlo:
//
//   - hide_presence (user_allow_viewonline): es un ajuste del juego pero
//     lazer_users no tiene la columna. Necesita migracion en g0v0 y que la
//     vista deje de devolver el 1 fijo.
//   - la firma del foro (user_sig) y el mail de aviso de respuestas
//     (user_notify): son de osu-web, no de Torii, asi que la columna no va en
//     lazer_users. Van en una tabla propia de osu-web y la vista phpbb_users
//     las trae con un LEFT JOIN, igual que phpbb_user_group ya hace contra
//     phpbb_groups. Escribirlas sin eso es tirarlas a un pozo: la vista las
//     seguiria leyendo como constantes.
