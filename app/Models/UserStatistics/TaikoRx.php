<?php

// torii: estadisticas de taiko relax.
//
// Es una variante de su ruleset base, igual que 4K y 7K son variantes de mania:
// mismo modo, tabla y ranking aparte. Ver el comentario de Beatmap::VARIANTS.
//
// La tabla es una vista sobre lazer_user_statistics filtrando por su modo.

namespace App\Models\UserStatistics;

/**
 * @property int $a_rank_count
 * @property float $accuracy_new
 * @property string $country_acronym
 * @property \Carbon\Carbon $last_played
 * @property \Carbon\Carbon $last_update
 * @property int $playcount
 * @property float $rank_score
 * @property int $rank_score_index
 * @property int $ranked_score
 * @property int $s_rank_count
 * @property int $sh_rank_count
 * @property int $user_id
 * @property int $x_rank_count
 * @property int $xh_rank_count
 */
class TaikoRx extends VariantModel
{
    protected $table = 'osu_user_stats_taiko_rx';
}
