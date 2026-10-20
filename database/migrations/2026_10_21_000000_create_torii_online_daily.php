<?php

declare(strict_types=1);

use Carbon\CarbonImmutable;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $peaks = json_decode(file_get_contents(resource_path('data/torii-online-bootstrap.json')), true, 512, JSON_THROW_ON_ERROR);
        $start = CarbonImmutable::today('UTC')->subDays(count($peaks) - 1);
        $rows = [];
        foreach ($peaks as $index => $peak) {
            $rows[] = [
                'day' => $start->addDays($index)->toDateString(),
                'peak_online' => $peak,
                'is_estimated' => true,
                'samples' => 0,
            ];
        }

        Schema::create('torii_online_daily', function (Blueprint $table) {
            $table->date('day')->primary();
            $table->unsignedInteger('peak_online');
            $table->boolean('is_estimated')->default(false);
            $table->unsignedInteger('samples')->default(0);
            $table->dateTime('first_sample_at')->nullable();
            $table->dateTime('last_sample_at')->nullable();
        });

        // una sola vez. no rellenar fechas nuevas si el sampler se cae.
        DB::table('torii_online_daily')->insert($rows);
    }

    public function down(): void
    {
        Schema::dropIfExists('torii_online_daily');
    }
};
