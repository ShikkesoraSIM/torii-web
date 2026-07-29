<?php

// torii: arma el indice `scores` de elasticsearch a partir de la tabla scores.
//
// osu-web no indexa scores por su cuenta: solo los encola, y quien los escribe
// de verdad es osu-elastic-indexer, un servicio aparte que este compose no
// levanta. Sin ese indice la pagina de un score tira 404 de elasticsearch,
// porque para mostrar la posicion del jugador hace una busqueda.
//
// El documento sale de leer que campos consulta ScoreSearch::getQuery():
// id, beatmap_id, ruleset_id, user_id, total_score, legacy_total_score, pp,
// is_legacy, mods, convert y country_code. Nada mas.
//
// Se crea un indice propio y se le cuelga el alias `scores`, que es el nombre
// contra el que consulta osu-web.

const ES = 'http://elasticsearch:9200';
const INDEX = 'scores_torii';
const CHUNK = 5000;

function es(string $method, string $path, ?string $body = null, string $type = 'application/json'): array
{
    $ch = curl_init(ES . $path);
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => ['Content-Type: ' . $type],
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    }
    $out = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return [$code, $out];
}

es('DELETE', '/' . INDEX);

[$code, $out] = es('PUT', '/' . INDEX, json_encode([
    'settings' => ['number_of_shards' => 1, 'number_of_replicas' => 0],
    'mappings' => ['properties' => [
        'id' => ['type' => 'long'],
        'beatmap_id' => ['type' => 'long'],
        'ruleset_id' => ['type' => 'short'],
        'user_id' => ['type' => 'long'],
        'total_score' => ['type' => 'long'],
        'legacy_total_score' => ['type' => 'long'],
        'pp' => ['type' => 'float'],
        'is_legacy' => ['type' => 'boolean'],
        'convert' => ['type' => 'boolean'],
        'mods' => ['type' => 'keyword'],
        'country_code' => ['type' => 'keyword'],
    ]],
]));
if ($code >= 300) {
    fwrite(STDERR, "no se pudo crear el indice: {$out}\n");
    exit(1);
}

es('POST', '/_aliases', json_encode(['actions' => [
    ['remove' => ['index' => '*', 'alias' => 'scores']],
    ['add' => ['index' => INDEX, 'alias' => 'scores']],
]]));

$db = new PDO('mysql:host=db;dbname=osu;charset=utf8mb4', 'root', '', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

// El beatmap se trae por el join para saber si el score es un convert: un mapa
// de osu! jugado en taiko es el mismo beatmap con otro ruleset.
//
// El WHERE no es opcional. osu-web asume que este indice ya viene filtrado
// (Score::scopeIndexable) y no vuelve a filtrar al leerlo, asi que meter todos
// los scores llena los leaderboards de mapas con plays FALLADAS. Tienen que
// entrar solo las que pasaron, las que se conservan y las que puntuan.
$sql = <<<'SQL'
SELECT s.id, s.beatmap_id, s.ruleset_id, s.user_id, s.total_score, s.pp,
       JSON_EXTRACT(s.data, '$.mods[*].acronym') AS mods,
       b.playmode, u.country_acronym
FROM osu.scores s
JOIN osu.osu_beatmaps b ON b.beatmap_id = s.beatmap_id
JOIN osu.phpbb_users u ON u.user_id = s.user_id
WHERE s.id > ? AND s.passed = 1 AND s.preserve = 1 AND s.ranked = 1
ORDER BY s.id LIMIT
SQL;
$stmt = $db->prepare($sql . ' ' . CHUNK);

$after = 0;
$total = 0;
while (true) {
    $stmt->execute([$after]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (count($rows) === 0) {
        break;
    }

    $bulk = '';
    foreach ($rows as $row) {
        $after = (int) $row['id'];
        $mods = json_decode($row['mods'] ?? '[]', true) ?: [];

        $doc = [
            'id' => (int) $row['id'],
            'beatmap_id' => (int) $row['beatmap_id'],
            'ruleset_id' => (int) $row['ruleset_id'],
            'user_id' => (int) $row['user_id'],
            'total_score' => (int) $row['total_score'],
            'legacy_total_score' => 0,
            'is_legacy' => false,
            'convert' => (int) $row['playmode'] !== (int) $row['ruleset_id'],
            'mods' => $mods,
            'country_code' => $row['country_acronym'],
        ];
        // pp se deja afuera cuando es nulo a proposito: la busqueda filtra por
        // exists, asi que un cero seria un score sin pp que igual aparece.
        if ($row['pp'] !== null) {
            $doc['pp'] = (float) $row['pp'];
        }

        $bulk .= json_encode(['index' => ['_id' => (string) $row['id']]]) . "\n";
        $bulk .= json_encode($doc) . "\n";
    }

    [$code, $out] = es('POST', '/' . INDEX . '/_bulk', $bulk, 'application/x-ndjson');
    if ($code >= 300) {
        fwrite(STDERR, "fallo el bulk: " . substr($out, 0, 400) . "\n");
        exit(1);
    }

    $total += count($rows);
    echo "\rindexados {$total}";
}

es('POST', '/' . INDEX . '/_refresh');
echo "\nlisto: {$total} scores en el indice\n";
