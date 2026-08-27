<?php

// torii: las fotos de perfil las guarda la api del juego, no el sitio.

declare(strict_types=1);

namespace App\Libraries\Torii;

use App\Exceptions\ImageProcessorException;
use App\Libraries\ImageProcessor;
use App\Models\User;
use Illuminate\Support\Facades\Http;

/**
 * Fotos de perfil contra la api de Torii.
 *
 * El sitio no puede pedir un token del usuario: el password grant de g0v0 exige
 * turnstile para todo lo que no sea el cliente del juego. Asi que se usa el
 * mismo trato que ya tiene el bot de discord, un secreto compartido en un header
 * y el id del usuario explicito. No agrega permisos que el sitio no tuviera: ya
 * escribe en lazer_users a traves de sus vistas.
 *
 * Lo importante es que esto NO escribe el archivo por su cuenta, aunque podria
 * (storage/avatars esta en la misma maquina). Del otro lado, subir una foto
 * ademas valida la imagen, borra la anterior, deja el rastro para moderacion,
 * avisa a los mods si es nsfw e invalida el cache del usuario en redis.
 * Escribiendo el archivo a mano se perderia todo eso sin que nadie se entere, y
 * el cache viejo dejaria la foto anterior dando vueltas por horas.
 */
class ProfileMedia
{
    // g0v0 RECHAZA (no achica) cualquier avatar de mas de 256x256, asi que la
    // imagen se procesa aca antes de mandarla. Mismos numeros que usaba
    // AvatarHelper cuando el archivo se guardaba local.
    private const AVATAR_DIM = [256, 256];
    private const AVATAR_FILESIZE = 100000;

    private const TIMEOUT = 15;

    public static function enabled(): bool
    {
        return static::apiUrl() !== '' && static::token() !== '';
    }

    /**
     * Si el usuario tiene la foto marcada como nsfw.
     *
     * Se lee de la base y no de la api a proposito: esto lo llama la pagina de
     * configuracion en cada carga, y meterle una llamada http a un render es
     * justo lo que hace lento a un sitio. La columna esta a un indice de
     * distancia y el dato es el mismo.
     *
     * Nunca revienta: si algo falla se devuelve false y la pagina carga igual.
     * Que la configuracion entera se caiga por no poder dibujar un tilde seria
     * bastante peor que el tilde equivocado.
     */
    public static function avatarIsNsfw(User $user): bool
    {
        try {
            $row = \DB::selectOne(
                'SELECT avatar_nsfw FROM `'.$GLOBALS['cfg']['torii']['source_schema'].'`.`lazer_users` WHERE id = ?',
                [$user->getKey()]
            );
        } catch (\Throwable $e) {
            log_error($e);

            return false;
        }

        return (bool) ($row->avatar_nsfw ?? false);
    }

    public static function deleteAvatar(User $user): void
    {
        static::assertEnabled();

        // El id va en la query y no en el cuerpo: del otro lado es un parametro
        // de query, y un DELETE con cuerpo json le llegaria vacio.
        static::handle(static::request()->delete(
            static::apiUrl().'/api/private/web/avatar?user_id='.$user->getKey()
        ));

        $user->refresh();
    }

    public static function setAvatar(User $user, \SplFileInfo $src): void
    {
        static::assertEnabled();

        $path = $src->getRealPath();
        if ($path === false) {
            throw new ImageProcessorException(osu_trans('users.show.edit.cover.upload.broken_file'));
        }

        // Achica y saca el exif, igual que antes. Tira ImageProcessorException
        // sola si el archivo no es una imagen.
        (new ImageProcessor($path, static::AVATAR_DIM, static::AVATAR_FILESIZE))->process();

        $contents = file_get_contents($path);
        if ($contents === false) {
            throw new ImageProcessorException(osu_trans('users.show.edit.cover.upload.broken_file'));
        }

        // Subir NO tiene que desmarcar una cuenta que ya estaba marcada: quien
        // sube fotos subidas de tono suele subir otra igual, y que el tilde se
        // borre solo en cada cambio lo deja publicando sin marca sin enterarse.
        // Para sacarlo esta la casilla, que es explicita.
        $isNsfw = static::avatarIsNsfw($user);

        static::handle(
            static::request()
                ->attach('content', $contents, 'avatar.png')
                ->post(static::apiUrl().'/api/private/web/avatar/upload', [
                    'user_id' => $user->getKey(),
                    'is_nsfw' => $isNsfw ? 'true' : 'false',
                ])
        );

        // La foto vive en lazer_users y la vista la lee de ahi, asi que el
        // usuario que este request ya tenia cargado quedo viejo: sin esto la
        // respuesta devuelve la foto ANTERIOR y en pantalla parece que no paso
        // nada hasta recargar.
        $user->refresh();
    }

    public static function setAvatarNsfw(User $user, bool $isNsfw): void
    {
        static::assertEnabled();

        static::handle(static::request()->asForm()->post(static::apiUrl().'/api/private/web/avatar/nsfw', [
            'user_id' => $user->getKey(),
            'is_nsfw' => $isNsfw ? 'true' : 'false',
        ]));

        $user->refresh();
    }

    private static function apiUrl(): string
    {
        return $GLOBALS['cfg']['torii']['api_url'];
    }

    private static function assertEnabled(): void
    {
        if (!static::enabled()) {
            throw new ImageProcessorException('Profile pictures are not available right now.');
        }
    }

    /**
     * Traduce la respuesta de la api a algo que el jugador pueda leer.
     *
     * g0v0 pone el motivo en "detail" y ahi vienen cosas utiles ("File size
     * exceeds...", "Your account is restricted..."), asi que se muestran tal
     * cual. Un 5xx no: eso es problema nuestro y no le dice nada a nadie.
     */
    private static function handle(\Illuminate\Http\Client\Response $response): void
    {
        if ($response->successful()) {
            return;
        }

        $detail = $response->json('detail');

        if ($response->serverError() || !is_string($detail) || $detail === '') {
            throw new ImageProcessorException('Could not save your picture. Try again in a moment.');
        }

        throw new ImageProcessorException($detail);
    }

    private static function request(): \Illuminate\Http\Client\PendingRequest
    {
        return Http::withHeaders(['X-Torii-Web-Token' => static::token()])
            ->timeout(static::TIMEOUT);
    }

    private static function token(): string
    {
        return $GLOBALS['cfg']['torii']['web_token'];
    }
}
