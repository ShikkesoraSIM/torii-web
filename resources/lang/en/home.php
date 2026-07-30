<?php

// Copyright (c) ppy Pty Ltd <contact@ppy.sh>. Licensed under the GNU Affero General Public License v3.0.
// See the LICENCE file in the repository root for full licence text.

return [
    'landing' => [
        'download' => 'Download now',
        'online' => '<strong>:players</strong> online right now',
        'plays' => '<strong>:count</strong> plays submitted',
        'peak' => 'Peak, :count online users',
        'players' => '<strong>:count</strong> registered players',
        'title' => 'welcome',
        'see_more_news' => 'see more news',

        'slogan' => [
            'main' => 'a private osu! server that keeps your progress',
            'sub' => 'built by Shikkesora, running on osu!lazer',
        ],
    ],

    'search' => [
        'advanced_link' => 'Advanced search',
        'button' => 'Search',
        'empty_result' => 'Nothing found!',
        'keyword_required' => 'A search keyword is required',
        'placeholder' => 'type to search',
        'title' => 'search',

        'artist_track' => [
            'more_simple' => 'See more featured artist track search results',
        ],
        'beatmapset' => [
            'login_required' => 'Sign in to search beatmaps',
            'more' => ':count more beatmap search results',
            'more_simple' => 'See more beatmap search results',
            'title' => 'Beatmaps',
        ],

        'forum_post' => [
            'all' => 'All forums',
            'link' => 'Search the forum',
            'login_required' => 'Sign in to search the forum',
            'more_simple' => 'See more forum search results',
            'title' => 'Forum',

            'label' => [
                'forum' => 'search in forums',
                'forum_children' => 'include subforums',
                'include_deleted' => 'include deleted posts',
                'topic_id' => 'topic #',
                'username' => 'author',
            ],
        ],

        'mode' => [
            'all' => 'all',
            'artist_track' => 'featured artist track',
            'beatmapset' => 'beatmap',
            'forum_post' => 'forum',
            'team' => 'team',
            'user' => 'player',
            'wiki_page' => 'wiki',
        ],

        'team' => [
            'login_required' => 'Sign in to search teams',
            'more_simple' => 'See more team search results',
        ],

        'user' => [
            'login_required' => 'Sign in to search users',
            'more' => ':count more player search results',
            'more_simple' => 'See more player search results',
            'more_hidden' => 'Player search is limited to :max players. Try refining search query.',
            'title' => 'Players',
        ],

        'wiki_page' => [
            'link' => 'Search the wiki',
            'more_simple' => 'See more wiki search results',
            'title' => 'Wiki',
        ],
    ],

    'download' => [
        // el nombre del cliente en el boton grande. Estaba hardcodeado como
        // "osu!" en la vista.
        'client' => 'Torii',
        'download' => 'Download',
        'for_os' => 'for :os',
        'or' => 'or',
        'os_version_or_later' => ':os_version or later',
        'other_os' => 'other platforms',
        'quick_start_guide' => 'quick start guide',
        'tagline_1' => 'let\'s get you',
        'tagline_2' => 'started!',

        // torii: los tres streams del cliente. El boton grande de arriba baja el
        // estable; esto es para el que quiere otro.
        'torii_streams' => [
            'title' => 'other builds',
            'description' => 'all three connect to the same server and share your account, scores and pp. you can switch between them at any time from the game settings.',
            'version' => 'version :version',
            'changelog' => 'release notes',
            'torii' => [
                'name' => 'Torii',
                'description' => 'the stable build. this is the one you want unless you have a reason not to.',
            ],
            'nova' => [
                'name' => 'Torii Nova',
                'description' => 'runs ahead of stable on a newer runtime. new features land here first, and so do new bugs.',
            ],
            'vanilla' => [
                'name' => 'Torii Vanilla',
                'description' => 'upstream osu!lazer, unmodified except for pointing at this server. no Torii features.',
            ],
        ],
        'video-guide' => 'video guide',

        'help' => [
            '_' => 'if you have a problem starting the game or registering for an account, :help_forum_link or :support_button.',
            'help_forum_link' => 'check the help forum',
            'support_button' => 'contact support',
        ],

        'steps' => [
            'register' => [
                'title' => 'get an account',
                'description' => 'follow the prompts when starting the game to sign in or make a new account',
            ],
            'download' => [
                'title' => 'install the game',
                'description' => 'click the button above to download the installer, then run it!',
            ],
            'beatmaps' => [
                'title' => 'get beatmaps',
                'description' => [
                    '_' => ':browse the vast library of user-created beatmaps and start playing!',
                    'browse' => 'browse',
                ],
            ],
        ],
    ],

    // la pagina del corazoncito del pie. Upstream trae la de osu!supporter con
    // la carta de peppy y los precios de ellos, asi que va reescrita entera.
    // Las keys viven aca y no en community.php porque esa es la version de
    // upstream y la comparten las 40 traducciones.
    'support' => [
        'title' => 'Support Torii',
        'lead' => 'Torii is free to play and always will be. Donations exist to cover what it costs to keep the lights on, nothing else.',

        'costs' => [
            'title' => 'Where it goes',
            'servers' => 'Servers and bandwidth: the game server, the website, replays and beatmap downloads.',
            'storage' => 'Domains, storage and the odd licence.',
            'volunteers' => 'Nobody is paid. Torii is run by volunteers in their spare time.',
        ],

        'perks' => [
            'title' => 'What you get',
            'title_tag' => 'A Supporter title on your profile.',
            'aura' => 'The pink hearts aura around your name, everywhere your name shows up.',
            'no_advantage' => 'No gameplay advantage, ever. Nothing here makes you rank higher.',
        ],

        'osu' => [
            'title' => 'Support osu! first',
            '_' => 'Torii runs on osu!lazer, which ppy builds and gives away for free. If you can only support one, support :link.',
            'link' => 'osu! itself',
        ],

        'convinced' => [
            'title' => 'Still here?',
            'button' => 'Donate on Ko-fi',
            'rate' => 'Every :dollars is one month of Supporter, and it stacks.',
            'username' => 'Put @yourusername in the Ko-fi message so the Supporter title lands on the right account.',
        ],
    ],

    'user' => [
        'title' => 'dashboard',
        'news' => [
            'title' => 'News',
            'error' => 'Error loading news, try refreshing the page?...',
        ],
        'header' => [
            'stats' => [
                'friends' => 'Online Friends',
                'games' => 'Games',
                'online' => 'Online Users',
            ],
        ],
        'beatmaps' => [
            'daily_challenge' => 'Daily Challenge Beatmap',
            'new' => 'New Ranked Beatmaps',
            'popular' => 'Popular Beatmaps',
            'by_user' => 'by :user',
            'resets' => 'resets :ends',
        ],
        'buttons' => [
            'download' => 'Download Torii',
            'support' => 'Support Torii',
        ],
        'livestream' => [
            'title' => 'Featured Livestream',
        ],
        'show' => [
            'admin' => [
                'page' => 'Open admin console',
            ],
        ],
    ],
];
