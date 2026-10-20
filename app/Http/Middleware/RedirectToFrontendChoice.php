<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

namespace App\Http\Middleware;

use Closure;
use Illuminate\Contracts\Auth\Guard;

class RedirectToFrontendChoice
{
    protected $auth;

    public function __construct(Guard $auth)
    {
        $this->auth = $auth;
    }

    public function handle($request, Closure $next)
    {
        $preference = $request->cookie('torii_frontend');
        $needsChoice = !in_array($preference, ['classic', 'torii-web'], true);
        $acceptsHtml = str_contains($request->header('Accept', ''), 'text/html');

        if (
            $needsChoice
            && $this->auth->user() !== null
            && $request->isMethod('GET')
            && $acceptsHtml
            && !is_json_request()
        ) {
            $query = http_build_query([
                'from' => 'torii-web',
                'return' => $request->getRequestUri(),
            ]);

            return redirect()->away(rtrim(config('osu.frontend_choice.classic_url'), '/')."/frontend-choice?{$query}");
        }

        return $next($request);
    }
}
