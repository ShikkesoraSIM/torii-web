{{--
    Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
    See the LICENCE file in the repository root for full licence text.
--}}
{{-- torii: esta era la pagina de donaciones de osu! tal cual, con la carta
     firmada por peppy, los perks de osu!supporter y el boton al checkout de
     Xsolla. Se llega con el corazoncito del pie, o sea que Torii pedia plata en
     nombre de ppy y con un carrito que aca no cobra nada.

     Lo que sigue es la version de Torii. No usa las keys de community.support ni
     el $data del controller: esa es la copy de upstream y sus 40 traducciones
     hablan de osu!supporter, asi que el texto vive en home.support.
     El $supporterStatus tambien queda afuera: se calcula desde
     osu_user_donations, que aca esta vacia porque las donaciones las lleva g0v0,
     y a un supporter de verdad le mostraba "US$0.00 / not yet".

     La tipografia es la de osu-md (la misma del wiki) porque es el unico bloque
     de contenido del sitio que ya trae headers, listas y links armados. --}}
{{-- el titulo de la ruta ("support the game") vive en page_title.php, que es la
     copy de upstream; el h1 de abajo ya dice de que va. --}}
@extends('master', ['titleOverride' => osu_trans('home.support.title')])

@section('content')
    @component('layout._page_header_v4', ['params' => [
        'showTitle' => false,
        'theme' => 'supporter',
    ]])
    @endcomponent

    <div class="osu-page osu-page--generic">
        <div class="osu-md">
            <h1 class="osu-md__header osu-md__header--1">{{ osu_trans('home.support.title') }}</h1>
            <p class="osu-md__paragraph">{{ osu_trans('home.support.lead') }}</p>

            <h2 class="osu-md__header osu-md__header--2">{{ osu_trans('home.support.costs.title') }}</h2>
            <ul class="osu-md__list">
                <li class="osu-md__list-item">{{ osu_trans('home.support.costs.servers') }}</li>
                <li class="osu-md__list-item">{{ osu_trans('home.support.costs.storage') }}</li>
                <li class="osu-md__list-item">{{ osu_trans('home.support.costs.volunteers') }}</li>
            </ul>

            <h2 class="osu-md__header osu-md__header--2">{{ osu_trans('home.support.perks.title') }}</h2>
            <ul class="osu-md__list">
                <li class="osu-md__list-item">{{ osu_trans('home.support.perks.title_tag') }}</li>
                <li class="osu-md__list-item">{{ osu_trans('home.support.perks.aura') }}</li>
                <li class="osu-md__list-item">{{ osu_trans('home.support.perks.no_advantage') }}</li>
            </ul>

            <h2 class="osu-md__header osu-md__header--2">{{ osu_trans('home.support.osu.title') }}</h2>
            <p class="osu-md__paragraph">
                {{-- el cliente dice lo mismo cuando le tocas el corazon: si
                     podes bancar uno solo, banca al que hace el juego. --}}
                {!! osu_trans('home.support.osu._', [
                    'link' => link_to(
                        'https://osu.ppy.sh/home/support',
                        osu_trans('home.support.osu.link'),
                        ['class' => 'osu-md__link', 'rel' => 'noreferrer'],
                    ),
                ]) !!}
            </p>

            <h2 class="osu-md__header osu-md__header--2">{{ osu_trans('home.support.convinced.title') }}</h2>
            <p class="osu-md__paragraph">
                {{ osu_trans('home.support.convinced.rate', ['dollars' => currency(5, 0, false)]) }}
                {{ osu_trans('home.support.convinced.username') }}
            </p>
            <a class="btn-osu-big btn-osu-big--pink" href="{{ osu_url('donate') }}" rel="noreferrer">
                <span class="btn-osu-big__content">
                    <span class="btn-osu-big__left">
                        <span class="btn-osu-big__text-top">
                            {{ osu_trans('home.support.convinced.button') }}
                        </span>
                    </span>
                    <span class="btn-osu-big__icon">
                        <span class="fas fa-heart"></span>
                    </span>
                </span>
            </a>
        </div>
    </div>
@endsection
