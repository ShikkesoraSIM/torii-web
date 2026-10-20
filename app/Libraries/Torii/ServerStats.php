<?php

// torii: los numeros de la portada.
//
// Upstream los saca de osu_banchostats, que es una serie temporal que escribe
// bancho cada pocos minutos. Torii no tiene bancho ni esa tabla (esta, y esta
// vacia), asi que la portada saludaba con "1 registered players, 0 currently
// online in 0 games" hasta que se proyectaron los contadores a mano.
//
// Aca sale todo de la base, en vivo:
//
//   jugadores    osu_counts, que refresca torii-cache.sql
//   en linea     la bandera is_online de la fila del usuario, que mantiene g0v0
//   plays        cuantos scores hay
//   grafico      scores por dia de los ultimos diez dias
//
// El historial online guarda picos diarios. Arranca con diez dias estimados,
// marcados aparte, que las mediciones van reemplazando. No toca los contadores.
//
// Cache de cinco minutos con mutex: sin el, cada vez que vence el cache TODOS
// los que entran a la portada al mismo tiempo pagan el barrido de scores.
// cache_remember_mutexed deja pasar a uno y a los demas les da el valor viejo.

declare(strict_types=1);

namespace App\Libraries\Torii;

use App\Models\Count;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class ServerStats
{
    const CACHE_KEY = 'torii_server_stats:activity:v3';
    const CACHE_SECONDS = 300;
    const GRAPH_DAYS = 10;

    public int $currentOnline;
    public int $totalPlays;
    public int $totalUsers;
    public array $graphData;
    public int $onlineFriends;

    public function __construct()
    {
        $data = cache_remember_mutexed(static::CACHE_KEY, static::CACHE_SECONDS, [
            'currentOnline' => 0,
            'totalPlays' => 0,
            'totalUsers' => 0,
            'graphData' => [],
        ], fn () => [
            'currentOnline' => (int) User::default()->where('torii_is_online', 1)->count(),
            'totalPlays' => (int) DB::table(static::scoresTable())->count(),
            'totalUsers' => (int) Count::totalUsers()->count,
            'graphData' => static::playsPerDay(),
        ]);

        $this->currentOnline = $data['currentOnline'];
        $this->totalPlays = $data['totalPlays'];
        $this->totalUsers = $data['totalUsers'];
        $this->graphData = $data['graphData'];

        // Los amigos en linea son por usuario, asi que no pueden ir al cache
        // compartido. Es una cuenta sobre las pocas filas de sus amigos.
        $this->onlineFriends = auth()->user()?->friends()->where('phpbb_users.torii_is_online', 1)->count() ?? 0;
    }

    /**
     * Se cuenta sobre la tabla de Torii y no sobre la vista scores, que deja
     * afuera relax y autopilot. Para "cuanto se juega aca" esos 45 mil scores
     * cuentan igual: son plays de verdad, de gente de verdad.
     */
    private static function scoresTable(): string
    {
        $schema = $GLOBALS['cfg']['torii']['source_schema'];

        return QueryHints::isView('scores') ? "{$schema}.scores" : 'scores';
    }

    private static function playsPerDay(): array
    {
        $today = now('UTC')->startOfDay();
        $start = $today->copy()->subDays(static::GRAPH_DAYS - 1);
        $online = OnlineActivity::dailyPeaks($start, $today);
        $rows = DB::table(static::scoresTable())
            ->selectRaw('DATE(ended_at) AS day, COUNT(*) AS plays')
            ->where('ended_at', '>=', $start)
            ->where('ended_at', '<', $today->copy()->addDay())
            ->groupBy('day')
            ->pluck('plays', 'day');

        $data = [];

        // Los dias sin ninguna play tienen que ir igual, con cero: si se saltean
        // el grafico comprime el hueco y muestra una actividad que no existio.
        for ($i = 0; $i < static::GRAPH_DAYS; $i++) {
            $day = $start->copy()->addDays($i)->toDateString();
            $data[] = [
                'date' => $day,
                'scores' => (int) ($rows[$day] ?? 0),
                'online' => $online[$day]['online'] ?? null,
                'online_estimated' => $online[$day]['estimated'] ?? false,
            ];
        }

        return $data;
    }
}
