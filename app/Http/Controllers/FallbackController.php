<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

namespace App\Http\Controllers;

class FallbackController extends Controller
{
    public function __construct()
    {
        if (is_api_request()) {
            $this->middleware('api');
        } else {
            $this->middleware('web');
        }

        parent::__construct();
    }

    public function index()
    {
        app('route-section')->setError(404);

        if (is_json_request()) {
            return error_popup(osu_trans('errors.missing_route'), 404);
        }

        if (request()->isMethod('GET') && request()->cookie('torii_frontend') === 'torii-web') {
            $uri = request()->getRequestUri();
            $separator = str_contains($uri, '?') ? '&' : '?';
            $classicUrl = rtrim(config('osu.frontend_choice.classic_url'), '/');

            return redirect()->away("{$classicUrl}{$uri}{$separator}frontend-fallback=1");
        }

        return ext_view('layout.error', ['statusCode' => 404], 'html', 404);
    }
}
