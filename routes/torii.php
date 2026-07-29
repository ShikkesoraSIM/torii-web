<?php

// torii: las rutas propias del fork.
//
// Archivo aparte a proposito. routes/web.php es de los que mas se mueven
// upstream, asi que todo lo que sea nuestro entra por aca y lo unico que se
// toca alla es el require. Los controladores viven en App\Http\Controllers\Torii
// y RouteSection deriva de ese namespace la seccion 'community', que es la que
// pinta el menu.

Route::group(['middleware' => ['web']], function () {
    Route::get('rankings/points', 'Torii\PointsController@index')->name('rankings.points');
});
