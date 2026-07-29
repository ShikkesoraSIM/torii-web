-- torii: segunda tanda de proyeccion.
--
-- Todo lo que un barrido exhaustivo encontro vacio o mal despues de la primera
-- pasada. Se corre DESPUES de torii-project.sql y es idempotente igual que ese.
--
-- El USE hace falta aunque todo este calificado con su esquema: el DELETE de
-- varias tablas con alias resuelve el alias contra la base por defecto, y sin
-- ninguna seleccionada tira "No database selected".

USE osu;

-- ---------------------------------------------------------------- contadores --
--
-- osu-web lee estos numeros de la fila, no los calcula. Con usercount en 1 la
-- portada saluda diciendo "1 registered players".

UPDATE osu.osu_counts SET count = (SELECT COUNT(*) FROM osu.phpbb_users)
WHERE name = 'usercount';

UPDATE osu.osu_counts SET count = (SELECT MAX(id) FROM osu.scores)
WHERE name = 'last_processed_score_id';

-- ------------------------------------------------------------------- grupos --
--
-- La primera pasada hardcodeaba group_id = 2, que en este esquema NO es el
-- grupo por defecto sino 'alumni': los 791 jugadores salian marcados como
-- osu!alumni. El default es el 7.

UPDATE osu.phpbb_users SET group_id = 7 WHERE group_id = 2;

INSERT INTO osu.phpbb_user_group (group_id, user_id, group_leader, user_pending, playmodes)
SELECT g.group_id, x.user_id, 0, 0, NULL
FROM (
    SELECT id AS user_id, 'admin'   AS ident FROM torii.lazer_users WHERE is_admin = 1
    UNION ALL SELECT id, 'gmt'     FROM torii.lazer_users WHERE is_gmt = 1
    UNION ALL SELECT id, 'nat'     FROM torii.lazer_users WHERE is_qat = 1
    UNION ALL SELECT id, 'bng'     FROM torii.lazer_users WHERE is_bng = 1
    UNION ALL SELECT id, 'bot'     FROM torii.lazer_users WHERE is_bot = 1
    UNION ALL SELECT id, 'default' FROM torii.lazer_users
) x
JOIN osu.phpbb_groups g ON g.identifier = x.ident
JOIN osu.phpbb_users p ON p.user_id = x.user_id
ON DUPLICATE KEY UPDATE user_pending = 0;

-- User::isBot() mira group_id directo, no la tabla de pertenencia.
UPDATE osu.phpbb_users p
JOIN torii.lazer_users u ON u.id = p.user_id
SET p.group_id = 6
WHERE u.is_bot = 1;

UPDATE osu.phpbb_users p
JOIN torii.lazer_users u ON u.id = p.user_id
SET p.osu_subscriber = (u.is_supporter = 1),
    p.osu_subscriptionexpiry = u.donor_end_at,
    p.support_length = COALESCE(u.total_supporter_months, 0);

-- ------------------------------------------------------- historial de cuenta --

INSERT INTO osu.osu_user_banhistory
    (ban_id, user_id, reason, ban_status, period, timestamp, banner_id, permanent)
SELECT h.id, h.user_id, LEFT(COALESCE(h.description,''), 8000),
       -- OJO: el enum de Torii escribe SLIENCE, con el error de tipeo adentro.
       CASE h.type WHEN 'NOTE' THEN 0 WHEN 'RESTRICTION' THEN 1
                   WHEN 'SLIENCE' THEN 2 WHEN 'TOURNAMENT_BAN' THEN 3 ELSE 0 END,
       COALESCE(h.length, 0), h.timestamp, NULL, COALESCE(h.permanent, 0)
FROM torii.user_account_history h
JOIN osu.phpbb_users u ON u.user_id = h.user_id
ON DUPLICATE KEY UPDATE reason = VALUES(reason), ban_status = VALUES(ban_status);

-- ------------------------------------------------ nombres de usuario previos --

INSERT INTO osu.osu_username_change_history (user_id, username, username_last, type, timestamp)
SELECT u.id, LEFT(u.username, 30), LEFT(jt.uname, 30), 'admin', COALESCE(u.join_date, NOW())
FROM torii.lazer_users u
JOIN JSON_TABLE(u.previous_usernames, '$[*]'
         COLUMNS (uname VARCHAR(30) PATH '$')) jt
JOIN osu.phpbb_users p ON p.user_id = u.id
WHERE JSON_LENGTH(u.previous_usernames) > 0
  AND jt.uname <> u.username
  -- change_id es autoincremental, sin este guard cada corrida duplica.
  AND NOT EXISTS (SELECT 1 FROM osu.osu_username_change_history h
                  WHERE h.user_id = u.id AND h.username_last = jt.uname);

-- ------------------------------------------------------------ scores fijados --
--
-- Sin los de relax y autopilot: si entran con ruleset_id 0 el perfil los mezcla
-- con osu vanilla y muestra un pp que no corresponde.

INSERT INTO osu.score_pins (user_id, score_id, ruleset_id, display_order, created_at, updated_at)
SELECT s.user_id, s.id,
       CASE s.gamemode WHEN 'TAIKO' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END,
       s.pinned_order, NOW(), NOW()
FROM torii.scores s
JOIN osu.scores o ON o.id = s.id
WHERE s.pinned_order > 0 AND s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA')
ON DUPLICATE KEY UPDATE display_order = VALUES(display_order);

-- ---------------------------------------------------------------- peak rank --
--
-- Se deriva del historial, que es lo mismo que hace Torii. LEAST en el update
-- porque el mejor rank es el numero mas chico.

INSERT INTO osu.osu_user_performance_rank_highest (user_id, mode, `rank`, updated_at)
SELECT r.user_id,
       CASE r.mode WHEN 'TAIKO' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END,
       MIN(r.`rank`), NOW()
FROM torii.rank_history r
JOIN osu.phpbb_users u ON u.user_id = r.user_id
WHERE r.`rank` > 0 AND r.mode IN ('OSU','TAIKO','FRUITS','MANIA')
GROUP BY r.user_id, r.mode
ON DUPLICATE KEY UPDATE `rank` = LEAST(`rank`, VALUES(`rank`));

-- ------------------------------------------------------------------- paises --
--
-- BQ (Caribe Neerlandes) no viene en el seed de osu-web y cuatro jugadores lo
-- tienen, asi que se caian del ranking por pais.

INSERT INTO osu.osu_countries (acronym, name, display, usercount, playcount, rankedscore, pp)
VALUES ('BQ', 'Caribbean Netherlands', 1, 0, 0, 0, 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- El seed trae los 253 paises con numeros inventados. Se ponen en cero y se
-- recalculan solo los que tienen gente.
UPDATE osu.osu_countries SET usercount = 0, pp = 0, playcount = 0, rankedscore = 0;
UPDATE osu.osu_countries c JOIN (
    SELECT country_acronym, COUNT(*) n, SUM(rank_score) pp,
           SUM(playcount) plays, SUM(ranked_score) ranked
    FROM osu.osu_user_stats GROUP BY country_acronym
) s ON s.country_acronym = c.acronym
SET c.usercount = s.n, c.pp = s.pp, c.playcount = s.plays, c.rankedscore = s.ranked;

-- --------------------------------------------------- plays por mapa, sumadas --
--
-- torii.beatmap_playcounts tiene filas repetidas por (user, beatmap) y el
-- ON DUPLICATE de la primera pasada se quedaba con la ultima en vez de sumarlas.

UPDATE osu.osu_user_beatmap_playcount o
JOIN (SELECT user_id, beatmap_id, SUM(playcount) AS s
      FROM torii.beatmap_playcounts GROUP BY user_id, beatmap_id) t
  ON t.user_id = o.user_id AND t.beatmap_id = o.beatmap_id
SET o.playcount = t.s;

-- --------------------------------------------- sets que no tienen ni un mapa --
--
-- 1361 beatmapsets quedaron sin ninguna difficulty porque el dump no las traia.
-- osu-web resuelve la ficha con whereHas('beatmaps'), asi que esas paginas dan
-- 404 pero igual aparecen en la busqueda. No arrastran nada: ni scores, ni
-- favoritos, ni playcounts.

DELETE s FROM osu.osu_beatmapsets s
LEFT JOIN osu.osu_beatmaps b ON b.beatmapset_id = s.beatmapset_id
WHERE b.beatmap_id IS NULL;

-- ---------------------------------------------- grafico de fails y abandonos --
--
-- osu-web guarda cien columnas p1..p100, una por cada centesimo del mapa. Torii
-- guarda lo mismo empaquetado en un varbinary de 400 bytes: cien enteros de
-- cuatro bytes en little endian. REVERSE da vuelta los bytes de cada uno para
-- poder leerlos con CONV, que espera big endian.

INSERT INTO osu.osu_beatmap_failtimes (beatmap_id, type, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23, p24, p25, p26, p27, p28, p29, p30, p31, p32, p33, p34, p35, p36, p37, p38, p39, p40, p41, p42, p43, p44, p45, p46, p47, p48, p49, p50, p51, p52, p53, p54, p55, p56, p57, p58, p59, p60, p61, p62, p63, p64, p65, p66, p67, p68, p69, p70, p71, p72, p73, p74, p75, p76, p77, p78, p79, p80, p81, p82, p83, p84, p85, p86, p87, p88, p89, p90, p91, p92, p93, p94, p95, p96, p97, p98, p99, p100)
SELECT f.beatmap_id, 'fail',
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 1, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 5, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 9, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 13, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 17, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 21, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 25, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 29, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 33, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 37, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 41, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 45, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 49, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 53, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 57, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 61, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 65, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 69, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 73, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 77, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 81, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 85, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 89, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 93, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 97, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 101, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 105, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 109, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 113, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 117, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 121, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 125, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 129, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 133, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 137, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 141, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 145, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 149, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 153, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 157, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 161, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 165, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 169, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 173, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 177, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 181, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 185, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 189, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 193, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 197, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 201, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 205, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 209, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 213, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 217, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 221, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 225, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 229, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 233, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 237, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 241, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 245, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 249, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 253, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 257, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 261, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 265, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 269, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 273, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 277, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 281, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 285, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 289, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 293, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 297, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 301, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 305, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 309, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 313, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 317, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 321, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 325, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 329, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 333, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 337, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 341, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 345, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 349, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 353, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 357, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 361, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 365, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 369, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 373, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 377, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 381, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 385, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 389, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 393, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`fail`, 397, 4))), 16, 10)
FROM torii.failtime f
JOIN osu.osu_beatmaps b ON b.beatmap_id = f.beatmap_id
WHERE f.`fail` IS NOT NULL
ON DUPLICATE KEY UPDATE p1 = VALUES(p1), p2 = VALUES(p2), p3 = VALUES(p3), p4 = VALUES(p4), p5 = VALUES(p5), p6 = VALUES(p6), p7 = VALUES(p7), p8 = VALUES(p8), p9 = VALUES(p9), p10 = VALUES(p10), p11 = VALUES(p11), p12 = VALUES(p12), p13 = VALUES(p13), p14 = VALUES(p14), p15 = VALUES(p15), p16 = VALUES(p16), p17 = VALUES(p17), p18 = VALUES(p18), p19 = VALUES(p19), p20 = VALUES(p20), p21 = VALUES(p21), p22 = VALUES(p22), p23 = VALUES(p23), p24 = VALUES(p24), p25 = VALUES(p25), p26 = VALUES(p26), p27 = VALUES(p27), p28 = VALUES(p28), p29 = VALUES(p29), p30 = VALUES(p30), p31 = VALUES(p31), p32 = VALUES(p32), p33 = VALUES(p33), p34 = VALUES(p34), p35 = VALUES(p35), p36 = VALUES(p36), p37 = VALUES(p37), p38 = VALUES(p38), p39 = VALUES(p39), p40 = VALUES(p40), p41 = VALUES(p41), p42 = VALUES(p42), p43 = VALUES(p43), p44 = VALUES(p44), p45 = VALUES(p45), p46 = VALUES(p46), p47 = VALUES(p47), p48 = VALUES(p48), p49 = VALUES(p49), p50 = VALUES(p50), p51 = VALUES(p51), p52 = VALUES(p52), p53 = VALUES(p53), p54 = VALUES(p54), p55 = VALUES(p55), p56 = VALUES(p56), p57 = VALUES(p57), p58 = VALUES(p58), p59 = VALUES(p59), p60 = VALUES(p60), p61 = VALUES(p61), p62 = VALUES(p62), p63 = VALUES(p63), p64 = VALUES(p64), p65 = VALUES(p65), p66 = VALUES(p66), p67 = VALUES(p67), p68 = VALUES(p68), p69 = VALUES(p69), p70 = VALUES(p70), p71 = VALUES(p71), p72 = VALUES(p72), p73 = VALUES(p73), p74 = VALUES(p74), p75 = VALUES(p75), p76 = VALUES(p76), p77 = VALUES(p77), p78 = VALUES(p78), p79 = VALUES(p79), p80 = VALUES(p80), p81 = VALUES(p81), p82 = VALUES(p82), p83 = VALUES(p83), p84 = VALUES(p84), p85 = VALUES(p85), p86 = VALUES(p86), p87 = VALUES(p87), p88 = VALUES(p88), p89 = VALUES(p89), p90 = VALUES(p90), p91 = VALUES(p91), p92 = VALUES(p92), p93 = VALUES(p93), p94 = VALUES(p94), p95 = VALUES(p95), p96 = VALUES(p96), p97 = VALUES(p97), p98 = VALUES(p98), p99 = VALUES(p99), p100 = VALUES(p100);

INSERT INTO osu.osu_beatmap_failtimes (beatmap_id, type, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23, p24, p25, p26, p27, p28, p29, p30, p31, p32, p33, p34, p35, p36, p37, p38, p39, p40, p41, p42, p43, p44, p45, p46, p47, p48, p49, p50, p51, p52, p53, p54, p55, p56, p57, p58, p59, p60, p61, p62, p63, p64, p65, p66, p67, p68, p69, p70, p71, p72, p73, p74, p75, p76, p77, p78, p79, p80, p81, p82, p83, p84, p85, p86, p87, p88, p89, p90, p91, p92, p93, p94, p95, p96, p97, p98, p99, p100)
SELECT f.beatmap_id, 'exit',
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 1, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 5, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 9, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 13, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 17, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 21, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 25, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 29, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 33, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 37, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 41, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 45, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 49, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 53, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 57, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 61, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 65, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 69, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 73, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 77, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 81, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 85, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 89, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 93, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 97, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 101, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 105, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 109, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 113, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 117, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 121, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 125, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 129, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 133, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 137, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 141, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 145, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 149, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 153, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 157, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 161, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 165, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 169, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 173, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 177, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 181, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 185, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 189, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 193, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 197, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 201, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 205, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 209, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 213, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 217, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 221, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 225, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 229, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 233, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 237, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 241, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 245, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 249, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 253, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 257, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 261, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 265, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 269, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 273, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 277, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 281, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 285, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 289, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 293, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 297, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 301, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 305, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 309, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 313, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 317, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 321, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 325, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 329, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 333, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 337, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 341, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 345, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 349, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 353, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 357, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 361, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 365, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 369, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 373, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 377, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 381, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 385, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 389, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 393, 4))), 16, 10),
       CONV(HEX(REVERSE(SUBSTRING(f.`exit`, 397, 4))), 16, 10)
FROM torii.failtime f
JOIN osu.osu_beatmaps b ON b.beatmap_id = f.beatmap_id
WHERE f.`exit` IS NOT NULL
ON DUPLICATE KEY UPDATE p1 = VALUES(p1), p2 = VALUES(p2), p3 = VALUES(p3), p4 = VALUES(p4), p5 = VALUES(p5), p6 = VALUES(p6), p7 = VALUES(p7), p8 = VALUES(p8), p9 = VALUES(p9), p10 = VALUES(p10), p11 = VALUES(p11), p12 = VALUES(p12), p13 = VALUES(p13), p14 = VALUES(p14), p15 = VALUES(p15), p16 = VALUES(p16), p17 = VALUES(p17), p18 = VALUES(p18), p19 = VALUES(p19), p20 = VALUES(p20), p21 = VALUES(p21), p22 = VALUES(p22), p23 = VALUES(p23), p24 = VALUES(p24), p25 = VALUES(p25), p26 = VALUES(p26), p27 = VALUES(p27), p28 = VALUES(p28), p29 = VALUES(p29), p30 = VALUES(p30), p31 = VALUES(p31), p32 = VALUES(p32), p33 = VALUES(p33), p34 = VALUES(p34), p35 = VALUES(p35), p36 = VALUES(p36), p37 = VALUES(p37), p38 = VALUES(p38), p39 = VALUES(p39), p40 = VALUES(p40), p41 = VALUES(p41), p42 = VALUES(p42), p43 = VALUES(p43), p44 = VALUES(p44), p45 = VALUES(p45), p46 = VALUES(p46), p47 = VALUES(p47), p48 = VALUES(p48), p49 = VALUES(p49), p50 = VALUES(p50), p51 = VALUES(p51), p52 = VALUES(p52), p53 = VALUES(p53), p54 = VALUES(p54), p55 = VALUES(p55), p56 = VALUES(p56), p57 = VALUES(p57), p58 = VALUES(p58), p59 = VALUES(p59), p60 = VALUES(p60), p61 = VALUES(p61), p62 = VALUES(p62), p63 = VALUES(p63), p64 = VALUES(p64), p65 = VALUES(p65), p66 = VALUES(p66), p67 = VALUES(p67), p68 = VALUES(p68), p69 = VALUES(p69), p70 = VALUES(p70), p71 = VALUES(p71), p72 = VALUES(p72), p73 = VALUES(p73), p74 = VALUES(p74), p75 = VALUES(p75), p76 = VALUES(p76), p77 = VALUES(p77), p78 = VALUES(p78), p79 = VALUES(p79), p80 = VALUES(p80), p81 = VALUES(p81), p82 = VALUES(p82), p83 = VALUES(p83), p84 = VALUES(p84), p85 = VALUES(p85), p86 = VALUES(p86), p87 = VALUES(p87), p88 = VALUES(p88), p89 = VALUES(p89), p90 = VALUES(p90), p91 = VALUES(p91), p92 = VALUES(p92), p93 = VALUES(p93), p94 = VALUES(p94), p95 = VALUES(p95), p96 = VALUES(p96), p97 = VALUES(p97), p98 = VALUES(p98), p99 = VALUES(p99), p100 = VALUES(p100);

-- ------------------------------------------------------------------ replays --
--
-- Los archivos de replay viven en el storage de produccion y no se copiaron.
-- Con has_replay en 1 el boton de descarga se dibuja y despues muere.

UPDATE osu.scores SET has_replay = 0 WHERE has_replay = 1;

-- ------------------------------------------------------------ primer puesto --
--
-- IMPORTANTE: esto va DESPUES de reindexar elasticsearch sin los fails, si no el
-- lider de miles de mapas termina siendo una play fallada.
-- Solo cuentan los mapas que tienen leaderboard: ranked, approved y loved.

DELETE FROM osu.beatmap_leaders;

INSERT INTO osu.beatmap_leaders (score_id, beatmap_id, ruleset_id, user_id)
SELECT id, beatmap_id, ruleset_id, user_id FROM (
    SELECT s.id, s.beatmap_id, s.ruleset_id, s.user_id,
           ROW_NUMBER() OVER (PARTITION BY s.beatmap_id, s.ruleset_id
                              ORDER BY s.total_score DESC, s.id ASC) rn
    FROM osu.scores s
    JOIN osu.osu_beatmaps b ON b.beatmap_id = s.beatmap_id
    WHERE s.passed = 1 AND s.preserve = 1 AND s.ranked = 1
      AND b.approved IN (1, 2, 4)
) t WHERE rn = 1;
