-- torii: cambia las tablas proyectadas por las vistas. Se corre UNA vez.
--
-- Las 25 tablas que aparecen abajo dejan de tener datos propios: pasan a ser
-- vistas sobre el esquema de g0v0. En vez de borrarlas se mudan a un esquema
-- osu_bak, que sirve para dos cosas: comparar fila por fila que la vista
-- devuelve lo mismo que devolvia la copia, y volver atras sin tener que
-- reproyectar nada.
--
-- Orden de corrida:
--   1. este archivo
--   2. torii-cache.sql          (crea y llena lo que no puede ser vista)
--   3. torii-views.sql          (generado por torii-views.php)
--   4. torii-userpages.php      (la pagina de perfil, que vive en el foro)
--
-- Cuando osu_bak ya no haga falta: DROP DATABASE osu_bak;

CREATE DATABASE IF NOT EXISTS osu_bak DEFAULT CHARACTER SET utf8mb4;

-- El catalogo de paises hay que salvarlo ANTES de mudar la tabla: el nombre y
-- la bandera son datos de osu-web, no de Torii, y la vista los necesita.
CREATE TABLE IF NOT EXISTS osu.torii_country_catalog (
    acronym CHAR(2) NOT NULL,
    name VARCHAR(255) NOT NULL,
    display TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (acronym)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO osu.torii_country_catalog (acronym, name, display)
SELECT acronym, name, display FROM osu.osu_countries;

-- BQ (Caribe Neerlandes) no viene en el seed de osu-web y cuatro jugadores lo
-- tienen, asi que se caian del ranking por pais.
INSERT IGNORE INTO osu.torii_country_catalog (acronym, name, display)
VALUES ('BQ', 'Caribbean Netherlands', 1), ('XX', 'Unknown', 0);

RENAME TABLE
    osu.phpbb_users                        TO osu_bak.phpbb_users,
    osu.phpbb_user_group                   TO osu_bak.phpbb_user_group,
    osu.phpbb_zebra                        TO osu_bak.phpbb_zebra,
    osu.osu_user_stats                     TO osu_bak.osu_user_stats,
    osu.osu_user_stats_taiko               TO osu_bak.osu_user_stats_taiko,
    osu.osu_user_stats_fruits              TO osu_bak.osu_user_stats_fruits,
    osu.osu_user_stats_mania               TO osu_bak.osu_user_stats_mania,
    osu.osu_beatmapsets                    TO osu_bak.osu_beatmapsets,
    osu.osu_beatmaps                       TO osu_bak.osu_beatmaps,
    osu.scores                             TO osu_bak.scores,
    osu.score_pins                         TO osu_bak.score_pins,
    osu.osu_user_achievements              TO osu_bak.osu_user_achievements,
    osu.osu_favouritemaps                  TO osu_bak.osu_favouritemaps,
    osu.osu_user_beatmap_playcount         TO osu_bak.osu_user_beatmap_playcount,
    osu.osu_user_month_playcount           TO osu_bak.osu_user_month_playcount,
    osu.osu_user_replayswatched            TO osu_bak.osu_user_replayswatched,
    osu.teams                              TO osu_bak.teams,
    osu.team_members                       TO osu_bak.team_members,
    osu.osu_events                         TO osu_bak.osu_events,
    osu.osu_user_banhistory                TO osu_bak.osu_user_banhistory,
    osu.osu_username_change_history        TO osu_bak.osu_username_change_history,
    osu.osu_user_performance_rank          TO osu_bak.osu_user_performance_rank,
    osu.osu_user_performance_rank_highest  TO osu_bak.osu_user_performance_rank_highest,
    osu.osu_countries                      TO osu_bak.osu_countries,
    osu.beatmap_leaders                    TO osu_bak.beatmap_leaders,
    -- Las tres de ranked play. osu-web las crea con sus migraciones y en g0v0
    -- existen casi iguales, porque su esquema salio del de ellos.
    osu.matchmaking_pools                  TO osu_bak.matchmaking_pools,
    osu.matchmaking_user_stats             TO osu_bak.matchmaking_user_stats,
    osu.matchmaking_user_elo_history       TO osu_bak.matchmaking_user_elo_history,
    -- Y las salas. Sin mudarlas el CREATE VIEW rebota contra la tabla (un DROP
    -- VIEW IF EXISTS no tira una tabla) y la web se queda leyendo las de
    -- osu-web, que estan en cero mientras g0v0 tiene cuatrocientas y pico. No
    -- da error en ninguna pantalla: ranked play y el multi se ven vacios.
    osu.multiplayer_rooms                  TO osu_bak.multiplayer_rooms,
    osu.multiplayer_playlist_items         TO osu_bak.multiplayer_playlist_items,
    osu.multiplayer_scores_high            TO osu_bak.multiplayer_scores_high;
