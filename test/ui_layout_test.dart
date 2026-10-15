// Telefon boyutunda kadro sahası ve puan tablosu düzenini doğrular:
// RenderFlex taşmaları testte hata olarak patlar.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:turcoscore/data/favorites/favorite_store.dart';
import 'package:turcoscore/data/models/event_details.dart';
import 'package:turcoscore/data/models/match_models.dart';
import 'package:turcoscore/data/models/player_models.dart';
import 'package:turcoscore/data/models/tournament_models.dart';
import 'package:turcoscore/data/repositories/score_repository.dart';
import 'package:turcoscore/data/sources/score_data_source.dart';
import 'package:turcoscore/features/leagues/league_detail_screen.dart';
import 'package:turcoscore/features/matches/match_detail_screen.dart';
import 'package:turcoscore/state/leagues_controller.dart';

class _FakeSource implements ScoreDataSource {
  @override
  String get name => 'Test';

  @override
  Future<List<MatchEvent>> fetchEventsForDate(DateTime date) async => const [];

  @override
  Future<List<MatchEvent>> fetchLiveEvents() async => const [];

  @override
  Future<EventBundle> fetchEventBundle(MatchEvent preview) async {
    Lineup lineup(bool isHome) => Lineup(
          formation: '4-3-3',
          players: [
            for (var i = 1; i <= 14; i++)
              LineupPlayer(
                player: PlayerSummary(
                  id: i,
                  name: i == 1
                      ? 'Kaleci Oyuncu'
                      : 'Oyuncu Adı Soyad$i',
                  position: i == 1 ? 'G' : 'M',
                  jerseyNumber: i,
                ),
                isHome: isHome,
                jerseyNumber: i,
                position: i == 1 ? 'G' : 'M',
                rating: 5.5 + (i % 5) * 0.8,
                isStarter: i <= 11,
              ),
          ],
        );

    return EventBundle(
      event: preview,
      statistics: const MatchStatistics(groups: []),
      incidents: const [],
      homeLineup: lineup(true),
      awayLineup: lineup(false),
    );
  }

  @override
  Future<List<Tournament>> fetchTournaments() async => const [];

  @override
  Future<List<Season>> fetchSeasons(int tournamentId) async =>
      [const Season(id: 2026, name: '2026-27', isCurrent: true)];

  @override
  Future<StandingsTable> fetchStandings(int tournamentId, int seasonId) async {
    StandingRow row(int i, String name) => StandingRow(
          position: i,
          team: TeamRef(id: i, name: name, logoUrl: null),
          matches: 10,
          won: 10 - i,
          drawn: 2,
          lost: i - 2,
          goalsFor: 30 - i * 2,
          goalsAgainst: 8 + i * 2,
          points: (10 - i) * 3 + 2,
          promotionText: i == 1 ? 'Şampiyonlar Ligi' : null,
        );

    // Gruplu turnuva düzeni: iki grup, her grupta9 takım.
    return StandingsTable(
      rows: const [],
      sections: [
        StandingSection(
          name: 'A Grubu',
          rows: [for (var i = 1; i <= 9; i++) row(i, 'Takım $i')],
        ),
        StandingSection(
          name: 'B Grubu',
          rows: [for (var i = 10; i <= 18; i++) row(i - 9, 'Takım $i')],
        ),
      ],
    );
  }

  @override
  Future<List<SearchItem>> search(String query) async => const [];

  @override
  Future<PlayerProfile?> fetchPlayer(int playerId) async => null;

  @override
  Future<List<PlayerSummary>> fetchTeamSquad(
    int teamId, {
    String? leagueSlug,
  }) async =>
      const [];
}

Widget _wrap(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MultiProvider(
        providers: [
          Provider<ScoreRepository>.value(
            value: ScoreRepository(source: _FakeSource()),
          ),
          ChangeNotifierProvider(create: (_) => FavoriteStore()),
        ],
        child: home,
      ),
    );

MatchEvent _preview() => MatchEvent(
      id: 1,
      startTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      tournamentName: 'Süper Lig',
      tournamentId: 1,
      countryName: 'Türkiye',
      tournamentFlagUrl: null,
      home: const TeamRef(id: 1, name: 'Galatasaray', logoUrl: null),
      away: const TeamRef(id: 2, name: 'Fenerbahçe', logoUrl: null),
      statusType: 'finished',
      statusDescription: 'MS',
      homeScore: 2,
      awayScore: 1,
      winnerCode: 'home',
      sourceKey: 'tur.1',
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('kadro sekmesi saha görünümünü taşmasız açar', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(_wrap(MatchDetailScreen(preview: _preview())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kadrolar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tahmini'), findsOneWidget);
    expect(find.text('Yedekler'), findsOneWidget);
    // Saha artık tam ad gösterir: "1 Kaleci Oyuncu".
    expect(find.textContaining('Kaleci Oyuncu'), findsOneWidget);
    // Yedekler listesinde tam ad görünür.
    expect(find.textContaining('Adı Soyad12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('takım değiştirince saha yeniden çizilir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(_wrap(MatchDetailScreen(preview: _preview())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kadrolar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fenerbahçe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tahmini'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('puan tablosu telefon boyutunda taşmasız açılır', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(_wrap(
      LeagueDetailScreen(
        tournament: Tournament(id: 1, name: 'Süper Lig', countryName: 'Türkiye'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A Grubu'), findsOneWidget);
    expect(find.text('B Grubu'), findsOneWidget);
    expect(find.text('Takım'), findsWidgets);
    expect(find.text('Takım 1'), findsOneWidget);
    expect(find.text('Şampiyonlar Ligi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('lig araması Türkçe karakter ve boşluk duyarlı değil', () {
    final controller = TournamentsController(
      ScoreRepository(source: _FakeSource()),
    );
    controller.tournaments = const [
      Tournament(id: 1, name: 'Trendyol Süper Lig', countryName: 'Türkiye'),
      Tournament(id: 2, name: 'Premier League', countryName: 'İngiltere'),
    ];

    controller.query = 'süperlig';
    expect(controller.visible.map((t) => t.name), ['Trendyol Süper Lig']);

    controller.query = 'SÜPER LIG';
    expect(controller.visible.single.name, 'Trendyol Süper Lig');

    controller.query = 'premierleague';
    expect(controller.visible.single.name, 'Premier League');

    controller.query = 'türkiye';
    expect(controller.visible.single.name, 'Trendyol Süper Lig');
  });
}
