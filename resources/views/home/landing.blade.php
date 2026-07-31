{{--
    Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
    See the LICENCE file in the repository root for full licence text.
--}}
@php
    $currentLocaleMeta = current_locale_meta();
    $navLinks = nav_links();
@endphp

@extends('master', [
    'titleOverride' => osu_trans('home.landing.title'),
    'blank' => 'true',
    'bodyAdditionalClasses' => 'osu-layout--body-landing'
])

@section('content')
    <nav class="osu-page">
        <!-- Mobile Navigation -->
        @include('layout._header_mobile')

        <!-- Desktop Navigation -->
        <div class="landing-nav hidden-xs">
            <div class="landing-nav__section">
                @foreach ($navLinks as $section => $links)
                    <a
                        href="{{ array_first($links) }}"
                        class="landing-nav__link {{ ($section == "home") ? "landing-nav__link--bold" : "" }}"
                    >
                        {{ osu_trans("layout.menu.$section._") }}
                    </a>
                @endforeach

                {!! app('layout-cache')->getLocalesLanding() !!}
            </div>

            <div class="landing-nav__section">
                <a
                    href="#"
                    class="landing-nav__link js-nav-toggle js-click-menu js-user-login--menu"
                    data-click-menu-target="nav2-login-box"
                >
                    {{ osu_trans("users.login._") }}
                </a>
            </div>
        </div>

    </nav>

    <div class="js-nav-data" id="nav-data-landing" data-turbo-permanent></div>
    @include('layout._popup_login', ['modifiers' => ['landing']])

    <div class="osu-page">
        <div class="landing-hero">
            <div class="landing-hero__bg-container">
                {{--
                    playsinline is for iphone autoplay
                    reference: https://webkit.org/blog/6784/new-video-policies-for-ios/
                --}}
                {{-- torii: aca iba un video de osu! alojado en assets.ppy.sh.
                     No es nuestro y ademas daba una caja negra vacia. El fondo
                     lo pone landing-hero__bg-container por css. --}}
                @if (present($GLOBALS['cfg']['osu']['landing']['video_url']))
                    <video
                        class="landing-hero__bg"
                        autoplay
                        loop
                        muted
                        playsinline
                        src="{{ $GLOBALS['cfg']['osu']['landing']['video_url'] }}"
                    ></video>
                @endif
            </div>

            {{-- torii: aca iba Pippi, la mascota de osu!. El logo grande de la
                 marca ya se dibuja mas abajo en landing-hero__logo. --}}

            <div class="landing-hero__info">
                {{-- torii: numeros reales del servidor. El de partidas en
                     curso no existe aca y se cambio por las plays, que es lo
                     que de verdad dice si el lugar esta vivo. --}}
                {!! osu_trans("home.landing.players", ['count' => i18n_number_format($stats->totalUsers)]) !!},
                {!! osu_trans("home.landing.online", ['players' => i18n_number_format($stats->currentOnline)]) !!},
                {!! osu_trans("home.landing.plays", ['count' => i18n_number_format($stats->totalPlays)]) !!}
            </div>

            <div class="landing-hero__messages">
                <div class="landing-hero__message-extra-container">
                    <div class="landing-hero__message-extra landing-hero__message-extra--top">
                        <div class="landing-hero__logo"></div>
                    </div>
                </div>

                <div class="landing-hero__slogan">
                    <h1 class="landing-hero__slogan-main">
                        {{ osu_trans('home.landing.slogan.main') }}
                    </h1>

                    <h2 class="landing-hero__slogan-sub">
                        {{ osu_trans('home.landing.slogan.sub') }}
                    </h2>
                </div>

                {{-- torii: aca iba el boton que mandaba a /download. Las
                     descargas ahora estan en esta misma pagina, apenas mas
                     abajo, asi que el boton era un rodeo. --}}
            </div>

            <div class="landing-hero__graph js-landing-graph"></div>

            <script id="json-stats" type="application/json">
                {!! json_encode($stats->graphData) !!}
            </script>
        </div>
    </div>

    {{-- torii: descargar y las diferencias del servidor, en la portada misma.
         El que llega sin cuenta viene a decidir si vale la pena bajarlo: eso
         se responde aca, no una pagina mas adelante. --}}
    <div class="osu-page">
        <section class="landing-start" id="start">
            <div class="landing-start__header">
                <h2 class="landing-start__title">{{ osu_trans('home.landing.start.title') }}</h2>
                <p class="landing-start__lead">{{ osu_trans('home.landing.start.lead') }}</p>
            </div>

            @if (count($toriiStreams) > 0)
                <div class="landing-start__list">
                    @foreach ($toriiStreams as $stream)
                        <div class="landing-start__item landing-start__item--{{ $stream['id'] }}">
                            <div class="landing-start__name">{{ $stream['nombre'] }}</div>
                            @if (present($stream['version']))
                                <div class="landing-start__version">
                                    {{ osu_trans('home.download.torii_streams.version', ['version' => $stream['version']]) }}
                                </div>
                            @endif
                            <p class="landing-start__detail">{{ $stream['detalle'] }}</p>
                            <div class="landing-start__actions">
                                <a class="btn-osu-big btn-osu-big--rounded-thin" href="{{ $stream['url'] }}">
                                    <div class="btn-osu-big__content">
                                        <div class="btn-osu-big__left">
                                            {{ osu_trans('home.download.download') }}
                                        </div>
                                        <span class="btn-osu-big__icon">
                                            <span class="svg-icon svg-icon--download"></span>
                                        </span>
                                    </div>
                                </a>
                                @if (present($stream['notas']))
                                    <a class="landing-start__link" href="{{ $stream['notas'] }}" rel="nofollow noreferrer">
                                        {{ osu_trans('home.download.torii_streams.changelog') }}
                                    </a>
                                @endif
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif

            {{-- Los archivos que ofrecen las tarjetas son los de la plataforma
                 que detectamos. Al que entra desde otra maquina hay que dejarle
                 la salida a la lista completa. --}}
            <p class="landing-start__note">
                @if (present($toriiPlatformName))
                    <span>{{ osu_trans('home.landing.start.detected', ['platform' => $toriiPlatformName]) }}</span>
                @endif
                {{-- El span envuelve la frase entera a proposito: el contenedor
                     es flex y sin el, el enlace de adentro la partiria en tres
                     items y el gap le abriria huecos en el medio. --}}
                <span>
                    {!! osu_trans('home.landing.start.other_platforms', [
                        'link' => link_to(route('download'), osu_trans('home.landing.start.other_platforms_link')),
                    ]) !!}
                </span>
            </p>
        </section>

        <section class="landing-features">
            <h2 class="landing-features__title">{{ osu_trans('home.landing.features.title') }}</h2>

            <div class="landing-features__list">
                @foreach (['pp', 'mods', 'custom', 'relax'] as $feature)
                    <div class="landing-features__item">
                        <div class="landing-features__name">{{ osu_trans("home.landing.features.{$feature}.title") }}</div>
                        <p class="landing-features__detail">{{ osu_trans("home.landing.features.{$feature}.description") }}</p>
                    </div>
                @endforeach
            </div>
        </section>
    </div>

    {{-- torii: sin noticias el componente no dibuja nada pero el contenedor
         se queda igual, y en la portada eso es una franja negra en el medio.
         Mientras no haya noticias, no va el bloque. --}}
    @if (count($news) > 0)
        <div class="osu-page js-react" data-react="landing-news">
        </div>
    @endif

    <footer class="osu-layout__section osu-layout__section--landing-footer">
        <div class="osu-page">
            <div class="landing-sitemap">
                @foreach (footer_landing_links() as $section => $links)
                    <ul class="landing-sitemap__list">
                        <li class="landing-sitemap__item">
                            <div class="landing-sitemap__header">{{ osu_trans("layout.footer.$section._") }}</div>
                        </li>
                        @foreach ($links as $action => $link)
                            <li class="landing-sitemap__item"><a href="{{ $link }}" class="landing-sitemap__link">{{ osu_trans("layout.footer.$section.$action") }}</a></li>
                        @endforeach
                    </ul>
                @endforeach
            </div>
        </div>

        <div class="landing-footer-social">
            <a href="{{ route('support-the-game') }}" class="landing-footer-social__icon landing-footer-social__icon--support">
                <span class="fas fa-heart"></span>
            </a>
            {{-- torii: upstream manda a /wiki/Twitter, que aca da 404. Torii
                 vive en discord, no en twitter. --}}
            <a href="{{ osu_url('social.discord') }}" class="landing-footer-social__icon">
                <span class="fab fa-discord"></span>
            </a>
        </div>

        @include('layout.footer', ['modifiers' => ['landing'], 'withLinks' => false])
    </footer>
@endsection

@section ("script")
    @parent

    <script id="json-posts" type="application/json">
        {!! json_encode($news) !!}
    </script>

    {{-- torii: los datos estructurados decian que esta pagina es osu!, con la
         url de ppy, su logo, su fecha de lanzamiento y su repositorio. Es lo
         que se lleva un buscador o el preview de un link, asi que decia la
         marca equivocada en todos lados. --}}
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "VideoGame",
      "name": "Torii",
      "url": "{{ config('app.url') }}",
      "description": "{{ osu_trans('home.landing.slogan.main') }}",
      "author": {
        "@type": "Organization",
        "name": "Shikkesora"
      },
      "publisher": {
        "@type": "Organization",
        "name": "Shikkesora"
      },
      "applicationCategory": "Game",
      "gamePlatform": ["Windows", "macOS", "Linux", "Android", "iOS"],
      "playMode": ["SinglePlayer", "MultiPlayer"],
      "genre": "Rhythm",
      "inLanguage": ["en"],
      "isBasedOn": {
        "@type": "VideoGame",
        "name": "osu!",
        "url": "https://osu.ppy.sh/"
      }
    }
    </script>
@endsection
