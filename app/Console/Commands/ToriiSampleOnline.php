<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Libraries\Torii\OnlineActivity;
use App\Models\User;
use Illuminate\Console\Command;

class ToriiSampleOnline extends Command
{
    protected $description = 'Record the daily Torii online peak.';

    protected $signature = 'torii:sample-online {--watch : Sample every minute}';

    public function handle(): int
    {
        do {
            $online = User::default()->where('torii_is_online', 1)->count();
            $peak = OnlineActivity::record($online);
            $this->line("online={$online} peak={$peak}");

            if (!$this->option('watch')) {
                break;
            }
            sleep(60);
        } while (true);

        return static::SUCCESS;
    }
}
