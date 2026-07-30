<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

declare(strict_types=1);

namespace App\Models;

use App\Exceptions\InvariantException;
use App\Jobs\EsDocument;
use App\Jobs\Notifications\TeamApplicationAccept;
use App\Libraries\BBCodeForDB;
use App\Libraries\Elasticsearch\Indexable;
use App\Libraries\Transactions\AfterCommit;
use App\Libraries\Uploader;
use App\Libraries\User\Cover as UserCover;
use App\Libraries\UsernameValidation;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Team extends Model implements AfterCommit, Indexable, Traits\ReportableInterface
{
    use Traits\Es\TeamSearch, Traits\Reportable;

    const FLAG_MAX_DIMENSIONS = [512, 256];

    const MAX_FIELD_LENGTHS = [
        'description' => 64000,
        'name' => 40,
        'short_name' => 4,
        'url' => 255,
    ];

    protected $casts = ['is_open' => 'bool'];

    private Uploader $header;
    private Uploader $flag;

    private static function sanitiseName(?string $value): ?string
    {
        return presence(preg_replace('/  +/', ' ', trim($value ?? '')));
    }

    public function applications(): HasMany
    {
        return $this->hasMany(TeamApplication::class);
    }

    // torii: los equipos de Torii no tienen canal de chat y esta relacion
    // devuelve nulo siempre. La vista teams expone channel_id = 0 fijo porque
    // torii.teams no tiene donde guardarlo, asi que un canal creado desde aca
    // quedaria huerfano: se crea, se le mete gente, y al recargar el equipo
    // nadie sabe cual era. Por eso no se crea ninguno y los lugares que lo
    // usaban (dar de alta un miembro, sacarlo, borrar el equipo) trabajan sin
    // canal, que era el "Call to a member function removeUser() on null".
    //
    // La relacion queda porque el dia que g0v0 tenga la columna alcanza con
    // volver a enganchar el alta.
    public function channel(): BelongsTo
    {
        return $this->belongsTo(Chat\Channel::class, 'channel_id');
    }

    public function leader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'leader_id');
    }

    public function members(): HasMany
    {
        return $this->hasMany(TeamMember::class);
    }

    public function statistics(): HasMany
    {
        return $this->hasMany(TeamStatistics::class);
    }

    public function setDefaultRulesetIdAttribute(?int $value): void
    {
        $this->attributes['default_ruleset_id'] = Beatmap::MODES[Beatmap::modeStr($value) ?? 'osu'];
    }

    public function setDescriptionAttribute(?string $value): void
    {
        $this->attributes['description'] = app('chat-filters')->filter($value);
    }

    public function setFlagAttribute(?string $value): void
    {
        if ($value !== null) {
            $this->flag()->set($value);
        }
    }

    public function setHeaderAttribute(?string $value): void
    {
        if ($value !== null) {
            $this->header()->set($value);
        }
    }

    public function setNameAttribute(?string $value): void
    {
        $this->attributes['name'] = static::sanitiseName($value);
    }

    public function setShortNameAttribute(?string $value): void
    {
        $this->attributes['short_name'] = static::sanitiseName($value);
    }

    public function setUrlAttribute(?string $value): void
    {
        $this->attributes['url'] = $value === null
            ? null
            : (is_http($value)
                ? $value
                : "https://{$value}"
            );
    }

    public function addMember(TeamApplication $application): void
    {
        $this->getConnection()->transaction(function () use ($application) {
            $application->delete();
            $this->members()->create(['user_id' => $application->getKey()]);
        });

        (new TeamApplicationAccept($application, $this->leader))->dispatch();
    }

    public function afterCommit(): void
    {
        dispatch(new EsDocument($this));
    }

    public function delete()
    {
        $this->header()->delete();
        $this->flag()->delete();

        return $this->getConnection()->transaction(function () {
            // torii: los miembros y las solicitudes van ANTES que el equipo.
            // torii.team_members tiene una foreign key contra torii.teams y
            // MySQL rechaza el borrado mientras queden filas apuntando; upstream
            // los borra despues porque en su esquema esa foreign key no existe.
            // Va todo en la misma transaccion, asi que si el borrado del equipo
            // falla no queda un equipo vacio.
            $this->applications()->delete();
            $this->members()->delete();
            $this->statistics()->delete();

            return parent::delete();
        });
    }

    public function descriptionHtml(): string
    {
        $description = presence($this->description);

        return $description === null
            ? ''
            : bbcode((new BBCodeForDB($description))->generate());
    }

    public function emptySlots(): int
    {
        $max = $this->maxMembers();
        $current = $this->members->count();

        return $max - $current;
    }

    public function extraStatistics($rulesetId): array
    {
        return \Cache::remember(
            "team:{$this->getKey()}:extraStatistics:{$rulesetId}",
            $GLOBALS['cfg']['osu']['team']['extra_statistics_cache_duration'],
            fn () => $this->slowExtraStatistics($rulesetId),
        );
    }

    public function flag(): Uploader
    {
        return $this->flag ??= new Uploader(
            'teams/flag',
            $this,
            'flag_file',
            ['image' => [
                'maxDimensions' => static::FLAG_MAX_DIMENSIONS,
                'maxFilesize' => 200_000,
            ]],
        );
    }

    public function header(): Uploader
    {
        return $this->header ??= new Uploader(
            'teams/header',
            $this,
            'header_file',
            ['image' => [
                'maxDimensions' => UserCover::CUSTOM_COVER_MAX_DIMENSIONS,
                'maxFilesize' => UserCover::CUSTOM_COVER_MAX_FILESIZE,
            ]],
        );
    }

    public function isValid(): bool
    {
        $this->validationErrors()->reset();

        $wordFilters = app('chat-filters');
        foreach (['name', 'short_name'] as $field) {
            $value = $this->$field;
            if ($value === null) {
                $this->validationErrors()->add($field, 'required');
            } elseif ($this->isDirty($field)) {
                // printable ascii characters
                if (!preg_match('/^[ -~]+$/', $value)) {
                    $this->validationErrors()->add($field, '.invalid_characters');
                } elseif (!$wordFilters->isClean($value) || !UsernameValidation::allowedName($value)) {
                    $this->validationErrors()->add($field, '.word_not_allowed');
                } elseif (static::whereNot('id', $this->getKey())->where($field, $value)->exists()) {
                    $this->validationErrors()->add($field, '.used');
                }
            }
        }

        $this->validateDbFieldLengths();

        if ($this->isDirty('url')) {
            $url = $this->url;
            if ($url !== null && !is_http($url)) {
                $this->validationErrors()->add('url', 'url');
            }
        }

        if ($this->isDirty('ruleset_id')) {
            if (Beatmap::modeStr($this->ruleset_id) === null) {
                $this->validationErrors()->add('ruleset_id', '.unknown_ruleset_id');
            }
        }

        return $this->validationErrors()->isEmpty();
    }

    public function leaderOrDeleted(): User
    {
        $leader = $this->leader;

        return $leader === null || $leader->isRestricted()
            ? new DeletedUser(['user_id' => $this->leader_id])
            : $leader;
    }

    public function maxMembers(): int
    {
        $this->loadMissing('members.user');

        $supporterCount = $this->members->filter(fn ($member) => $member->user?->isSupporter() ?? false)->count();

        return min(8 + (4 * $supporterCount), $GLOBALS['cfg']['osu']['team']['max_members']);
    }

    public function removeMember(TeamMember $member): void
    {
        if ($member->user_id === $this->leader_id) {
            throw new InvariantException('can not remove leader from the team');
        }

        $member->delete();
    }

    public function save(array $options = [])
    {
        if (!$this->isValid()) {
            return false;
        }

        if (!$this->exists) {
            return $this->getConnection()->transaction(function () use ($options) {
                $this->channel_id ??= 0;
                $this->default_ruleset_id ??= $this->leader->osu_playmode;
                $saved = parent::save($options);

                if ($saved) {
                    $this->members()->create(['user_id' => $this->leader_id]);

                    $this->flag()->updateFile();
                    $this->header()->updateFile();
                }

                return parent::save($options);
            });
        }

        $this->flag()->updateFile();
        $this->header()->updateFile();

        return parent::save($options);
    }

    public function slowExtraStatistics(int $rulesetId): array
    {
        $userIds = $this
            ->members()
            ->whereHas('user', fn ($q) => $q->default())
            ->pluck('user_id');

        $userStats = UserStatistics\Model::getClass(Beatmap::modeStr($rulesetId))
            ::whereIn('user_id', $userIds)
            ->selectRaw('
                SUM(x_rank_count) x_rank_count,
                SUM(xh_rank_count) xh_rank_count,
                SUM(s_rank_count) s_rank_count,
                SUM(sh_rank_count) sh_rank_count,
                SUM(a_rank_count) a_rank_count,
                SUM(total_seconds_played) total_seconds_played
            ')->first()?->getAttributes();

        static $userStatsKeys = [
            'x_rank_count',
            'xh_rank_count',
            's_rank_count',
            'sh_rank_count',
            'a_rank_count',
            'total_seconds_played',
        ];

        $ret = [];
        foreach ($userStatsKeys as $key) {
            $ret[$key] = intval($userStats[$key] ?? 0);
        }

        $ret['first_places'] = BeatmapLeader::whereIn('user_id', $userIds)->where('ruleset_id', $rulesetId)->count();

        $ret['ranked_beatmapsets'] = Beatmapset::whereIn('user_id', $userIds)->ranked()->count();
        $ret['kudosu_total'] = intval(User::whereIn('user_id', $userIds)->sum('osu_kudostotal') ?? 0);

        return $ret;
    }

    public function trashed(): bool
    {
        return false;
    }

    public function url(): string
    {
        return route('teams.show', ['team' => $this->getKey()]);
    }

    public function validationErrorsTranslationPrefix(): string
    {
        return 'team';
    }

    protected function newReportableExtraParams(): array
    {
        return [
            'reason' => 'UnwantedContent',
            'user_id' => $this->leader_id,
        ];
    }
}
