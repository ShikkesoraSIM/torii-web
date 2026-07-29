<?php

// torii: genera las vistas que hacen que osu-web lea directamente de las tablas
// de g0v0, en vez de una copia.
//
// Por que generado y no un .sql escrito a mano: las tablas de osu-web tienen
// entre 3 y 90 columnas y una vista TIENE que exponerlas todas, porque Eloquent
// hace SELECT * y despues accede a los atributos por nombre. Escribir 474
// columnas a mano es tedioso pero sobre todo fragil: cuando ppy agregue una
// columna en una migracion, la vista hecha a mano se queda corta y el error
// aparece lejos, en una pagina cualquiera. Aca se lee information_schema, se
// usan las expresiones del mapa para las columnas que Torii sabe llenar, y el
// resto se rellena solo con el default de la columna.
//
// Se corre asi (imprime el sql por stdout, no toca la base):
//
//     docker compose exec -T php php /tmp/torii-views.php > torii-views.sql
//
// Y con otro esquema origen, que es el caso de produccion:
//
//     ... php /tmp/torii-views.php osu_api
//
// Lo que NO es una vista, y por que: los agregados caros. playcount por mapa,
// favourite_count, difficulty_names, los failtimes y los primeros puestos son
// cuentas sobre cientos de miles de filas que no se pueden resolver por fila
// sin matar cualquier listado. Van a tablas de cache angostas que refresca
// torii-refresh-cache.sql, y las vistas las traen con un LEFT JOIN por clave
// primaria. Es lo mismo que hace osu! upstream: esas columnas tampoco se
// calculan en vivo alla, las escribe un worker de cola.

// ---------------------------------------------------------------------------

$src = $argv[1] ?? 'torii';
$dst = $argv[2] ?? 'osu';
// De donde se leen las columnas que tiene que exponer cada vista. Normalmente
// es el mismo destino, pero la primera vez las tablas ya se mudaron a osu_bak y
// hay que leerlas de ahi. Ese tambien es el camino cuando ppy agrega una
// columna: revertir, migrar, regenerar leyendo de osu, y volver a cambiar.
$ref = $argv[3] ?? $dst;

foreach ([$src, $dst, $ref] as $s) {
    if (!preg_match('/^[a-z0-9_]+$/i', $s)) {
        fwrite(STDERR, "esquemas invalidos\n");
        exit(1);
    }
}

$pdo = new PDO("mysql:host=".(getenv('DB_HOST') ?: 'db').";charset=utf8mb4", getenv('DB_USERNAME') ?: 'root', getenv('DB_PASSWORD') ?: '');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// -------------------------------------------------------------- expresiones --

// Traducciones que se repiten. El modo de juego viaja como texto en Torii y
// como entero en osu-web, y los modos propios (relax, autopilot) no tienen
// numero: caen al modo base.
function mode_int(string $c): string
{
    return "CASE $c WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1"
         . " WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2"
         . " WHEN 'MANIA' THEN 3 ELSE 0 END";
}

function status_int(string $c): string
{
    return "CASE $c WHEN 'GRAVEYARD' THEN -2 WHEN 'WIP' THEN -1 WHEN 'PENDING' THEN 0"
         . " WHEN 'RANKED' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'QUALIFIED' THEN 3"
         . " WHEN 'LOVED' THEN 4 ELSE 0 END";
}

// osu-web no guarda la actividad estructurada: guarda una linea de html que
// vuelve a parsear con una regex por tipo de evento. Hay que escribir
// exactamente ese formato, con el signo de admiracion del final incluido.
//
// Va todo en un solo SELECT con un CASE por tipo y no cuatro selects unidos,
// porque una vista con UNION la materializa MySQL entera antes de filtrar y el
// perfil pide los eventos de UN usuario.
function event_text(): string
{
    // Torii tiene modos que el parser de osu-web no conoce y si el texto entre
    // parentesis no es uno de los cuatro suyos descarta el evento entero.
    $mode = "CASE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode'))"
          . " WHEN 'osu!relax' THEN 'osu!' WHEN 'osu!autopilot' THEN 'osu!'"
          . " WHEN 'catch relax' THEN 'osu!catch' WHEN 'taiko relax' THEN 'osu!taiko'"
          . " ELSE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode')) END";

    $bid = "SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1)";
    $uname = "JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username'))";
    $title = "JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.title'))";

    return "LEFT(CASE e.type
        WHEN 'RANK' THEN CONCAT(
            '<img src=''/images/', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.scorerank')),
            '_small.png''/> <b><a href=''/users/', e.user_id, '''>', $uname,
            '</a></b> achieved rank #', JSON_EXTRACT(e.event_payload, '$.rank'),
            ' on <a href=''/b/', $bid, '''>', $title, '</a> (', $mode, ')')
        WHEN 'RANK_LOST' THEN CONCAT(
            '<b><a href=''/users/', e.user_id, '''>', $uname,
            '</a></b> has lost first place on <a href=''/b/', $bid, '''>', $title,
            '</a> (', $mode, ')')
        WHEN 'ACHIEVEMENT' THEN CONCAT(
            '<b><a href=''/users/', e.user_id, '''>', $uname,
            '</a></b> unlocked the \"<b>',
            JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.achievement.name')), '</b>\" medal!')
        WHEN 'USERNAME_CHANGE' THEN CONCAT(
            '<b><a href=''/users/', e.user_id, '''>',
            JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.previous_username')),
            '</a></b> has changed their username to ', $uname, '!')
    END, 1000)";
}

// El grafico de posicion global. osu-web guarda noventa columnas r0..r89 en vez
// de una fila por dia y las lee como buffer circular; sin el contador de
// osu_counts arranca en r1, lee hasta r89 y le pega la posicion actual al
// final. Asi que r89 es hoy y r1 son 88 dias atras.
function rank_history_cols(): array
{
    $cols = [];
    for ($i = 1; $i <= 89; $i++) {
        $ago = 89 - $i;
        $cols["r$i"] = "COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = $ago THEN h.`rank` END), 0)";
    }

    return $cols;
}

// ---------------------------------------------------------------- el mapa --

$V = [];

// La portada propia es el NOMBRE del archivo, no la url. Se usa dos veces
// (para la columna y para decidir el preset), asi que se arma una sola vez.
$customCover = "CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url'))"
    . " LIKE 'https://lazer-api.shikkesora.com/file/cover/%'"
    . " THEN SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')), '/', -1)"
    . ' ELSE NULL END';

// ------------------------------------------------------------------ usuarios --
//
// Correo y contrasena si viajan aca, al reves que en la proyeccion de
// evaluacion: sin ellos no hay forma de que alguien inicie sesion de verdad.
// El hash de Torii es bcrypt(md5(pass)) y osu-web espera bcrypt(pass) pelado,
// asi que la comparacion se resuelve en php, no aca.

$V['phpbb_users'] = [
    'from' => "$src.lazer_users u",
    'where' => "u.username IS NOT NULL AND u.username <> ''",
    'cols' => [
        'user_id' => 'u.id',
        'user_type' => '0',
        // El grupo por defecto de este esquema es el 7; el 2 es alumni. Los
        // bots miran group_id directo y no la tabla de pertenencia.
        'group_id' => 'CASE WHEN u.is_bot = 1 THEN 6 ELSE 7 END',
        'user_permissions' => "''",
        'user_interests' => "LEFT(COALESCE(u.interests,''), 255)",
        'user_occ' => "LEFT(COALESCE(u.occupation,''), 255)",
        'user_sig' => "''",
        'username' => 'LEFT(u.username, 255)',
        'username_clean' => 'LEFT(LOWER(u.username), 255)',
        'user_email' => 'LEFT(COALESCE(u.email, CONCAT(\'user\', u.id, \'@torii.invalid\')), 100)',
        'user_password' => "LEFT(COALESCE(u.pw_bcrypt, ''), 255)",
        'user_regdate' => 'UNIX_TIMESTAMP(COALESCE(u.join_date, NOW()))',
        'user_lastvisit' => 'UNIX_TIMESTAMP(COALESCE(u.last_visit, u.join_date, NOW()))',
        'user_posts' => 'COALESCE(u.post_count, 0)',
        'user_colour' => "LEFT(COALESCE(u.profile_colour, ''), 6)",
        'country_acronym' => "LEFT(COALESCE(NULLIF(u.country_code,''), 'XX'), 2)",
        'osu_playmode' => "CASE u.playmode WHEN 'taiko' THEN 1 WHEN 'fruits' THEN 2 WHEN 'mania' THEN 3 ELSE 0 END",
        'user_from' => "LEFT(COALESCE(u.location,''), 100)",
        'user_website' => "LEFT(COALESCE(u.website,''), 200)",
        'user_twitter' => "LEFT(COALESCE(u.twitter,''), 255)",
        'user_lang' => "'en'",
        'osu_subscriber' => '(u.is_supporter = 1)',
        'osu_subscriptionexpiry' => 'u.donor_end_at',
        'support_length' => 'COALESCE(u.total_supporter_months, 0)',
        'user_warnings' => '0',
        // El avatar y la portada son el NOMBRE del archivo, no la url: osu-web
        // arma la ruta con el id del usuario mas ese nombre y nginx la proxea a
        // la api de Torii. AvatarHelper ademas convierte el guion bajo del
        // nombre en un signo de pregunta, asi que el archivo tiene que tener
        // exactamente uno; si no, la url sale partida al medio.
        'user_avatar' => "CASE WHEN u.avatar_url LIKE 'https://lazer-api.shikkesora.com/file/avatars/%'"
            . " AND (CHAR_LENGTH(SUBSTRING_INDEX(u.avatar_url, '/', -1))"
            . " - CHAR_LENGTH(REPLACE(SUBSTRING_INDEX(u.avatar_url, '/', -1), '_', ''))) = 1"
            . " THEN SUBSTRING_INDEX(u.avatar_url, '/', -1) ELSE '' END",
        'custom_cover_filename' => $customCover,
        // osu-web solo respeta la portada propia si NO hay preset asignado, asi
        // que los que tienen portada propia van con preset nulo.
        //
        // Y los que NO tienen portada propia TIENEN que traer un preset. Si
        // llegan con los dos en nulo, Cover::setDefaultPresetId les asigna uno y
        // lo intenta guardar en la fila, que aca es una vista: eso reventaba
        // cualquier pagina donde apareciera ese usuario con "Column
        // 'cover_preset_id' is not updatable". Se le da el 1, que es la unica
        // fila de user_cover_presets y la que nginx proxea a una imagen real.
        'cover_preset_id' => "CASE WHEN $customCover IS NULL THEN 1 ELSE NULL END",
        // La pagina de perfil vive en phpbb_posts, que sigue siendo una tabla
        // de verdad porque es el foro. torii-refresh-cache.sql copia ahi el
        // texto que el jugador escribe desde el cliente, con id derivado.
        'userpage_post_id' => "CASE WHEN COALESCE(JSON_UNQUOTE(JSON_EXTRACT(u.page, '$.raw')), '') <> ''"
            . " THEN 900000 + u.id ELSE NULL END",
        'user_avatar_type' => '0',
        'osu_playstyle' => 'COALESCE((JSON_CONTAINS(u.playstyle, \'"mouse"\') * 1)'
            . ' + (JSON_CONTAINS(u.playstyle, \'"keyboard"\') * 2)'
            . ' + (JSON_CONTAINS(u.playstyle, \'"tablet"\') * 4)'
            . ' + (JSON_CONTAINS(u.playstyle, \'"touch"\') * 8), 0)',
    ],
    // Lo que es de Torii y osu-web no tiene columna donde ponerlo. Al llegar
    // como atributo del modelo, cada una necesita su linea en el match de
    // User::getAttribute o el perfil entero se cae con UnhandledMatchError.
    'extra' => [
        'torii_points' => 'COALESCE(u.points, 0)',
        'torii_aura' => 'u.equipped_aura',
        'torii_name_colour' => 'u.equipped_name_colour',
        'torii_supporter_months' => 'COALESCE(u.total_supporter_months, 0)',
        'torii_is_online' => 'COALESCE(u.is_online, 0)',
    ],
];

// Los grupos de un jugador salen de tres lados y ninguno es una tabla de
// pertenencia: las banderas de su fila, la lista torii_titles, y si tiene
// donacion viva. Es exactamente lo que hace build_groups() en g0v0
// (app/models/torii_groups.py), replicado aca para que el badge de la web y el
// del juego digan siempre lo mismo.
//
// Hay dos catalogos y los dos hacen falta:
//
//   - los grupos propios de osu-web (admin, gmt, nat, bng, bot, default) NO se
//     ven en ningun lado, porque tienen display_order en nulo y sin eso
//     Group::hasBadge() da false. Estan para los PERMISOS: isAdmin(), isGMT() y
//     compania miran la pertenencia a estos y son las que abren las
//     herramientas de moderacion.
//   - los de Torii (torii-*, ids 1001 a 1031, los siembra torii-groups.sql) son
//     los que se DIBUJAN, con el color y la sigla que ya usa el cliente.
//
// Asi un admin queda en 'admin' (puede moderar) y en 'torii-admin' (se le ve el
// badge rojo), sin que aparezca dos veces.
//
// El ultimo OR es el que hace que agregar un grupo nuevo no toque esta vista:
// para todo torii-X la pertenencia es "X esta en torii_titles". Las lineas de
// arriba son las excepciones, o sea los que ademas se ganan por bandera.
//
// Va como join contra phpbb_groups, que tiene veintisiete filas, y no como una
// union de selects: la union obliga a MySQL a materializar la vista entera
// antes de filtrar por usuario.
$V['phpbb_user_group'] = [
    'from' => "$src.lazer_users u JOIN $dst.phpbb_groups g ON ("
        . "g.identifier = 'default'"
        . " OR (g.identifier IN ('admin','torii-admin') AND u.is_admin = 1)"
        . " OR (g.identifier IN ('gmt','torii-mod')     AND u.is_gmt = 1)"
        . " OR (g.identifier = 'nat'   AND u.is_qat = 1)"
        . " OR (g.identifier = 'bng'   AND u.is_bng = 1)"
        . " OR (g.identifier = 'bot'   AND u.is_bot = 1)"
        . " OR (g.identifier = 'torii-qat'    AND u.is_qat = 1)"
        . " OR (g.identifier = 'torii-pooler' AND u.is_bng = 1)"
        // La bandera is_supporter puede quedar vieja: no hay nada que la apague
        // cuando se vence la donacion. La ventana de donacion es la fuente.
        . " OR (g.identifier = 'torii-supporter' AND u.donor_end_at > NOW())"
        . " OR (g.identifier = 'torii-donator'   AND u.has_supported = 1)"
        . " OR (g.identifier LIKE 'torii-%'"
        . "     AND JSON_CONTAINS(u.torii_titles, JSON_QUOTE(SUBSTRING(g.identifier, 7))) = 1))",
    'cols' => [
        'group_id' => 'g.group_id',
        'user_id' => 'u.id',
        'group_leader' => '0',
        'user_pending' => '0',
        'playmodes' => 'NULL',
    ],
];

// osu-web guarda amigos y bloqueados en la misma fila con dos banderas; Torii
// los tiene como dos tipos de la misma relacion.
$V['phpbb_zebra'] = [
    'from' => "$src.relationship r",
    'cols' => [
        'user_id' => 'r.user_id',
        'zebra_id' => 'r.target_id',
        'friend' => "(r.type = 'FOLLOW')",
        'foe' => "(r.type = 'BLOCK')",
    ],
];

// --------------------------------------------------------------- estadisticas --
//
// Torii guarda una fila por modo en una sola tabla; osu-web tiene una tabla por
// modo. Los modos propios (relax, autopilot y los rulesets custom) no tienen
// tabla donde ir todavia: eso es lo que hay que resolver para que aparezcan en
// la web, y es un trabajo aparte.

// La posicion global y la del pais NO se calculan al vuelo en osu-web: las lee
// de la fila. rank_score_index es la global y `rank` la del pais, y si quedan
// en cero el perfil muestra el pp pero sin ningun numero de ranking al lado.
//
// Con la proyeccion habia que recalcularlas a mano en cada corrida y quedaban
// viejas entre una y otra. Aca salen de una funcion de ventana sobre las
// estadisticas del modo, o sea que la posicion es exacta en el momento en que
// se mira la pagina.
//
// El precio: una funcion de ventana obliga a MySQL a materializar la vista
// entera antes de filtrar, o sea que cada lectura ordena todas las filas del
// modo. Con los 791 jugadores de hoy eso es ruido. Si algun dia son cien mil,
// esto pasa a una tabla de cache como las de abajo y se cambia solo el mapa.
//
// Los que tienen cero pp no tienen posicion. No hace falta excluirlos del
// ORDER BY: caen al final y no corren la numeracion de los que si puntuan.
function rank_window(string $order): string
{
    return "CAST(ROW_NUMBER() OVER (" . ($order === 'country' ? 'PARTITION BY u.country_code ' : '')
         . "ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED)";
}

function user_stats(string $src, string $mode): array
{
    return [
        'from' => "$src.lazer_user_statistics s JOIN $src.lazer_users u ON u.id = s.user_id",
        'where' => "s.mode = '$mode'",
        'cols' => [
            'rank_score_index' => 'CASE WHEN COALESCE(s.pp,0) > 0 THEN ' . rank_window('global') . ' ELSE 0 END',
            'rank' => 'CASE WHEN COALESCE(s.pp,0) > 0 THEN ' . rank_window('country') . ' ELSE 0 END',
            'user_id' => 's.user_id',
            'count300' => 'COALESCE(s.count_300,0)',
            'count100' => 'COALESCE(s.count_100,0)',
            'count50' => 'COALESCE(s.count_50,0)',
            'countMiss' => 'COALESCE(s.count_miss,0)',
            'accuracy' => 'COALESCE(s.hit_accuracy,0)',
            'accuracy_new' => 'COALESCE(s.hit_accuracy,0)',
            'playcount' => 'COALESCE(s.play_count,0)',
            'ranked_score' => 'COALESCE(s.ranked_score,0)',
            'total_score' => 'COALESCE(s.total_score,0)',
            'x_rank_count' => 'COALESCE(s.grade_ss,0)',
            'xh_rank_count' => 'COALESCE(s.grade_ssh,0)',
            's_rank_count' => 'COALESCE(s.grade_s,0)',
            'sh_rank_count' => 'COALESCE(s.grade_sh,0)',
            'a_rank_count' => 'COALESCE(s.grade_a,0)',
            'level' => 'COALESCE(s.level_current,1)',
            'replay_popularity' => 'COALESCE(s.replays_watched_by_others,0)',
            'max_combo' => 'LEAST(COALESCE(s.maximum_combo,0), 65535)',
            'country_acronym' => "COALESCE(NULLIF(u.country_code,''),'XX')",
            'rank_score' => 'COALESCE(s.pp,0)',
            'last_update' => 'NOW()',
            'last_played' => 'COALESCE(s.last_played, NOW())',
            'total_seconds_played' => 'COALESCE(s.play_time,0)',
        ],
    ];
}

// Relax y autopilot. Son variantes de su ruleset base, no rulesets nuevos: ver
// el comentario de Beatmap::VARIANTS. La tabla que osu-web espera es la de una
// variante (14 columnas, no las 30 de la principal), asi que el layout se lo
// piden prestado a la de mania 4K, que ya existe.
function user_stats_variant(string $src, string $mode): array
{
    return [
        'like' => 'osu_user_stats_mania_4k',
        'from' => "$src.lazer_user_statistics s JOIN $src.lazer_users u ON u.id = s.user_id",
        'where' => "s.mode = '$mode'",
        'cols' => [
            'user_id' => 's.user_id',
            'playcount' => 'COALESCE(s.play_count,0)',
            'x_rank_count' => 'COALESCE(s.grade_ss,0)',
            'xh_rank_count' => 'COALESCE(s.grade_ssh,0)',
            's_rank_count' => 'COALESCE(s.grade_s,0)',
            'sh_rank_count' => 'COALESCE(s.grade_sh,0)',
            'a_rank_count' => 'COALESCE(s.grade_a,0)',
            'country_acronym' => "COALESCE(NULLIF(u.country_code,''),'XX')",
            'rank_score' => 'COALESCE(s.pp,0)',
            'rank_score_index' => 'CASE WHEN COALESCE(s.pp,0) > 0 THEN ' . rank_window('global') . ' ELSE 0 END',
            'ranked_score' => 'COALESCE(s.ranked_score,0)',
            'accuracy_new' => 'COALESCE(s.hit_accuracy,0)',
            'last_update' => 'NOW()',
            'last_played' => 'COALESCE(s.last_played, NOW())',
        ],
    ];
}

$V['osu_user_stats_osu_rx'] = user_stats_variant($src, 'OSURX');
$V['osu_user_stats_osu_ap'] = user_stats_variant($src, 'OSUAP');
$V['osu_user_stats_taiko_rx'] = user_stats_variant($src, 'TAIKORX');
$V['osu_user_stats_fruits_rx'] = user_stats_variant($src, 'FRUITSRX');

$V['osu_user_stats'] = user_stats($src, 'OSU');
$V['osu_user_stats_taiko'] = user_stats($src, 'TAIKO');
$V['osu_user_stats_fruits'] = user_stats($src, 'FRUITS');
$V['osu_user_stats_mania'] = user_stats($src, 'MANIA');

// ----------------------------------------------------------------- beatmaps --
//
// OJO con la autoria: beatmapsets.user_id NO es un usuario de Torii salvo que
// is_local sea 1. Es el id del creador en el espacio de ids de ppy, copiado
// crudo de lo que devuelve el mirror, y como los ids de Torii van de 2 a 793
// cualquier set cuyo creador tenga un id chico quedaba acreditado a un jugador
// local que no lo mapeo. El nombre del mapper no se pierde: sigue en creator.

$V['osu_beatmapsets'] = [
    'from' => "$src.beatmapsets b"
        . " LEFT JOIN $dst.torii_cache_beatmapset c ON c.beatmapset_id = b.id",
    // Hay sets que no tienen ni una difficulty porque el mirror no las trajo.
    // osu-web resuelve la ficha con whereHas('beatmaps'), asi que esas paginas
    // dan 404 pero igual aparecen en la busqueda y en los listados. No
    // arrastran nada: ni scores, ni favoritos, ni playcounts.
    'where' => "EXISTS (SELECT 1 FROM $src.beatmaps m2 WHERE m2.beatmapset_id = b.id)",
    'cols' => [
        'beatmapset_id' => 'b.id',
        'user_id' => 'CASE WHEN b.is_local = 1 THEN b.user_id ELSE 0 END',
        'artist' => "LEFT(COALESCE(b.artist,''), 80)",
        'artist_unicode' => "LEFT(COALESCE(NULLIF(b.artist_unicode,''), b.artist, ''), 80)",
        'title' => "LEFT(COALESCE(b.title,''), 80)",
        'title_unicode' => "LEFT(COALESCE(NULLIF(b.title_unicode,''), b.title, ''), 80)",
        'creator' => "LEFT(COALESCE(b.creator,''), 80)",
        'source' => "LEFT(COALESCE(b.source,''), 200)",
        'tags' => "LEFT(COALESCE(b.tags,''), 1000)",
        'video' => 'COALESCE(b.video, 0)',
        'storyboard' => 'COALESCE(b.storyboard, 0)',
        'bpm' => 'COALESCE(b.bpm, 0)',
        'approved' => status_int('b.beatmap_status'),
        // Un set ranked, approved, qualified o loved TIENE que traer fecha: el
        // panel la exige y si es nula tira una excepcion que se lleva puesto
        // todo el arbol de React. La pagina carga, hidrata, y recien ahi se
        // muere, asi que no se ve como un error de servidor. Torii deja
        // ranked_date en NULL en los mapas que aprobo a mano.
        'approved_date' => "CASE WHEN b.beatmap_status IN ('RANKED','APPROVED','QUALIFIED','LOVED')"
            . " THEN COALESCE(b.ranked_date, b.last_updated, b.submitted_date) ELSE b.ranked_date END",
        'submit_date' => 'COALESCE(b.submitted_date, b.last_updated, NOW())',
        'last_update' => 'COALESCE(b.last_updated, NOW())',
        'genre_id' => "CASE b.beatmap_genre WHEN 'VIDEO_GAME' THEN 2 WHEN 'ANIME' THEN 3"
            . " WHEN 'ROCK' THEN 4 WHEN 'POP' THEN 5 WHEN 'OTHER' THEN 6 WHEN 'NOVELTY' THEN 7"
            . " WHEN 'HIP_HOP' THEN 9 WHEN 'ELECTRONIC' THEN 10 WHEN 'METAL' THEN 11"
            . " WHEN 'CLASSICAL' THEN 12 WHEN 'FOLK' THEN 13 WHEN 'JAZZ' THEN 14 ELSE 1 END",
        'language_id' => "CASE b.beatmap_language WHEN 'ENGLISH' THEN 2 WHEN 'JAPANESE' THEN 3"
            . " WHEN 'CHINESE' THEN 4 WHEN 'INSTRUMENTAL' THEN 5 WHEN 'KOREAN' THEN 6"
            . " WHEN 'FRENCH' THEN 7 WHEN 'GERMAN' THEN 8 WHEN 'SWEDISH' THEN 9"
            . " WHEN 'SPANISH' THEN 10 WHEN 'ITALIAN' THEN 11 WHEN 'RUSSIAN' THEN 12"
            . " WHEN 'POLISH' THEN 13 WHEN 'OTHER' THEN 14 ELSE 1 END",
        'nsfw' => 'COALESCE(b.nsfw, 0)',
        'spotlight' => 'COALESCE(b.spotlight, 0)',
        'hype' => 'COALESCE(b.hype_current, 0)',
        'nominations' => 'COALESCE(b.nominations_current, 0)',
        'track_id' => 'b.track_id',
        'download_disabled' => 'COALESCE(b.download_disabled, 0)',
        'discussion_locked' => 'COALESCE(b.discussion_locked, 0)',
        'displaytitle' => "LEFT(CONCAT(COALESCE(b.artist,''), ' - ', COALESCE(b.title,'')), 200)",
        'active' => '1',
        // Sin cover_updated_at el front ni siquiera pide la portada: descarta
        // las urls que terminan en ?0 antes de renderizar.
        'cover_updated_at' => 'COALESCE(b.last_updated, NOW())',
        'play_count' => 'COALESCE(c.play_count, 0)',
        'favourite_count' => 'COALESCE(c.favourite_count, 0)',
        'difficulty_names' => 'c.difficulty_names',
        'versions_available' => 'GREATEST(COALESCE(c.versions_available, 1), 1)',
    ],
];

// El JOIN contra beatmapsets no es decorativo: Torii tiene mas beatmaps que
// beatmapsets referenciados, y un beatmap sin su set es exactamente lo que hace
// explotar a osu-web con un "member function on null".
$V['osu_beatmaps'] = [
    'from' => "$src.beatmaps m"
        . " JOIN $src.beatmapsets bs ON bs.id = m.beatmapset_id"
        . " LEFT JOIN $dst.torii_cache_beatmap c ON c.beatmap_id = m.id",
    'cols' => [
        'beatmap_id' => 'm.id',
        'beatmapset_id' => 'm.beatmapset_id',
        'user_id' => 'CASE WHEN m.is_local = 1 THEN m.user_id ELSE 0 END',
        'filename' => "LEFT(CONCAT(m.beatmapset_id, ' ', COALESCE(m.version,''), '.osu'), 150)",
        'checksum' => "LEFT(COALESCE(m.checksum,''), 32)",
        'version' => "LEFT(COALESCE(m.version,''), 80)",
        'total_length' => 'COALESCE(m.total_length, 0)',
        'hit_length' => 'COALESCE(m.hit_length, 0)',
        'countTotal' => 'COALESCE(m.count_circles,0) + COALESCE(m.count_sliders,0) + COALESCE(m.count_spinners,0)',
        'countNormal' => 'COALESCE(m.count_circles,0)',
        'countSlider' => 'COALESCE(m.count_sliders,0)',
        'countSpinner' => 'COALESCE(m.count_spinners,0)',
        'diff_drain' => 'GREATEST(COALESCE(m.drain,0), 0)',
        'diff_size' => 'GREATEST(COALESCE(m.cs,0), 0)',
        'diff_overall' => 'GREATEST(COALESCE(m.accuracy,0), 0)',
        'diff_approach' => 'GREATEST(COALESCE(m.ar,0), 0)',
        'playmode' => mode_int('m.mode'),
        'approved' => status_int('m.beatmap_status'),
        'last_update' => 'COALESCE(m.last_updated, NOW())',
        'difficultyrating' => 'COALESCE(m.difficulty_rating, 0)',
        'max_combo' => 'LEAST(COALESCE(m.max_combo, 0), 16777215)',
        'bpm' => 'COALESCE(m.bpm, 0)',
        'deleted_at' => 'm.deleted_at',
        'playcount' => 'COALESCE(c.playcount, 0)',
        'passcount' => 'COALESCE(c.passcount, 0)',
    ],
];

// ------------------------------------------------------------------- scores --
//
// osu-web guarda mods y estadisticas dentro de la columna json `data`. Torii ya
// tiene los mods y maximum_statistics en ese mismo formato y los conteos en
// columnas sueltas, asi que solo hay que rearmar el objeto `statistics`. El
// JSON_MERGE_PATCH con NULLIF es para no escribir las claves en cero: un score
// de osu! no tiene que decir que hizo 0 slider_tail_hit.
$scoreData = "JSON_OBJECT(
        'mods', COALESCE(s.mods, JSON_ARRAY()),
        'maximum_statistics', COALESCE(s.maximum_statistics, JSON_OBJECT()),
        'total_score_without_mods', s.total_score_without_mods,
        'statistics', JSON_MERGE_PATCH(JSON_OBJECT(), JSON_OBJECT(
            'great',           NULLIF(s.n300, 0),
            'ok',              NULLIF(s.n100, 0),
            'meh',             NULLIF(s.n50, 0),
            'miss',            NULLIF(s.nmiss, 0),
            'perfect',         NULLIF(s.ngeki, 0),
            'good',            NULLIF(s.nkatu, 0),
            'large_tick_hit',  NULLIF(s.nlarge_tick_hit, 0),
            'large_tick_miss', NULLIF(s.nlarge_tick_miss, 0),
            'small_tick_hit',  NULLIF(s.nsmall_tick_hit, 0),
            'slider_tail_hit', NULLIF(s.nslider_tail_hit, 0),
            'large_bonus',     NULLIF(s.nlarge_bonus, 0),
            'small_bonus',     NULLIF(s.nsmall_bonus, 0)
        ))
    )";

// Relax y autopilot NO entran, y no es por prolijidad.
//
// osu-web filtra los scores por ruleset_id y en Torii un score de relax no
// tiene ruleset propio: su ruleset_id colapsa al modo base. O sea que una play
// de osu!relax aparecia en las plays recientes del perfil como si fuera osu!
// standard, mezclada con las otras y sin ninguna marca. Los otros lugares donde
// podian colarse (leaderboard de mapa, best performance, primeros puestos)
// filtran ademas por ranked, asi que ahi no llegaban: la unica cosa que hacian
// era ese leak.
//
// Que se pierde: nada que se estuviera mostrando. El ranking de relax y
// autopilot sale de lazer_user_statistics, que es una tabla aparte por modo, y
// esta entero (ver osu_user_stats_osu_rx y compania). Las plays cuentan igual
// en el playcount y el passcount de cada mapa, que se calculan en la cache
// sobre torii.scores sin este filtro.
//
// Para mostrar los scores de relax uno por uno hace falta que tengan
// ruleset_id propio (4 a 7, como en g0v0), y eso arrastra el enum Ruleset, los
// mapas exhaustivos de score-helper.ts y mods.json, que solo conocen 0 a 3. Es
// un trabajo aparte y grande; esto no lo bloquea.
$V['scores'] = [
    'from' => "$src.scores s",
    'where' => "s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA')",
    'cols' => [
        'id' => 's.id',
        'user_id' => 's.user_id',
        'ruleset_id' => mode_int('s.gamemode'),
        'beatmap_id' => 's.beatmap_id',
        // Los replays viven en el storage de la api de Torii y osu-web no sabe
        // servirlos, asi que el boton de descarga se dibujaria para morir.
        'has_replay' => '0',
        'preserve' => 'COALESCE(s.preserve, 0)',
        'ranked' => 'COALESCE(s.ranked, 0)',
        'rank' => "COALESCE(s.`rank`, 'D')",
        'passed' => 'COALESCE(s.passed, 0)',
        'accuracy' => 'COALESCE(s.accuracy, 0)',
        'max_combo' => 'COALESCE(s.max_combo, 0)',
        'total_score' => 'COALESCE(s.total_score, 0)',
        'data' => $scoreData,
        'pp' => 's.pp',
        'started_at' => 's.started_at',
        'ended_at' => 'COALESCE(s.ended_at, NOW())',
        'unix_updated_at' => 'UNIX_TIMESTAMP(COALESCE(s.ended_at, NOW()))',
    ],
];

// Sin los de relax y autopilot: si entran con ruleset_id 0 el perfil los mezcla
// con osu vanilla y muestra un pp que no corresponde.
// PELIGRO, y el JOIN de abajo es lo que lo desactiva.
//
// Un pin no es una fila propia en Torii: es la columna pinned_order del score.
// Si esta vista sale de una sola tabla, MySQL la considera borrable y el
// "despinnear" de osu-web, que es un DELETE, no borraria el pin: borraria el
// SCORE. Con el join contra usuarios MySQL rechaza el DELETE ("Can not delete
// from join view") y el pin lo saca ToriiWriteThrough poniendo pinned_order en
// cero, que es lo que corresponde.
//
// El join no cuesta nada: es la clave primaria de lazer_users y la vista sigue
// resolviendose por MERGE.
$V['score_pins'] = [
    'from' => "$src.scores s JOIN $src.lazer_users pu ON pu.id = s.user_id",
    'where' => "s.pinned_order > 0 AND s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA')",
    'cols' => [
        'user_id' => 's.user_id',
        'score_id' => 's.id',
        'ruleset_id' => mode_int('s.gamemode'),
        'display_order' => 's.pinned_order',
        'created_at' => 'COALESCE(s.ended_at, NOW())',
        'updated_at' => 'COALESCE(s.ended_at, NOW())',
    ],
];

// ------------------------------------------------------- medallas, favoritos --

$V['osu_user_achievements'] = [
    'from' => "$src.lazer_user_achievements a",
    'cols' => [
        'user_id' => 'a.user_id',
        'achievement_id' => 'a.achievement_id',
        'date' => 'COALESCE(a.achieved_at, NOW())',
    ],
];

$V['osu_favouritemaps'] = [
    'from' => "$src.favourite_beatmapset f",
    'cols' => [
        'user_id' => 'f.user_id',
        'beatmapset_id' => 'f.beatmapset_id',
        'dateadded' => 'COALESCE(f.date, NOW())',
    ],
];

// --------------------------------------------------------------- playcounts --
//
// year_month es char(4) en formato ymm con dos digitos de anio: julio de 2026
// es '2607'. Es el formato que arma osu-web cuando escribe estas filas.

// La fuente tiene tres pares (jugador, mapa) repetidos, asi que hay que sumar
// en vez de quedarse con una fila. Es un GROUP BY sobre 64 mil filas y MySQL
// empuja el filtro por user_id adentro, que es como lo pide el perfil.
$V['osu_user_beatmap_playcount'] = [
    'from' => "$src.beatmap_playcounts p",
    'group' => 'p.user_id, p.beatmap_id',
    'cols' => [
        'user_id' => 'p.user_id',
        'beatmap_id' => 'p.beatmap_id',
        'playcount' => 'LEAST(SUM(p.playcount), 65535)',
    ],
];

$V['osu_user_month_playcount'] = [
    'from' => "$src.monthly_playcounts m",
    'cols' => [
        'user_id' => 'm.user_id',
        'year_month' => "CONCAT(LPAD(m.year % 100, 2, '0'), LPAD(m.month, 2, '0'))",
        'playcount' => 'LEAST(m.count, 65535)',
    ],
];

$V['osu_user_replayswatched'] = [
    'from' => "$src.replays_watched_counts r",
    'cols' => [
        'user_id' => 'r.user_id',
        'year_month' => "CONCAT(LPAD(r.year % 100, 2, '0'), LPAD(r.month, 2, '0'))",
        'count' => 'r.count',
    ],
];

// ------------------------------------------------------------------ equipos --

$V['teams'] = [
    'from' => "$src.teams t",
    'cols' => [
        'id' => 't.id',
        'name' => 'LEFT(t.name, 255)',
        'short_name' => "LEFT(COALESCE(t.short_name,''), 255)",
        // flag_file y header_file son NOMBRES de archivo, no urls: osu-web arma
        // la ruta como teams/flag/{id}/{flag_file}. Con la url entera queda un
        // rectangulo negro. Va NULLIF y no cadena vacia porque osu-web solo
        // saltea la imagen si el valor es nulo; con vacio arma una url
        // terminada en barra que igual da 404.
        'flag_file' => "NULLIF(SUBSTRING_INDEX(COALESCE(t.flag_url,''), '/', -1), '')",
        'header_file' => "NULLIF(SUBSTRING_INDEX(COALESCE(t.cover_url,''), '/', -1), '')",
        'url' => "LEFT(COALESCE(t.website,''), 255)",
        'description' => 't.description',
        'default_ruleset_id' => mode_int('t.playmode'),
        'leader_id' => 't.leader_id',
        'channel_id' => '0',
        'created_at' => 'COALESCE(t.created_at, NOW())',
        'updated_at' => 'COALESCE(t.created_at, NOW())',
    ],
];

$V['team_members'] = [
    'from' => "$src.team_members m",
    'cols' => [
        'user_id' => 'm.user_id',
        'team_id' => 'm.team_id',
        'created_at' => 'COALESCE(m.joined_at, NOW())',
        'updated_at' => 'COALESCE(m.joined_at, NOW())',
    ],
];

// ---------------------------------------------------------------- actividad --

$V['osu_events'] = [
    'from' => "$src.user_events e",
    'where' => "e.type IN ('RANK','RANK_LOST','ACHIEVEMENT','USERNAME_CHANGE')"
        . " AND CASE e.type"
        . "   WHEN 'ACHIEVEMENT' THEN JSON_EXTRACT(e.event_payload, '$.achievement.name') IS NOT NULL"
        . "   WHEN 'USERNAME_CHANGE' THEN JSON_EXTRACT(e.event_payload, '$.user.previous_username') IS NOT NULL"
        . "   ELSE JSON_EXTRACT(e.event_payload, '$.beatmap.url') IS NOT NULL END",
    'cols' => [
        'event_id' => 'e.id',
        'text' => event_text(),
        'beatmap_id' => "CASE WHEN e.type IN ('RANK','RANK_LOST')"
            . " THEN SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1)"
            . " ELSE NULL END",
        'beatmapset_id' => 'NULL',
        'user_id' => 'e.user_id',
        'date' => 'e.created_at',
        'epicfactor' => '1',
        'private' => '0',
    ],
];

// ------------------------------------------------------- historial de cuenta --

$V['osu_user_banhistory'] = [
    'from' => "$src.user_account_history h",
    'cols' => [
        'ban_id' => 'h.id',
        'user_id' => 'h.user_id',
        'reason' => "LEFT(COALESCE(h.description,''), 8000)",
        // OJO: el enum de Torii escribe SLIENCE, con el error de tipeo adentro.
        'ban_status' => "CASE h.type WHEN 'NOTE' THEN 0 WHEN 'RESTRICTION' THEN 1"
            . " WHEN 'SLIENCE' THEN 2 WHEN 'TOURNAMENT_BAN' THEN 3 ELSE 0 END",
        'period' => 'COALESCE(h.length, 0)',
        'timestamp' => 'h.timestamp',
        'banner_id' => 'NULL',
        'permanent' => 'COALESCE(h.permanent, 0)',
    ],
];

// Los nombres anteriores viajan como un array json en la fila del usuario.
// JSON_TABLE lo abre en filas; el change_id se deriva de la posicion para que
// sea estable entre lecturas.
$V['osu_username_change_history'] = [
    'from' => "$src.lazer_users u JOIN JSON_TABLE(u.previous_usernames, '$[*]'"
        . " COLUMNS (uname VARCHAR(30) PATH '$', pos FOR ORDINALITY)) jt",
    // El COLLATE no es opcional: JSON_TABLE devuelve la cadena con la
    // collation de la conexion y las tablas de Torii estan en general_ci, asi
    // que compararlas de una es "illegal mix of collations".
    'where' => 'JSON_LENGTH(u.previous_usernames) > 0'
        . ' AND jt.uname COLLATE utf8mb4_general_ci <> u.username',
    'cols' => [
        'change_id' => 'u.id * 100 + jt.pos',
        'user_id' => 'u.id',
        'username' => 'LEFT(u.username, 30)',
        'username_last' => 'LEFT(jt.uname, 30)',
        'type' => "'admin'",
        'timestamp' => 'COALESCE(u.join_date, NOW())',
    ],
];

// --------------------------------------------------------- posicion historica --

$V['osu_user_performance_rank'] = [
    'from' => "$src.rank_history h",
    'where' => "h.mode IN ('OSU','TAIKO','FRUITS','MANIA')",
    'group' => 'h.user_id, ' . mode_int('h.mode'),
    'cols' => array_merge([
        'user_id' => 'h.user_id',
        'mode' => mode_int('h.mode'),
    ], rank_history_cols()),
];

// El mejor rank historico es el numero mas chico.
$V['osu_user_performance_rank_highest'] = [
    'from' => "$src.rank_history h",
    'where' => "h.`rank` > 0 AND h.mode IN ('OSU','TAIKO','FRUITS','MANIA')",
    'group' => 'h.user_id, ' . mode_int('h.mode'),
    'cols' => [
        'user_id' => 'h.user_id',
        'mode' => mode_int('h.mode'),
        'rank' => 'MIN(h.`rank`)',
        'updated_at' => 'MAX(h.date)',
    ],
];

// ---------------------------------------------------------- ranked play --
//
// osu-web ya trae toda la pantalla de ranked play hecha: la ruta
// /rankings/ranked-play/{modo}/{pool}, los modelos, el selector de pool y el
// badge de rating provisional. Lo unico que le faltaba era de donde leer, y
// resulta que el esquema de g0v0 es casi el mismo porque salio del suyo.
//
// variant_id y use_dmr no existen en Torii: van en cero, que es lo que
// significa "sin variante" y "sin dynamic match rating".
$V['matchmaking_pools'] = [
    'from' => "$src.matchmaking_pools p",
    'cols' => [
        'id' => 'p.id',
        'ruleset_id' => 'p.ruleset_id',
        'name' => 'p.name',
        'type' => 'p.type',
        'active' => 'p.active',
        'lobby_size' => 'p.lobby_size',
        'rating_search_radius' => 'p.rating_search_radius',
        'rating_search_radius_max' => 'p.rating_search_radius_max',
        'rating_search_radius_exp' => 'p.rating_search_radius_exp',
        'created_at' => 'p.created_at',
        'updated_at' => 'p.updated_at',
    ],
];

// elo_data es el json con la posterior del rating: de ahi sale el sigma que
// decide si el rating todavia es provisional.
//
// OJO: en g0v0 la clave primaria de esta tabla es (user_id) sola, no
// (user_id, pool_id), asi que un jugador tiene UNA fila y no una por pool. La
// vista lo refleja tal cual. El dia que se juegue ranked play de mas de un modo
// hay que arreglar la tabla primero, no la vista.
$V['matchmaking_user_stats'] = [
    'from' => "$src.matchmaking_user_stats m",
    'where' => 'm.pool_id IS NOT NULL',
    'cols' => [
        'user_id' => 'm.user_id',
        'pool_id' => 'm.pool_id',
        'first_placements' => 'COALESCE(m.first_placements, 0)',
        'total_points' => 'COALESCE(m.total_points, 0)',
        'elo_data' => 'm.elo_data',
        'rating' => 'COALESCE(m.rating, 0)',
        'plays' => 'COALESCE(m.plays, 0)',
        'created_at' => 'm.created_at',
        'updated_at' => 'm.updated_at',
    ],
];

$V['matchmaking_user_elo_history'] = [
    'from' => "$src.matchmaking_user_elo_history h",
    'cols' => [
        'id' => 'h.id',
        'room_id' => 'h.room_id',
        'pool_id' => 'h.pool_id',
        'user_id' => 'h.user_id',
        'opponent_id' => 'h.opponent_id',
        'result' => 'h.result',
        'elo_before' => 'h.elo_before',
        'elo_after' => 'h.elo_after',
        'created_at' => 'h.created_at',
        'updated_at' => 'h.updated_at',
    ],
];

// -------------------------------------------------------------- agregados --
//
// El nombre y la bandera de cada pais son catalogo de osu-web, no dato de
// Torii, asi que quedan en una tabla propia; los numeros salen en vivo de las
// estadisticas. Son cuarenta grupos sobre diez mil filas, no cuesta nada.
$V['osu_countries'] = [
    'from' => "$dst.torii_country_catalog b LEFT JOIN ("
        . " SELECT COALESCE(NULLIF(u.country_code,''),'XX') AS acronym, COUNT(*) AS usercount,"
        . " SUM(COALESCE(s.play_count,0)) AS playcount, SUM(COALESCE(s.ranked_score,0)) AS rankedscore,"
        . " SUM(COALESCE(s.pp,0)) AS pp"
        . " FROM $src.lazer_user_statistics s JOIN $src.lazer_users u ON u.id = s.user_id"
        . " WHERE s.mode = 'OSU' GROUP BY 1"
        . ") c ON c.acronym = b.acronym",
    'cols' => [
        'acronym' => 'b.acronym',
        'name' => 'b.name',
        'display' => 'b.display',
        'usercount' => 'COALESCE(c.usercount, 0)',
        'playcount' => 'COALESCE(c.playcount, 0)',
        'rankedscore' => 'COALESCE(c.rankedscore, 0)',
        'pp' => 'COALESCE(c.pp, 0)',
    ],
];

// Los primeros puestos por mapa si van a cache: sacarlos en vivo es una funcion
// de ventana sobre los doscientos mil scores por cada lectura.
$V['beatmap_leaders'] = [
    'from' => "$dst.torii_cache_beatmap_leader l",
    'cols' => [
        'score_id' => 'l.score_id',
        'beatmap_id' => 'l.beatmap_id',
        'ruleset_id' => 'l.ruleset_id',
        'user_id' => 'l.user_id',
    ],
];

// ---------------------------------------------------------------- generador --

function columns(PDO $pdo, string $schema, string $table): array
{
    $st = $pdo->prepare(
        'SELECT COLUMN_NAME, COLUMN_TYPE, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
         ORDER BY ORDINAL_POSITION'
    );
    $st->execute([$schema, $table]);

    return $st->fetchAll(PDO::FETCH_ASSOC);
}

// Valor para una columna que el mapa no cubre. Se prefiere el default que la
// propia tabla declara: es lo que osu-web asume cuando inserta sin nombrarla.
function filler(array $col): string
{
    $default = $col['COLUMN_DEFAULT'];

    if ($default !== null) {
        $d = strtoupper(trim($default, '()'));
        if ($d === 'CURRENT_TIMESTAMP' || $d === 'NOW' || $d === 'UNIX_TIMESTAMP') {
            return in_array($col['DATA_TYPE'], ['int', 'bigint'], true) ? 'UNIX_TIMESTAMP()' : 'NOW()';
        }
        if (is_numeric($default)) {
            return $default;
        }

        return "'" . str_replace("'", "''", $default) . "'";
    }

    if ($col['IS_NULLABLE'] === 'YES') {
        return 'NULL';
    }

    $t = $col['DATA_TYPE'];

    if (in_array($t, ['tinyint', 'smallint', 'mediumint', 'int', 'bigint', 'float', 'double', 'decimal'], true)) {
        return '0';
    }
    if (in_array($t, ['timestamp', 'datetime', 'date'], true)) {
        return 'NOW()';
    }
    if ($t === 'json') {
        return 'JSON_OBJECT()';
    }
    if ($t === 'enum') {
        // El primer valor del enum. COLUMN_TYPE viene como enum('a','b').
        preg_match("/enum\('([^']*)'/", $col['COLUMN_TYPE'], $m);

        return "'" . ($m[1] ?? '') . "'";
    }
    if (in_array($t, ['binary', 'varbinary', 'blob'], true)) {
        return "''";
    }

    return "''";
}

// ------------------------------------------------------------------- salida --

$out = [];
$out[] = "-- torii: vistas que apuntan osu-web a las tablas de g0v0.";
$out[] = "--";
$out[] = "-- GENERADO por torii-views.php. No editar a mano: se regenera.";
$out[] = "-- origen: $src   destino: $dst   columnas leidas de: $ref";
$out[] = "";

$missing = [];

foreach ($V as $table => $def) {
    // Las vistas nuevas (las de relax y autopilot) no tienen tabla de donde
    // leer el layout, asi que lo piden prestado a la variante que ya existe.
    // Se busca primero en el esquema de referencia y despues en el destino.
    // Los dos hacen falta: cuando se regenera despues de mudar tablas a
    // osu_bak, unas viven alla y otras (las que se prestan el layout, como la
    // tabla de variante de mania) siguen en osu.
    $layout = $def['like'] ?? $table;
    $cols = columns($pdo, $ref, $layout);

    if ($cols === [] && $ref !== $dst) {
        $cols = columns($pdo, $dst, $layout);
    }

    if ($cols === []) {
        $missing[] = "$ref.$table no existe";
        continue;
    }

    // Columnas que osu-web no tiene y Torii si. Se agregan al final en vez de
    // dar error: son datos propios (puntos, aura, color de nombre) que el fork
    // muestra en sus propias pantallas. Eloquent hace SELECT * asi que llegan
    // al modelo como un atributo mas, pero ojo: User::getAttribute es un match
    // sin default, o sea que cada una necesita su linea ahi.
    $extra = $def['extra'] ?? [];
    $known = $def['cols'];
    $unknown = array_diff(array_keys($known), array_column($cols, 'COLUMN_NAME'));

    if ($unknown !== []) {
        $missing[] = "$table: el mapa nombra columnas que no existen: " . implode(', ', $unknown);
    }

    $select = [];
    $filled = [];

    foreach ($cols as $col) {
        $name = $col['COLUMN_NAME'];
        $expr = $known[$name] ?? null;

        if ($expr === null) {
            $expr = filler($col);
            $filled[] = $name;
        }

        $select[] = "    $expr AS `$name`";
    }

    foreach ($extra as $name => $expr) {
        // Al regenerar leyendo del propio esquema destino, las columnas extra
        // de la corrida anterior ya vienen en la lista de la vista y se
        // duplicarian. Las de arriba mandan: tienen la misma expresion.
        if (in_array($name, array_column($cols, 'COLUMN_NAME'), true)) {
            continue;
        }

        $select[] = "    $expr AS `$name`";
    }

    $out[] = '-- ' . str_repeat('-', 75);
    $out[] = "-- $table";

    if ($filled !== []) {
        // Deja constancia de lo que no viene de Torii, que es justamente donde
        // hay que mirar cuando algo aparece vacio en la web.
        $out[] = '-- sin dato en Torii, va el default de la columna: ' . implode(', ', $filled);
    }

    $out[] = "DROP VIEW IF EXISTS `$dst`.`$table`;";
    $out[] = "CREATE VIEW `$dst`.`$table` AS";
    $out[] = 'SELECT';
    $out[] = implode(",\n", $select);
    $out[] = "FROM {$def['from']}";

    if (isset($def['where'])) {
        $out[] = "WHERE {$def['where']}";
    }
    if (isset($def['group'])) {
        $out[] = "GROUP BY {$def['group']}";
    }

    $out[] = ';';
    $out[] = '';
}

if ($missing !== []) {
    fwrite(STDERR, "ERRORES:\n  " . implode("\n  ", $missing) . "\n");
    exit(1);
}

echo implode("\n", $out), "\n";
