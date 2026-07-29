<?php

// torii: la pagina de perfil, la pestana "me!".
//
// osu-web no la guarda en la fila del usuario: la guarda como un tema del foro
// y deja el id del post en phpbb_users.userpage_post_id. Torii la guarda como
// un json en lazer_users.page, con el bbcode crudo y el html ya renderizado,
// que es lo que leen el juego y lazer-web.
//
// Si osu-web la guardara a su manera, el jugador escribiria su pagina desde la
// web y en el juego seguiria viendo la vieja. Asi que la fuente de verdad sigue
// siendo lazer_users.page: se escribe ahi, y ademas se deja una copia en
// phpbb_posts porque es de donde osu-web la lee para mostrarla.
//
// El id del post se deriva del id del usuario con la misma cuenta que hace la
// vista phpbb_users, asi que no hace falta guardar el vinculo en ningun lado.

declare(strict_types=1);

namespace App\Libraries\Torii;

use App\Libraries\BBCodeForDB;
use App\Libraries\BBCodeFromDB;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class UserPage
{
    // phpbb_posts esta vacia y post_id es mediumint, asi que de 900000 para
    // arriba no choca con nada del foro.
    const POST_ID_OFFSET = 900000;

    public static function handles(User $user): bool
    {
        return QueryHints::isView($user->getTable());
    }

    public static function postId(User $user): int
    {
        return static::POST_ID_OFFSET + $user->getKey();
    }

    public static function update(User $user, string $text): User
    {
        $bb = new BBCodeForDB($text);
        $postText = $bb->generate();
        $html = (new BBCodeFromDB($postText, $bb->uid))->toHTML();

        DB::transaction(function () use ($bb, $html, $postText, $text, $user) {
            DB::update(
                'UPDATE `'.WriteThrough::schema().'`.`lazer_users` SET page = JSON_OBJECT(\'raw\', ?, \'html\', ?) WHERE id = ?',
                [$text, $html, $user->getKey()]
            );

            DB::insert(
                'INSERT INTO `phpbb_posts`
                    (post_id, topic_id, forum_id, poster_id, poster_ip, post_time,
                     post_username, post_subject, post_text, bbcode_uid, bbcode_bitfield,
                     post_postcount)
                 VALUES (?, 0, 0, ?, \'\', ?, \'\', ?, ?, ?, ?, 0)
                 ON DUPLICATE KEY UPDATE
                    post_text = VALUES(post_text),
                    bbcode_uid = VALUES(bbcode_uid),
                    bbcode_bitfield = VALUES(bbcode_bitfield)',
                [
                    static::postId($user),
                    $user->getKey(),
                    time(),
                    mb_substr($user->username."'s user page", 0, 100),
                    $postText,
                    $bb->uid,
                    $bb->bitfield,
                ]
            );
        });

        return $user->fresh();
    }
}
