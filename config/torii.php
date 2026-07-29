<?php

// torii: configuracion propia del fork. Archivo nuevo a proposito, para no
// meter mano en config/osu.php y arrastrar conflictos en cada sync con ppy.

return [
    // El esquema de MySQL donde vive g0v0. Las vistas de osu lo apuntan y la
    // capa de escritura escribe ahi. En la instancia local se llama torii; en
    // produccion, osu_api.
    'source_schema' => env('TORII_SOURCE_SCHEMA', 'torii'),

    // Verificacion de sesion por correo. Torii no tiene salida de mail, asi que
    // el codigo termina en el log del servidor: pedirlo deja al jugador
    // encerrado afuera de su propia configuracion. Con esto en true toda sesion
    // cuenta como verificada.
    //
    // Va por config y no por env() directo a proposito: con la config cacheada
    // (php artisan config:cache, que es lo normal en produccion) env() devuelve
    // null y el flag se apagaria solo sin que nadie se entere.
    'skip_session_verification' => (bool) env('TORII_SKIP_SESSION_VERIFICATION', false),
];
