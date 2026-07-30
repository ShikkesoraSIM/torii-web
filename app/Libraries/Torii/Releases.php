<?php

// torii: resuelve la ultima release de cada stream del cliente.
//
// Por que hace falta y no alcanza con las urls fijas de config/osu.php: esas
// apuntan a /releases/latest/download/, que en github es la ultima release NO
// marcada como prerelease. Torii publica tres streams desde el mismo repo y los
// distingue por el sufijo del tag:
//
//   -torii     el estable, .NET 8.  Es el unico sin prerelease, asi que es el
//              que resuelve /latest y por eso las urls fijas siempre daban este.
//   -nova      .NET 10, va adelante. Marcado prerelease.
//   -vanilla   upstream de ppy cableado a Torii. Marcado prerelease.
//
// Github no tiene un /latest-prerelease, asi que para nova y vanilla hay que
// preguntarle a la api cual es el tag mas nuevo de cada sufijo. La respuesta
// viene ordenada de mas nueva a mas vieja, asi que la primera de cada sufijo es
// la que va.

declare(strict_types=1);

namespace App\Libraries\Torii;

use Exception;

class Releases
{
    // En el orden en que se muestran.
    const STREAMS = ['torii', 'nova', 'vanilla'];

    // Los tres streams publican la misma grilla de archivos, con el mismo
    // nombre. Las claves son las de $lazerPlatformNames de HomeController mas
    // las arm64, que la deteccion por user-agent no distingue pero el que las
    // necesita las busca.
    const ASSETS = [
        'windows_x64' => 'install-win-x64.exe',
        'windows_arm64' => 'install-win-arm64.exe',
        'macos_as' => 'osu.app.Apple.Silicon.zip',
        'macos_intel' => 'osu.app.Intel.zip',
        'linux_x64' => 'torii-linux-x64.AppImage',
        'linux_arm64' => 'torii-linux-arm64.AppImage',
        'android' => 'torii.apk',
    ];

    const REPO = 'ShikkesoraSIM/torii-osu';

    // Media hora. La api de github sin token permite 60 pedidos por hora por ip,
    // y la pagina de descarga es de las mas visitadas: sin cache un pico de
    // visitas la agota y todos ven la pagina degradada.
    const CACHE_SEGUNDOS = 1800;

    /**
     * Todos los streams con su tag y sus urls por plataforma.
     *
     * Devuelve [] si github no contesta. Ese caso NO es un error a mostrar: la
     * pagina sigue andando con el boton de siempre, que apunta a /latest.
     */
    public static function all(): array
    {
        return cache()->remember('torii_releases', static::CACHE_SEGUNDOS, function () {
            try {
                return static::consultar();
            } catch (Exception $e) {
                // A la pagina de descarga no le sirve reventar por esto.
                \Log::warning('torii: no se pudieron leer las releases: '.$e->getMessage());

                return [];
            }
        });
    }

    /**
     * Un solo stream, o null si no se pudo resolver.
     */
    public static function stream(string $stream): ?array
    {
        return static::all()[$stream] ?? null;
    }

    /**
     * La url de un archivo para un stream y una plataforma.
     *
     * Cae a la url fija de config cuando no se pudo resolver el stream, que para
     * el estable es la correcta igual.
     */
    public static function url(string $stream, string $platform): ?string
    {
        $tag = static::stream($stream)['tag'] ?? null;
        $asset = static::ASSETS[$platform] ?? null;

        if ($tag === null || $asset === null) {
            return $stream === 'torii' ? osu_url("lazer_dl.{$platform}") : null;
        }

        return 'https://github.com/'.static::REPO."/releases/download/{$tag}/{$asset}";
    }

    private static function consultar(): array
    {
        $ctx = stream_context_create([
            'http' => [
                'timeout' => 5,
                // Github rechaza sin user-agent.
                'header' => "User-Agent: torii-web\r\nAccept: application/vnd.github+json\r\n",
                // Un 403 por rate limit tiene que llegar como respuesta y no
                // como warning de php, asi que se pide el cuerpo igual.
                'ignore_errors' => true,
            ],
        ]);

        $crudo = file_get_contents(
            'https://api.github.com/repos/'.static::REPO.'/releases?per_page=30',
            false,
            $ctx,
        );

        if ($crudo === false) {
            throw new Exception('github no contesto');
        }

        $releases = json_decode($crudo, true);

        if (!is_array($releases) || !isset($releases[0]['tag_name'])) {
            throw new Exception('respuesta inesperada: '.substr($crudo, 0, 120));
        }

        $out = [];

        foreach ($releases as $r) {
            if (($r['draft'] ?? false) === true) {
                continue;
            }

            $tag = $r['tag_name'] ?? '';
            $stream = static::streamDelTag($tag);

            // La primera de cada sufijo es la mas nueva: la api las devuelve
            // ordenadas por fecha de publicacion descendente.
            if ($stream === null || isset($out[$stream])) {
                continue;
            }

            $out[$stream] = [
                'tag' => $tag,
                // Sin la v de adelante ni el sufijo: "2026.727.0".
                'version' => preg_replace('/^v|-'.preg_quote($stream, '/').'$/', '', $tag),
                'publicada' => $r['published_at'] ?? null,
                'prerelease' => (bool) ($r['prerelease'] ?? false),
                'notas' => $r['html_url'] ?? null,
            ];
        }

        return $out;
    }

    private static function streamDelTag(string $tag): ?string
    {
        foreach (static::STREAMS as $stream) {
            if (str_ends_with($tag, '-'.$stream)) {
                return $stream;
            }
        }

        return null;
    }
}
