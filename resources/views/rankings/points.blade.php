{{--
    torii: ranking de puntos.

    Mismo molde que rankings/kudosu: es el unico ranking de osu-web que no
    ordena por jugar, asi que es el que mejor le queda a una moneda.
--}}
@extends('rankings.index', [
    'hasFilter' => false,
    'hasMode' => false,
    'params' => ['type' => 'points'],
])

@section('scores')
    <table class="ranking-page-table">
        <thead>
            <tr>
                <th></th>
                <th class="ranking-page-table__heading ranking-page-table__heading--main"></th>
                <th class="ranking-page-table__heading ranking-page-table__heading--focused ranking-page-table__heading--grade">
                    {{ osu_trans('rankings.points.balance') }}
                </th>
            </tr>
        </thead>
        <tbody>
            @php
                $firstItem = $scores->firstItem();
            @endphp
            @foreach ($scores as $index => $user)
                <tr class="{{ class_with_modifiers('ranking-page-table__row', ['inactive' => !$user->isActive()]) }}">
                    <td class="ranking-page-table__column">
                        #{{ i18n_number_format($firstItem + $index) }}
                    </td>
                    <td class="ranking-page-table__column ranking-page-table__column--main">
                        @include('rankings._main_column', ['object' => $user])
                    </td>
                    <td class="ranking-page-table__column">
                        {{ i18n_number_format($user->torii_points) }}
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endsection
