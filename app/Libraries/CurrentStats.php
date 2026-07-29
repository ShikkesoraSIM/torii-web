<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

namespace App\Libraries;



class CurrentStats
{
    public int $currentOnline;
    public int $currentGames;
    public array $graphData;
    public int $onlineFriends;
    public int $totalUsers;

    public int $totalPlays;

    public function __construct()
    {
        // torii: los numeros salian de osu_banchostats, que es la serie que
        // escribe bancho cada pocos minutos. Torii no tiene bancho y esa tabla
        // esta vacia, asi que la portada saludaba con cero de todo. Ahora sale
        // de la base, en vivo. Ver App\Libraries\Torii\ServerStats.
        $stats = new Torii\ServerStats();

        $this->currentOnline = $stats->currentOnline;
        $this->graphData = $stats->graphData;
        $this->onlineFriends = $stats->onlineFriends;
        $this->totalPlays = $stats->totalPlays;
        $this->totalUsers = $stats->totalUsers;

        // Torii no tiene partidas multijugador en curso que contar. Queda en
        // cero para no romper a nadie que lo lea, pero la portada muestra las
        // plays en su lugar.
        $this->currentGames = 0;
    }
}
