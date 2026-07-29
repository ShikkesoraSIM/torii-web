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
        static $maxResults = 1000;

        $maxPage = $maxResults / static::PAGE_SIZE;
        $page = min(get_int(request('page')) ?? 1, $maxPage);

        $scores = User::default()
            ->with('team')
            ->where('torii_points', '>', 0)
            ->orderBy('torii_points', 'desc')
            ->orderBy('user_id', 'asc')
            ->paginate(static::PAGE_SIZE, ['*'], 'page', $page, $maxResults);

        if (is_json_request()) {
            return ['ranking' => json_collection($scores, new UserCompactTransformer())];
        }

        return ext_view('rankings.points', compact('scores'));
    }
}
