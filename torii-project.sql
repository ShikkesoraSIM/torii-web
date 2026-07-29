-- torii: proyecta los datos reales de Torii (esquema g0v0, importado en `torii`)
-- al esquema que espera osu-web (`osu`).
--
-- De UNA SOLA VIA y para evaluar: sirve para ver osu-web con datos de verdad y
-- decidir si el camino vale la pena. NO es un sistema de sincronizacion.
--
-- Regla que se aplico en todas las secciones, despues de romperla tres veces:
-- solo se nombran las columnas que aportan algo mas las NOT NULL sin default, y
-- todo texto libre pasa por LEFT() al ancho real de la columna destino. Torii
-- deja escribir strings mas largos que los que aguanta el esquema de osu-web.
--
-- Correo, contrasena e ip NO se copian: es una instancia de prueba y no hay
-- razon para meterle credenciales reales de los jugadores.
--
-- Se corre entero y cuantas veces haga falta: todo es INSERT ... ON DUPLICATE.
-- Requiere haber corrido antes torii-medals.sql (catalogo de medallas).

-- Alto a proposito: hay beatmapsets con muchisimas difficulties y el default de
-- 1024 corta el GROUP_CONCAT de difficulty_names, lo que en modo estricto es un
-- error y no un warning. Se junta entero y despues lo corta el LEFT().
SET SESSION group_concat_max_len = 1048576;

-- ---------------------------------------------------------------- usuarios --

INSERT INTO osu.phpbb_users (
    user_id, user_type, group_id,
    user_permissions, user_interests, user_occ, user_sig,
    username, username_clean, user_email, user_regdate, user_lastvisit,
    user_posts, user_colour, country_acronym, osu_playmode,
    user_from, user_website, user_twitter, user_lang,
    user_avatar, custom_cover_filename, cover_preset_id
)
SELECT
    u.id, 0, 7,   -- 7 es default; el 2 de este esquema es alumni
    '', COALESCE(u.interests,''), COALESCE(u.occupation,''), '',
    LEFT(u.username, 255),
    LEFT(LOWER(u.username), 255),
    CONCAT('user', u.id, '@torii.invalid'),
    UNIX_TIMESTAMP(COALESCE(u.join_date, NOW())),
    UNIX_TIMESTAMP(COALESCE(u.last_visit, u.join_date, NOW())),
    COALESCE(u.post_count, 0),
    LEFT(COALESCE(u.profile_colour, ''), 6),
    LEFT(COALESCE(NULLIF(u.country_code,''), 'XX'), 2),
    CASE u.playmode WHEN 'taiko' THEN 1 WHEN 'fruits' THEN 2 WHEN 'mania' THEN 3 ELSE 0 END,
    LEFT(COALESCE(u.location,''), 100), LEFT(COALESCE(u.website,''), 200),
    LEFT(COALESCE(u.twitter,''), 255), 'en',
    -- El avatar y la portada son solo el nombre del archivo, no la url: osu-web
    -- arma la ruta con el id del usuario mas ese nombre, y nginx la proxea a la
    -- api de Torii. Ademas AvatarHelper convierte el guion bajo del nombre en un
    -- signo de pregunta, asi que el archivo TIENE que tener exactamente uno; si
    -- no, la url sale partida al medio y se prefiere el avatar generico.
    CASE WHEN u.avatar_url LIKE 'https://lazer-api.shikkesora.com/file/avatars/%'
              AND (CHAR_LENGTH(SUBSTRING_INDEX(u.avatar_url, '/', -1))
                   - CHAR_LENGTH(REPLACE(SUBSTRING_INDEX(u.avatar_url, '/', -1), '_', ''))) = 1
         THEN SUBSTRING_INDEX(u.avatar_url, '/', -1)
         ELSE '' END,
    CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')) LIKE 'https://lazer-api.shikkesora.com/file/cover/%'
         THEN SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')), '/', -1)
         ELSE NULL END,
    -- osu-web solo respeta la portada propia si NO hay preset asignado.
    NULL
FROM torii.lazer_users u
WHERE u.username IS NOT NULL AND u.username <> ''
ON DUPLICATE KEY UPDATE
    username = VALUES(username),
    user_avatar = VALUES(user_avatar),
    custom_cover_filename = VALUES(custom_cover_filename),
    cover_preset_id = VALUES(cover_preset_id);

-- Torii guarda una fila por modo en una sola tabla; osu-web tiene una tabla por
-- modo. `rank` queda en 0 y lo recalcula osu-web. Los modos propios de Torii
-- (relax, autopilot y los rulesets custom) no tienen tabla donde ir y se quedan
-- afuera: osu-web solo conoce los cuatro de siempre.

INSERT INTO osu.osu_user_stats (
    user_id, count300, count100, count50, countMiss,
    accuracy_total, accuracy_count, accuracy, playcount,
    ranked_score, total_score,
    x_rank_count, xh_rank_count, s_rank_count, sh_rank_count, a_rank_count,
    `rank`, level, replay_popularity, max_combo,
    country_acronym, rank_score, rank_score_index, accuracy_new,
    last_update, last_played, total_seconds_played
)
SELECT
    s.user_id,
    COALESCE(s.count_300,0), COALESCE(s.count_100,0), COALESCE(s.count_50,0), COALESCE(s.count_miss,0),
    0, 0,
    COALESCE(s.hit_accuracy,0),
    COALESCE(s.play_count,0),
    COALESCE(s.ranked_score,0), COALESCE(s.total_score,0),
    COALESCE(s.grade_ss,0), COALESCE(s.grade_ssh,0),
    COALESCE(s.grade_s,0), COALESCE(s.grade_sh,0), COALESCE(s.grade_a,0),
    0,
    COALESCE(s.level_current,1),
    COALESCE(s.replays_watched_by_others,0),
    LEAST(COALESCE(s.maximum_combo,0), 65535),
    COALESCE(NULLIF(u.country_code,''),'XX'),
    COALESCE(s.pp,0), 0,
    COALESCE(s.hit_accuracy,0),
    NOW(), COALESCE(s.last_played, NOW()),
    COALESCE(s.play_time,0)
FROM torii.lazer_user_statistics s
JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'OSU'
ON DUPLICATE KEY UPDATE rank_score = VALUES(rank_score);

INSERT INTO osu.osu_user_stats_taiko (
    user_id, count300, count100, count50, countMiss,
    accuracy_total, accuracy_count, accuracy, playcount,
    ranked_score, total_score,
    x_rank_count, xh_rank_count, s_rank_count, sh_rank_count, a_rank_count,
    `rank`, level, replay_popularity, max_combo,
    country_acronym, rank_score, rank_score_index, accuracy_new,
    last_update, last_played, total_seconds_played
)
SELECT
    s.user_id,
    COALESCE(s.count_300,0), COALESCE(s.count_100,0), COALESCE(s.count_50,0), COALESCE(s.count_miss,0),
    0, 0, COALESCE(s.hit_accuracy,0), COALESCE(s.play_count,0),
    COALESCE(s.ranked_score,0), COALESCE(s.total_score,0),
    COALESCE(s.grade_ss,0), COALESCE(s.grade_ssh,0),
    COALESCE(s.grade_s,0), COALESCE(s.grade_sh,0), COALESCE(s.grade_a,0),
    0, COALESCE(s.level_current,1), COALESCE(s.replays_watched_by_others,0),
    LEAST(COALESCE(s.maximum_combo,0), 65535),
    COALESCE(NULLIF(u.country_code,''),'XX'),
    COALESCE(s.pp,0), 0, COALESCE(s.hit_accuracy,0),
    NOW(), COALESCE(s.last_played, NOW()), COALESCE(s.play_time,0)
FROM torii.lazer_user_statistics s
JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'TAIKO'
ON DUPLICATE KEY UPDATE rank_score = VALUES(rank_score);

INSERT INTO osu.osu_user_stats_fruits (
    user_id, count300, count100, count50, countMiss,
    accuracy_total, accuracy_count, accuracy, playcount,
    ranked_score, total_score,
    x_rank_count, xh_rank_count, s_rank_count, sh_rank_count, a_rank_count,
    `rank`, level, replay_popularity, max_combo,
    country_acronym, rank_score, rank_score_index, accuracy_new,
    last_update, last_played, total_seconds_played
)
SELECT
    s.user_id,
    COALESCE(s.count_300,0), COALESCE(s.count_100,0), COALESCE(s.count_50,0), COALESCE(s.count_miss,0),
    0, 0, COALESCE(s.hit_accuracy,0), COALESCE(s.play_count,0),
    COALESCE(s.ranked_score,0), COALESCE(s.total_score,0),
    COALESCE(s.grade_ss,0), COALESCE(s.grade_ssh,0),
    COALESCE(s.grade_s,0), COALESCE(s.grade_sh,0), COALESCE(s.grade_a,0),
    0, COALESCE(s.level_current,1), COALESCE(s.replays_watched_by_others,0),
    LEAST(COALESCE(s.maximum_combo,0), 65535),
    COALESCE(NULLIF(u.country_code,''),'XX'),
    COALESCE(s.pp,0), 0, COALESCE(s.hit_accuracy,0),
    NOW(), COALESCE(s.last_played, NOW()), COALESCE(s.play_time,0)
FROM torii.lazer_user_statistics s
JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'FRUITS'
ON DUPLICATE KEY UPDATE rank_score = VALUES(rank_score);

INSERT INTO osu.osu_user_stats_mania (
    user_id, count300, count100, count50, countMiss,
    accuracy_total, accuracy_count, accuracy, playcount,
    ranked_score, total_score,
    x_rank_count, xh_rank_count, s_rank_count, sh_rank_count, a_rank_count,
    `rank`, level, replay_popularity, max_combo,
    country_acronym, rank_score, rank_score_index, accuracy_new,
    last_update, last_played, total_seconds_played
)
SELECT
    s.user_id,
    COALESCE(s.count_300,0), COALESCE(s.count_100,0), COALESCE(s.count_50,0), COALESCE(s.count_miss,0),
    0, 0, COALESCE(s.hit_accuracy,0), COALESCE(s.play_count,0),
    COALESCE(s.ranked_score,0), COALESCE(s.total_score,0),
    COALESCE(s.grade_ss,0), COALESCE(s.grade_ssh,0),
    COALESCE(s.grade_s,0), COALESCE(s.grade_sh,0), COALESCE(s.grade_a,0),
    0, COALESCE(s.level_current,1), COALESCE(s.replays_watched_by_others,0),
    LEAST(COALESCE(s.maximum_combo,0), 65535),
    COALESCE(NULLIF(u.country_code,''),'XX'),
    COALESCE(s.pp,0), 0, COALESCE(s.hit_accuracy,0),
    NOW(), COALESCE(s.last_played, NOW()), COALESCE(s.play_time,0)
FROM torii.lazer_user_statistics s
JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'MANIA'
ON DUPLICATE KEY UPDATE rank_score = VALUES(rank_score);

-- --------------------------------------------------------------- beatmapsets --
--
-- Los estados y los generos viajan como texto en Torii y como entero en
-- osu-web, asi que hay una traduccion explicita. Los enteros son los mismos que
-- usa la api oficial (-2 graveyard .. 4 loved) y las tablas osu_genres y
-- osu_languages que osu-web ya trae cargadas.

INSERT INTO osu.osu_beatmapsets (
    beatmapset_id, user_id, artist, artist_unicode, title, title_unicode, creator,
    source, tags, video, storyboard, bpm, approved, approved_date, submit_date,
    last_update, genre_id, language_id, nsfw, spotlight, track_id,
    download_disabled, discussion_locked, displaytitle, active, cover_updated_at
)
SELECT
    b.id,
    -- OJO: torii.beatmapsets.user_id NO es un usuario de Torii. Es el id del
    -- creador en el espacio de ids de ppy, copiado crudo de lo que devuelve el
    -- mirror. Como los ids de Torii van de 2 a 793, cualquier set cuyo creador
    -- tenga un id chico quedaba acreditado a un jugador local que no lo mapeo.
    -- El caso extremo: el mirror devuelve user_id 3 para 10.728 sets de 3.853
    -- mappers distintos, y el 3 local es Shikkesora.
    -- El nombre del mapper no se pierde, sigue en la columna creator.
    CASE WHEN b.is_local = 1 THEN b.user_id ELSE 0 END,
    LEFT(COALESCE(b.artist,''), 80), LEFT(COALESCE(NULLIF(b.artist_unicode,''), b.artist, ''), 80),
    LEFT(COALESCE(b.title,''), 80), LEFT(COALESCE(NULLIF(b.title_unicode,''), b.title, ''), 80),
    LEFT(COALESCE(b.creator,''), 80),
    LEFT(COALESCE(b.source,''), 200), LEFT(COALESCE(b.tags,''), 1000),
    COALESCE(b.video, 0), COALESCE(b.storyboard, 0), COALESCE(b.bpm, 0),
    CASE b.beatmap_status
        WHEN 'GRAVEYARD' THEN -2 WHEN 'WIP' THEN -1 WHEN 'PENDING' THEN 0
        WHEN 'RANKED' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'QUALIFIED' THEN 3
        WHEN 'LOVED' THEN 4 ELSE 0 END,
    -- Un set en estado ranked, approved, qualified o loved TIENE que traer
    -- fecha. El panel de beatmapset la exige y si es nula tira una excepcion que
    -- se lleva puesto todo el arbol de React: la pagina carga, hidrata, y recien
    -- ahi se muere, asi que no se ve como un error de servidor. Torii deja
    -- ranked_date en NULL para los mapas que aprobo a mano, entonces se cae al
    -- ultimo update.
    CASE WHEN b.beatmap_status IN ('RANKED','APPROVED','QUALIFIED','LOVED')
         THEN COALESCE(b.ranked_date, b.last_updated, b.submitted_date)
         ELSE b.ranked_date END,
    COALESCE(b.submitted_date, b.last_updated, NOW()),
    COALESCE(b.last_updated, NOW()),
    CASE b.beatmap_genre
        WHEN 'VIDEO_GAME' THEN 2 WHEN 'ANIME' THEN 3 WHEN 'ROCK' THEN 4
        WHEN 'POP' THEN 5 WHEN 'OTHER' THEN 6 WHEN 'NOVELTY' THEN 7
        WHEN 'HIP_HOP' THEN 9 WHEN 'ELECTRONIC' THEN 10 WHEN 'METAL' THEN 11
        WHEN 'CLASSICAL' THEN 12 WHEN 'FOLK' THEN 13 WHEN 'JAZZ' THEN 14
        ELSE 1 END,
    CASE b.beatmap_language
        WHEN 'ENGLISH' THEN 2 WHEN 'JAPANESE' THEN 3 WHEN 'CHINESE' THEN 4
        WHEN 'INSTRUMENTAL' THEN 5 WHEN 'KOREAN' THEN 6 WHEN 'FRENCH' THEN 7
        WHEN 'GERMAN' THEN 8 WHEN 'SWEDISH' THEN 9 WHEN 'SPANISH' THEN 10
        WHEN 'ITALIAN' THEN 11 WHEN 'RUSSIAN' THEN 12 WHEN 'POLISH' THEN 13
        WHEN 'OTHER' THEN 14 ELSE 1 END,
    COALESCE(b.nsfw, 0), COALESCE(b.spotlight, 0), b.track_id,
    COALESCE(b.download_disabled, 0), COALESCE(b.discussion_locked, 0),
    LEFT(CONCAT(COALESCE(b.artist,''), ' - ', COALESCE(b.title,'')), 200),
    1,
    -- Sin cover_updated_at el front ni siquiera pide la portada: descarta las
    -- urls que terminan en ?0 antes de renderizar.
    COALESCE(b.last_updated, NOW())
FROM torii.beatmapsets b
ON DUPLICATE KEY UPDATE
    approved = VALUES(approved),
    last_update = VALUES(last_update),
    user_id = VALUES(user_id),
    cover_updated_at = VALUES(cover_updated_at);

-- ------------------------------------------------------------------ beatmaps --
--
-- El JOIN contra beatmapsets no es decorativo: Torii tiene mas beatmaps que
-- beatmapsets referenciados, y un beatmap sin su set es exactamente lo que hace
-- explotar a osu-web con un "member function on null".

INSERT INTO osu.osu_beatmaps (
    beatmap_id, beatmapset_id, user_id, filename, checksum, version,
    total_length, hit_length, countTotal, countNormal, countSlider, countSpinner,
    diff_drain, diff_size, diff_overall, diff_approach, playmode, approved,
    last_update, difficultyrating, max_combo, bpm, deleted_at
)
SELECT
    -- Mismo problema de autoria que en beatmapsets: el user_id que trae Torii es
    -- del espacio de ids de ppy y colisiona con los usuarios locales.
    m.id, m.beatmapset_id, CASE WHEN m.is_local = 1 THEN m.user_id ELSE 0 END,
    LEFT(CONCAT(m.beatmapset_id, ' ', COALESCE(m.version,''), '.osu'), 150),
    LEFT(COALESCE(m.checksum,''), 32), LEFT(COALESCE(m.version,''), 80),
    COALESCE(m.total_length, 0), COALESCE(m.hit_length, 0),
    COALESCE(m.count_circles,0) + COALESCE(m.count_sliders,0) + COALESCE(m.count_spinners,0),
    COALESCE(m.count_circles,0), COALESCE(m.count_sliders,0), COALESCE(m.count_spinners,0),
    COALESCE(m.drain,0), COALESCE(m.cs,0), COALESCE(m.accuracy,0), COALESCE(m.ar,0),
    CASE m.mode WHEN 'TAIKO' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END,
    CASE m.beatmap_status
        WHEN 'GRAVEYARD' THEN -2 WHEN 'WIP' THEN -1 WHEN 'PENDING' THEN 0
        WHEN 'RANKED' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'QUALIFIED' THEN 3
        WHEN 'LOVED' THEN 4 ELSE 0 END,
    COALESCE(m.last_updated, NOW()), COALESCE(m.difficulty_rating, 0),
    LEAST(COALESCE(m.max_combo, 0), 16777215), COALESCE(m.bpm, 0),
    m.deleted_at
FROM torii.beatmaps m
JOIN torii.beatmapsets s ON s.id = m.beatmapset_id
ON DUPLICATE KEY UPDATE
    approved = VALUES(approved),
    difficultyrating = VALUES(difficultyrating),
    user_id = VALUES(user_id);

-- -------------------------------------------------------------------- scores --
--
-- osu-web guarda mods y estadisticas dentro de la columna json `data`. Torii ya
-- tiene los mods y maximum_statistics en ese mismo formato, y los conteos en
-- columnas sueltas, asi que solo hay que rearmar el objeto `statistics`.
--
-- El truco del JSON_MERGE_PATCH con NULLIF es para no escribir las claves en
-- cero: un score de osu! no tiene que decir que hizo 0 slider_tail_hit.
--
-- Los modos propios (relax, autopilot) entran igual porque son plays reales,
-- pero con ranked = 0. osu-web los mapearia al modo base y ensuciaria los
-- rankings y el top play de cada perfil.
--
-- La clave primaria de esta tabla es (id, preserve, unix_updated_at) por como
-- esta particionada, no solo el id. Si unix_updated_at se deja al default toma
-- la hora de la corrida, nunca colisiona con la corrida anterior y el ON
-- DUPLICATE no sirve para nada: la segunda pasada duplica los 197 mil scores.
-- Se fija derivado de ended_at, que es estable, y ademas se vacia la tabla
-- antes porque aca todos los scores salen de Torii.

DELETE FROM osu.scores;

INSERT INTO osu.scores (
    id, user_id, ruleset_id, beatmap_id, has_replay, preserve, ranked, `rank`,
    passed, accuracy, max_combo, total_score, data, pp, started_at, ended_at,
    unix_updated_at
)
SELECT
    s.id, s.user_id,
    CASE s.gamemode
        WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1
        WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2
        WHEN 'MANIA' THEN 3 ELSE 0 END,
    s.beatmap_id,
    -- has_replay va en 0 fijo: los archivos viven en el storage de produccion y no
    -- se copian, asi que el boton de descarga se dibujaria para morir.
    0, COALESCE(s.preserve, 0),
    CASE WHEN s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA') THEN COALESCE(s.ranked, 0) ELSE 0 END,
    COALESCE(s.`rank`, 'D'), COALESCE(s.passed, 0),
    COALESCE(s.accuracy, 0), COALESCE(s.max_combo, 0), COALESCE(s.total_score, 0),
    JSON_OBJECT(
        'mods', COALESCE(s.mods, JSON_ARRAY()),
        'maximum_statistics', COALESCE(s.maximum_statistics, JSON_OBJECT()),
        'total_score_without_mods', s.total_score_without_mods,
        'statistics', JSON_MERGE_PATCH(JSON_OBJECT(), JSON_OBJECT(
            'great',           NULLIF(s.n300, 0),
            'ok',              NULLIF(s.n100, 0),
            'meh',             NULLIF(s.n50, 0),
            'miss',            NULLIF(s.nmiss, 0),
            'perfect',         NULLIF(s.ngeki, 0),
            'good',            NULLIF(s.nkatu, 0),
            'large_tick_hit',  NULLIF(s.nlarge_tick_hit, 0),
            'large_tick_miss', NULLIF(s.nlarge_tick_miss, 0),
            'small_tick_hit',  NULLIF(s.nsmall_tick_hit, 0),
            'slider_tail_hit', NULLIF(s.nslider_tail_hit, 0),
            'large_bonus',     NULLIF(s.nlarge_bonus, 0),
            'small_bonus',     NULLIF(s.nsmall_bonus, 0)
        ))
    ),
    s.pp, s.started_at, COALESCE(s.ended_at, NOW()),
    UNIX_TIMESTAMP(COALESCE(s.ended_at, NOW()))
FROM torii.scores s
JOIN osu.osu_beatmaps b ON b.beatmap_id = s.beatmap_id
JOIN osu.phpbb_users u ON u.user_id = s.user_id
ON DUPLICATE KEY UPDATE pp = VALUES(pp), ranked = VALUES(ranked);

-- ------------------------------------------------------------------ medallas --

INSERT INTO osu.osu_user_achievements (user_id, achievement_id, date)
SELECT a.user_id, a.achievement_id, COALESCE(a.achieved_at, NOW())
FROM torii.lazer_user_achievements a
JOIN osu.phpbb_users u ON u.user_id = a.user_id
JOIN osu.osu_achievements m ON m.achievement_id = a.achievement_id
ON DUPLICATE KEY UPDATE date = VALUES(date);

-- Cuantos jugadores tienen cada medalla. Es lo que se muestra como porcentaje al
-- lado de cada una; sin esto salen todas en cero.
UPDATE osu.osu_achievements a
SET a.achieved_count = (
    SELECT COUNT(*) FROM osu.osu_user_achievements ua
    WHERE ua.achievement_id = a.achievement_id
);

-- ----------------------------------------------------------------- favoritos --

INSERT INTO osu.osu_favouritemaps (user_id, beatmapset_id, dateadded)
SELECT f.user_id, f.beatmapset_id, COALESCE(f.date, NOW())
FROM torii.favourite_beatmapset f
JOIN osu.phpbb_users u ON u.user_id = f.user_id
JOIN osu.osu_beatmapsets s ON s.beatmapset_id = f.beatmapset_id
ON DUPLICATE KEY UPDATE dateadded = VALUES(dateadded);

-- --------------------------------------------------------------- playcounts --
--
-- year_month es char(4) en formato ymm de dos digitos de anio: julio de 2026 es
-- '2607'. Es el formato que arma osu-web al escribir estas filas.

INSERT INTO osu.osu_user_beatmap_playcount (user_id, beatmap_id, playcount)
-- La fuente tiene filas repetidas por (usuario, mapa); sin el GROUP BY el
-- ON DUPLICATE se queda con la ultima en vez de sumarlas.
SELECT p.user_id, p.beatmap_id, SUM(p.playcount)
FROM torii.beatmap_playcounts p
JOIN osu.phpbb_users u ON u.user_id = p.user_id
JOIN osu.osu_beatmaps b ON b.beatmap_id = p.beatmap_id
GROUP BY p.user_id, p.beatmap_id
ON DUPLICATE KEY UPDATE playcount = VALUES(playcount);

INSERT INTO osu.osu_user_month_playcount (user_id, `year_month`, playcount)
SELECT m.user_id,
       CONCAT(LPAD(m.year % 100, 2, '0'), LPAD(m.month, 2, '0')),
       m.count
FROM torii.monthly_playcounts m
JOIN osu.phpbb_users u ON u.user_id = m.user_id
ON DUPLICATE KEY UPDATE playcount = VALUES(playcount);

INSERT INTO osu.osu_user_replayswatched (user_id, `year_month`, count)
SELECT r.user_id,
       CONCAT(LPAD(r.year % 100, 2, '0'), LPAD(r.month, 2, '0')),
       r.count
FROM torii.replays_watched_counts r
JOIN osu.phpbb_users u ON u.user_id = r.user_id
ON DUPLICATE KEY UPDATE count = VALUES(count);

-- ------------------------------------------------------------------- amigos --
--
-- osu-web guarda amigos y bloqueados en la misma fila con dos banderas; Torii
-- los tiene como dos tipos distintos de la misma relacion.

INSERT INTO osu.phpbb_zebra (user_id, zebra_id, friend, foe)
SELECT r.user_id, r.target_id, r.type = 'FOLLOW', r.type = 'BLOCK'
FROM torii.relationship r
JOIN osu.phpbb_users a ON a.user_id = r.user_id
JOIN osu.phpbb_users b ON b.user_id = r.target_id
ON DUPLICATE KEY UPDATE friend = VALUES(friend), foe = VALUES(foe);

-- ------------------------------------------------------------------- equipos --

INSERT INTO osu.teams (
    id, name, short_name, flag_file, header_file, url, description,
    default_ruleset_id, leader_id, channel_id, created_at, updated_at
)
SELECT
    t.id, LEFT(t.name, 255), LEFT(COALESCE(t.short_name,''), 255),
    -- flag_file y header_file son NOMBRES de archivo, no urls: osu-web arma la
    -- ruta como teams/flag/{id}/{flag_file}. Con la url entera queda un
    -- rectangulo negro. Va NULLIF y no cadena vacia porque osu-web solo saltea
    -- la imagen si el valor es nulo; con vacio arma una url terminada en barra
    -- que igual da 404.
    NULLIF(SUBSTRING_INDEX(COALESCE(t.flag_url,''), '/', -1), ''),
    NULLIF(SUBSTRING_INDEX(COALESCE(t.cover_url,''), '/', -1), ''),
    LEFT(COALESCE(t.website,''), 255), t.description,
    CASE t.playmode WHEN 'TAIKO' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END,
    t.leader_id, 0,
    COALESCE(t.created_at, NOW()), NOW()
FROM torii.teams t
JOIN osu.phpbb_users u ON u.user_id = t.leader_id
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    flag_file = VALUES(flag_file),
    header_file = VALUES(header_file);

INSERT INTO osu.team_members (user_id, team_id, created_at, updated_at)
SELECT m.user_id, m.team_id, COALESCE(m.joined_at, NOW()), NOW()
FROM torii.team_members m
JOIN osu.phpbb_users u ON u.user_id = m.user_id
JOIN osu.teams t ON t.id = m.team_id
ON DUPLICATE KEY UPDATE team_id = VALUES(team_id);

-- ---------------------------------------------------------------- actividad --
--
-- osu-web no guarda la actividad estructurada: guarda una linea de html y la
-- vuelve a parsear con una expresion regular por tipo de evento. Asi que hay
-- que escribir exactamente el formato que esa regex espera, incluido el
-- signo de admiracion del final.
--
-- Torii guarda el payload en json con urls absolutas a lazer.shikkesora.com; se
-- reescriben a rutas relativas para que los links no se vayan del sitio local.
--
-- Esta es la unica seccion que no puede ser ON DUPLICATE: la clave es un id
-- autoincremental y no hay con que deduplicar. Se vacia primero para que correr
-- el archivo dos veces no deje la actividad repetida.

DELETE FROM osu.osu_events;

INSERT INTO osu.osu_events (text, beatmap_id, beatmapset_id, user_id, date, epicfactor, private)
SELECT
    LEFT(CONCAT(
        '<img src=''/images/',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.scorerank')),
        '_small.png''/> <b><a href=''/users/', e.user_id, '''>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
        '</a></b> achieved rank #',
        JSON_EXTRACT(e.event_payload, '$.rank'),
        ' on <a href=''/b/',
        SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1),
        '''>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.title')),
        '</a> (',
        -- Torii tiene modos que osu-web no conoce. Su parser rechaza el evento
        -- entero si el modo entre parentesis no es uno de los cuatro suyos, asi
        -- que relax y autopilot se muestran como su modo base. Son 13.888
        -- eventos que si no quedaban como error de parseo.
        CASE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode'))
            WHEN 'osu!relax'     THEN 'osu!'
            WHEN 'osu!autopilot' THEN 'osu!'
            WHEN 'catch relax'   THEN 'osu!catch'
            WHEN 'taiko relax'   THEN 'osu!taiko'
            ELSE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode'))
        END,
        ')'
    ), 1000),
    SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1),
    NULL, e.user_id, e.created_at, 1, 0
FROM torii.user_events e
JOIN osu.phpbb_users u ON u.user_id = e.user_id
WHERE e.type = 'RANK'
  AND JSON_EXTRACT(e.event_payload, '$.beatmap.url') IS NOT NULL;

INSERT INTO osu.osu_events (text, beatmap_id, beatmapset_id, user_id, date, epicfactor, private)
SELECT
    LEFT(CONCAT(
        '<b><a href=''/users/', e.user_id, '''>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
        '</a></b> has lost first place on <a href=''/b/',
        SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1),
        '''>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.title')),
        '</a> (',
        -- Torii tiene modos que osu-web no conoce. Su parser rechaza el evento
        -- entero si el modo entre parentesis no es uno de los cuatro suyos, asi
        -- que relax y autopilot se muestran como su modo base. Son 13.888
        -- eventos que si no quedaban como error de parseo.
        CASE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode'))
            WHEN 'osu!relax'     THEN 'osu!'
            WHEN 'osu!autopilot' THEN 'osu!'
            WHEN 'catch relax'   THEN 'osu!catch'
            WHEN 'taiko relax'   THEN 'osu!taiko'
            ELSE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode'))
        END,
        ')'
    ), 1000),
    SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1),
    NULL, e.user_id, e.created_at, 1, 0
FROM torii.user_events e
JOIN osu.phpbb_users u ON u.user_id = e.user_id
WHERE e.type = 'RANK_LOST'
  AND JSON_EXTRACT(e.event_payload, '$.beatmap.url') IS NOT NULL;

INSERT INTO osu.osu_events (text, beatmap_id, beatmapset_id, user_id, date, epicfactor, private)
SELECT
    LEFT(CONCAT(
        '<b><a href=''/users/', e.user_id, '''>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
        '</a></b> unlocked the "<b>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.achievement.name')),
        '</b>" medal!'
    ), 1000),
    NULL, NULL, e.user_id, e.created_at, 1, 0
FROM torii.user_events e
JOIN osu.phpbb_users u ON u.user_id = e.user_id
WHERE e.type = 'ACHIEVEMENT'
  AND JSON_EXTRACT(e.event_payload, '$.achievement.name') IS NOT NULL;

INSERT INTO osu.osu_events (text, beatmap_id, beatmapset_id, user_id, date, epicfactor, private)
SELECT
    LEFT(CONCAT(
        '<b><a href=''/users/', e.user_id, '''>',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.previous_username')),
        '</a></b> has changed their username to ',
        JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
        '!'
    ), 1000),
    NULL, NULL, e.user_id, e.created_at, 1, 0
FROM torii.user_events e
JOIN osu.phpbb_users u ON u.user_id = e.user_id
WHERE e.type = 'USERNAME_CHANGE'
  AND JSON_EXTRACT(e.event_payload, '$.user.previous_username') IS NOT NULL;

-- -------------------------------------------------------------- agregados --
--
-- Contadores que osu-web lee de la fila en vez de contar en vivo. Sin esto los
-- beatmaps aparecen todos con cero plays aunque los scores esten cargados.

UPDATE osu.osu_beatmaps b
JOIN (
    SELECT beatmap_id, SUM(playcount) AS pc
    FROM torii.beatmap_playcounts GROUP BY beatmap_id
) t ON t.beatmap_id = b.beatmap_id
SET b.playcount = t.pc;

UPDATE osu.osu_beatmaps b
JOIN (
    SELECT beatmap_id, COUNT(*) AS passes
    FROM torii.scores WHERE passed = 1 GROUP BY beatmap_id
) t ON t.beatmap_id = b.beatmap_id
SET b.passcount = t.passes;

UPDATE osu.osu_beatmapsets s
JOIN (
    -- versions_available es tinyint y hay algun set con mas de 255
    -- difficulties, asi que se recorta en vez de reventar.
    SELECT beatmapset_id,
           LEAST(COUNT(*), 255) AS versions,
           SUM(playcount) AS pc,
           LEFT(GROUP_CONCAT(version SEPARATOR ','), 2048) AS names
    FROM osu.osu_beatmaps GROUP BY beatmapset_id
) t ON t.beatmapset_id = s.beatmapset_id
SET s.versions_available = t.versions,
    s.play_count = t.pc,
    s.difficulty_names = t.names;

UPDATE osu.osu_beatmapsets s
JOIN (
    SELECT beatmapset_id, COUNT(*) AS favs
    FROM osu.osu_favouritemaps GROUP BY beatmapset_id
) t ON t.beatmapset_id = s.beatmapset_id
SET s.favourite_count = t.favs;

-- ---------------------------------------------------------------- rankings --
--
-- osu-web no calcula la posicion global al vuelo, la lee de la fila:
-- rank_score_index es la global y `rank` la del pais. Si quedan en cero el
-- perfil muestra el pp pero sin ningun numero de ranking al lado.
--
-- Solo entran los que tienen pp: un jugador en cero no tiene posicion.

UPDATE osu.osu_user_stats s JOIN (
    SELECT user_id,
           ROW_NUMBER() OVER (ORDER BY rank_score DESC) AS global_idx,
           ROW_NUMBER() OVER (PARTITION BY country_acronym ORDER BY rank_score DESC) AS country_idx
    FROM osu.osu_user_stats WHERE rank_score > 0
) t ON t.user_id = s.user_id
SET s.rank_score_index = t.global_idx, s.`rank` = t.country_idx;

UPDATE osu.osu_user_stats_taiko s JOIN (
    SELECT user_id,
           ROW_NUMBER() OVER (ORDER BY rank_score DESC) AS global_idx,
           ROW_NUMBER() OVER (PARTITION BY country_acronym ORDER BY rank_score DESC) AS country_idx
    FROM osu.osu_user_stats_taiko WHERE rank_score > 0
) t ON t.user_id = s.user_id
SET s.rank_score_index = t.global_idx, s.`rank` = t.country_idx;

UPDATE osu.osu_user_stats_fruits s JOIN (
    SELECT user_id,
           ROW_NUMBER() OVER (ORDER BY rank_score DESC) AS global_idx,
           ROW_NUMBER() OVER (PARTITION BY country_acronym ORDER BY rank_score DESC) AS country_idx
    FROM osu.osu_user_stats_fruits WHERE rank_score > 0
) t ON t.user_id = s.user_id
SET s.rank_score_index = t.global_idx, s.`rank` = t.country_idx;

UPDATE osu.osu_user_stats_mania s JOIN (
    SELECT user_id,
           ROW_NUMBER() OVER (ORDER BY rank_score DESC) AS global_idx,
           ROW_NUMBER() OVER (PARTITION BY country_acronym ORDER BY rank_score DESC) AS country_idx
    FROM osu.osu_user_stats_mania WHERE rank_score > 0
) t ON t.user_id = s.user_id
SET s.rank_score_index = t.global_idx, s.`rank` = t.country_idx;

-- La tabla de paises alimenta el ranking por pais y el contador de jugadores
-- que se ve en la bandera del perfil.

UPDATE osu.osu_countries c JOIN (
    SELECT country_acronym,
           COUNT(*) AS users,
           SUM(rank_score) AS pp,
           SUM(playcount) AS plays,
           SUM(ranked_score) AS ranked
    FROM osu.osu_user_stats GROUP BY country_acronym
) t ON t.country_acronym = c.acronym
SET c.usercount = t.users, c.pp = t.pp, c.playcount = t.plays, c.rankedscore = t.ranked;
