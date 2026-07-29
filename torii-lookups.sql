-- torii: las tablas de catalogo de osu-web que ni las migraciones ni nosotros
-- llenamos.
--
-- Existe porque armar el esquema en prod de cero destapo un agujero: osu-web
-- reparte sus datos base entre las migraciones y unos seeders, y los seeders no
-- se pueden correr aca.
--
-- MiscSeeder es el que traeria esto, pero arranca con DELETE de osu_countries,
-- osu_achievements, osu_genres, osu_languages y user_cover_presets, y despues
-- inventa diez medallas de prueba con factories. O sea que correrlo BORRA las
-- 134 medallas reales de Torii (las trae torii-medals.sql, sacadas del codigo de
-- g0v0) y las cambia por basura. Y ademas ya no puede: osu_countries es una
-- vista y un DELETE contra una vista con LEFT JOIN no se propaga.
--
-- GroupSeeder tiene el mismo problema al reves: se puede correr, pero borra
-- phpbb_groups entero, asi que se lleva puestos los quince grupos de Torii. Va
-- ANTES de torii-groups.sql, nunca despues.
--
-- Asi que lo que hace falta de verdad va escrito aca. Idempotente.

-- ------------------------------------------------------ generos e idiomas ----
--
-- Son la traduccion de los enteros que guarda osu_beatmapsets. Sin estas filas
-- la ficha de cualquier mapa muestra el genero y el idioma en blanco. Los ids
-- son los de la api oficial y son los que mapean las vistas.

INSERT INTO osu.osu_genres (genre_id, name) VALUES
    (0, 'Any'), (1, 'Unspecified'), (2, 'Video Game'), (3, 'Anime'), (4, 'Rock'),
    (5, 'Pop'), (6, 'Other'), (7, 'Novelty'), (9, 'Hip Hop'), (10, 'Electronic'),
    (11, 'Metal'), (12, 'Classical'), (13, 'Folk'), (14, 'Jazz')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO osu.osu_languages (language_id, name) VALUES
    (0, 'Any'), (1, 'Unspecified'), (2, 'English'), (3, 'Japanese'), (4, 'Chinese'),
    (5, 'Instrumental'), (6, 'Korean'), (7, 'French'), (8, 'German'), (9, 'Swedish'),
    (10, 'Spanish'), (11, 'Italian'), (12, 'Russian'), (13, 'Polish'), (14, 'Other')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ------------------------------------------------------------- contadores ----
--
-- osu-web lee estos numeros de la fila, no los calcula. Los refresca despues
-- torii-cache.sql; aca solo tienen que EXISTIR, porque el codigo que los lee
-- hace ->count sobre el resultado y con la fila ausente se cae.
--
-- pp_rank_column lo pide MiscSeeder y lo usa el ranking para saber por que
-- columna ordenar.

INSERT INTO osu.osu_counts (name, count) VALUES
    ('usercount', 0),
    ('last_processed_score_id', 0),
    ('pp_rank_column', 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ------------------------------------------------- portada de perfil -----
--
-- Tiene que haber al menos una fila activa. Dos razones:
--
--   1. La vista phpbb_users le da cover_preset_id = 1 a todo el que no subio
--      portada propia. Si el preset 1 no existe, la portada del perfil queda
--      sin resolver.
--   2. Sin ninguna fila activa, el selector de portada de la configuracion de
--      cuenta se queda sin opciones.
--
-- El archivo es el mismo nombre que siembra osu-web. No esta en el disco: nginx
-- intercepta ese path exacto y lo proxea a una portada de verdad, asi que el
-- nombre importa y el archivo no.

INSERT INTO osu.user_cover_presets (id, filename, active, created_at, updated_at)
VALUES (1, 'b7896c39893437c06747a9e74490f407298ab67983fba39a273bebf68540ceee.jpeg', 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE active = 1, filename = VALUES(filename);
