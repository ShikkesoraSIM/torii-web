{{--
    Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
    See the LICENCE file in the repository root for full licence text.
--}}
@extends('master')

@section('content')
@component('layout._page_header_v4')
@endcomponent

<div class="osu-page osu-page--generic-compact">
    <div class="download-page">
        <div class="download-page__header">
            <div class="download-page__banner">
                {{-- torii: el video de fondo salia de assets.ppy.sh. Sin url
                     configurada no va el tag, que si no queda una caja negra. --}}
                @if (present($GLOBALS['cfg']['osu']['urls']['download_video']))
                    <video class="download-page__banner-video" src="{{ $GLOBALS['cfg']['osu']['urls']['download_video'] }}" autoplay muted loop playsinline>
                    </video>
                @endif
                <div class="download-page__banner-content download-page__banner-content--main">
                    <div class="download-page__tagline">
                        <span class="download-page__tagline-1">{{ osu_trans('home.download.tagline_1') }}</span>
                        <span class="download-page__tagline-2">{{ osu_trans('home.download.tagline_2') }}</span>
                    </div>
                    <a
                        class="btn-osu-big btn-osu-big--download"
                        href="{{ $lazerUrl }}"
                    >
                        <div class="btn-osu-big__content">
                            <div class="btn-osu-big__left">
                                {{ osu_trans('home.download.download') }}
                                <div>
                                    <div class="btn-osu-big__text-top btn-osu-big__text-top--download">
                                        {{ osu_trans('home.download.client') }}
                                    </div>
                                    {{ osu_trans('home.download.for_os', ['os' => $lazerPlatformName]) }}
                                </div>
                                <div class="btn-osu-big__text-bottom btn-osu-big__text-bottom--download-version">
                                    {{ $version }}
                                </div>
                            </div>
                            <span class="btn-osu-big__icon">
                                <span class="svg-icon svg-icon--download"></span>
                            </span>
                        </div>
                    </a>
                    <div class="download-page__other-platforms">
                        @include('objects._basic_select_options', ['modifiers' => 'download', 'selectOptions' => $selectOptions])
                    </div>
                </div>
            </div>
            {{-- torii: aca iba el bloque de osu!(stable): el boton a
                 m1.ppy.sh, el espejo a m2.ppy.sh y el fallback de macOS a
                 osx.ppy.sh. Torii no tiene cliente stable ni build de macOS
                 legacy, y los tres servian binarios de ppy que no se conectan
                 aca, asi que el bloque entero no va. --}}
        </div>

        <div class="download-page__guide">
            {{-- torii: el iframe de aca era una playlist de youtube de ppy
                 enseñando a instalar osu! vanilla. Solo se dibuja si hay una
                 playlist propia configurada. --}}
            @if (present($playlistId = $GLOBALS['cfg']['osu']['urls']['youtube-tutorial-playlist']))
                <iframe
                    class="download-page__video u-embed-wide"
                    src="https://youtube.com/embed/videoseries?list={{ $playlistId }}"
                ></iframe>
            @endif
            <div class="download-page__guide-content">
                <div class="download-page__steps">
                    <div class="download-page__step">
                        <span class="download-page__step-number">1</span>
                        <div class="download-page__text download-page__text--title">
                            {{ osu_trans("home.download.steps.download.title") }}
                        </div>
                        <div class="download-page__text download-page__text--description">
                            {{ osu_trans("home.download.steps.download.description") }}
                        </div>
                        {!! img2x([
                            'class' => 'download-page__example',
                            'src' => '/images/layout/download-step-1.jpg',
                        ]) !!}
                    </div>
                    <div class="download-page__step">
                        <span class="download-page__step-number">2</span>
                        <div class="download-page__text download-page__text--title">
                            {{ osu_trans('home.download.steps.register.title') }}
                        </div>
                        <div class="download-page__text download-page__text--description">
                            {{ osu_trans('home.download.steps.register.description') }}
                        </div>
                        {!! img2x([
                            'class' => 'download-page__example',
                            'src' => '/images/layout/download-step-2.png',
                        ]) !!}
                    </div>
                    <div class="download-page__step">
                        <span class="download-page__step-number">3</span>
                        <div class="download-page__text download-page__text--title">
                            {{ osu_trans("home.download.steps.beatmaps.title") }}
                        </div>
                        <div class="download-page__text download-page__text--description">
                            {!! osu_trans('home.download.steps.beatmaps.description._', [
                                'browse' => link_to(
                                    route('beatmapsets.index'),
                                    osu_trans('home.download.steps.beatmaps.description.browse')
                                )
                            ]) !!}
                        </div>
                        {!! img2x([
                            'class' => 'download-page__example',
                            'src' => '/images/layout/download-step-3.jpg',
                        ]) !!}
                    </div>
                </div>

                @if ($GLOBALS['cfg']['services']['enchant']['id'] !== null)
                    <div class="download-page__help">
                        {!! osu_trans('home.download.help._', [
                            'support_button' => link_to(
                                '#',
                                osu_trans('home.download.help.support_button'),
                                [
                                    'class' => 'js-enchant--show',
                                    'role' => 'button',
                                ],
                            ),
                            'help_forum_link' => link_to(
                                route('forum.forums.show', ['forum' => $GLOBALS['cfg']['osu']['forum']['help_forum_id']]),
                                osu_trans('home.download.help.help_forum_link')
                            )
                        ]) !!}
                    </div>

                    @include('objects._enchant')
                @endif
            </div>
        </div>
    </div>
</div>
@endsection
