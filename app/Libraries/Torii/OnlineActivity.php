<?php

declare(strict_types=1);

namespace App\Libraries\Torii;

use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use InvalidArgumentException;

class OnlineActivity
{
    public const TABLE = 'torii_online_daily';

    public static function dailyPeaks(CarbonInterface $start, CarbonInterface $end): array
    {
        if (!Schema::hasTable(static::TABLE)) {
            return [];
        }

        return DB::table(static::TABLE)
            ->whereBetween('day', [$start->toDateString(), $end->toDateString()])
            ->get(['day', 'peak_online', 'is_estimated'])
            ->mapWithKeys(fn ($row) => [$row->day => [
                'online' => (int) $row->peak_online,
                'estimated' => (bool) $row->is_estimated,
            ]])->all();
    }

    public static function record(int $online, ?CarbonInterface $observedAt = null): int
    {
        if ($online < 0) {
            throw new InvalidArgumentException('Online count cannot be negative.');
        }

        $at = CarbonImmutable::instance($observedAt ?? CarbonImmutable::now('UTC'))->utc();
        $day = $at->toDateString();
        $timestamp = $at->toDateTimeString();

        return DB::transaction(function () use ($online, $day, $timestamp) {
            DB::table(static::TABLE)->insertOrIgnore([
                'day' => $day,
                'peak_online' => $online,
                'is_estimated' => false,
                'samples' => 0,
            ]);

            $row = DB::table(static::TABLE)->where('day', $day)->lockForUpdate()->first();
            // la primera medicion reemplaza el relleno, aunque de menos.
            $peak = $row->is_estimated ? $online : max((int) $row->peak_online, $online);
            DB::table(static::TABLE)->where('day', $day)->update([
                'peak_online' => $peak,
                'is_estimated' => false,
                'samples' => (int) $row->samples + 1,
                'first_sample_at' => $row->first_sample_at === null ? $timestamp : min($row->first_sample_at, $timestamp),
                'last_sample_at' => $row->last_sample_at === null ? $timestamp : max($row->last_sample_at, $timestamp),
            ]);

            return $peak;
        }, 3);
    }
}
