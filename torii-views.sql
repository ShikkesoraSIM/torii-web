-- torii: vistas que apuntan osu-web a las tablas de g0v0.
--
-- GENERADO por torii-views.php. No editar a mano: se regenera.
-- origen: torii   destino: osu   columnas leidas de: osu

-- ---------------------------------------------------------------------------
-- phpbb_users
-- sin dato en Torii, va el default de la columna: user_perm_from, user_ip, user_passchg, user_birthday, user_lastmark, user_lastpost_time, user_lastpage, user_last_confirm_key, user_last_search, user_last_warning, user_login_attempts, user_inactive_reason, user_inactive_time, user_timezone, user_dst, user_dateformat, user_style, user_rank, user_new_privmsg, user_unread_privmsg, user_last_privmsg, user_message_rules, user_full_folder, user_emailtime, user_topic_show_days, user_topic_sortby_type, user_topic_sortby_dir, user_post_show_days, user_post_sortby_type, user_post_sortby_dir, user_notify, user_notify_pm, user_notify_type, user_allow_pm, user_allow_viewonline, user_allow_viewemail, user_allow_massemail, user_options, user_avatar_width, user_avatar_height, user_sig_bbcode_uid, user_sig_bbcode_bitfield, user_msnm, user_jabber, user_actkey, user_newpasswd, osu_mapperrank, osu_testversion, osu_kudosavailable, osu_kudosdenied, osu_kudostotal, username_previous, osu_featurevotes, remember_token, lock_email_changes
DROP VIEW IF EXISTS `osu`.`phpbb_users`;
CREATE VIEW `osu`.`phpbb_users` AS
SELECT
    u.id AS `user_id`,
    0 AS `user_type`,
    CASE WHEN u.is_bot = 1 THEN 6 ELSE 7 END AS `group_id`,
    '' AS `user_permissions`,
    0 AS `user_perm_from`,
    '' AS `user_ip`,
    UNIX_TIMESTAMP(COALESCE(u.join_date, NOW())) AS `user_regdate`,
    LEFT(u.username, 255) AS `username`,
    LEFT(LOWER(u.username), 255) AS `username_clean`,
    LEFT(COALESCE(u.pw_bcrypt, ''), 255) AS `user_password`,
    0 AS `user_passchg`,
    LEFT(COALESCE(u.email, CONCAT('user', u.id, '@torii.invalid')), 100) AS `user_email`,
    '' AS `user_birthday`,
    UNIX_TIMESTAMP(COALESCE(u.last_visit, u.join_date, NOW())) AS `user_lastvisit`,
    0 AS `user_lastmark`,
    0 AS `user_lastpost_time`,
    '' AS `user_lastpage`,
    '' AS `user_last_confirm_key`,
    0 AS `user_last_search`,
    0 AS `user_warnings`,
    0 AS `user_last_warning`,
    0 AS `user_login_attempts`,
    0 AS `user_inactive_reason`,
    0 AS `user_inactive_time`,
    COALESCE(u.post_count, 0) AS `user_posts`,
    'en' AS `user_lang`,
    0.00 AS `user_timezone`,
    0 AS `user_dst`,
    '' AS `user_dateformat`,
    0 AS `user_style`,
    0 AS `user_rank`,
    LEFT(COALESCE(u.profile_colour, ''), 6) AS `user_colour`,
    0 AS `user_new_privmsg`,
    0 AS `user_unread_privmsg`,
    0 AS `user_last_privmsg`,
    0 AS `user_message_rules`,
    0 AS `user_full_folder`,
    0 AS `user_emailtime`,
    0 AS `user_topic_show_days`,
    '' AS `user_topic_sortby_type`,
    '' AS `user_topic_sortby_dir`,
    0 AS `user_post_show_days`,
    '' AS `user_post_sortby_type`,
    '' AS `user_post_sortby_dir`,
    0 AS `user_notify`,
    0 AS `user_notify_pm`,
    0 AS `user_notify_type`,
    0 AS `user_allow_pm`,
    0 AS `user_allow_viewonline`,
    0 AS `user_allow_viewemail`,
    0 AS `user_allow_massemail`,
    0 AS `user_options`,
    CASE WHEN u.avatar_url LIKE 'https://lazer-api.shikkesora.com/file/avatars/%' AND (CHAR_LENGTH(SUBSTRING_INDEX(u.avatar_url, '/', -1)) - CHAR_LENGTH(REPLACE(SUBSTRING_INDEX(u.avatar_url, '/', -1), '_', ''))) = 1 THEN SUBSTRING_INDEX(u.avatar_url, '/', -1) ELSE '' END AS `user_avatar`,
    0 AS `user_avatar_type`,
    0 AS `user_avatar_width`,
    0 AS `user_avatar_height`,
    '' AS `user_sig`,
    '' AS `user_sig_bbcode_uid`,
    '' AS `user_sig_bbcode_bitfield`,
    LEFT(COALESCE(u.location,''), 100) AS `user_from`,
    LEFT(COALESCE(u.twitter,''), 255) AS `user_twitter`,
    '' AS `user_msnm`,
    '' AS `user_jabber`,
    LEFT(COALESCE(u.website,''), 200) AS `user_website`,
    LEFT(COALESCE(u.occupation,''), 255) AS `user_occ`,
    LEFT(COALESCE(u.interests,''), 255) AS `user_interests`,
    '' AS `user_actkey`,
    '' AS `user_newpasswd`,
    0 AS `osu_mapperrank`,
    0 AS `osu_testversion`,
    (u.is_supporter = 1) AS `osu_subscriber`,
    u.donor_end_at AS `osu_subscriptionexpiry`,
    COALESCE(u.total_supporter_months, 0) AS `support_length`,
    0 AS `osu_kudosavailable`,
    0 AS `osu_kudosdenied`,
    0 AS `osu_kudostotal`,
    LEFT(COALESCE(NULLIF(u.country_code,''), 'XX'), 2) AS `country_acronym`,
    CASE WHEN COALESCE(JSON_UNQUOTE(JSON_EXTRACT(u.page, '$.raw')), '') <> '' THEN 900000 + u.id ELSE NULL END AS `userpage_post_id`,
    NULL AS `username_previous`,
    0 AS `osu_featurevotes`,
    COALESCE((JSON_CONTAINS(u.playstyle, '"mouse"') * 1) + (JSON_CONTAINS(u.playstyle, '"keyboard"') * 2) + (JSON_CONTAINS(u.playstyle, '"tablet"') * 4) + (JSON_CONTAINS(u.playstyle, '"touch"') * 8), 0) AS `osu_playstyle`,
    CASE u.playmode WHEN 'taiko' THEN 1 WHEN 'fruits' THEN 2 WHEN 'mania' THEN 3 ELSE 0 END AS `osu_playmode`,
    NULL AS `remember_token`,
    NULL AS `lock_email_changes`,
    CASE WHEN CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')) LIKE 'https://lazer-api.shikkesora.com/file/cover/%' THEN SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')), '/', -1) ELSE NULL END IS NULL THEN 1 ELSE NULL END AS `cover_preset_id`,
    CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')) LIKE 'https://lazer-api.shikkesora.com/file/cover/%' THEN SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(u.cover, '$.url')), '/', -1) ELSE NULL END AS `custom_cover_filename`
FROM torii.lazer_users u
WHERE u.username IS NOT NULL AND u.username <> ''
;

-- ---------------------------------------------------------------------------
-- phpbb_user_group
DROP VIEW IF EXISTS `osu`.`phpbb_user_group`;
CREATE VIEW `osu`.`phpbb_user_group` AS
SELECT
    g.group_id AS `group_id`,
    u.id AS `user_id`,
    0 AS `group_leader`,
    0 AS `user_pending`,
    NULL AS `playmodes`
FROM torii.lazer_users u JOIN osu.phpbb_groups g ON (g.identifier = 'default' OR (g.identifier = 'admin' AND u.is_admin = 1) OR (g.identifier = 'gmt'   AND u.is_gmt = 1) OR (g.identifier = 'nat'   AND u.is_qat = 1) OR (g.identifier = 'bng'   AND u.is_bng = 1) OR (g.identifier = 'bot'   AND u.is_bot = 1))
;

-- ---------------------------------------------------------------------------
-- phpbb_zebra
DROP VIEW IF EXISTS `osu`.`phpbb_zebra`;
CREATE VIEW `osu`.`phpbb_zebra` AS
SELECT
    r.user_id AS `user_id`,
    r.target_id AS `zebra_id`,
    (r.type = 'FOLLOW') AS `friend`,
    (r.type = 'BLOCK') AS `foe`
FROM torii.relationship r
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_osu_rx
DROP VIEW IF EXISTS `osu`.`osu_user_stats_osu_rx`;
CREATE VIEW `osu`.`osu_user_stats_osu_rx` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'OSURX'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_osu_ap
DROP VIEW IF EXISTS `osu`.`osu_user_stats_osu_ap`;
CREATE VIEW `osu`.`osu_user_stats_osu_ap` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'OSUAP'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_taiko_rx
DROP VIEW IF EXISTS `osu`.`osu_user_stats_taiko_rx`;
CREATE VIEW `osu`.`osu_user_stats_taiko_rx` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'TAIKORX'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_fruits_rx
DROP VIEW IF EXISTS `osu`.`osu_user_stats_fruits_rx`;
CREATE VIEW `osu`.`osu_user_stats_fruits_rx` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'FRUITSRX'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats
-- sin dato en Torii, va el default de la columna: accuracy_total, accuracy_count, fail_count, exit_count
DROP VIEW IF EXISTS `osu`.`osu_user_stats`;
CREATE VIEW `osu`.`osu_user_stats` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.count_300,0) AS `count300`,
    COALESCE(s.count_100,0) AS `count100`,
    COALESCE(s.count_50,0) AS `count50`,
    COALESCE(s.count_miss,0) AS `countMiss`,
    0 AS `accuracy_total`,
    0 AS `accuracy_count`,
    COALESCE(s.hit_accuracy,0) AS `accuracy`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.total_score,0) AS `total_score`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (PARTITION BY u.country_code ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank`,
    COALESCE(s.level_current,1) AS `level`,
    COALESCE(s.replays_watched_by_others,0) AS `replay_popularity`,
    0 AS `fail_count`,
    0 AS `exit_count`,
    LEAST(COALESCE(s.maximum_combo,0), 65535) AS `max_combo`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`,
    COALESCE(s.play_time,0) AS `total_seconds_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'OSU'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_taiko
-- sin dato en Torii, va el default de la columna: accuracy_total, accuracy_count, fail_count, exit_count
DROP VIEW IF EXISTS `osu`.`osu_user_stats_taiko`;
CREATE VIEW `osu`.`osu_user_stats_taiko` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.count_300,0) AS `count300`,
    COALESCE(s.count_100,0) AS `count100`,
    COALESCE(s.count_50,0) AS `count50`,
    COALESCE(s.count_miss,0) AS `countMiss`,
    0 AS `accuracy_total`,
    0 AS `accuracy_count`,
    COALESCE(s.hit_accuracy,0) AS `accuracy`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.total_score,0) AS `total_score`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (PARTITION BY u.country_code ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank`,
    COALESCE(s.level_current,1) AS `level`,
    COALESCE(s.replays_watched_by_others,0) AS `replay_popularity`,
    0 AS `fail_count`,
    0 AS `exit_count`,
    LEAST(COALESCE(s.maximum_combo,0), 65535) AS `max_combo`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`,
    COALESCE(s.play_time,0) AS `total_seconds_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'TAIKO'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_fruits
-- sin dato en Torii, va el default de la columna: accuracy_total, accuracy_count, fail_count, exit_count
DROP VIEW IF EXISTS `osu`.`osu_user_stats_fruits`;
CREATE VIEW `osu`.`osu_user_stats_fruits` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.count_300,0) AS `count300`,
    COALESCE(s.count_100,0) AS `count100`,
    COALESCE(s.count_50,0) AS `count50`,
    COALESCE(s.count_miss,0) AS `countMiss`,
    0 AS `accuracy_total`,
    0 AS `accuracy_count`,
    COALESCE(s.hit_accuracy,0) AS `accuracy`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.total_score,0) AS `total_score`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (PARTITION BY u.country_code ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank`,
    COALESCE(s.level_current,1) AS `level`,
    COALESCE(s.replays_watched_by_others,0) AS `replay_popularity`,
    0 AS `fail_count`,
    0 AS `exit_count`,
    LEAST(COALESCE(s.maximum_combo,0), 65535) AS `max_combo`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`,
    COALESCE(s.play_time,0) AS `total_seconds_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'FRUITS'
;

-- ---------------------------------------------------------------------------
-- osu_user_stats_mania
-- sin dato en Torii, va el default de la columna: accuracy_total, accuracy_count, fail_count, exit_count
DROP VIEW IF EXISTS `osu`.`osu_user_stats_mania`;
CREATE VIEW `osu`.`osu_user_stats_mania` AS
SELECT
    s.user_id AS `user_id`,
    COALESCE(s.count_300,0) AS `count300`,
    COALESCE(s.count_100,0) AS `count100`,
    COALESCE(s.count_50,0) AS `count50`,
    COALESCE(s.count_miss,0) AS `countMiss`,
    0 AS `accuracy_total`,
    0 AS `accuracy_count`,
    COALESCE(s.hit_accuracy,0) AS `accuracy`,
    COALESCE(s.play_count,0) AS `playcount`,
    COALESCE(s.ranked_score,0) AS `ranked_score`,
    COALESCE(s.total_score,0) AS `total_score`,
    COALESCE(s.grade_ss,0) AS `x_rank_count`,
    COALESCE(s.grade_ssh,0) AS `xh_rank_count`,
    COALESCE(s.grade_s,0) AS `s_rank_count`,
    COALESCE(s.grade_sh,0) AS `sh_rank_count`,
    COALESCE(s.grade_a,0) AS `a_rank_count`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (PARTITION BY u.country_code ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank`,
    COALESCE(s.level_current,1) AS `level`,
    COALESCE(s.replays_watched_by_others,0) AS `replay_popularity`,
    0 AS `fail_count`,
    0 AS `exit_count`,
    LEAST(COALESCE(s.maximum_combo,0), 65535) AS `max_combo`,
    COALESCE(NULLIF(u.country_code,''),'XX') AS `country_acronym`,
    COALESCE(s.pp,0) AS `rank_score`,
    CASE WHEN COALESCE(s.pp,0) > 0 THEN CAST(ROW_NUMBER() OVER (ORDER BY COALESCE(s.pp,0) DESC, s.user_id ASC) AS SIGNED) ELSE 0 END AS `rank_score_index`,
    COALESCE(s.hit_accuracy,0) AS `accuracy_new`,
    NOW() AS `last_update`,
    COALESCE(s.last_played, NOW()) AS `last_played`,
    COALESCE(s.play_time,0) AS `total_seconds_played`
FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id
WHERE s.mode = 'MANIA'
;

-- ---------------------------------------------------------------------------
-- osu_beatmapsets
-- sin dato en Torii, va el default de la columna: thread_id, epilepsy, approvedby_id, filename, rating, offset, star_priority, filesize, filesize_novideo, body_hash, header_hash, osz2_hash, download_disabled_url, thread_icon_date, discussion_enabled, deleted_at, previous_queue_duration, queued_at, storyboard_hash, anime_cover, comment_locked, eligible_main_rulesets
DROP VIEW IF EXISTS `osu`.`osu_beatmapsets`;
CREATE VIEW `osu`.`osu_beatmapsets` AS
SELECT
    b.id AS `beatmapset_id`,
    CASE WHEN b.is_local = 1 THEN b.user_id ELSE 0 END AS `user_id`,
    0 AS `thread_id`,
    LEFT(COALESCE(b.artist,''), 80) AS `artist`,
    LEFT(COALESCE(NULLIF(b.artist_unicode,''), b.artist, ''), 80) AS `artist_unicode`,
    LEFT(COALESCE(b.title,''), 80) AS `title`,
    LEFT(COALESCE(NULLIF(b.title_unicode,''), b.title, ''), 80) AS `title_unicode`,
    LEFT(COALESCE(b.creator,''), 80) AS `creator`,
    LEFT(COALESCE(b.source,''), 200) AS `source`,
    LEFT(COALESCE(b.tags,''), 1000) AS `tags`,
    COALESCE(b.video, 0) AS `video`,
    COALESCE(b.storyboard, 0) AS `storyboard`,
    0 AS `epilepsy`,
    COALESCE(b.bpm, 0) AS `bpm`,
    GREATEST(COALESCE(c.versions_available, 1), 1) AS `versions_available`,
    CASE b.beatmap_status WHEN 'GRAVEYARD' THEN -2 WHEN 'WIP' THEN -1 WHEN 'PENDING' THEN 0 WHEN 'RANKED' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'QUALIFIED' THEN 3 WHEN 'LOVED' THEN 4 ELSE 0 END AS `approved`,
    NULL AS `approvedby_id`,
    CASE WHEN b.beatmap_status IN ('RANKED','APPROVED','QUALIFIED','LOVED') THEN COALESCE(b.ranked_date, b.last_updated, b.submitted_date) ELSE b.ranked_date END AS `approved_date`,
    COALESCE(b.submitted_date, b.last_updated, NOW()) AS `submit_date`,
    COALESCE(b.last_updated, NOW()) AS `last_update`,
    NULL AS `filename`,
    1 AS `active`,
    0 AS `rating`,
    0 AS `offset`,
    LEFT(CONCAT(COALESCE(b.artist,''), ' - ', COALESCE(b.title,'')), 200) AS `displaytitle`,
    CASE b.beatmap_genre WHEN 'VIDEO_GAME' THEN 2 WHEN 'ANIME' THEN 3 WHEN 'ROCK' THEN 4 WHEN 'POP' THEN 5 WHEN 'OTHER' THEN 6 WHEN 'NOVELTY' THEN 7 WHEN 'HIP_HOP' THEN 9 WHEN 'ELECTRONIC' THEN 10 WHEN 'METAL' THEN 11 WHEN 'CLASSICAL' THEN 12 WHEN 'FOLK' THEN 13 WHEN 'JAZZ' THEN 14 ELSE 1 END AS `genre_id`,
    CASE b.beatmap_language WHEN 'ENGLISH' THEN 2 WHEN 'JAPANESE' THEN 3 WHEN 'CHINESE' THEN 4 WHEN 'INSTRUMENTAL' THEN 5 WHEN 'KOREAN' THEN 6 WHEN 'FRENCH' THEN 7 WHEN 'GERMAN' THEN 8 WHEN 'SWEDISH' THEN 9 WHEN 'SPANISH' THEN 10 WHEN 'ITALIAN' THEN 11 WHEN 'RUSSIAN' THEN 12 WHEN 'POLISH' THEN 13 WHEN 'OTHER' THEN 14 ELSE 1 END AS `language_id`,
    0 AS `star_priority`,
    0 AS `filesize`,
    NULL AS `filesize_novideo`,
    NULL AS `body_hash`,
    NULL AS `header_hash`,
    NULL AS `osz2_hash`,
    COALESCE(b.download_disabled, 0) AS `download_disabled`,
    NULL AS `download_disabled_url`,
    NULL AS `thread_icon_date`,
    COALESCE(c.favourite_count, 0) AS `favourite_count`,
    COALESCE(c.play_count, 0) AS `play_count`,
    c.difficulty_names AS `difficulty_names`,
    COALESCE(b.last_updated, NOW()) AS `cover_updated_at`,
    0 AS `discussion_enabled`,
    COALESCE(b.discussion_locked, 0) AS `discussion_locked`,
    NULL AS `deleted_at`,
    COALESCE(b.hype_current, 0) AS `hype`,
    COALESCE(b.nominations_current, 0) AS `nominations`,
    0 AS `previous_queue_duration`,
    NULL AS `queued_at`,
    NULL AS `storyboard_hash`,
    COALESCE(b.nsfw, 0) AS `nsfw`,
    0 AS `anime_cover`,
    b.track_id AS `track_id`,
    COALESCE(b.spotlight, 0) AS `spotlight`,
    0 AS `comment_locked`,
    NULL AS `eligible_main_rulesets`
FROM torii.beatmapsets b LEFT JOIN osu.torii_cache_beatmapset c ON c.beatmapset_id = b.id
WHERE EXISTS (SELECT 1 FROM torii.beatmaps m2 WHERE m2.beatmapset_id = b.id)
;

-- ---------------------------------------------------------------------------
-- osu_beatmaps
-- sin dato en Torii, va el default de la columna: youtube_preview, score_version, osu_file_version, lazer_only
DROP VIEW IF EXISTS `osu`.`osu_beatmaps`;
CREATE VIEW `osu`.`osu_beatmaps` AS
SELECT
    m.id AS `beatmap_id`,
    m.beatmapset_id AS `beatmapset_id`,
    CASE WHEN m.is_local = 1 THEN m.user_id ELSE 0 END AS `user_id`,
    LEFT(CONCAT(m.beatmapset_id, ' ', COALESCE(m.version,''), '.osu'), 150) AS `filename`,
    LEFT(COALESCE(m.checksum,''), 32) AS `checksum`,
    LEFT(COALESCE(m.version,''), 80) AS `version`,
    COALESCE(m.total_length, 0) AS `total_length`,
    COALESCE(m.hit_length, 0) AS `hit_length`,
    COALESCE(m.count_circles,0) + COALESCE(m.count_sliders,0) + COALESCE(m.count_spinners,0) AS `countTotal`,
    COALESCE(m.count_circles,0) AS `countNormal`,
    COALESCE(m.count_sliders,0) AS `countSlider`,
    COALESCE(m.count_spinners,0) AS `countSpinner`,
    GREATEST(COALESCE(m.drain,0), 0) AS `diff_drain`,
    GREATEST(COALESCE(m.cs,0), 0) AS `diff_size`,
    GREATEST(COALESCE(m.accuracy,0), 0) AS `diff_overall`,
    GREATEST(COALESCE(m.ar,0), 0) AS `diff_approach`,
    CASE m.mode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS `playmode`,
    CASE m.beatmap_status WHEN 'GRAVEYARD' THEN -2 WHEN 'WIP' THEN -1 WHEN 'PENDING' THEN 0 WHEN 'RANKED' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'QUALIFIED' THEN 3 WHEN 'LOVED' THEN 4 ELSE 0 END AS `approved`,
    COALESCE(m.last_updated, NOW()) AS `last_update`,
    COALESCE(m.difficulty_rating, 0) AS `difficultyrating`,
    LEAST(COALESCE(m.max_combo, 0), 16777215) AS `max_combo`,
    COALESCE(c.playcount, 0) AS `playcount`,
    COALESCE(c.passcount, 0) AS `passcount`,
    NULL AS `youtube_preview`,
    0 AS `score_version`,
    0 AS `osu_file_version`,
    m.deleted_at AS `deleted_at`,
    COALESCE(m.bpm, 0) AS `bpm`,
    0 AS `lazer_only`
FROM torii.beatmaps m JOIN torii.beatmapsets bs ON bs.id = m.beatmapset_id LEFT JOIN osu.torii_cache_beatmap c ON c.beatmap_id = m.id
;

-- ---------------------------------------------------------------------------
-- scores
-- sin dato en Torii, va el default de la columna: legacy_score_id, legacy_total_score, build_id
DROP VIEW IF EXISTS `osu`.`scores`;
CREATE VIEW `osu`.`scores` AS
SELECT
    s.id AS `id`,
    s.user_id AS `user_id`,
    CASE s.gamemode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS `ruleset_id`,
    s.beatmap_id AS `beatmap_id`,
    0 AS `has_replay`,
    COALESCE(s.preserve, 0) AS `preserve`,
    COALESCE(s.ranked, 0) AS `ranked`,
    COALESCE(s.`rank`, 'D') AS `rank`,
    COALESCE(s.passed, 0) AS `passed`,
    COALESCE(s.accuracy, 0) AS `accuracy`,
    COALESCE(s.max_combo, 0) AS `max_combo`,
    COALESCE(s.total_score, 0) AS `total_score`,
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
    ) AS `data`,
    s.pp AS `pp`,
    NULL AS `legacy_score_id`,
    0 AS `legacy_total_score`,
    s.started_at AS `started_at`,
    COALESCE(s.ended_at, NOW()) AS `ended_at`,
    UNIX_TIMESTAMP(COALESCE(s.ended_at, NOW())) AS `unix_updated_at`,
    NULL AS `build_id`
FROM torii.scores s
WHERE s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA')
;

-- ---------------------------------------------------------------------------
-- score_pins
DROP VIEW IF EXISTS `osu`.`score_pins`;
CREATE VIEW `osu`.`score_pins` AS
SELECT
    s.user_id AS `user_id`,
    s.id AS `score_id`,
    CASE s.gamemode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS `ruleset_id`,
    s.pinned_order AS `display_order`,
    COALESCE(s.ended_at, NOW()) AS `created_at`,
    COALESCE(s.ended_at, NOW()) AS `updated_at`
FROM torii.scores s JOIN torii.lazer_users pu ON pu.id = s.user_id
WHERE s.pinned_order > 0 AND s.gamemode IN ('OSU','TAIKO','FRUITS','MANIA')
;

-- ---------------------------------------------------------------------------
-- osu_user_achievements
-- sin dato en Torii, va el default de la columna: beatmap_id
DROP VIEW IF EXISTS `osu`.`osu_user_achievements`;
CREATE VIEW `osu`.`osu_user_achievements` AS
SELECT
    a.user_id AS `user_id`,
    a.achievement_id AS `achievement_id`,
    COALESCE(a.achieved_at, NOW()) AS `date`,
    NULL AS `beatmap_id`
FROM torii.lazer_user_achievements a
;

-- ---------------------------------------------------------------------------
-- osu_favouritemaps
DROP VIEW IF EXISTS `osu`.`osu_favouritemaps`;
CREATE VIEW `osu`.`osu_favouritemaps` AS
SELECT
    f.user_id AS `user_id`,
    f.beatmapset_id AS `beatmapset_id`,
    COALESCE(f.date, NOW()) AS `dateadded`
FROM torii.favourite_beatmapset f
;

-- ---------------------------------------------------------------------------
-- osu_user_beatmap_playcount
DROP VIEW IF EXISTS `osu`.`osu_user_beatmap_playcount`;
CREATE VIEW `osu`.`osu_user_beatmap_playcount` AS
SELECT
    p.user_id AS `user_id`,
    p.beatmap_id AS `beatmap_id`,
    LEAST(SUM(p.playcount), 65535) AS `playcount`
FROM torii.beatmap_playcounts p
GROUP BY p.user_id, p.beatmap_id
;

-- ---------------------------------------------------------------------------
-- osu_user_month_playcount
DROP VIEW IF EXISTS `osu`.`osu_user_month_playcount`;
CREATE VIEW `osu`.`osu_user_month_playcount` AS
SELECT
    m.user_id AS `user_id`,
    CONCAT(LPAD(m.year % 100, 2, '0'), LPAD(m.month, 2, '0')) AS `year_month`,
    LEAST(m.count, 65535) AS `playcount`
FROM torii.monthly_playcounts m
;

-- ---------------------------------------------------------------------------
-- osu_user_replayswatched
DROP VIEW IF EXISTS `osu`.`osu_user_replayswatched`;
CREATE VIEW `osu`.`osu_user_replayswatched` AS
SELECT
    r.user_id AS `user_id`,
    CONCAT(LPAD(r.year % 100, 2, '0'), LPAD(r.month, 2, '0')) AS `year_month`,
    r.count AS `count`
FROM torii.replays_watched_counts r
;

-- ---------------------------------------------------------------------------
-- teams
-- sin dato en Torii, va el default de la columna: is_open
DROP VIEW IF EXISTS `osu`.`teams`;
CREATE VIEW `osu`.`teams` AS
SELECT
    t.id AS `id`,
    LEFT(t.name, 255) AS `name`,
    LEFT(COALESCE(t.short_name,''), 255) AS `short_name`,
    NULLIF(SUBSTRING_INDEX(COALESCE(t.flag_url,''), '/', -1), '') AS `flag_file`,
    NULLIF(SUBSTRING_INDEX(COALESCE(t.cover_url,''), '/', -1), '') AS `header_file`,
    LEFT(COALESCE(t.website,''), 255) AS `url`,
    t.description AS `description`,
    0 AS `is_open`,
    CASE t.playmode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS `default_ruleset_id`,
    t.leader_id AS `leader_id`,
    0 AS `channel_id`,
    COALESCE(t.created_at, NOW()) AS `created_at`,
    COALESCE(t.created_at, NOW()) AS `updated_at`
FROM torii.teams t
;

-- ---------------------------------------------------------------------------
-- team_members
DROP VIEW IF EXISTS `osu`.`team_members`;
CREATE VIEW `osu`.`team_members` AS
SELECT
    m.user_id AS `user_id`,
    m.team_id AS `team_id`,
    COALESCE(m.joined_at, NOW()) AS `created_at`,
    COALESCE(m.joined_at, NOW()) AS `updated_at`
FROM torii.team_members m
;

-- ---------------------------------------------------------------------------
-- osu_events
-- sin dato en Torii, va el default de la columna: text_clean, legacy_score_event
DROP VIEW IF EXISTS `osu`.`osu_events`;
CREATE VIEW `osu`.`osu_events` AS
SELECT
    e.id AS `event_id`,
    LEFT(CASE e.type
        WHEN 'RANK' THEN CONCAT(
            '<img src=''/images/', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.scorerank')),
            '_small.png''/> <b><a href=''/users/', e.user_id, '''>', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
            '</a></b> achieved rank #', JSON_EXTRACT(e.event_payload, '$.rank'),
            ' on <a href=''/b/', SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1), '''>', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.title')), '</a> (', CASE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode')) WHEN 'osu!relax' THEN 'osu!' WHEN 'osu!autopilot' THEN 'osu!' WHEN 'catch relax' THEN 'osu!catch' WHEN 'taiko relax' THEN 'osu!taiko' ELSE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode')) END, ')')
        WHEN 'RANK_LOST' THEN CONCAT(
            '<b><a href=''/users/', e.user_id, '''>', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
            '</a></b> has lost first place on <a href=''/b/', SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1), '''>', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.title')),
            '</a> (', CASE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode')) WHEN 'osu!relax' THEN 'osu!' WHEN 'osu!autopilot' THEN 'osu!' WHEN 'catch relax' THEN 'osu!catch' WHEN 'taiko relax' THEN 'osu!taiko' ELSE JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.mode')) END, ')')
        WHEN 'ACHIEVEMENT' THEN CONCAT(
            '<b><a href=''/users/', e.user_id, '''>', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')),
            '</a></b> unlocked the "<b>',
            JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.achievement.name')), '</b>" medal!')
        WHEN 'USERNAME_CHANGE' THEN CONCAT(
            '<b><a href=''/users/', e.user_id, '''>',
            JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.previous_username')),
            '</a></b> has changed their username to ', JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.user.username')), '!')
    END, 1000) AS `text`,
    NULL AS `text_clean`,
    CASE WHEN e.type IN ('RANK','RANK_LOST') THEN SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(e.event_payload, '$.beatmap.url')), '/', -1) ELSE NULL END AS `beatmap_id`,
    NULL AS `beatmapset_id`,
    e.user_id AS `user_id`,
    e.created_at AS `date`,
    1 AS `epicfactor`,
    0 AS `private`,
    NULL AS `legacy_score_event`
FROM torii.user_events e
WHERE e.type IN ('RANK','RANK_LOST','ACHIEVEMENT','USERNAME_CHANGE') AND CASE e.type   WHEN 'ACHIEVEMENT' THEN JSON_EXTRACT(e.event_payload, '$.achievement.name') IS NOT NULL   WHEN 'USERNAME_CHANGE' THEN JSON_EXTRACT(e.event_payload, '$.user.previous_username') IS NOT NULL   ELSE JSON_EXTRACT(e.event_payload, '$.beatmap.url') IS NOT NULL END
;

-- ---------------------------------------------------------------------------
-- osu_user_banhistory
-- sin dato en Torii, va el default de la columna: supporting_url
DROP VIEW IF EXISTS `osu`.`osu_user_banhistory`;
CREATE VIEW `osu`.`osu_user_banhistory` AS
SELECT
    h.id AS `ban_id`,
    h.user_id AS `user_id`,
    LEFT(COALESCE(h.description,''), 8000) AS `reason`,
    NULL AS `supporting_url`,
    CASE h.type WHEN 'NOTE' THEN 0 WHEN 'RESTRICTION' THEN 1 WHEN 'SLIENCE' THEN 2 WHEN 'TOURNAMENT_BAN' THEN 3 ELSE 0 END AS `ban_status`,
    COALESCE(h.length, 0) AS `period`,
    h.timestamp AS `timestamp`,
    NULL AS `banner_id`,
    COALESCE(h.permanent, 0) AS `permanent`
FROM torii.user_account_history h
;

-- ---------------------------------------------------------------------------
-- osu_username_change_history
DROP VIEW IF EXISTS `osu`.`osu_username_change_history`;
CREATE VIEW `osu`.`osu_username_change_history` AS
SELECT
    u.id * 100 + jt.pos AS `change_id`,
    u.id AS `user_id`,
    LEFT(u.username, 30) AS `username`,
    'admin' AS `type`,
    COALESCE(u.join_date, NOW()) AS `timestamp`,
    LEFT(jt.uname, 30) AS `username_last`
FROM torii.lazer_users u JOIN JSON_TABLE(u.previous_usernames, '$[*]' COLUMNS (uname VARCHAR(30) PATH '$', pos FOR ORDINALITY)) jt
WHERE JSON_LENGTH(u.previous_usernames) > 0 AND jt.uname COLLATE utf8mb4_general_ci <> u.username
;

-- ---------------------------------------------------------------------------
-- osu_user_performance_rank
-- sin dato en Torii, va el default de la columna: r0
DROP VIEW IF EXISTS `osu`.`osu_user_performance_rank`;
CREATE VIEW `osu`.`osu_user_performance_rank` AS
SELECT
    h.user_id AS `user_id`,
    CASE h.mode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS `mode`,
    0 AS `r0`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 88 THEN h.`rank` END), 0) AS `r1`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 87 THEN h.`rank` END), 0) AS `r2`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 86 THEN h.`rank` END), 0) AS `r3`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 85 THEN h.`rank` END), 0) AS `r4`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 84 THEN h.`rank` END), 0) AS `r5`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 83 THEN h.`rank` END), 0) AS `r6`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 82 THEN h.`rank` END), 0) AS `r7`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 81 THEN h.`rank` END), 0) AS `r8`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 80 THEN h.`rank` END), 0) AS `r9`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 79 THEN h.`rank` END), 0) AS `r10`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 78 THEN h.`rank` END), 0) AS `r11`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 77 THEN h.`rank` END), 0) AS `r12`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 76 THEN h.`rank` END), 0) AS `r13`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 75 THEN h.`rank` END), 0) AS `r14`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 74 THEN h.`rank` END), 0) AS `r15`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 73 THEN h.`rank` END), 0) AS `r16`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 72 THEN h.`rank` END), 0) AS `r17`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 71 THEN h.`rank` END), 0) AS `r18`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 70 THEN h.`rank` END), 0) AS `r19`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 69 THEN h.`rank` END), 0) AS `r20`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 68 THEN h.`rank` END), 0) AS `r21`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 67 THEN h.`rank` END), 0) AS `r22`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 66 THEN h.`rank` END), 0) AS `r23`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 65 THEN h.`rank` END), 0) AS `r24`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 64 THEN h.`rank` END), 0) AS `r25`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 63 THEN h.`rank` END), 0) AS `r26`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 62 THEN h.`rank` END), 0) AS `r27`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 61 THEN h.`rank` END), 0) AS `r28`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 60 THEN h.`rank` END), 0) AS `r29`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 59 THEN h.`rank` END), 0) AS `r30`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 58 THEN h.`rank` END), 0) AS `r31`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 57 THEN h.`rank` END), 0) AS `r32`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 56 THEN h.`rank` END), 0) AS `r33`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 55 THEN h.`rank` END), 0) AS `r34`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 54 THEN h.`rank` END), 0) AS `r35`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 53 THEN h.`rank` END), 0) AS `r36`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 52 THEN h.`rank` END), 0) AS `r37`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 51 THEN h.`rank` END), 0) AS `r38`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 50 THEN h.`rank` END), 0) AS `r39`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 49 THEN h.`rank` END), 0) AS `r40`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 48 THEN h.`rank` END), 0) AS `r41`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 47 THEN h.`rank` END), 0) AS `r42`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 46 THEN h.`rank` END), 0) AS `r43`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 45 THEN h.`rank` END), 0) AS `r44`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 44 THEN h.`rank` END), 0) AS `r45`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 43 THEN h.`rank` END), 0) AS `r46`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 42 THEN h.`rank` END), 0) AS `r47`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 41 THEN h.`rank` END), 0) AS `r48`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 40 THEN h.`rank` END), 0) AS `r49`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 39 THEN h.`rank` END), 0) AS `r50`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 38 THEN h.`rank` END), 0) AS `r51`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 37 THEN h.`rank` END), 0) AS `r52`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 36 THEN h.`rank` END), 0) AS `r53`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 35 THEN h.`rank` END), 0) AS `r54`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 34 THEN h.`rank` END), 0) AS `r55`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 33 THEN h.`rank` END), 0) AS `r56`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 32 THEN h.`rank` END), 0) AS `r57`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 31 THEN h.`rank` END), 0) AS `r58`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 30 THEN h.`rank` END), 0) AS `r59`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 29 THEN h.`rank` END), 0) AS `r60`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 28 THEN h.`rank` END), 0) AS `r61`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 27 THEN h.`rank` END), 0) AS `r62`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 26 THEN h.`rank` END), 0) AS `r63`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 25 THEN h.`rank` END), 0) AS `r64`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 24 THEN h.`rank` END), 0) AS `r65`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 23 THEN h.`rank` END), 0) AS `r66`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 22 THEN h.`rank` END), 0) AS `r67`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 21 THEN h.`rank` END), 0) AS `r68`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 20 THEN h.`rank` END), 0) AS `r69`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 19 THEN h.`rank` END), 0) AS `r70`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 18 THEN h.`rank` END), 0) AS `r71`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 17 THEN h.`rank` END), 0) AS `r72`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 16 THEN h.`rank` END), 0) AS `r73`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 15 THEN h.`rank` END), 0) AS `r74`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 14 THEN h.`rank` END), 0) AS `r75`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 13 THEN h.`rank` END), 0) AS `r76`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 12 THEN h.`rank` END), 0) AS `r77`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 11 THEN h.`rank` END), 0) AS `r78`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 10 THEN h.`rank` END), 0) AS `r79`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 9 THEN h.`rank` END), 0) AS `r80`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 8 THEN h.`rank` END), 0) AS `r81`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 7 THEN h.`rank` END), 0) AS `r82`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 6 THEN h.`rank` END), 0) AS `r83`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 5 THEN h.`rank` END), 0) AS `r84`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 4 THEN h.`rank` END), 0) AS `r85`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 3 THEN h.`rank` END), 0) AS `r86`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 2 THEN h.`rank` END), 0) AS `r87`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 1 THEN h.`rank` END), 0) AS `r88`,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 0 THEN h.`rank` END), 0) AS `r89`
FROM torii.rank_history h
WHERE h.mode IN ('OSU','TAIKO','FRUITS','MANIA')
GROUP BY h.user_id, CASE h.mode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END
;

-- ---------------------------------------------------------------------------
-- osu_user_performance_rank_highest
DROP VIEW IF EXISTS `osu`.`osu_user_performance_rank_highest`;
CREATE VIEW `osu`.`osu_user_performance_rank_highest` AS
SELECT
    h.user_id AS `user_id`,
    CASE h.mode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END AS `mode`,
    MIN(h.`rank`) AS `rank`,
    MAX(h.date) AS `updated_at`
FROM torii.rank_history h
WHERE h.`rank` > 0 AND h.mode IN ('OSU','TAIKO','FRUITS','MANIA')
GROUP BY h.user_id, CASE h.mode WHEN 'TAIKO' THEN 1 WHEN 'TAIKORX' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'FRUITSRX' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END
;

-- ---------------------------------------------------------------------------
-- osu_countries
-- sin dato en Torii, va el default de la columna: shipping_rate
DROP VIEW IF EXISTS `osu`.`osu_countries`;
CREATE VIEW `osu`.`osu_countries` AS
SELECT
    b.acronym AS `acronym`,
    b.name AS `name`,
    COALESCE(c.rankedscore, 0) AS `rankedscore`,
    COALESCE(c.playcount, 0) AS `playcount`,
    COALESCE(c.usercount, 0) AS `usercount`,
    COALESCE(c.pp, 0) AS `pp`,
    b.display AS `display`,
    0 AS `shipping_rate`
FROM osu.torii_country_catalog b LEFT JOIN ( SELECT COALESCE(NULLIF(u.country_code,''),'XX') AS acronym, COUNT(*) AS usercount, SUM(COALESCE(s.play_count,0)) AS playcount, SUM(COALESCE(s.ranked_score,0)) AS rankedscore, SUM(COALESCE(s.pp,0)) AS pp FROM torii.lazer_user_statistics s JOIN torii.lazer_users u ON u.id = s.user_id WHERE s.mode = 'OSU' GROUP BY 1) c ON c.acronym = b.acronym
;

-- ---------------------------------------------------------------------------
-- beatmap_leaders
DROP VIEW IF EXISTS `osu`.`beatmap_leaders`;
CREATE VIEW `osu`.`beatmap_leaders` AS
SELECT
    l.score_id AS `score_id`,
    l.beatmap_id AS `beatmap_id`,
    l.ruleset_id AS `ruleset_id`,
    l.user_id AS `user_id`
FROM osu.torii_cache_beatmap_leader l
;

