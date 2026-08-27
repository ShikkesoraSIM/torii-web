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

    // La api de Torii, para lo que no se puede resolver escribiendo la base
    // directamente. Hoy: las fotos de perfil.
    //
    // El sitio NO puede pedir un token del usuario: el password grant exige
    // turnstile para todo lo que no sea el cliente del juego, y meterle un
    // captcha al login solo para poder cambiar una foto no tiene sentido. Asi
    // que se usa el mismo trato que ya tiene el bot de discord, un secreto
    // compartido y el id del usuario explicito. No agrega permisos: el sitio ya
    // escribe en lazer_users a traves de sus vistas.
    //
    // Vacio => el sitio se comporta como antes y dice que no se puede subir.
    'api_url' => rtrim(env('TORII_API_URL', ''), '/'),
    'web_token' => env('TORII_WEB_TOKEN', ''),
];
