<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

namespace App\Http\Middleware;

use App\Models\User;

class VerifyUserAlways extends VerifyUser
{
    const GET_ACTION_METHODS = [
        'GET' => true,
        'HEAD' => true,
        'OPTIONS' => true,
    ];

    public static function isRequired(?User $user): bool
    {
        // torii: en la instancia de evaluacion no hay correo de verdad. El
        // codigo se manda al log de laravel, asi que verificar la sesion es
        // imposible sin ir a leer el archivo, y encima salta siempre porque los
        // grupos reales de Torii se proyectaron y el admin cuenta como
        // privilegiado. Con TORII_SKIP_SESSION_VERIFICATION=true no se pide.
        // Fuera de esta instancia la variable no existe y el comportamiento es
        // el de siempre.
        if (env('TORII_SKIP_SESSION_VERIFICATION') === true) {
            return false;
        }

        return $user !== null
            && (
                $GLOBALS['cfg']['osu']['user']['always_require_verification']
                || $user->isPrivileged()
                || $user->isInactive());
    }

    public function requiresVerification($request)
    {
        $method = $request->getMethod();
        $isPostAction = $GLOBALS['cfg']['osu']['user']['post_action_verification']
            ? !isset(static::GET_ACTION_METHODS[$method])
            : false;

        $isRequired = $isPostAction || $method === 'DELETE' || session()->get('requires_verification');

        return $isRequired;
    }
}
