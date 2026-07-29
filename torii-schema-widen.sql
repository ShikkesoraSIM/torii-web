-- torii: ensancha beatmapset_id de mediumint a int en las tablas que se pueblan.
--
-- Por que hace falta: osu-web dimensiono la columna para los ids de ppy, que
-- hoy andan por los 2.4 millones y entran comodos en un mediumint (tope
-- 16777215). Torii reparte los ids de los mapas subidos localmente a partir de
-- 800000000, y esos no entran. Son 68 beatmapsets locales, con sus difficulties
-- y 1039 scores colgando.
--
-- La alternativa era saltearlos, pero entonces los mapas propios del servidor
-- son justo los que no se ven, que es lo contrario de lo que uno quiere mirar
-- en una evaluacion.
--
-- Vale la pena anotarlo igual como hallazgo: si algun dia osu-web se adopta en
-- serio, el espacio de ids locales de Torii choca con su esquema y hay que
-- decidir si se migran los ids o se parchea el esquema de entrada.

ALTER TABLE osu.osu_beatmapsets   MODIFY beatmapset_id INT UNSIGNED NOT NULL AUTO_INCREMENT;
ALTER TABLE osu.osu_beatmaps      MODIFY beatmapset_id INT UNSIGNED NULL;
ALTER TABLE osu.osu_favouritemaps MODIFY beatmapset_id INT UNSIGNED NOT NULL;
ALTER TABLE osu.osu_events        MODIFY beatmapset_id INT UNSIGNED NULL;
