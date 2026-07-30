{{--
    Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
    See the LICENCE file in the repository root for full licence text.
--}}
{{-- torii: aca vivia la pagina de TestFlight de osu!, con el link privado para
     osu!supporters y el limite de testers de la cuenta de Apple de ellos. Torii
     no tiene ni TestFlight ni .ipa publicado, pero el selector de plataformas
     de /home/download manda a los de iOS a esta url, asi que la pagina tiene
     que decir la verdad en vez de ofrecer una beta que no es nuestra.
     El titulo de la ruta sigue siendo "testflight" y vive en page_title.php,
     de ahi el titleOverride y el showTitle en false. --}}
@extends('master', ['titleOverride' => 'iOS'])

@section('content')
    @include('layout._page_header_v4', ['params' => [
        'showTitle' => false,
        'theme' => 'home',
    ]])
    <div class="osu-page osu-page--generic">
        <div class="osu-md">
            <h1 class="osu-md__header osu-md__header--1">Torii on iOS</h1>

            <p class="osu-md__paragraph">
                There is no iOS download. Torii is not on the App Store and there is no TestFlight
                beta, because Apple only distributes apps through those two and we are on neither.
            </p>

            <p class="osu-md__paragraph">
                The client does build for iOS, so if you have a Mac, Xcode and a signing identity
                you can build it from source and sideload it onto your own device. You keep it
                signed yourself, and nothing about that is supported here.
                <a class="osu-md__link" href="{{ osu_url('lazer_dl_other') }}" rel="noreferrer">Source and releases</a>.
            </p>

            <p class="osu-md__paragraph">
                Windows, macOS, Linux and Android are normal downloads on the
                <a class="osu-md__link" href="{{ route('download') }}">download page</a>. If you
                want to hear about it when iOS changes, ask in
                <a class="osu-md__link" href="{{ osu_url('social.discord') }}" rel="noreferrer">Discord</a>.
            </p>
        </div>
    </div>
@endsection
