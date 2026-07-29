-- torii: lo que las vistas NO pueden resolver en vivo.
--
-- Las vistas de torii-views.sql leen las tablas de g0v0 directamente, asi que
-- un score entra a la web en el mismo instante en que entra al juego. Pero hay
-- un punado de columnas que son cuentas sobre cientos de miles de filas y que
-- osu-web lee por fila, no calcula. Resolverlas por fila en una vista significa
-- barrer la tabla de scores entera cada vez que alguien abre un listado.
--
-- Esas van a estas tablas angostas, que las vistas traen con un LEFT JOIN por
-- clave primaria. Es lo mismo que hace osu! upstream: alla tampoco se calculan
-- en vivo, las escribe un worker de cola.
--
-- Lo que queda desactualizado entre corridas: las plays y los favoritos de un
-- mapa, los nombres de las difficulties de un set, el grafico de fails y quien
-- tiene el primer puesto. Nada de eso cambia la experiencia si tiene una hora.
-- Lo que si cambia (scores, pp, posicion, medallas, amigos, equipos) es todo
-- vista y no pasa por aca.
--
-- Idempotente. Se corre a mano la primera vez y despues por cron.

SET SESSION group_concat_max_len = 1048576;

-- --------------------------------------------------------------- catalogo --
--
-- El nombre y la bandera de cada pais son datos de osu-web (los trae su seed),
-- no de Torii. La vista osu_countries junta este catalogo con los numeros que
-- salen en vivo de las estadisticas, asi que hay que sacarlos de la tabla antes
-- de que la tabla deje de existir. Por eso el INSERT ... SELECT de abajo se
-- saltea solo si ya se hizo.

CREATE TABLE IF NOT EXISTS osu.torii_country_catalog (
    acronym CHAR(2) NOT NULL,
    name VARCHAR(255) NOT NULL,
    display TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (acronym)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------------ cache --

CREATE TABLE IF NOT EXISTS osu.torii_cache_beatmap (
    beatmap_id INT UNSIGNED NOT NULL,
    playcount INT UNSIGNED NOT NULL DEFAULT 0,
    passcount INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (beatmap_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS osu.torii_cache_beatmapset (
    beatmapset_id INT UNSIGNED NOT NULL,
    play_count INT UNSIGNED NOT NULL DEFAULT 0,
    favourite_count MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,
    difficulty_names VARCHAR(2048) DEFAULT NULL,
    versions_available TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (beatmapset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS osu.torii_cache_beatmap_leader (
    score_id BIGINT UNSIGNED NOT NULL,
    beatmap_id INT UNSIGNED NOT NULL,
    ruleset_id SMALLINT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (score_id),
    UNIQUE KEY uniq_beatmap_ruleset (beatmap_id, ruleset_id),
    KEY idx_user_ruleset (user_id, ruleset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- refresco --

-- Solo se guardan los mapas que tienen alguna play. Los otros los resuelve el
-- COALESCE del LEFT JOIN en la vista y asi la tabla queda en decenas de miles
-- de filas en vez de en trescientas mil.
TRUNCATE TABLE osu.torii_cache_beatmap;
INSERT INTO osu.torii_cache_beatmap (beatmap_id, playcount, passcount)
SELECT COALESCE(p.beatmap_id, s.beatmap_id), COALESCE(p.pc, 0), COALESCE(s.passes, 0)
FROM (SELECT beatmap_id, SUM(playcount) AS pc FROM torii.beatmap_playcounts GROUP BY beatmap_id) p
LEFT JOIN (SELECT beatmap_id, COUNT(*) AS passes FROM torii.scores WHERE passed = 1 GROUP BY beatmap_id) s
  ON s.beatmap_id = p.beatmap_id
UNION
SELECT s.beatmap_id, COALESCE(p.pc, 0), s.passes
FROM (SELECT beatmap_id, COUNT(*) AS passes FROM torii.scores WHERE passed = 1 GROUP BY beatmap_id) s
LEFT JOIN (SELECT beatmap_id, SUM(playcount) AS pc FROM torii.beatmap_playcounts GROUP BY beatmap_id) p
  ON p.beatmap_id = s.beatmap_id;

-- versions_available es tinyint y hay sets con mas de 255 difficulties, asi que
-- se recorta en vez de reventar.
TRUNCATE TABLE osu.torii_cache_beatmapset;
INSERT INTO osu.torii_cache_beatmapset
    (beatmapset_id, play_count, favourite_count, difficulty_names, versions_available)
SELECT m.beatmapset_id,
       COALESCE(SUM(c.playcount), 0),
       0,
       LEFT(GROUP_CONCAT(m.version SEPARATOR ','), 2048),
       LEAST(COUNT(*), 255)
FROM torii.beatmaps m
LEFT JOIN osu.torii_cache_beatmap c ON c.beatmap_id = m.id
GROUP BY m.beatmapset_id;

UPDATE osu.torii_cache_beatmapset s
JOIN (SELECT beatmapset_id, COUNT(*) AS favs FROM torii.favourite_beatmapset GROUP BY beatmapset_id) t
  ON t.beatmapset_id = s.beatmapset_id
SET s.favourite_count = t.favs;

-- Primer puesto por mapa y modo. Solo los mapas que tienen leaderboard (ranked,
-- approved, loved) y solo plays aprobadas: sin el passed = 1 el lider de miles
-- de mapas termina siendo una play fallada.
TRUNCATE TABLE osu.torii_cache_beatmap_leader;
INSERT INTO osu.torii_cache_beatmap_leader (score_id, beatmap_id, ruleset_id, user_id)
SELECT id, beatmap_id, ruleset_id, user_id FROM (
    SELECT s.id, s.beatmap_id, s.user_id,
           CASE s.gamemode WHEN 'TAIKO' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS ruleset_id,
           ROW_NUMBER() OVER (
               PARTITION BY s.beatmap_id, s.gamemode
               ORDER BY s.total_score DESC, s.id ASC) AS rn
    FROM torii.scores s
    JOIN torii.beatmaps b ON b.id = s.beatmap_id
    WHERE s.passed = 1 AND s.preserve = 1 AND s.ranked = 1
      AND s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA')
      AND b.beatmap_status IN ('RANKED','APPROVED','LOVED')
) t WHERE rn = 1;

-- Cuantos jugadores tienen cada medalla, que es el porcentaje que se muestra al
-- lado. osu_achievements sigue siendo tabla de verdad porque el catalogo sale
-- del codigo del servidor, no de la base.
UPDATE osu.osu_achievements a
SET a.achieved_count = (
    SELECT COUNT(*) FROM torii.lazer_user_achievements ua
    WHERE ua.achievement_id = a.achievement_id
);

-- Contadores que osu-web lee de la fila. Con usercount en 1 la portada saluda
-- diciendo "1 registered players".
UPDATE osu.osu_counts SET count = (SELECT COUNT(*) FROM torii.lazer_users WHERE username <> '')
WHERE name = 'usercount';

UPDATE osu.osu_counts SET count = (SELECT COALESCE(MAX(id), 0) FROM torii.scores)
WHERE name = 'last_processed_score_id';

-- ------------------------------------------------------ grafico de fails --
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
JOIN torii.beatmaps b ON b.id = f.beatmap_id
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
JOIN torii.beatmaps b ON b.id = f.beatmap_id
WHERE f.`exit` IS NOT NULL
ON DUPLICATE KEY UPDATE p1 = VALUES(p1), p2 = VALUES(p2), p3 = VALUES(p3), p4 = VALUES(p4), p5 = VALUES(p5), p6 = VALUES(p6), p7 = VALUES(p7), p8 = VALUES(p8), p9 = VALUES(p9), p10 = VALUES(p10), p11 = VALUES(p11), p12 = VALUES(p12), p13 = VALUES(p13), p14 = VALUES(p14), p15 = VALUES(p15), p16 = VALUES(p16), p17 = VALUES(p17), p18 = VALUES(p18), p19 = VALUES(p19), p20 = VALUES(p20), p21 = VALUES(p21), p22 = VALUES(p22), p23 = VALUES(p23), p24 = VALUES(p24), p25 = VALUES(p25), p26 = VALUES(p26), p27 = VALUES(p27), p28 = VALUES(p28), p29 = VALUES(p29), p30 = VALUES(p30), p31 = VALUES(p31), p32 = VALUES(p32), p33 = VALUES(p33), p34 = VALUES(p34), p35 = VALUES(p35), p36 = VALUES(p36), p37 = VALUES(p37), p38 = VALUES(p38), p39 = VALUES(p39), p40 = VALUES(p40), p41 = VALUES(p41), p42 = VALUES(p42), p43 = VALUES(p43), p44 = VALUES(p44), p45 = VALUES(p45), p46 = VALUES(p46), p47 = VALUES(p47), p48 = VALUES(p48), p49 = VALUES(p49), p50 = VALUES(p50), p51 = VALUES(p51), p52 = VALUES(p52), p53 = VALUES(p53), p54 = VALUES(p54), p55 = VALUES(p55), p56 = VALUES(p56), p57 = VALUES(p57), p58 = VALUES(p58), p59 = VALUES(p59), p60 = VALUES(p60), p61 = VALUES(p61), p62 = VALUES(p62), p63 = VALUES(p63), p64 = VALUES(p64), p65 = VALUES(p65), p66 = VALUES(p66), p67 = VALUES(p67), p68 = VALUES(p68), p69 = VALUES(p69), p70 = VALUES(p70), p71 = VALUES(p71), p72 = VALUES(p72), p73 = VALUES(p73), p74 = VALUES(p74), p75 = VALUES(p75), p76 = VALUES(p76), p77 = VALUES(p77), p78 = VALUES(p78), p79 = VALUES(p79), p80 = VALUES(p80), p81 = VALUES(p81), p82 = VALUES(p82), p83 = VALUES(p83), p84 = VALUES(p84), p85 = VALUES(p85), p86 = VALUES(p86), p87 = VALUES(p87), p88 = VALUES(p88), p89 = VALUES(p89), p90 = VALUES(p90), p91 = VALUES(p91), p92 = VALUES(p92), p93 = VALUES(p93), p94 = VALUES(p94), p95 = VALUES(p95), p96 = VALUES(p96), p97 = VALUES(p97), p98 = VALUES(p98), p99 = VALUES(p99), p100 = VALUES(p100);
