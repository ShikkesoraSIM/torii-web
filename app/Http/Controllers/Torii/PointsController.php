<?php

// torii: el ranking de puntos.
//
// Los puntos son la moneda del servidor: se ganan jugando y se gastan en la
// tienda de cosmeticos. Hay 22 mil movimientos y 300 jugadores con saldo, o sea
// que ya es una economia de verdad y merece su tabla como cualquier otro
// ranking.
//
// Se dibuja con el mismo molde que el ranking de kudosu, que es el unico de
// osu-web que rankea por algo que no es jugar. Misma tabla, mismo filtro, misma
// paginacion; lo unico distinto es la columna.

declare(strict_types=1);

namespace App\Http\Controllers\Torii;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Transformers\UserCompactTransformer;

class PointsController extends Controller
{
    const PAGE_SIZE = 50;

    public function index()
    {
        // El h1 y el <title> de esta pagina decian literal "unknown", y el menu
        // de arriba se pintaba como si fuera la seccion community.
        //
        // Los dos salen del namespace del controlador: page_title() busca
        // page_title.{namespace}.{controlador}.{accion} y RouteSection hace lo
        // mismo con su propio mapa. Los dos mapas son de upstream y solo
        // conocen App\Http\Controllers y App\Http\Controllers\Ranking, asi que
        // cualquier cosa colgada de \Torii cae al fallback ('unknown' y
        // 'community' respectivamente).
        //
        // Se declara aca a mano en vez de agregarle una entrada 'torii' a esos
        // dos mapas para no dejar nada del fork en archivos que se
        // resincronizan con ppy. RouteSection respeta el atributo si ya viene
        // puesto en la request, y esto corre antes de que la vista lo pida.
        \Request::instance()->attributes->set('route_section', [
            'action' => 'index',
            'controller' => 'ranking_controller',
            'namespace' => 'main',
            'section' => 'rankings',
        ]);

        // Los que tienen saldo son unos 300, no mil. Con el tope fijo de
        // upstream el paginador ofrecia 20 paginas y 14 salian vacias.
        $query = User::default()->where('torii_points', '>', 0);
        $total = (clone $query)->count();

        $maxPage = max(1, (int) ceil($total / static::PAGE_SIZE));
        $page = min(get_int(request('page')) ?? 1, $maxPage);

        $scores = $query
            ->with('team')
            ->orderBy('torii_points', 'desc')
            ->orderBy('user_id', 'asc')
            ->paginate(static::PAGE_SIZE, ['*'], 'page', $page, $total);

        if (is_json_request()) {
            return ['ranking' => json_collection($scores, new UserCompactTransformer())];
        }

        return ext_view('rankings.points', compact('scores'));
    }
}
