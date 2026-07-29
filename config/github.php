<?php

/*
 * This file is part of Laravel GitHub.
 *
 * (c) Graham Campbell <graham@alt-three.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

return [

    /*
    |--------------------------------------------------------------------------
    | Default Connection Name
    |--------------------------------------------------------------------------
    |
    | Here you may specify which of the connections below you wish to use as
    | your default connection for all work. Of course, you may use many
    | connections at once using the manager class.
    |
    */

    'default' => 'main',

    /*
    |--------------------------------------------------------------------------
    | GitHub Connections
    |--------------------------------------------------------------------------
    |
    | Here are each of the connections setup for your application. Example
    | configuration has been included, but you may add as many connections as
    | you would like. Note that the 3 supported authentication methods are:
    | "application", "password", and "token".
    |
    */

    'connections' => [

        'main' => [
            // torii: sin token NO se autentica, en vez de autenticarse con la
            // cadena vacia.
            //
            // compose pasa GITHUB_TOKEN: "${GITHUB_TOKEN}", que sin la variable
            // seteada llega como "" y no como ausente. Con method => 'token' y
            // token vacio, el cliente manda un Authorization en blanco y github
            // contesta 401 Bad credentials. Eso dejaba la wiki entera en 404,
            // porque el sync se come la excepcion y el indice queda en cero
            // documentos, sin decir nada.
            //
            // El repositorio de la wiki de Torii es publico, asi que sin
            // autenticar se lee igual. El limite pasa de 5000 a 60 pedidos por
            // hora, que para ocho paginas que se revisan cada cinco horas sobra.
            'token' => presence(env('GITHUB_TOKEN')),
            'method' => presence(env('GITHUB_TOKEN')) === null ? 'none' : 'token',
            // 'backoff' => false,
            // 'cache' => false,
            // 'version' => 'v3',
            // 'enterprise' => false,
        ],

        'alternative' => [
            'clientId' => 'your-client-id',
            'clientSecret' => 'your-client-secret',
            'method' => 'application',
            // 'backoff' => false,
            // 'cache' => false,
            // 'version' => 'v3',
            // 'enterprise' => false,
        ],

        'other' => [
            'username' => 'your-username',
            'password' => 'your-password',
            'method' => 'password',
            // 'backoff' => false,
            // 'cache' => false,
            // 'version' => 'v3',
            // 'enterprise' => false,
        ],

    ],

];
