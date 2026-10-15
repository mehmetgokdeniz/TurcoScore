# TurcoScore

**English** | [Türkçe](README.tr.md)

A Flutter live-scores app for match results, live score, league tables and
player info, fed by the public **ESPN** API.

> SofaScore was the first choice, but its bot/WAF + captcha returns 403 from
> every network, so the source was switched to ESPN. The SofaScore code is
> preserved in `data/sources/sofascore_source.dart`.

## Features

- **Matches** — daily match list with a date strip, live filter, favorites chip
- **Match detail** — minute-by-minute timeline (goals, penalties, cards,
  substitutions, VAR), stats in Turkish (possession, shots, on target, fouls,
  corners, pass accuracy, xG), lineups on a formation pitch, last-5 form badges
  and head-to-head history
- **Leagues** — 35 tournaments pulled in parallel (8 at a time, ~3s): 13 club
  leagues (Trendyol Süper Lig + Trendyol 1. Lig), 6 cups, 16 national-team
  competitions (World Cup + qualifiers, UEFA Nations League, Euro + qualifiers,
  Copa América, AFCON/Asia/Gold Cup, CONCACAF Nations League, friendlies)
- **Standings** — table with season selection; knockout tournaments show each
  group as its own section
- **Search** — teams + leagues (ESPN) and players (Maçkolik) in one box,
  350 ms debounce; "galatasaray" → Galatasaray, "messi" → player profile
- **Player profile** — age, height, weight, position, birth date/place,
  contract, season stats; a transparent estimated rating
  (`core/utils/player_rating.dart`) with red/orange/green/blue tiers
- **Team squad** — formation view with photos, shirt numbers, full names,
  SofaScore-style rating badges and substitutes
- **Favorites & notifications** (local, no server): match kick-off, goals,
  red cards. Checked every **60 s** while the app is open (`AppShell` timer)
  and every **15 min** in the background (`workmanager`, `lib/background.dart`).
  Only *new* events are notified. Android 13+ asks for the permission on first
  launch.
- **Demo mode** — on network error / 403 / 429 / 451 the repository falls back
  to `DemoData` and the UI shows a "demo data" banner

## Getting started

```bash
flutter pub get
flutter run
```

Verification:

```bash
flutter analyze
flutter test
dart run tool/probe_espn.dart   # end-to-end live API check
```

Release APK:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

A prebuilt release APK is also committed under [`releases/`](releases/).

## Configuration (.env)

There are **no API keys to hide** — every endpoint the app uses is a public,
keyless API. Base URLs and the (currently unused) key slots live in
[`.env.example`](.env.example):

```bash
cp .env.example .env   # .env is git-ignored
```

| File | Tracked? | Purpose |
|---|---|---|
| `.env.example` | yes | template: base URLs, future key slots |
| `.env` | **no** | your local copy, never committed |

If you switch to a licensed source (API-Football, football-data.org, ...), put
its key in `.env` and keep the file out of git — `.gitignore` already excludes
`.env`, `.env.*` and re-includes only `.env.example`.

## Architecture

```
lib/
├── main.dart                     # Provider + MaterialApp (tr locale, light/dark theme)
├── background.dart               # 15-min background favorite check
├── core/
│   ├── constants/api_constants.dart   # SofaScore endpoints (backup source)
│   ├── network/api_client.dart        # HTTP + timeout + fallback base URLs + error classes
│   ├── notifications/match_notifier.dart
│   ├── theme/app_theme.dart           # Material 3 theme
│   ├── utils/                         # json_utils, errors, player_rating
│   └── widgets/                       # TeamLogo, StatusBadge, Error/Empty/Loading, DemoBanner
├── data/
│   ├── models/                        # MatchEvent, Tournament, StandingRow, PlayerProfile...
│   ├── sources/
│   │   ├── score_data_source.dart     # the app's single data contract (interface)
│   │   ├── espn_source.dart           # ACTIVE source (+ league config)
│   │   ├── sofascore_source.dart      # passive, code preserved
│   │   └── mackolik_client.dart       # Turkish leagues / player profiles
│   ├── repositories/score_repository.dart  # source + demo fallback, single gate
│   ├── favorites/favorite_store.dart
│   └── demo/demo_data.dart            # sample data when unreachable
├── state/                             # ChangeNotifier controllers
│   ├── matches_controller.dart
│   ├── leagues_controller.dart        # TournamentsController + StandingsController
│   ├── detail_controllers.dart        # MatchDetailController + PlayerController
│   ├── search_controller.dart         # 350 ms debounce search
│   └── load_state.dart
└── features/
    ├── shell/app_shell.dart           # bottom nav: Matches / Leagues / Search
    ├── matches/                       # list (date strip + live filter), match detail
    ├── leagues/                       # league list, standings (season picker)
    ├── search/                        # team / league / player search
    ├── player/                        # player profile
    └── team/                          # team squad
```

Layer rule: `features → state → data → core`. Screens never touch the
repository directly — they go through a controller. Swapping the source does
not affect the screens: `ScoreRepository(source: SofaScoreSource())`.

## ESPN API (active)

No key required; all endpoints were verified live in 2026-10
(re-run with `dart run tool/probe_espn.dart`).

| Purpose | Endpoint |
|---|---|
| Daily matches (per league) | `/apis/site/v2/sports/soccer/{slug}/scoreboard?dates=yyyyMMdd` |
| Live matches | same endpoint for today → filter `status.type.state == 'in'` |
| Match detail | `/apis/site/v2/sports/soccer/{slug}/summary?event={id}` |
| Stats | inside summary: `boxscore.teams[].statistics` |
| Match events | inside summary: `header.competitions[0].details` |
| Lineups | inside summary: `rosters[]` (formation + ordered starting XI) |
| **Standings** | `/apis/v2/sports/soccer/{slug}/standings?season={year}` |
| Season picker | `seasons` → {year}-{year+1} and the previous one |
| League list | fixed configuration (`EspnSource.leagues`) |
| Team squad | `/apis/site/v2/sports/soccer/{slug}/teams/{id}/roster` |
| Player profile | `sports.core.api.espn.com/v2/sports/soccer/athletes/{id}` |
| Search | `/apis/common/v3/search?q=&sport=soccer` (teams + leagues) |

Important notes:

- **Standings path differs:** `site/v2` returns an empty `{}`; the working path
  is `/apis/v2/...` ("site/v2 returns a stub").
- **Season resolution:** if the requested year is empty, the app falls back to
  ESPN's season-less (latest populated) call; the season list comes from the
  response's `seasons` field. In knockout tournaments each group is shown as
  its own section (`Group A` → `A Grubu`).
- **Search:** without `sport=soccer` no football teams come back. ESPN search
  has no player results; players are reached via match squads and team lists.
- **Stats/event shape** differs between scoreboard and summary
  (`athletesInvolved` vs `participants[].athlete`) — both are read.
- **Match summary:** a minute-by-minute timeline via `keyEvents` — goals,
  scored/missed penalties, yellow/red cards, substitutions (in/out names), VAR
  and other events; all labelled in Turkish with processed scores.
- **Last 5:** both teams' W/D/L form as coloured badges on the summary tab.
- **Head-to-head:** `seasonseries` is listed; tapping a row opens that match.
- **Date fix:** the summary object has no `header.date`; the date is read from
  `competitions[0].date`.
- **Images:** team logos come from ESPN's single `logo` field, else from the
  `a.espncdn.com/i/teamlogos/soccer/500/{id}.png` CDN. League logos come from
  the core league endpoint and are cached (also written from the scoreboard
  response, so they show in list headers).
- **Naming:** Turkish leagues are shown with their sponsor names
  (e.g. `Trendyol Süper Lig`).
- **Demo mode:** on network error / 403 / 429 / 451 the repository falls back
  to `DemoData` and a banner appears.

## Maçkolik sources (Turkish leagues + players)

`lib/data/sources/mackolik_client.dart` — unofficial endpoints (UTF-8):

| Purpose | Endpoint |
|---|---|
| Player search | `/AjaxHandlers/SearchHandler.aspx?q=` (JS array literal) |
| Player profile | `/Player/Default.aspx?id={id}` (bio + matches/goals/assists/shots) |
| Standings | `/AjaxHandlers/StandingHandler.ashx?op=standing&id={seasonId}` (JSON) |

- **Search is merged:** players from Maçkolik, teams/leagues from ESPN, player
  results shown first. Example: `messi` → "Lionel Messi (Inter Miami)" →
  profile with age, height, weight, position, birth date/place, contract and
  season stats.
- **Standings column mapping** (verified against the `Standing2.js` render):
  `[2]+[3] O`, `[4]+[5] G`, `[6]+[7] B`, `[8]+[9] M`, `[10]+[11] A`,
  `[12]+[13] Y`, `[14]+[15]+[17] P`.
- **Trendyol 1. Lig:** where ESPN has no data, the Maçkolik JSON takes over
  (`espnTournamentToSeason`: 1→73482, 2→73487).

### Known limitations (result of the free-source survey)

- **Real match ratings:** SofaScore 403/captcha, FotMob signed/closed, ESPN
  doesn't publish ratings, Maçkolik has no API (HTML only). Ratings are
  therefore derived from stats. A licensed API key is needed for real ratings.
- **Global player search:** ESPN search ignores player results
  (`type=player` is ignored), TheSportsDB's free plan returns 404 for player
  profiles. Players are reached via match squads and team lists.
- **Lower Turkish tiers:** ESPN only has `tur.1` (Süper Lig) and `tur.2`
  (1. Lig); no slugs for 3. Lig or the Turkish Cup. TheSportsDB's free plan
  limits standings to 5 rows and daily matches to 3 events. Full coverage
  needs a keyed source such as API-Football / football-data.

## SofaScore (passive source)

Evidence of unavailability: `www.sofascore.com` and `api.sofascore.com` return
403 from this machine (including robots.txt), a request from another network is
redirected to `captcha.html`, `api.sofascore.app` returns an empty 200.
Circumventing the captcha/block was deliberately not attempted.

The code is kept: endpoints in `core/constants/api_constants.dart`, client in
`data/sources/sofascore_source.dart`. Switching back is one line:
`ScoreRepository(source: SofaScoreSource())`.

## Model parsing rule

API types come back inconsistent (a score field may be `int` *or* `string`).
Models use `tryInt / tryString / tryMap`; unknown fields silently pass as
`null`. Never read `json['x']` directly when adding a field.

## App icon

- Source image processed by `tool/make_icon.dart` (checkered background is
  detected at the edges and filled with navy, converted to a 1024x PNG):
  `dart run tool/make_icon.dart`
- Launcher icons: `dart run flutter_launcher_icons`
  (Android mipmap + iOS AppIcon, configured in `pubspec.yaml`).

## Roadmap

- Favorite teams/players (`shared_preferences` + local notifications)
- 30–60 s polling for live scores
- Top scorers / leaderboards (`common/v3/.../statistics/byathlete`)
- Disk cache limit for `cached_network_image`

## Legal / rate limits

ESPN's API is unofficial. Keep request counts low and use a 30–60 s interval
when adding polling. Prefer a licensed source for commercial distribution.

## License

See [LICENSE](LICENSE).
