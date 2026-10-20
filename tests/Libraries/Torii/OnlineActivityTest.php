<?php

declare(strict_types=1);

namespace Tests\Libraries\Torii;

use App\Libraries\Torii\OnlineActivity;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use Tests\TestCase;

class OnlineActivityTest extends TestCase
{
    public function testFirstMeasurementReplacesHigherEstimate(): void
    {
        $this->seedDay('2026-10-21', 20);
        $this->assertSame(6, OnlineActivity::record(6, CarbonImmutable::parse('2026-10-21 12:00:00', 'UTC')));
        $day = DB::table(OnlineActivity::TABLE)->where('day', '2026-10-21')->first();
        $this->assertFalse((bool) $day->is_estimated);
        $this->assertSame(1, (int) $day->samples);
    }

    public function testObservedPeakDoesNotDecrease(): void
    {
        $at = CarbonImmutable::parse('2026-10-21 12:00:00', 'UTC');
        OnlineActivity::record(6, $at);
        OnlineActivity::record(19, $at->addMinute());
        $this->assertSame(19, OnlineActivity::record(15, $at->addMinutes(2)));
        $day = DB::table(OnlineActivity::TABLE)->first();
        $this->assertSame(3, (int) $day->samples);
        $this->assertSame('2026-10-21 12:00:00', $day->first_sample_at);
        $this->assertSame('2026-10-21 12:02:00', $day->last_sample_at);
    }

    public function testRealZeroIsNotMissingOrEstimated(): void
    {
        $at = CarbonImmutable::parse('2026-10-21', 'UTC');
        $this->seedDay($at->toDateString(), 20);
        OnlineActivity::record(0, $at);
        $this->assertSame(['online' => 0, 'estimated' => false], OnlineActivity::dailyPeaks($at, $at)['2026-10-21']);
    }

    public function testDatesUseUtc(): void
    {
        OnlineActivity::record(17, CarbonImmutable::parse('2026-10-22 00:01:00', 'Asia/Singapore'));
        $this->assertSame('2026-10-21', DB::table(OnlineActivity::TABLE)->value('day'));
    }

    public function testTenRecordedDaysReplaceTheBootstrapWindow(): void
    {
        $start = CarbonImmutable::parse('2026-10-21', 'UTC');
        for ($index = 0; $index < 10; $index++) {
            $this->seedDay($start->subDays(9 - $index)->toDateString(), 20);
        }
        for ($index = 0; $index < 10; $index++) {
            OnlineActivity::record(17 + $index % 4, $start->addDays($index));
        }
        $history = OnlineActivity::dailyPeaks($start, $start->addDays(9));
        $this->assertCount(10, $history);
        foreach ($history as $day) {
            $this->assertFalse($day['estimated']);
        }
        $before = DB::table(OnlineActivity::TABLE)->count();
        $this->assertSame([], OnlineActivity::dailyPeaks($start->addDays(30), $start->addDays(39)));
        $this->assertSame($before, DB::table(OnlineActivity::TABLE)->count());
    }

    public function testRealPeaksAreNotCappedAtTheBootstrapMaximum(): void
    {
        $this->assertSame(32, OnlineActivity::record(32, CarbonImmutable::parse('2026-10-21', 'UTC')));
    }

    public function testOutOfOrderSamplesKeepTheirTimeRange(): void
    {
        $at = CarbonImmutable::parse('2026-10-21 12:00:00', 'UTC');
        OnlineActivity::record(20, $at->addHour());
        OnlineActivity::record(17, $at);
        $day = DB::table(OnlineActivity::TABLE)->first();
        $this->assertSame(20, (int) $day->peak_online);
        $this->assertSame('2026-10-21 12:00:00', $day->first_sample_at);
        $this->assertSame('2026-10-21 13:00:00', $day->last_sample_at);
    }

    public function testNegativeCountsAreRejected(): void
    {
        $this->expectException(InvalidArgumentException::class);
        OnlineActivity::record(-1);
    }

    protected function setUp(): void
    {
        parent::setUp();
        DB::table(OnlineActivity::TABLE)->delete();
    }

    private function seedDay(string $day, int $online): void
    {
        DB::table(OnlineActivity::TABLE)->insert([
            'day' => $day,
            'peak_online' => $online,
            'is_estimated' => true,
            'samples' => 0,
        ]);
    }
}
