<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

declare(strict_types=1);

namespace App\Libraries\User;

use App\Libraries\ImageProcessor;
use App\Libraries\StorageUrl;
use App\Libraries\Torii\ProfileMedia;
use App\Models\User;

class AvatarHelper
{
    private const DISK = 'avatar';

    public static function set(User $user, ?\SplFileInfo $src): bool
    {
        // torii: las fotos las guarda la api del juego, no el sitio. Guardarlas
        // aca no serviria de nada: nginx proxea /uploads/avatar a la api, asi
        // que el archivo local no se llega a servir nunca y el juego se queda
        // mirando un 404. Ver el comentario largo en Torii\ProfileMedia.
        if (ProfileMedia::enabled()) {
            if ($src === null) {
                ProfileMedia::deleteAvatar($user);
            } else {
                ProfileMedia::setAvatar($user, $src);
            }

            return true;
        }

        $id = $user->getKey();
        $storage = storage_disk(static::DISK);

        if ($src === null) {
            $storage->delete($id);
        } else {
            $srcPath = $src->getRealPath();
            $processor = new ImageProcessor($srcPath, [256, 256], 100000);
            $processor->process();

            $storage->putFileAs('/', $src, $id, 'public');
            $entry = $id.'_'.time().'.'.$processor->ext();
        }

        cache_proxy_purge(StorageUrl::make(static::DISK, (string) $id));

        return $user->update(['user_avatar' => $entry ?? '']);
    }

    public static function url(User $user): string
    {
        $value = $user->getRawAttribute('user_avatar');

        return present($value)
            ? StorageUrl::make(static::DISK, strtr($value, '_', '?'))
            : $GLOBALS['cfg']['osu']['avatar']['default'];
    }
}
