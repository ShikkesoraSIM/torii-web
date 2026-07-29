-- torii: historial de posicion global, el grafico que sale arriba del perfil.
--
-- osu-web no guarda una fila por dia: guarda noventa columnas r0..r89 y las usa
-- como buffer circular, con un contador en osu_counts que dice cual es la de
-- hoy. Cuando ese contador no existe, RankHistory::getDataAttribute arranca en
-- r1 y lee hasta r89, y despues le pega la posicion actual sacada de las stats.
-- Asi que se llenan r1..r89 con los ultimos 89 dias, del mas viejo al mas
-- nuevo, y no se toca ningun contador.
--
-- Los dias sin dato quedan en cero, que es lo que el grafico interpreta como
-- "no habia posicion todavia".
--
-- Generado, no editar a mano.

INSERT INTO osu.osu_user_performance_rank (user_id, mode, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31, r32, r33, r34, r35, r36, r37, r38, r39, r40, r41, r42, r43, r44, r45, r46, r47, r48, r49, r50, r51, r52, r53, r54, r55, r56, r57, r58, r59, r60, r61, r62, r63, r64, r65, r66, r67, r68, r69, r70, r71, r72, r73, r74, r75, r76, r77, r78, r79, r80, r81, r82, r83, r84, r85, r86, r87, r88, r89)
SELECT
    h.user_id,
    CASE h.mode WHEN 'TAIKO' THEN 1 WHEN 'FRUITS' THEN 2 WHEN 'MANIA' THEN 3 ELSE 0 END,
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 88 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 87 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 86 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 85 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 84 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 83 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 82 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 81 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 80 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 79 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 78 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 77 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 76 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 75 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 74 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 73 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 72 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 71 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 70 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 69 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 68 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 67 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 66 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 65 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 64 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 63 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 62 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 61 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 60 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 59 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 58 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 57 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 56 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 55 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 54 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 53 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 52 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 51 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 50 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 49 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 48 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 47 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 46 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 45 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 44 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 43 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 42 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 41 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 40 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 39 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 38 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 37 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 36 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 35 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 34 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 33 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 32 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 31 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 30 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 29 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 28 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 27 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 26 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 25 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 24 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 23 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 22 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 21 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 20 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 19 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 18 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 17 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 16 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 15 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 14 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 13 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 12 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 11 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 10 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 9 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 8 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 7 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 6 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 5 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 4 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 3 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 2 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 1 THEN h.rank END), 0),
    COALESCE(MAX(CASE WHEN DATEDIFF(CURDATE(), h.date) = 0 THEN h.rank END), 0)
FROM torii.rank_history h
JOIN osu.phpbb_users u ON u.user_id = h.user_id
WHERE h.mode IN ('OSU', 'TAIKO', 'FRUITS', 'MANIA')
  AND h.date >= DATE_SUB(CURDATE(), INTERVAL 89 DAY)
GROUP BY h.user_id, h.mode
ON DUPLICATE KEY UPDATE r1 = VALUES(r1), r2 = VALUES(r2), r3 = VALUES(r3), r4 = VALUES(r4), r5 = VALUES(r5), r6 = VALUES(r6), r7 = VALUES(r7), r8 = VALUES(r8), r9 = VALUES(r9), r10 = VALUES(r10), r11 = VALUES(r11), r12 = VALUES(r12), r13 = VALUES(r13), r14 = VALUES(r14), r15 = VALUES(r15), r16 = VALUES(r16), r17 = VALUES(r17), r18 = VALUES(r18), r19 = VALUES(r19), r20 = VALUES(r20), r21 = VALUES(r21), r22 = VALUES(r22), r23 = VALUES(r23), r24 = VALUES(r24), r25 = VALUES(r25), r26 = VALUES(r26), r27 = VALUES(r27), r28 = VALUES(r28), r29 = VALUES(r29), r30 = VALUES(r30), r31 = VALUES(r31), r32 = VALUES(r32), r33 = VALUES(r33), r34 = VALUES(r34), r35 = VALUES(r35), r36 = VALUES(r36), r37 = VALUES(r37), r38 = VALUES(r38), r39 = VALUES(r39), r40 = VALUES(r40), r41 = VALUES(r41), r42 = VALUES(r42), r43 = VALUES(r43), r44 = VALUES(r44), r45 = VALUES(r45), r46 = VALUES(r46), r47 = VALUES(r47), r48 = VALUES(r48), r49 = VALUES(r49), r50 = VALUES(r50), r51 = VALUES(r51), r52 = VALUES(r52), r53 = VALUES(r53), r54 = VALUES(r54), r55 = VALUES(r55), r56 = VALUES(r56), r57 = VALUES(r57), r58 = VALUES(r58), r59 = VALUES(r59), r60 = VALUES(r60), r61 = VALUES(r61), r62 = VALUES(r62), r63 = VALUES(r63), r64 = VALUES(r64), r65 = VALUES(r65), r66 = VALUES(r66), r67 = VALUES(r67), r68 = VALUES(r68), r69 = VALUES(r69), r70 = VALUES(r70), r71 = VALUES(r71), r72 = VALUES(r72), r73 = VALUES(r73), r74 = VALUES(r74), r75 = VALUES(r75), r76 = VALUES(r76), r77 = VALUES(r77), r78 = VALUES(r78), r79 = VALUES(r79), r80 = VALUES(r80), r81 = VALUES(r81), r82 = VALUES(r82), r83 = VALUES(r83), r84 = VALUES(r84), r85 = VALUES(r85), r86 = VALUES(r86), r87 = VALUES(r87), r88 = VALUES(r88), r89 = VALUES(r89);
