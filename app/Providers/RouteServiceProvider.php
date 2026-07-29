<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Route;

class RouteServiceProvider extends ServiceProvider
{
    /**
     * This namespace is applied to the controller routes in your routes file.
     *
     * In addition, it is set as the URL generator's root namespace.
     *
     * @var string
     */
    protected $namespace = 'App\Http\Controllers';

    /**
     * Define the routes for the application.
     *
     * @param \Illuminate\Routing\Router $router
     *
     * @return void
     */
    public function map()
    {
        Route::group(['namespace' => $this->namespace], function ($router) {
            // torii: las rutas del fork van aparte para no pelear con web.php
            // en cada sync con ppy, y van ANTES: web.php tiene un
            // rankings/{mode}/{type} generico que se come cualquier cosa que
            // arranque con rankings/, y por eso las suyas propias
            // (rankings/kudosu, rankings/top-plays) tambien estan declaradas
            // antes que el.
            require base_path('routes/torii.php');
            require base_path('routes/web.php');
        });
    }
}
