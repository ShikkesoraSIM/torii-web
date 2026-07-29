-- torii: el catalogo de grupos propios de Torii.
--
-- osu-web ya sabe dibujar badges de grupo en el perfil, al lado del nombre en
-- el foro y en las tarjetas de usuario. Lo que le faltaba era saber que existen
-- los grupos de Torii, que son estos quince y viven en el codigo del servidor
-- (g0v0, app/models/torii_groups.py), no en su base.
--
-- Los ids, los identificadores, los nombres, las siglas y los colores son los
-- mismos que usa g0v0 para armar el array `groups` de la api. Asi el badge que
-- ve un jugador en la web es literalmente el mismo que ve en el juego, con el
-- mismo color, en vez de dos catalogos que se van separando solos.
--
-- La pertenencia NO va aca: la resuelve la vista phpbb_user_group, que la
-- deriva en vivo de las banderas y de torii_titles. Ver torii-views.php.
--
-- group_type 0 = sin pagina de listado. osu-web dibujaria un link a
-- /groups/{id} y esa pagina todavia no tiene nada que mostrar.
--
-- display_order manda el orden de los badges: primero el staff, despues los
-- roles de comunidad, al final los de reconocimiento.
--
-- Idempotente.

INSERT INTO osu.phpbb_groups
    (group_id, group_type, group_name, group_desc, identifier, short_name, colour, display_order, has_playmodes)
VALUES
    (1001, 0, 'Torii Admin',       'Runs the place.',                        'torii-admin',      'ADM',  'FF3B3B',  1, 0),
    (1003, 0, 'Developer',         'Builds the client and the server.',      'torii-dev',        'DEV',  '00E5FF',  2, 0),
    (1002, 0, 'Moderator',         'Keeps the community in one piece.',      'torii-mod',        'MOD',  '4A90E2',  3, 0),
    (1005, 0, 'Quality Assurance', 'Checks that what ships actually works.', 'torii-qat',        'QAT',  'FFD700',  4, 0),
    (1004, 0, 'Map Pooler',        'Picks the maps for ranked play.',        'torii-pooler',     'MAP',  'B24BF3',  5, 0),
    (1006, 0, 'Tournament Staff',  'Runs the tournaments.',                  'torii-tournament', 'TRN',  '3F51B5',  6, 0),
    (1010, 0, 'osu! Advisor',      'Advises on osu! standard.',              'torii-advisor-osu',   'ADV', 'FF66AA',  7, 0),
    (1011, 0, 'Taiko Advisor',     'Advises on taiko.',                      'torii-advisor-taiko', 'ADV', 'FF6B35',  8, 0),
    (1012, 0, 'Catch Advisor',     'Advises on catch.',                      'torii-advisor-catch', 'ADV', '26C6A6',  9, 0),
    (1013, 0, 'Mania Advisor',     'Advises on mania.',                      'torii-advisor-mania', 'ADV', 'E91E8C', 10, 0),
    (1020, 0, 'Alumni',            'Used to be staff.',                      'torii-alumni',     'ALM',  '9E9E9E', 11, 0),
    (1021, 0, 'Torii Supporter',   'Currently supporting the server.',       'torii-supporter',  'SUP',  'FF7FC8', 12, 0),
    (1022, 0, 'Donator',           'Has supported the server at some point.','torii-donator',    'DON',  'A78BFA', 13, 0),
    (1031, 0, 'Bug Finder',        'Found something before anyone else.',    'torii-bug-finder', 'BUG',  '8CE0C5', 14, 0),
    (1030, 0, 'Goofball',          'Earned it.',                             'torii-goof',       'GOOF', '9CE5A0', 15, 0)
ON DUPLICATE KEY UPDATE
    group_name = VALUES(group_name),
    group_desc = VALUES(group_desc),
    short_name = VALUES(short_name),
    colour = VALUES(colour),
    display_order = VALUES(display_order),
    group_type = VALUES(group_type);
