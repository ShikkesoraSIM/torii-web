<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Events\UserSessionEvent;
use Closure;
use Illuminate\Http\Request;

class SetSessionVerification
{
    public function handle(Request $request, Closure $next)
    {
        $user = \Auth::user();
        if ($user !== null) {
            $session = \Session::instance();
            // torii: Torii no manda correo. El codigo de verificacion termina
            // en el log del servidor, asi que pedirlo deja al jugador sin forma
            // de entrar a su propia configuracion, y a los privilegiados
            // (admin, gmt, bng, nat) les salta siempre. Con la verificacion
            // apagada toda sesion cuenta como verificada, que es lo unico
            // coherente cuando no hay canal para verificarla.
            //
            // Va aca y no en VerifyUserAlways::isRequired porque ese solo
            // decide el flag de la sesion: el que corta el request es
            // VerifyUser::handle, que mira isSessionVerified().
            $isVerified = $GLOBALS['cfg']['torii']['skip_session_verification']
                || $session->isVerified();

            if ($isVerified) {
                $user->markSessionVerified();
            } else {
                $isRequired = VerifyUserAlways::isRequired($user);
                if ($session->get('requires_verification') !== $isRequired) {
                    $session->put('requires_verification', $isRequired);
                    $session->save();
                    UserSessionEvent::newVerificationRequirementChange(
                        $user->getKey(),
                        $isRequired,
                    )->broadcast();
                }
            }
        }

        return $next($request);
    }
}
