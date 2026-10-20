# Online history

Prepared locally. These steps have not been run in production.

The new `osu.torii_online_daily` table stores one online peak per UTC date.
It does not touch g0v0's tables, scores, PP or the live online counter.

The migration creates a one-time ten-day bootstrap using
`resources/data/torii-online-bootstrap.json`. These are estimates, usually
17-20 with a maximum of 26, not recovered historical measurements. The public
chart has no sample-data label, as requested; the DB and graph payload retain
`is_estimated` / `online_estimated` so estimates remain distinguishable.

The first measurement on a date replaces its estimate even if lower. Following
measurements can only raise that day's peak. Real peaks above 26 are allowed.
New dates are not bootstrapped again; old estimates leave the rolling ten-day
window. A sampler outage therefore creates missing data, not more estimates.

## Enable After Approval

Production disables the general migrator because legacy tables are views.
Run ONLY the new migration path, never the full pending migration queue:

```sh
docker compose -f compose.yaml -f deploy/prod/compose.prod.yml exec -T php php artisan migrate --path=database/migrations/2026_10_21_000000_create_torii_online_daily.php --force
docker compose -f compose.yaml -f deploy/prod/compose.prod.yml exec -T php php artisan torii:sample-online
docker compose -f compose.yaml -f deploy/prod/compose.prod.yml --profile online-history up -d --no-deps torii-online-sampler
```

The `online-history` profile is off by default. The sampler uses the existing
PHP image and current `torii_is_online` view, once per minute, independent of
page traffic. It does not enable the unrelated upstream scheduled commands.
Each sample performs one count plus a short transaction on its own daily row.
Concurrent updates are row-locked and deadlocks retried. No score rows are locked.
Container limits are 256 MiB and 0.25 CPU. The home caches stats for five minutes,
so a new measured peak can take that long to show up publicly.

Check logs and `torii_online_daily.samples`, `is_estimated` and `last_sample_at`
after enabling. A sampled peak is the highest observed minute, not an exact
continuous-connection maximum. The first real day is only partially sampled.
After ten daily windows with the sampler running, the visible window is fully
measured. If a day has no measurements, keep it missing.

To stop collecting, stop only `torii-online-sampler`; retain the daily records.
The source reader handles a missing history table without failing the home.
