# TurcoScore

**English** | [Türkçe](README.tr.md)

A Flutter live-scores app for match results, live score, league tables and
player info, fed by public (keyless) football data APIs.

> The original data source was unreachable from every network (bot/WAF +
> captcha → 403), so the data layer was moved to a different open provider.
> Screens never talk to a provider directly — they go through a single
> interface, so swapping sources is a one-line change.

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
- **Search** — teams, leagues and players in one box with a 350 ms debounce;
  "galatasaray" → Galatasaray, "messi" → player profile
- **Player profile** — age, height, weight, position, birth date/place,
  contract, season stats; a transparent estimated rating
  (`core/utils/player_rating.dart`) with red/orange/green/blue tiers
- **Team squad** — formation view with photos, shirt numbers, full names,
  rating badges and substitutes
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
```

Release APK:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

A prebuilt release APK is also committed under [`releases/`](releases/).

## Configuration (.env)

There are **no API keys to hide** — every endpoint the app uses is public and
keyless. Base URLs and the (currently unused) key slots live in
[`.env.example`](.env.example):

```bash
cp .env.example .env   # .env is git-ignored
```

| File | Tracked? | Purpose |
|---|---|---|
| `.env.example` | yes | template: base URLs, future key slots |
| `.env` | **no** | your local copy, never committed |

If you switch to a licensed source, put its key in `.env` and keep the file
out of git — `.gitignore` already excludes `.env`, `.env.*` and re-includes
only `.env.example`.

## Architecture

```
lib/
├── main.dart                     # Provider + MaterialApp (tr locale, light/dark theme)
├── background.dart               # 15-min background favorite check
├── core/
│   ├── constants/api_constants.dart   # fallback source endpoints
│   ├── network/api_client.dart        # HTTP + timeout + fallback base URLs + error classes
│   ├── notifications/match_notifier.dart
│   ├── theme/app_theme.dart           # Material 3 theme
│   ├── utils/                         # json_utils, errors, player_rating
│   └── widgets/                       # TeamLogo, StatusBadge, Error/Empty/Loading, DemoBanner
├── data/
│   ├── models/                        # MatchEvent, Tournament, StandingRow, PlayerProfile...
│   ├── sources/                       # data contract + active/passive providers
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
not affect the screens: `ScoreRepository(source: ...)`.

## Data layer

- **One contract** — `data/sources/score_data_source.dart` is the only interface
  the app depends on; concrete providers implement it and the repository picks
  one.
- **Active vs. passive** — the active provider is wired in the repository; a
  second provider is kept in the tree as a fallback that can be re-enabled with
  a single line.
- **Fallback chain** — a provider may declare several base URLs; on network
  error / 403 / 429 / 451 the client moves to the next one.
- **Demo fallback** — if every source fails, the repository serves bundled
  `DemoData` and the UI shows a "demo data" banner instead of an error.
- **Merged search** — team/league results and player results are fetched from
  different providers and merged into one list, players first.

## Known limitations

- **Real match ratings:** free sources generally don't publish ratings or are
  blocked, so the rating is derived from stats (goals/assists/cards/saves plus
  the match result) via the transparent formula in
  `core/utils/player_rating.dart` and is labelled as *estimated*. A licensed
  API key is needed for official ratings.
- **Global player search:** most free search endpoints return only teams and
  leagues. Players are reached through match squads and team lists instead.
- **Lower Turkish tiers:** only the top two divisions are covered by the
  current source; 3. Lig and the Turkish Cup have no data, so those rows stay
  empty. Full coverage needs a keyed source such as API-Football or
  football-data.org.

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
- Top scorers / leaderboards
- Disk cache limit for `cached_network_image`

## Legal / rate limits

Public football data APIs like the ones used here are generally unofficial.
Keep request counts low and use a 30–60 s interval when adding polling.
Prefer a licensed source for commercial distribution.

## License

See [LICENSE](LICENSE).
