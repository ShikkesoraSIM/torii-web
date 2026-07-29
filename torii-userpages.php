<?php

// torii: proyecta la userpage, la pestana "me!" de cada perfil.
//
// No se puede hacer con SQL. osu-web no guarda el texto en la fila del usuario:
// guarda un post de foro y deja el id en phpbb_users.userpage_post_id. Y el
// bbcode no va crudo, va en el formato de phpbb, con un uid por post pegado a
// cada etiqueta ([b:1a2b3c] en vez de [b]) mas un bitfield que dice que
// etiquetas aparecen. Eso lo calcula BBCodeForDB, asi que hay que pasar por php.
//
// Correr con:
//   docker compose cp torii-userpages.php php:/tmp/userpages.php
//   docker compose exec -T php php /tmp/userpages.php
//
// Es idempotente: el id del post se deriva del id del usuario.

require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;

$rows = DB::connection('mysql')->select("
    SELECT u.id,
           u.username,
           JSON_UNQUOTE(JSON_EXTRACT(u.page, '$.raw')) AS raw,
           UNIX_TIMESTAMP(COALESCE(u.last_visit, u.join_date, NOW())) AS ts
    FROM torii.lazer_users u
    JOIN osu.phpbb_users p ON p.user_id = u.id
    WHERE u.page IS NOT NULL
      AND JSON_UNQUOTE(JSON_EXTRACT(u.page, '$.raw')) NOT IN ('', 'null')
");

$n = 0;
foreach ($rows as $r) {
    $bb = new App\Libraries\BBCodeForDB($r->raw);

    // post_id es mediumint y la tabla esta vacia, asi que el rango de 900000
    // para arriba no choca con nada y hace que volver a correr esto pise el
    // mismo post en vez de crear uno nuevo.
    $postId = 900000 + (int) $r->id;

    DB::statement(
        'INSERT INTO osu.phpbb_posts
            (post_id, topic_id, forum_id, poster_id, poster_ip, post_time,
             post_username, post_subject, post_text, bbcode_uid, bbcode_bitfield,
             post_postcount)
         VALUES (?, 0, 0, ?, \'\', ?, \'\', ?, ?, ?, ?, 0)
         ON DUPLICATE KEY UPDATE
            post_text = VALUES(post_text),
            bbcode_uid = VALUES(bbcode_uid),
            bbcode_bitfield = VALUES(bbcode_bitfield)',
        [
            $postId,
            $r->id,
            $r->ts,
            mb_substr($r->username."'s user page", 0, 100),
            $bb->generate(),
            $bb->uid,
            $bb->bitfield,
        ]
    );

    // El userpage_post_id no se escribe: la vista phpbb_users lo deriva del id
    // del usuario, con la misma cuenta, para los que tienen algo escrito.

    $n++;
}

echo "{$n} userpages proyectadas\n";
