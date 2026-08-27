{{--
    Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
    See the LICENCE file in the repository root for full licence text.
--}}
@php
    $user = Auth::user();
    $isSilenced = $user->isSilenced();
@endphp

@extends('master', ['titlePrepend' => osu_trans('accounts.edit.title_compact')])

@section('content')
    @if ($isSilenced && !$user->isRestricted())
        @include('objects._notification_banner', [
            'type' => 'alert',
            'title' => osu_trans('users.silenced_banner.title'),
            'message' => osu_trans('users.silenced_banner.message'),
        ])
    @endif

    @include('home._user_header_default', ['themeOverride' => 'settings'])

    <div class="osu-page osu-page--account-edit">
        <div class="account-edit account-edit--first">
            <div class="account-edit__section">
                <h2 class="account-edit__section-title">
                    {{ osu_trans('accounts.edit.profile.title') }}
                </h2>
            </div>

            <div class="account-edit__input-groups">
                <div class="account-edit__input-group">
                    <div class="account-edit-entry account-edit-entry--read-only">
                        <div class="account-edit-entry__label">
                            {{ osu_trans('accounts.edit.username') }}
                        </div>
                        <div class="account-edit-entry__input">
                            {{ $user->username }}
                        </div>

                        <div class="account-edit-entry__button">
                            <a class="btn-osu-big btn-osu-big--account-edit" href="{{route('store.products.show', 'username-change')}}">
                                <div class="btn-osu-big__content">
                                    <div class="btn-osu-big__left">
                                        {{ osu_trans('common.buttons.change') }}
                                    </div>

                                    <div class="btn-osu-big__icon">
                                        <i class="fas fa-pencil-alt"></i>
                                    </div>
                                </div>
                            </a>
                        </div>
                    </div>
                    @include('accounts._edit_country')
                </div>
                <div class="account-edit__input-group">
                    @include('accounts._edit_entry_simple', ['field' => 'user_from'])
                    @include('accounts._edit_entry_simple', ['field' => 'user_interests'])
                    @include('accounts._edit_entry_simple', ['field' => 'user_occ'])
                </div>
                <div class="account-edit__input-group">
                    @include('accounts._edit_entry_simple', ['field' => 'user_twitter'])
                    @include('accounts._edit_entry_simple', ['field' => 'user_discord'])
                    @include('accounts._edit_entry_simple', ['field' => 'user_website'])
                </div>
            </div>
        </div>

        @php
            $toriiAvatarNsfw = App\Libraries\Torii\ProfileMedia::avatarIsNsfw(Auth::user());
        @endphp
        <div class="account-edit" id="avatar">
            <div class="account-edit__section">
                <h2 class="account-edit__section-title">
                    {{ osu_trans('accounts.edit.avatar.title') }}
                </h2>
            </div>

            <div class="account-edit__input-groups">
                <div class="account-edit__input-group">
                    <div class="account-edit-entry account-edit-entry--block js-account-edit-avatar">
                        <div class="account-edit-entry__avatar">
                            <div class="avatar avatar--full-rounded u-current-user-avatar"></div>

                            <div class="account-edit-entry__drop-overlay">
                                <span>
                                {{ osu_trans('common.dropzone.target') }}
                                </span>
                            </div>

                            <div class="account-edit-entry__overlay-spinner">
                                {!! spinner() !!}
                            </div>
                        </div>

                        {{-- torii: el aviso va ANTES del boton, que es cuando
                             sirve leerlo. Y la casilla anda con o sin foto
                             puesta: tildarla primero y subir despues deja la
                             foto marcada desde el momento cero. --}}
                        <div class="account-edit-entry__rules" style="max-width: 62ch;">
                            {{ osu_trans('accounts.edit.avatar.nsfw_notice') }}
                        </div>

                        <div
                            class="js-account-edit js-account-edit-auto-submit"
                            data-url="{{ route('account.avatar-nsfw') }}"
                            data-user-preferences-update="1"
                            style="margin: 10px 0 15px;"
                        >
                            <label class="account-edit-entry__checkbox">
                                @include('objects._switch', ['locals' => [
                                    'additionalClass' => 'js-account-edit__input',
                                    'checked' => $toriiAvatarNsfw,
                                    'name' => 'avatar_nsfw',
                                ]])

                                <span class="account-edit-entry__checkbox-label">
                                    {{ osu_trans('accounts.edit.avatar.nsfw_label') }}
                                </span>

                                <div class="account-edit-entry__checkbox-status">
                                    @include('accounts._edit_entry_status', ['modifiers' => ['left']])
                                </div>
                            </label>
                        </div>

                        <p>
                            <label
                                class="btn-osu-big btn-osu-big--account-edit"
                                @if ($isSilenced)
                                    disabled
                                @endif
                            >
                                <span class="btn-osu-big__content">
                                    <span class="btn-osu-big__left">
                                        {{ osu_trans('common.buttons.upload_image') }}
                                    </span>

                                    <span class="btn-osu-big__icon">
                                        <i class="far fa-arrow-alt-circle-up"></i>
                                    </span>
                                </span>

                                <input
                                    class="js-account-edit-avatar__button fileupload"
                                    type="file"
                                    name="avatar_file"
                                    data-url="{{ route('account.avatar') }}"
                                    @if ($isSilenced)
                                        disabled
                                    @endif
                                >
                            </label>
                        </p>

                        <p>
                            <button
                                class="btn-osu-big btn-osu-big--account-edit js-account-edit-avatar--reset"
                                type="button"
                                data-url="{{ route('account.avatar') }}"
                                data-method="POST"
                                data-remote
                                data-confirm="{{ osu_trans('common.confirmation') }}"
                                @if ($isSilenced)
                                    disabled
                                @endif
                            >
                                <span class="btn-osu-big__content">
                                    <span class="btn-osu-big__left">
                                        {{ osu_trans('accounts.edit.avatar.reset') }}
                                    </span>

                                    <span class="btn-osu-big__icon">
                                        <i class="fas fa-times"></i>
                                    </span>
                                </span>
                            </button>
                        </p>

                    </div>
                </div>
            </div>
        </div>

        {{-- torii: se fueron tres secciones de aca, y ninguna por gusto.

             FIRMA: escribir user_sig lo rechaza la capa de escritura porque en
             lazer_users no hay columna donde ponerlo. Se guardaba nunca y
             avisaba con un error. Ademas el unico foro que existe es el de
             descripciones de mapas, con tres posts.

             NOTIFICACIONES: configuraba un sistema que nunca produjo una sola
             fila. No hay mail configurado (todo MAIL_* comentado), la tabla de
             discusiones de mapas ni siquiera existe, no hay noticias, no hay
             proceso de qualified, y user_notify tambien lo rechaza la capa de
             escritura. Eran seis controles para nada.

             API LEGACY: daba una key para una API v1 que en torii-web no tiene
             ni una ruta, y una contrasenia de IRC para un servidor que no
             existe. Cero usuarios habian sacado una.

             Los blades siguen en el repo por si algun dia aplican; lo unico que
             se saca es mostrarlos. --}}
        @include('accounts._edit_playstyles')

        @include('accounts._edit_privacy')

        @include('accounts._edit_options')

        @include('accounts._edit_password')

        @include('accounts._edit_email')

        {{-- torii: el 2FA de osu-web tampoco esta, y este es el que mas
             enganiaba de todos.

             Guarda en osu.user_totp_keys, mientras que el 2FA del juego vive en
             otra tabla de otro esquema: osu_api.totp_keys. Son dos cosas
             distintas que no se hablan. Resultado: las 19 personas que SI tienen
             2FA en Torii entraban aca y leian "Not configured", y cualquiera que
             lo activara desde el sitio se quedaba tranquilo creyendo que
             protegio su cuenta del juego, que no.

             De yapa el texto prometia "email verification will still be
             available as a fallback" y torii-web no manda un solo mail (todo
             MAIL_* esta comentado en el .env).

             Si algun dia se quiere 2FA desde el sitio, tiene que escribir en la
             tabla del juego, no en la suya. --}}

        @include('accounts._edit_sessions')

        @include('accounts._edit_oauth')

        @if (\App\Models\GithubUser::canAuthenticate())
            @include('accounts._edit_github_user')
        @endif

    </div>
@endsection

@section("script")
  <script id="json-authorized-clients" type="application/json">
    {!! json_encode($authorizedClients) !!}
  </script>

  <script id="json-own-clients" type="application/json">
    {!! json_encode($ownClients) !!}
  </script>

  @include('layout._react_js', ['src' => 'js/account-edit.js'])
@endsection
