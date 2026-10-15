import '../models/event_details.dart';
import '../models/match_models.dart';
import '../models/player_models.dart';
import '../models/tournament_models.dart';

/// Ağ kaynaklı erişilemezlikte arayüzün boş kalmaması için örnek veri.
/// Canlı API geldiğinde tamamen devre dışı kalır.
class DemoData {
  DemoData._();

  static int _ts(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

  static DateTime _at(int hour, int minute, {int dayOffset = 0}) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
  }

  static TeamRef _team(int id, String name) =>
      TeamRef(id: id, name: name, logoUrl: null);

  static MatchEvent _match({
    required int id,
    required int hour,
    required int minute,
    int dayOffset = 0,
    required int tournamentId,
    required String tournament,
    required String country,
    required TeamRef home,
    required TeamRef away,
    String statusType = 'notstarted',
    String? statusDescription,
    int? homeScore,
    int? awayScore,
  }) {
    return MatchEvent(
      id: id,
      startTimestamp: _ts(_at(hour, minute, dayOffset: dayOffset)),
      tournamentName: tournament,
      tournamentId: tournamentId,
      countryName: country,
      tournamentFlagUrl: null,
      home: home,
      away: away,
      statusType: statusType,
      statusDescription: statusDescription,
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }

  static List<MatchEvent> _all() => [
        _match(
          id: 900001,
          hour: 19,
          minute: 0,
          tournamentId: 201,
          tournament: 'Süper Lig',
          country: 'Türkiye',
          home: _team(1, 'Galatasaray'),
          away: _team(2, 'Fenerbahçe'),
          statusType: '2h',
          statusDescription: "67'",
          homeScore: 2,
          awayScore: 1,
        ),
        _match(
          id: 900002,
          hour: 21,
          minute: 30,
          tournamentId: 201,
          tournament: 'Süper Lig',
          country: 'Türkiye',
          home: _team(3, 'Beşiktaş'),
          away: _team(4, 'Trabzonspor'),
        ),
        _match(
          id: 900003,
          hour: 17,
          minute: 0,
          tournamentId: 201,
          tournament: 'Süper Lig',
          country: 'Türkiye',
          home: _team(5, 'Başakşehir'),
          away: _team(6, 'Samsunspor'),
          statusType: 'finished',
          statusDescription: 'MS',
          homeScore: 1,
          awayScore: 1,
        ),
        _match(
          id: 900004,
          hour: 18,
          minute: 30,
          tournamentId: 17,
          tournament: 'Premier League',
          country: 'İngiltere',
          home: _team(7, 'Arsenal'),
          away: _team(8, 'Liverpool'),
          statusType: 'ht',
          statusDescription: 'İY',
          homeScore: 1,
          awayScore: 0,
        ),
        _match(
          id: 900005,
          hour: 22,
          minute: 0,
          tournamentId: 17,
          tournament: 'Premier League',
          country: 'İngiltere',
          home: _team(9, 'Manchester City'),
          away: _team(10, 'Chelsea'),
        ),
        _match(
          id: 900006,
          hour: 20,
          minute: 0,
          tournamentId: 87,
          tournament: 'La Liga',
          country: 'İspanya',
          home: _team(11, 'Real Madrid'),
          away: _team(12, 'Barcelona'),
        ),
        _match(
          id: 900007,
          hour: 20,
          minute: 45,
          tournamentId: 87,
          tournament: 'La Liga',
          country: 'İspanya',
          home: _team(13, 'Atlético Madrid'),
          away: _team(14, 'Sevilla'),
          statusType: 'finished',
          statusDescription: 'MS',
          homeScore: 3,
          awayScore: 0,
        ),
        _match(
          id: 900008,
          hour: 21,
          minute: 45,
          tournamentId: 38,
          tournament: 'Serie A',
          country: 'İtalya',
          home: _team(15, 'Inter'),
          away: _team(16, 'Milan'),
          dayOffset: 1,
        ),
        _match(
          id: 900009,
          hour: 14,
          minute: 30,
          tournamentId: 54,
          tournament: 'TFF 1. Lig',
          country: 'Türkiye',
          home: _team(17, 'Manisa FK'),
          away: _team(18, 'Boluspor'),
          dayOffset: -1,
          statusType: 'finished',
          statusDescription: 'MS',
          homeScore: 2,
          awayScore: 0,
        ),
      ];

  static List<MatchEvent> eventsFor(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _all()
        .where((e) {
          final kickoff =
              DateTime.fromMillisecondsSinceEpoch(e.startTimestamp * 1000);
          return DateTime(kickoff.year, kickoff.month, kickoff.day) == target;
        })
        .toList()
      ..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
  }

  static List<MatchEvent> liveEvents() =>
      _all().where((e) => e.isLive).toList();

  static List<Tournament> tournaments() => const [
        Tournament(
          id: 201,
          name: 'Süper Lig',
          countryName: 'Türkiye',
          currentSeasonId: 76731,
        ),
        Tournament(
          id: 17,
          name: 'Premier League',
          countryName: 'İngiltere',
          currentSeasonId: 76732,
        ),
        Tournament(
          id: 87,
          name: 'La Liga',
          countryName: 'İspanya',
          currentSeasonId: 76733,
        ),
        Tournament(
          id: 38,
          name: 'Serie A',
          countryName: 'İtalya',
          currentSeasonId: 76734,
        ),
        Tournament(
          id: 35,
          name: 'Bundesliga',
          countryName: 'Almanya',
          currentSeasonId: 76735,
        ),
        Tournament(
          id: 54,
          name: 'TFF 1. Lig',
          countryName: 'Türkiye',
          currentSeasonId: 76736,
        ),
      ];

  static List<Season> seasons(int tournamentId) => [
        Season(id: tournamentId * 100 + 1, name: '2025/26', isCurrent: true),
        Season(id: tournamentId * 100, name: '2024/25'),
      ];

  static const Map<int, List<String>> _leagueTeams = {
    201: [
      'Galatasaray',
      'Fenerbahçe',
      'Beşiktaş',
      'Trabzonspor',
      'Samsunspor',
      'Başakşehir',
      'Göztepe',
      'Kasımpaşa',
      'Konyaspor',
      'Alanyaspor',
      'Rizespor',
      'Antalyaspor',
    ],
    17: [
      'Arsenal',
      'Liverpool',
      'Manchester City',
      'Chelsea',
      'Tottenham',
      'Manchester United',
      'Newcastle',
      'Aston Villa',
      'Brighton',
      'West Ham',
    ],
  };

  static StandingsTable standings(int tournamentId) {
    final teams = _leagueTeams[tournamentId] ?? _leagueTeams[201]!;
    const played = 10;
    return StandingsTable(
      rows: [
        for (var i = 0; i < teams.length; i++)
          () {
            final wins = (9 - i).clamp(0, played);
            final draws = (played - wins).clamp(0, 3);
            final losses = played - wins - draws;
            return StandingRow(
              position: i + 1,
              team: TeamRef(
                  id: tournamentId * 10 + i, name: teams[i], logoUrl: null),
              matches: played,
              won: wins,
              drawn: draws,
              lost: losses,
              goalsFor: 30 - i * 2,
              goalsAgainst: 8 + i * 2,
              points: wins * 3 + draws,
            );
          }(),
      ],
    );
  }

  static List<PlayerProfile> get _players => const [
        PlayerProfile(
          id: 901,
          name: 'Arda Güler',
          teamName: 'Real Madrid',
          position: 'M',
          countryName: 'Türkiye',
          age: 21,
          height: 175,
          weight: 70,
          jerseyNumber: 15,
          preferredFoot: 'Sağ',
        ),
        PlayerProfile(
          id: 902,
          name: 'Kerem Aktürkoğlu',
          teamName: 'Fenerbahçe',
          position: 'F',
          countryName: 'Türkiye',
          age: 28,
          height: 173,
          weight: 70,
          jerseyNumber: 10,
        ),
        PlayerProfile(
          id: 903,
          name: 'Julián Álvarez',
          teamName: 'Atlético Madrid',
          position: 'F',
          countryName: 'Arjantin',
          age: 26,
          height: 170,
          weight: 71,
        ),
        PlayerProfile(
          id: 904,
          name: 'Bukayo Saka',
          teamName: 'Arsenal',
          position: 'F',
          countryName: 'İngiltere',
          age: 24,
          height: 178,
          weight: 72,
        ),
      ];

  static PlayerProfile? player(int id) {
    for (final p in _players) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<PlayerSummary> squad(int teamId) => [
        for (var i = 1; i <= 11; i++)
          PlayerSummary(
            id: teamId * 100 + i,
            name: 'Oyuncu $i',
            position: i == 1
                ? 'G'
                : i <= 4
                    ? 'D'
                    : i <= 7
                        ? 'M'
                        : 'F',
            jerseyNumber: i,
          ),
      ];

  static List<SearchItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final items = <SearchItem>[
      for (final p in _players)
        SearchItem(
          kind: SearchKind.player,
          id: p.id,
          name: p.name,
          subtitle: p.teamName,
        ),
      for (final t in tournaments())
        SearchItem(
          kind: SearchKind.tournament,
          id: t.id,
          name: t.name,
          subtitle: t.countryName,
        ),
    ];
    return items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  static EventBundle bundleFor(MatchEvent event) {
    Map<String, dynamic> player(int id, String name, String pos, int number) => {
          'player': {'id': id, 'name': name, 'position': pos, 'jerseyNumber': number},
        };

    final home = Lineup.fromJson({
      'formation': '4-3-3',
      'players': [
        for (var i = 1; i <= 6; i++)
          player(event.home.id * 100 + i, '${event.home.name} Oyuncu $i', i == 1 ? 'G' : (i < 4 ? 'D' : 'M'), i),
      ],
    }, isHome: true);

    final away = Lineup.fromJson({
      'formation': '4-2-3-1',
      'players': [
        for (var i = 1; i <= 6; i++)
          player(event.away.id * 100 + i, '${event.away.name} Oyuncu $i', i == 1 ? 'G' : (i < 4 ? 'D' : 'M'), i),
      ],
    }, isHome: false);

    final statistics = MatchStatistics.fromJson({
      'statistics': [
        {
          'period': 'ALL',
          'groups': [
            {
              'groupName': 'Maç Özeti',
              'statisticsItems': [
                {'name': 'Topla oynama', 'home': '%58', 'away': '%42', 'homeValue': 58, 'awayValue': 42},
                {'name': 'Şut', 'home': '14', 'away': '9', 'homeValue': 14, 'awayValue': 9},
                {'name': 'İsabetli şut', 'home': '6', 'away': '3', 'homeValue': 6, 'awayValue': 3},
                {'name': 'Korner', 'home': '7', 'away': '4', 'homeValue': 7, 'awayValue': 4},
              ],
            },
          ],
        },
      ],
    });

    final incidents = [
      MatchIncident.fromJson({
        'type': 'goal',
        'matchTime': "23'",
        'player': {'name': '${event.home.name} Oyuncu 9'},
        'team': {'id': event.home.id},
        'homeScore': 1,
        'awayScore': 0,
      }),
      MatchIncident.fromJson({
        'type': 'goal',
        'matchTime': "51'",
        'player': {'name': '${event.away.name} Oyuncu 10'},
        'team': {'id': event.away.id},
        'homeScore': 1,
        'awayScore': 1,
      }),
      MatchIncident.fromJson({
        'type': 'goal',
        'matchTime': "64'",
        'player': {'name': '${event.home.name} Oyuncu 7'},
        'team': {'id': event.home.id},
        'homeScore': 2,
        'awayScore': 1,
      }),
    ];

    return EventBundle(
      event: event,
      statistics: statistics,
      incidents: incidents,
      homeLineup: home,
      awayLineup: away,
    );
  }
}
