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

                <div class="landing-hero__message-extra-container">
                    <div class="landing-hero__message-extra landing-hero__message-extra--bottom">
                        <a href="{{ route('download') }}" class="btn-osu-big btn-osu-big--download-landing">
                            <span class="btn-osu-big__content">
                                <span class="btn-osu-big__left">
                                    <span class="btn-osu-big__text-top">
                                        {{ osu_trans("home.landing.download") }}
                                    </span>
                                </span>

                                <span class="btn-osu-big__icon">
                                    <span class="fas fa-download"></span>
                                </span>
                            </span>
                        </a>
                    </div>
                </div>
            </div>

            <div class="landing-hero__graph js-landing-graph"></div>

            <script id="json-stats" type="application/json">
                {!! json_encode($stats->graphData) !!}
            </script>
        </div>
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
