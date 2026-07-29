-- torii: deshace torii-views-swap.sql. Tira las vistas y devuelve las tablas
-- que estaban en osu_bak a su lugar. La copia que tenian sigue igual: nada de
-- lo que hace la capa de vistas escribe en osu_bak.

DROP VIEW IF EXISTS osu.phpbb_users, osu.phpbb_user_group, osu.phpbb_zebra,
    osu.osu_user_stats, osu.osu_user_stats_taiko, osu.osu_user_stats_fruits,
    osu.osu_user_stats_mania, osu.osu_beatmapsets, osu.osu_beatmaps, osu.scores,
    osu.score_pins, osu.osu_user_achievements, osu.osu_favouritemaps,
    osu.osu_user_beatmap_playcount, osu.osu_user_month_playcount,
    osu.osu_user_replayswatched, osu.teams, osu.team_members, osu.osu_events,
    osu.osu_user_banhistory, osu.osu_username_change_history,
    osu.osu_user_performance_rank, osu.osu_user_performance_rank_highest,
    osu.osu_countries, osu.beatmap_leaders;

RENAME TABLE
    osu_bak.phpbb_users                        TO osu.phpbb_users,
    osu_bak.phpbb_user_group                   TO osu.phpbb_user_group,
    osu_bak.phpbb_zebra                        TO osu.phpbb_zebra,
    osu_bak.osu_user_stats                     TO osu.osu_user_stats,
    osu_bak.osu_user_stats_taiko               TO osu.osu_user_stats_taiko,
    osu_bak.osu_user_stats_fruits              TO osu.osu_user_stats_fruits,
    osu_bak.osu_user_stats_mania               TO osu.osu_user_stats_mania,
    osu_bak.osu_beatmapsets                    TO osu.osu_beatmapsets,
    osu_bak.osu_beatmaps                       TO osu.osu_beatmaps,
    osu_bak.scores                             TO osu.scores,
    osu_bak.score_pins                         TO osu.score_pins,
    osu_bak.osu_user_achievements              TO osu.osu_user_achievements,
    osu_bak.osu_favouritemaps                  TO osu.osu_favouritemaps,
    osu_bak.osu_user_beatmap_playcount         TO osu.osu_user_beatmap_playcount,
    osu_bak.osu_user_month_playcount           TO osu.osu_user_month_playcount,
    osu_bak.osu_user_replayswatched            TO osu.osu_user_replayswatched,
    osu_bak.teams                              TO osu.teams,
    osu_bak.team_members                       TO osu.team_members,
    osu_bak.osu_events                         TO osu.osu_events,
    osu_bak.osu_user_banhistory                TO osu.osu_user_banhistory,
    osu_bak.osu_username_change_history        TO osu.osu_username_change_history,
    osu_bak.osu_user_performance_rank          TO osu.osu_user_performance_rank,
    osu_bak.osu_user_performance_rank_highest  TO osu.osu_user_performance_rank_highest,
    osu_bak.osu_countries                      TO osu.osu_countries,
    osu_bak.beatmap_leaders                    TO osu.beatmap_leaders;
