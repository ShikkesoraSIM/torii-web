<?php

// torii: arma el indice `scores` de elasticsearch a partir de la tabla scores.
//
// Por que hace falta un script y no el indexador oficial: osu-elastic-indexer
// corre `queue watch`, o sea que indexa los scores que alguien le ENCOLA. El que
// encola en osu! upstream es osu-web al recibir el score, pero aca los scores no
// entran por osu-web: los recibe g0v0. O sea que no hay productor de esa cola y
// el indexador se quedaria esperando para siempre.
//
// Y no es que quede vacio y se note: el alias `scores` apuntando a un indice sin
// documentos hace que la web MIENTA. Todos los leaderboards de mapas vacios,
// todos los Best Performance vacios, y cada score diciendo que es #1 del mundo,
// porque el rank se calcula como "1 + cuantos te ganan" y sobre cero eso da 1.
//
// El documento sale de leer que campos consulta ScoreSearch::getQuery(): id,
// beatmap_id, ruleset_id, user_id, total_score, legacy_total_score, pp,
// is_legacy, mods, convert y country_code. Nada mas.
//
// Uso:
//   php torii-index-scores.php              incremental: solo los scores nuevos
//   php torii-index-scores.php --full       reconstruye de cero
//   php torii-index-scores.php --watch      se queda mirando (cada 3 segundos)
//   php torii-index-scores.php --watch=10   idem, cada 10
//
// El incremental arranca del id mas alto que ya esta indexado, asi que corre en
// segundos aunque haya doscientos mil scores.
//
// --watch existe porque por cron el atraso era el periodo del cron: con la
// corrida cada cinco minutos, meter una play y verla en el leaderboard o en tu
// Best Performance tardaba hasta cinco minutos. Y no hay nada que optimizar
// para llegar a eso: una pasada sin scores nuevos son dos consultas. Asi que en
// vez de afinar el cron, se queda prendido.
//
// Vuelve a resolver el alias en cada pasada a proposito: si mientras esta vivo
// corre un --full, el alias termina en un indice nuevo y el que mira tiene que
// seguirlo, no seguir escribiendo en el viejo que despues se borra.

const ES = 'http://elasticsearch:9200';
const ALIAS = 'scores';
const PREFIX = 'scores_torii';
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

function esJson(string $method, string $path, ?string $body = null): array
{
    [$code, $out] = es($method, $path, $body);

    return [$code, json_decode($out ?: 'null', true)];
}

const MAPPING = [
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
];

/**
 * A que indice apunta el alias hoy, si apunta a alguno.
 */
function currentIndex(): ?string
{
    [$code, $body] = esJson('GET', '/_alias/' . ALIAS);

    if ($code >= 300 || !is_array($body)) {
        return null;
    }

    return array_key_first($body);
}

/**
 * El id mas alto que ya esta indexado. De ahi arranca el incremental.
 */
function maxIndexedId(string $index): int
{
    [$code, $body] = esJson('POST', "/{$index}/_search", json_encode([
        'size' => 0,
        'aggs' => ['max_id' => ['max' => ['field' => 'id']]],
    ]));

    if ($code >= 300) {
        return 0;
    }

    return (int) ($body['aggregations']['max_id']['value'] ?? 0);
}

// -------------------------------------------------------------------- base --

// Los datos de conexion salen del entorno y no hardcodeados: en la maquina local
// el mysql es el del compose y en prod es el de g0v0, con otro host, otro usuario
// y contrasena. Antes decia host=db con root sin contrasena, o sea que en prod
// fallaba con "connection refused" a mitad del deploy.
$host = getenv('DB_HOST') ?: 'db';
$name = getenv('DB_DATABASE') ?: 'osu';
$user = getenv('DB_USERNAME') ?: 'root';
$pass = getenv('DB_PASSWORD') ?: '';

$db = new PDO("mysql:host={$host};dbname={$name};charset=utf8mb4", $user, $pass, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

// ------------------------------------------------------------------ modo ----

$full = in_array('--full', $argv, true);

$watch = 0;
foreach ($argv as $arg) {
    if ($arg === '--watch') {
        $watch = 3;
    } elseif (str_starts_with($arg, '--watch=')) {
        $watch = max(1, (int) substr($arg, 8));
    }
}

if ($full && $watch > 0) {
    fwrite(STDERR, "--full y --watch no van juntos: el que mira sigue el alias que deje el full\n");
    exit(1);
}

$live = currentIndex();

if ($live === null) {
    // Sin alias no hay nada que actualizar: la primera corrida es completa.
    if ($watch > 0) {
        fwrite(STDERR, "todavia no hay indice: corre una vez con --full antes de mirar\n");
        exit(1);
    }
    $full = true;
}

if ($full) {
    // Se construye en un indice NUEVO y el alias se mueve al final, en una sola
    // operacion atomica. Antes esto hacia DELETE del indice y lo rellenaba, o
    // sea que durante todo el rebuild los leaderboards del sitio se veian
    // vacios. En prod eso se nota.
    $index = PREFIX . '_' . date('YmdHis');
    $after = 0;

    [$code, $out] = es('PUT', '/' . $index, json_encode(MAPPING));
    if ($code >= 300) {
        fwrite(STDERR, "no se pudo crear {$index}: {$out}\n");
        exit(1);
    }

    echo "reconstruyendo en {$index}\n";
} else {
    $index = $live;
    $after = maxIndexedId($index);
    echo "incremental sobre {$index}, desde el id {$after}\n";
}

// ----------------------------------------------------------------- scores ---

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

// Una pasada: mete en $index todo lo que tenga id mayor a $after y devuelve
// cuantos entraron. Se llama una vez sola en el modo normal, y en bucle cuando
// se queda mirando.
$pasada = function (string $index, int $after, bool $callado) use ($stmt): int {
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

    [$code, $out] = es('POST', '/' . $index . '/_bulk', $bulk, 'application/x-ndjson');
    if ($code >= 300) {
        fwrite(STDERR, "fallo el bulk: " . substr((string) $out, 0, 400) . "\n");
        exit(1);
    }

    $total += count($rows);
    if (!$callado) {
        echo "\rindexados {$total}";
    }
}

if ($total > 0) {
    es('POST', '/' . $index . '/_refresh');
}

return $total;
};

// ------------------------------------------------------------------ bucle ---

if ($watch > 0) {
    // Que un docker compose down / restart lo baje en el acto y no a los diez
    // segundos por SIGKILL.
    if (function_exists('pcntl_async_signals')) {
        pcntl_async_signals(true);
        foreach ([SIGTERM, SIGINT] as $sig) {
            pcntl_signal($sig, function () { echo "\nchau\n"; exit(0); });
        }
    }

    echo "mirando cada {$watch}s (alias " . ALIAS . ")\n";

    while (true) {
        // El alias se resuelve de nuevo en cada vuelta: un --full lo mueve a un
        // indice nuevo y hay que seguirlo.
        $activo = currentIndex();

        if ($activo === null) {
            fwrite(STDERR, date('H:i:s') . " el alias " . ALIAS . " no existe, esperando\n");
        } else {
            $n = $pasada($activo, maxIndexedId($activo), true);
            if ($n > 0) {
                echo date('H:i:s') . " +{$n}\n";
            }
        }

        sleep($watch);
    }
}

$total = $pasada($index, $after, false);

// ------------------------------------------------------------------ alias ---

if ($full) {
    // remove sobre '*' saca el alias de cualquier indice que lo tuviera,
    // incluido el scores_1 vacio que crea osu-elastic-indexer si se lo dejan
    // arrancar. Todo junto para que no haya un instante sin alias.
    [$code, $out] = es('POST', '/_aliases', json_encode(['actions' => [
        ['remove' => ['index' => '*', 'alias' => ALIAS]],
        ['add' => ['index' => $index, 'alias' => ALIAS]],
    ]]));
    if ($code >= 300) {
        fwrite(STDERR, "no se pudo mover el alias: {$out}\n");
        exit(1);
    }

    // Los indices viejos con el prefijo se van; el que acaba de quedar activo no.
    [, $indices] = esJson('GET', '/' . PREFIX . '*');
    foreach (array_keys($indices ?: []) as $old) {
        if ($old !== $index) {
            es('DELETE', '/' . $old);
            echo "\nborrado el viejo {$old}";
        }
    }
}

[, $count] = esJson('GET', '/' . ALIAS . '/_count');
echo "\nlisto: {$total} scores nuevos, " . ($count['count'] ?? '?') . " en el indice\n";
