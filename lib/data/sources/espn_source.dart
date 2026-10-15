import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/player_rating.dart';
import '../models/event_details.dart';
import '../models/match_models.dart';
import '../models/player_models.dart';
import '../models/tournament_models.dart';
import 'score_data_source.dart';

/// İzlenen turnuva konfigürasyonu. id, listeki sıradır (1..N) ve kalıcıdır.
enum EspnLeagueKind { league, cup, national }

class EspnLeague {
  const EspnLeague(
    this.slug,
    this.name,
    this.country, {
    this.kind = EspnLeagueKind.league,
  });

  final String slug;
  final String name;
  final String country;
  final EspnLeagueKind kind;
}

/// ESPN'in resmi olmayan açık API'si (anahtar gerekmez).
///
/// Kullanılan uç noktalar (2026-10'da canlı doğrulandı):
///  - site/v2  : scoreboard, summary, roster
///  - apis/v2  : standings  (`site/v2` yolu stub döndürür!)
///  - core v2  : athlete (ligsiz)
///  - common/v3: search (takım + lig; oyuncu sonucu yok)
class EspnSource implements ScoreDataSource {
  EspnSource({ApiClient? client})
      : _client = client ??
            ApiClient(
              baseUrls: const ['https://site.api.espn.com'],
              headers: const {'Accept-Language': 'en-US,en;q=0.9'},
            );

  static const String _coreBase = 'https://sports.core.api.espn.com';
  static const String _headshot =
      'https://a.espncdn.com/i/headshots/soccer/players/full/';

  static const List<EspnLeague> leagues = [
    // --- kulüp ligleri (id 1..10 sabit) ---
    EspnLeague('tur.1', 'Trendyol Süper Lig', 'Türkiye'),
    EspnLeague('tur.2', 'Trendyol 1. Lig', 'Türkiye'),
    EspnLeague('eng.1', 'Premier League', 'İngiltere'),
    EspnLeague('esp.1', 'La Liga', 'İspanya'),
    EspnLeague('ita.1', 'Serie A', 'İtalya'),
    EspnLeague('ger.1', 'Bundesliga', 'Almanya'),
    EspnLeague('fra.1', 'Ligue 1', 'Fransa'),
    EspnLeague('uefa.champions', 'Şampiyonlar Ligi', 'Avrupa',
        kind: EspnLeagueKind.cup),
    EspnLeague('uefa.europa', 'Avrupa Ligi', 'Avrupa',
        kind: EspnLeagueKind.cup),
    EspnLeague('ned.1', 'Eredivisie', 'Hollanda'),
    EspnLeague('por.1', 'Primeira Liga', 'Portekiz'),
    // --- ek kulüp ligleri ---
    EspnLeague('bra.1', 'Série A', 'Brezilya'),
    EspnLeague('arg.1', 'Liga Profesional', 'Arjantin'),
    EspnLeague('usa.1', 'MLS', 'ABD'),
    EspnLeague('mex.1', 'Liga MX', 'Meksika'),
    // --- kupalar ---
    EspnLeague('uefa.europa.conf', 'Konferans Ligi', 'Avrupa',
        kind: EspnLeagueKind.cup),
    EspnLeague('conmebol.libertadores', 'Libertadores', 'Güney Amerika',
        kind: EspnLeagueKind.cup),
    EspnLeague('conmebol.sudamericana', 'Sudamericana', 'Güney Amerika',
        kind: EspnLeagueKind.cup),
    EspnLeague('fifa.cwc', 'Kulüpler Dünya Kupası', 'Dünya',
        kind: EspnLeagueKind.cup),
    // --- milli takımlar ---
    EspnLeague('fifa.world', 'Dünya Kupası', 'Dünya',
        kind: EspnLeagueKind.national),
    EspnLeague('fifa.worldq.uefa', 'Dünya Kupası - Avrupa Elemeleri', 'Avrupa',
        kind: EspnLeagueKind.national),
    EspnLeague('fifa.worldq.conmebol', 'Dünya Kupası - Güney Amerika Elemeleri',
        'Güney Amerika', kind: EspnLeagueKind.national),
    EspnLeague('fifa.worldq.afc', 'Dünya Kupası - Asya Elemeleri', 'Asya',
        kind: EspnLeagueKind.national),
    EspnLeague('fifa.worldq.caf', 'Dünya Kupası - Afrika Elemeleri', 'Afrika',
        kind: EspnLeagueKind.national),
    EspnLeague('fifa.worldq.concacaf', 'Dünya Kupası - K. Amerika Elemeleri',
        'Kuzey Amerika', kind: EspnLeagueKind.national),
    EspnLeague('fifa.worldq.ofc', 'Dünya Kupası - Okyanusya Elemeleri',
        'Okyanusya', kind: EspnLeagueKind.national),
    EspnLeague('uefa.nations', 'UEFA Uluslar Ligi', 'Avrupa',
        kind: EspnLeagueKind.national),
    EspnLeague('uefa.euro', 'Avrupa Şampiyonası', 'Avrupa',
        kind: EspnLeagueKind.national),
    EspnLeague('uefa.euroq', 'Avrupa Şampiyonası Elemeleri', 'Avrupa',
        kind: EspnLeagueKind.national),
    EspnLeague('conmebol.america', 'Copa América', 'Güney Amerika',
        kind: EspnLeagueKind.national),
    EspnLeague('caf.nations', 'Afrika Uluslar Kupası', 'Afrika',
        kind: EspnLeagueKind.national),
    EspnLeague('concacaf.gold', 'Altın Kupa', 'Kuzey Amerika',
        kind: EspnLeagueKind.national),
    EspnLeague('concacaf.nations.league', 'CONCACAF Uluslar Ligi',
        'Kuzey Amerika', kind: EspnLeagueKind.national),
    EspnLeague('afc.asian.cup', 'Asya Kupası', 'Asya',
        kind: EspnLeagueKind.national),
    EspnLeague('fifa.friendly', 'Dostluk Maçları', 'Dünya',
        kind: EspnLeagueKind.national),
  ];

  /// Aynı anda istek atılan lig sayısı (API'yi boğmamak için).
  static const int _concurrency = 8;

  final ApiClient _client;

  @override
  String get name => 'ESPN';

  static EspnLeague? leagueById(int? id) {
    if (id == null || id < 1 || id > leagues.length) return null;
    return leagues[id - 1];
  }

  static EspnLeague? leagueBySlug(String? slug) {
    if (slug == null) return null;
    for (final league in leagues) {
      if (league.slug == slug) return league;
    }
    return null;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- maç listesi

  Future<List<MatchEvent>> _scoreboard(EspnLeague league, DateTime date) async {
    final json = await _client.get(
      '/apis/site/v2/sports/soccer/${league.slug}/scoreboard',
      queryParameters: {'dates': _dateKey(date)},
    );

    // Lig logosu yanıtla gelir: ek isteksiz önbelleğe yazılır.
    final leagueLogos = tryMapList(json['leagues']);
    String? logoUrl;
    if (leagueLogos.isNotEmpty) {
      final logos = tryMapList(leagueLogos.first['logos']);
      logoUrl = logos.isEmpty ? null : tryString(logos.first['href']);
      if (logoUrl != null) _leagueLogos[league.slug] = logoUrl;
    }
    logoUrl ??= _leagueLogos[league.slug];

    final events = <MatchEvent>[];
    for (final raw in tryMapList(json['events'])) {
      final event = _eventFrom(raw, league, logoUrl: logoUrl);
      if (event != null) events.add(event);
    }
    return events;
  }

  @override
  Future<List<MatchEvent>> fetchEventsForDate(DateTime date) =>
      _fetchAllLeagues(date, liveOnly: false);

  @override
  Future<List<MatchEvent>> fetchLiveEvents() =>
      _fetchAllLeagues(DateTime.now(), liveOnly: true);

  Future<List<MatchEvent>> _fetchAllLeagues(
    DateTime date, {
    required bool liveOnly,
  }) async {
    var failures = 0;
    ApiException? lastFailure;
    final collected = <MatchEvent>[];

    // 30+ lig tek seferde çağrılmaz; parçalı çalıştırıyoruz.
    for (var start = 0; start < leagues.length; start += _concurrency) {
      final end =
          start + _concurrency > leagues.length ? leagues.length : start + _concurrency;
      final chunk = leagues.sublist(start, end);

      await Future.wait(chunk.map((league) async {
        try {
          final events = await _scoreboard(league, date);
          collected.addAll(liveOnly ? events.where((e) => e.isLive) : events);
        } on ApiException catch (e) {
          failures++;
          lastFailure = e;
        }
      }));
    }

    // Kimse veri getirmediyse kaynağı kullanılamaz say ki demo yedeği devreye girsin.
    if (failures == leagues.length && collected.isEmpty) {
      throw lastFailure ?? ApiException('Maç listesi çekilemedi');
    }
    if (liveOnly) {
      collected.sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
    }
    return collected;
  }

  MatchEvent? _eventFrom(
    Map<String, dynamic> json,
    EspnLeague league, {
    String? logoUrl,
  }) {
    final id = tryInt(json['id']);
    if (id == null || id == 0) return null;

    final competitionList = tryMapList(json['competitions']);
    final competition = competitionList.isEmpty ? null : competitionList.first;
    final status = tryMap(json['status']) ?? tryMap(competition?['status']);
    final type = tryMap(status?['type']);
    final state = tryString(type?['state']) ?? 'pre';
    final detail = tryString(type?['detail']);
    final shortDetail = tryString(type?['shortDetail']);

    Map<String, dynamic>? homeJson;
    Map<String, dynamic>? awayJson;
    for (final competitor in tryMapList(competition?['competitors'])) {
      final side = tryString(competitor['homeAway']);
      if (side == 'home') homeJson = competitor;
      if (side == 'away') awayJson = competitor;
    }
    if (homeJson == null || awayJson == null) return null;

    final isFinished = state == 'post';
    final isLive = state == 'in';
    final postponed = (detail ?? '').toLowerCase().contains('postponed');

    String statusType;
    if (isFinished) {
      statusType = 'finished';
    } else if (isLive) {
      statusType = 'live';
    } else {
      statusType = postponed ? 'postponed' : 'notstarted';
    }

    String? description;
    if (isLive) {
      description = tryString(tryMap(status?['clock'])?['displayValue']) ??
          detail ??
          shortDetail;
    } else if (isFinished) {
      description = detail ?? shortDetail;
    } else {
      description = postponed ? detail : null;
    }

    int? score(Map<String, dynamic> competitor) => isFinished || isLive
        ? tryInt(competitor['score'])
        : null;

    String? winnerCode;
    if (isFinished) {
      final homeWon = homeJson['winner'] == true;
      final awayWon = awayJson['winner'] == true;
      winnerCode = homeWon
          ? 'home'
          : awayWon
              ? 'away'
              : 'draw';
    }

    final kickoff = _parseKickoff(json);

    return MatchEvent(
      id: id,
      startTimestamp: kickoff == null
          ? DateTime.now().millisecondsSinceEpoch ~/ 1000
          : kickoff.millisecondsSinceEpoch ~/ 1000,
      tournamentName: league.name,
      tournamentId: leagues.indexOf(league) + 1,
      countryName: league.country,
      tournamentFlagUrl: null,
      home: _teamOf(homeJson),
      away: _teamOf(awayJson),
      statusType: statusType,
      statusDescription: description,
      homeScore: score(homeJson),
      awayScore: score(awayJson),
      winnerCode: winnerCode,
      sourceKey: league.slug,
      tournamentLogoUrl: logoUrl ?? _leagueLogos[league.slug],
    );
  }

  /// Maç zamanı: skorboard/özet nesnesinde `date`, bazen yalnız
  /// `competitions[0].date` içinde gelir (header'da date olmaz!).
  DateTime? _parseKickoff(Map<String, dynamic> json) {
    final direct = tryString(json['date']);
    if (direct != null) {
      final parsed = DateTime.tryParse(direct);
      if (parsed != null) return parsed;
    }
    final competitions = tryMapList(json['competitions']);
    if (competitions.isNotEmpty) {
      final fromCompetition = tryString(competitions.first['date']);
      if (fromCompetition != null) return DateTime.tryParse(fromCompetition);
    }
    return null;
  }

  TeamRef _teamRef(Map<String, dynamic> team) {
    final id = tryInt(team['id']) ?? 0;
    // Tekli `logo` alanı, `logos[]` listesi ve CDN yedeği sırayla denenir.
    final single = tryString(team['logo']);
    final logos = tryMapList(team['logos']);
    final fromList = logos.isEmpty ? null : tryString(logos.first['href']);
    return TeamRef(
      id: id,
      name: tryString(team['displayName'] ?? team['name']) ?? 'Bilinmiyor',
      shortName: tryString(team['shortDisplayName'] ?? team['abbreviation']),
      logoUrl: single ??
          fromList ??
          (id > 0
              ? 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png'
              : null),
    );
  }

  TeamRef _teamOf(Map<String, dynamic> competitor) =>
      _teamRef(tryMap(competitor['team']) ?? const {});

  // ------------------------------------------------------------------ maç detayı

  @override
  Future<EventBundle> fetchEventBundle(MatchEvent preview) async {
    final league = leagueBySlug(preview.sourceKey) ??
        leagueById(preview.tournamentId);
    if (league == null) {
      throw ApiException('Lig anahtarı bulunamadı',
          statusCode: 404, path: '${preview.id}');
    }

    final json = await _client.get(
      '/apis/site/v2/sports/soccer/${league.slug}/summary',
      queryParameters: {'event': '${preview.id}'},
    );

    final header = tryMap(json['header']);
    final event = header == null ? preview : (_eventFrom(header, league) ?? preview);

    final boxscore = tryMap(json['boxscore']);

    return EventBundle(
      event: event,
      statistics: _statistics(boxscore),
      incidents: _incidents(event, json),
      homeLineup: _lineup(tryMapList(json['rosters']), isHome: true, event: event),
      awayLineup: _lineup(tryMapList(json['rosters']), isHome: false, event: event),
      form: _forms(json),
      headToHead: _headToHead(json),
    );
  }

  /// ESPN istatistik adlarını Türkçeleştirir; olmayan alanda orijinal etiket.
  static const Map<String, String> _statLabels = {
    'possession': 'Topla oynama',
    'ballPossession': 'Topla oynama',
    'possessionPercentage': 'Topla oynama',
    'possessionPct': 'Topla oynama',
    'totalShots': 'Şut',
    'shots': 'Şut',
    'shotsOnTarget': 'İsabetli şut',
    'shotPct': 'İsabet oranı',
    'penaltyKickGoals': 'Penaltı golleri',
    'penaltyKickShots': 'Penaltılar',
    'accuratePasses': 'İsabetli pas',
    'totalPasses': 'Toplam pas',
    'passPct': 'Pas isabeti',
    'accurateCrosses': 'İsabetli orta',
    'totalCrosses': 'Toplam orta',
    'crossPct': 'Orta isabeti',
    'totalLongBalls': 'Uzun paslar',
    'accurateLongBalls': 'İsabetli uzun pas',
    'longballPct': 'Uzun pas isabeti',
    'effectiveTackles': 'Müdahaleler',
    'totalTackles': 'Toplam müdahale',
    'tacklePct': 'Müdahale isabeti',
    'effectiveClearance': 'Uzaklaştırmalar',
    'totalClearance': 'Toplam uzaklaştırma',
    'shotsOffTarget': 'İsabetsiz şut',
    'blockedShots': 'Blok edilen şut',
    'shotsInsideBox': 'Ceza sahası içi şut',
    'shotsOutsideBox': 'Ceza sahası dışı şut',
    'foulsCommitted': 'Fauller',
    'fouls': 'Fauller',
    'yellowCards': 'Sarı kartlar',
    'redCards': 'Kırmızı kartlar',
    'offsides': 'Ofsayt',
    'wonCorners': 'Korner',
    'cornerKicks': 'Korner',
    'saves': 'Kurtarışlar',
    'passes': 'Pas',
    'passesCompleted': 'İsabetli pas',
    'passCompletion': 'Pas isabeti',
    'crosses': 'Ortalar',
    'crossesCompleted': 'İsabetli orta',
    'tackles': 'Müdahale',
    'interceptions': 'Kesmeler',
    'clearances': 'Uzaklaştırma',
    'duels': 'Düellolar',
    'duelsWon': 'Kazanılan düellolar',
    'aerialsWon': 'Hava topu kazanma',
    'expectedGoals': 'Beklenen gol (xG)',
    'goals': 'Gol',
    'goalsConceded': 'Yenilen gol',
    'ballRecoveries': 'Top kazanma',
    'throwIns': 'Taç atışı',
    'goalKicks': 'Kale vuruşu',
    'penaltiesTaken': 'Penaltı',
    'subsTotal': 'Oyuncu değişikliği',
  };

  MatchStatistics _statistics(Map<String, dynamic>? boxscore) {
    final teams = tryMapList(boxscore?['teams']);
    if (teams.length < 2) return MatchStatistics.empty;

    final order = <String>[];
    final labels = <String, String>{};
    final home = <String, String>{};
    final away = <String, String>{};
    final homeValue = <String, double>{};
    final awayValue = <String, double>{};

    for (final teamStats in teams) {
      final isHome = tryString(teamStats['homeAway']) == 'home';
      final target = isHome ? home : away;
      final targetValue = isHome ? homeValue : awayValue;

      for (final stat in tryMapList(teamStats['statistics'])) {
        final key = tryString(stat['name']);
        if (key == null) continue;
        final display = tryString(stat['displayValue']) ?? '-';
        target[key] = display;
        labels.putIfAbsent(
          key,
          () => _statLabels[key] ?? tryString(stat['label']) ?? key,
        );
        final value = _numberFrom(display);
        if (value != null) targetValue[key] = value;
        if (!order.contains(key)) order.add(key);
      }
    }

    final items = [
      for (final key in order)
        if (home.containsKey(key) || away.containsKey(key))
          StatItem(
            name: labels[key] ?? key,
            home: home[key] ?? '-',
            away: away[key] ?? '-',
            homeValue: homeValue[key],
            awayValue: awayValue[key],
          ),
    ];

    if (items.isEmpty) return MatchStatistics.empty;
    return MatchStatistics(groups: [
      StatGroup(name: 'Takım İstatistikleri', items: items),
    ]);
  }

  /// Takımların son maçları (G/B/M) — `lastFiveGames`.
  List<TeamForm> _forms(Map<String, dynamic>? summary) {
    final forms = <TeamForm>[];
    for (final entry in tryMapList(summary?['lastFiveGames'])) {
      final team = tryMap(entry['team']) ?? const {};
      final teamId = tryInt(team['id']) ?? 0;
      final results = <String>[];
      for (final match in tryMapList(entry['events'])) {
        final result = tryString(match['gameResult']);
        if (result != null &&
            (result == 'W' || result == 'D' || result == 'L')) {
          results.add(result);
        }
      }
      if (results.isEmpty) continue;
      forms.add(TeamForm(
        teamId: teamId,
        teamName: tryString(team['displayName'] ?? team['name']) ?? '',
        logoUrl: _firstLogo(team) ??
            (teamId > 0
                ? 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png'
                : null),
        results: results.length > 5 ? results.sublist(results.length - 5) : results,
      ));
    }
    return forms;
  }

  /// İki takım arasındaki geçmiş maçlar — `seasonseries` (head-to-head).
  ///
  /// Alan bir **liste**: her eleman bir seri objesidir
  /// (`{type: 'head-to-head', events: [...]}`).
  List<HeadToHeadMatch> _headToHead(Map<String, dynamic>? summary) {
    final rawSeries = summary?['seasonseries'];
    final seriesList = rawSeries is List
        ? rawSeries
        : rawSeries == null
            ? const []
            : [rawSeries];

    final matches = <HeadToHeadMatch>[];
    for (final rawSeriesEntry in seriesList) {
      final series = tryMap(rawSeriesEntry);
      if (series == null) continue;
      final seriesType = (tryString(series['type']) ?? '').toLowerCase();
      if (seriesType.isNotEmpty && !seriesType.contains('head-to-head')) continue;

      for (final raw in tryMapList(series['events'])) {
        Map<String, dynamic>? home;
        Map<String, dynamic>? away;
        for (final competitor in tryMapList(raw['competitors'])) {
          final side = tryString(competitor['homeAway']);
          if (side == 'home') home = competitor;
          if (side == 'away') away = competitor;
        }
        if (home == null || away == null) continue;

        final homeTeam = tryMap(home['team']) ?? const {};
        final awayTeam = tryMap(away['team']) ?? const {};

        int? homeScore = tryInt(home['score']) ?? tryInt(home['homeScore']);
        int? awayScore = tryInt(away['score']) ?? tryInt(away['awayScore']);
        final scoreText = tryString(raw['score']);
        if ((homeScore == null || awayScore == null) &&
            scoreText != null &&
            scoreText.contains('-')) {
          final parts = scoreText.split('-');
          homeScore ??= int.tryParse(parts.first.trim());
          if (parts.length > 1) awayScore ??= int.tryParse(parts[1].trim());
        }

        final dateText = tryString(raw['date']);
        final parsed = dateText == null ? null : DateTime.tryParse(dateText);

        matches.add(HeadToHeadMatch(
          id: tryInt(raw['id']) ?? 0,
          startTimestamp:
              parsed == null ? 0 : parsed.millisecondsSinceEpoch ~/ 1000,
          homeName: tryString(homeTeam['displayName']) ?? '',
          awayName: tryString(awayTeam['displayName']) ?? '',
          homeLogoUrl: _firstLogo(homeTeam),
          awayLogoUrl: _firstLogo(awayTeam),
          homeScore: homeScore,
          awayScore: awayScore,
          isFinished: tryString(raw['status']) == 'post',
        ));
      }
    }
    return matches;
  }

  /// Özetin dakika dakika olay akışı.
  ///
  /// Birincil kaynak `keyEvents` (type.text + katılımcılar + saat); yoksa
  /// `header.competitions[0].details` kullanılır. Etiketler Türkçedir.
  List<MatchIncident> _incidents(
    MatchEvent event,
    Map<String, dynamic>? summary,
  ) {
    var events = tryMapList(summary?['keyEvents']);
    if (events.isEmpty) {
      final header = tryMap(summary?['header']);
      final competitionList = tryMapList(header?['competitions']);
      final competition =
          competitionList.isEmpty ? null : competitionList.first;
      events = tryMapList(competition?['details']);
    }

    final incidents = <MatchIncident>[];
    var homeScore = 0;
    var awayScore = 0;

    for (final entry in events) {
      final type = tryMap(entry['type']);
      final rawText =
          tryString(type?['text']) ?? tryString(entry['shortText']) ?? '';
      final rawKey = (tryString(type?['type']) ?? rawText).toLowerCase();

      final isScoringPlay =
          entry['scoringPlay'] == true && entry['shootout'] != true;
      final isRed = entry['redCard'] == true || rawKey.contains('red');
      final isYellow = entry['yellowCard'] == true || rawKey.contains('yellow');

      String kind;
      if (isScoringPlay) {
        kind = rawKey.contains('penalty') ? 'penalty' : 'goal';
      } else if (rawKey.contains('subst')) {
        kind = 'substitution';
      } else if (isRed || isYellow) {
        kind = 'card';
      } else if (rawKey.contains('var')) {
        kind = 'var';
      } else {
        kind = 'other';
      }

      final teamId = tryInt(tryMap(entry['team'])?['id']);
      int? home;
      int? away;
      if (isScoringPlay) {
        if (teamId == event.home.id) {
          homeScore++;
        } else if (teamId == event.away.id) {
          awayScore++;
        }
        home = homeScore;
        away = awayScore;
      }

      // Oyuncu adları `participants[].athlete` altında (1-2 kişi olabilir).
      final names = <String>[];
      for (final participant in tryMapList(entry['participants'])) {
        final name =
            tryString(tryMap(participant['athlete'])?['displayName']);
        if (name != null && name.isNotEmpty && !names.contains(name)) {
          names.add(name);
        }
      }

      incidents.add(MatchIncident(
        type: kind,
        minute: tryString(tryMap(entry['clock'])?['displayValue']) ?? '-',
        playerName: names.isEmpty ? null : names.join(' / '),
        teamId: teamId,
        homeScore: home,
        awayScore: away,
        text: _incidentLabel(rawText, kind, isRed: isRed),
      ));
    }
    return incidents;
  }

  /// Olay etiketini Türkçeleştirir.
  String _incidentLabel(String rawText, String kind, {bool isRed = false}) {
    final lower = rawText.toLowerCase();
    switch (kind) {
      case 'goal':
        if (lower.contains('own')) return 'Kendi kalesine gol';
        if (lower.contains('head')) return 'Kafa golü';
        return 'Gol';
      case 'penalty':
        if (lower.contains('miss') || lower.contains('save') ||
            lower.contains('awarded')) {
          return lower.contains('awarded') ? 'Penaltı verildi' : 'Penaltı kaçtı';
        }
        return 'Penaltı golü';
      case 'card':
        if (isRed || lower.contains('red')) return 'Kırmızı kart';
        if (lower.contains('second')) return 'İkinci sarı kart';
        return 'Sarı kart';
      case 'substitution':
        return 'Oyuncu değişikliği';
      case 'var':
        return 'VAR';
      default:
        const known = <String, String>{
          'corner kick': 'Korner',
          'corner': 'Korner',
          'offside': 'Ofsayt',
          'foul': 'Faul',
          'penalty': 'Penaltı',
          'substitution': 'Oyuncu değişikliği',
          'yellow card': 'Sarı kart',
          'red card': 'Kırmızı kart',
          'goal': 'Gol',
          'var': 'VAR',
        };
        final mapped = known[lower.trim()];
        if (mapped != null) return mapped;
        return rawText.trim().isEmpty ? 'Maç olayı' : rawText.trim();
    }
  }

  Lineup _lineup(
    List<Map<String, dynamic>> rosters, {
    required bool isHome,
    required MatchEvent event,
  }) {
    for (final entry in rosters) {
      if ((tryString(entry['homeAway']) == 'home') != isHome) continue;

      final players = <LineupPlayer>[];
      for (final row in tryMapList(entry['roster'])) {
        final athlete = tryMap(row['athlete']) ?? const {};
        final id = tryInt(athlete['id']) ?? 0;
        final positionCode = tryString(tryMap(row['position'])?['abbreviation']);

        final statValues = <String, double>{};
        for (final stat in tryMapList(row['stats'])) {
          final key = tryString(stat['name']);
          if (key == null) continue;
          final value = tryDouble(stat['value']) ??
              _numberFrom(tryString(stat['displayValue']) ?? '');
          if (value != null) statValues[key] = value;
        }

        // ESPN puan yayımlamaz: maç oynandıysa istatistikten türetilir (tahmini).
        double? rating;
        if (event.isFinished || event.isLive) {
          rating = estimatePlayerRating(
            stats: statValues,
            positionCode: positionCode,
            winnerCode: event.isFinished ? event.winnerCode : null,
            isHome: isHome,
          );
        }

        players.add(LineupPlayer(
          player: PlayerSummary(
            id: id,
            name: tryString(athlete['displayName'] ?? athlete['fullName']) ??
                'Bilinmeyen',
            position: positionCode,
            jerseyNumber: tryInt(row['jersey']),
            photoUrl: id > 0 ? '$_headshot$id.png' : null,
          ),
          isHome: isHome,
          jerseyNumber: tryInt(row['jersey']),
          position: positionCode,
          rating: rating,
          isStarter: row['starter'] == true,
        ));
      }

      // İlk 11 önce, yedekler sonra.
      final ordered = <LineupPlayer>[
        for (final player in players.where((p) => p.isStarter)) player,
        for (final player in players.where((p) => !p.isStarter)) player,
      ];

      return Lineup(formation: _formation(entry['formation']), players: ordered);
    }
    return Lineup.empty;
  }

  String? _formation(dynamic value) {
    if (value is String) return value;
    final map = tryMap(value);
    if (map == null) return null;
    return tryString(map['displayValue'] ?? map['name']);
  }

  // ---------------------------------------------------------------------- ligler

  /// Slug -> lig logosu (çekirdek lig ucundan bir kez alınır, bellekte tutulur).
  static final Map<String, String> _leagueLogos = {};

  @override
  Future<List<Tournament>> fetchTournaments() async {
    final currentYear = DateTime.now().year;
    final tournaments = [
      for (var i = 0; i < leagues.length; i++)
        Tournament(
          id: i + 1,
          name: leagues[i].name,
          countryName: leagues[i].country,
          slug: leagues[i].slug,
          currentSeasonId: currentYear,
          category: leagues[i].kind.name,
          logoUrl: _leagueLogos[leagues[i].slug],
        ),
    ];

    // Eksik logoları paralel tamamla (ilk açılışta bir kez çalışır).
    final missing = [
      for (final league in leagues)
        if (!_leagueLogos.containsKey(league.slug)) league,
    ];
    for (var start = 0; start < missing.length; start += _concurrency) {
      final end = start + _concurrency > missing.length
          ? missing.length
          : start + _concurrency;
      await Future.wait(missing.sublist(start, end).map((league) async {
        try {
          final json = await _client.getAt(
            _coreBase,
            '/v2/sports/soccer/leagues/${league.slug}',
            queryParameters: {'lang': 'en', 'region': 'us'},
          );
          final logos = tryMapList(json['logos']);
          final url = logos.isEmpty ? null : tryString(logos.first['href']);
          if (url != null) _leagueLogos[league.slug] = url;
        } on ApiException {
          // logo opsiyonel: hata sessiz geçilir
        }
      }));
    }

    return [
      for (final tournament in tournaments)
        Tournament(
          id: tournament.id,
          name: tournament.name,
          countryName: tournament.countryName,
          slug: tournament.slug,
          currentSeasonId: tournament.currentSeasonId,
          category: tournament.category,
          logoUrl: _leagueLogos[tournament.slug],
        ),
    ];
  }

  @override
  Future<List<Season>> fetchSeasons(int tournamentId) async {
    final league = leagueById(tournamentId);
    if (league == null) {
      throw ApiException('Lig bulunamadı', statusCode: 404);
    }

    // Sezonsuz istek ESPN'in "son dolu" sezonunu döndürür; `seasons` tümünü listeler.
    final json =
        await _client.get('/apis/v2/sports/soccer/${league.slug}/standings');
    final defaultYear = tryInt(tryMap(json['season'])?['year']);

    final years = <int>{};
    if (defaultYear != null) years.add(defaultYear);
    for (final season in tryMapList(json['seasons'])) {
      final year = tryInt(season['year']);
      if (year != null) years.add(year);
    }
    if (years.isEmpty) {
      final now = DateTime.now().year;
      years.addAll([now, now - 1]);
    }

    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final year in sorted)
        Season(
          id: year,
          name: _seasonName(year),
          isCurrent: year == (defaultYear ?? sorted.first),
        ),
    ];
  }

  static String _seasonName(int year) =>
      '$year-${(year + 1).toString().substring(2)}';

  @override
  Future<StandingsTable> fetchStandings(int tournamentId, int seasonId) async {
    final league = leagueById(tournamentId);
    if (league == null) {
      throw ApiException('Lig bulunamadı', statusCode: 404);
    }

    const path = '/apis/v2/sports/soccer';
    var json = await _client.get('$path/${league.slug}/standings',
        queryParameters: {'season': '$seasonId'});
    var table = _standingsFrom(json);

    if (!table.hasSections && table.rows.isEmpty) {
      // İstenen sezon boşsa ESPN'in varsayılan (son dolu) sezonuna düşeriz.
      json = await _client.get('$path/${league.slug}/standings');
      table = _standingsFrom(json);
    }
    return table;
  }

  StandingsTable _standingsFrom(Map<String, dynamic> json) {
    final children = tryMapList(json['children']);
    if (children.isEmpty) return const StandingsTable(rows: []);

    List<StandingRow> rowsOf(Map<String, dynamic> child) {
      final rows = <StandingRow>[];
      final standings = tryMap(child['standings']);
      for (final entry in tryMapList(standings?['entries'])) {
        rows.add(_standingRow(entry, rows.length + 1));
      }
      return rows;
    }

    if (children.length == 1) {
      return StandingsTable(rows: rowsOf(children.first));
    }

    // Turnuvalarda her çocuk bir grup: "Group A" -> "A Grubu".
    final sections = <StandingSection>[];
    final flat = <StandingRow>[];
    for (final child in children) {
      final rows = rowsOf(child);
      if (rows.isEmpty) continue;
      sections.add(StandingSection(
        name: _sectionName(tryString(child['name']) ?? ''),
        rows: rows,
      ));
      flat.addAll(rows);
    }

    if (sections.length <= 1) {
      return StandingsTable(rows: flat);
    }
    return StandingsTable(rows: flat, sections: sections);
  }

  String _sectionName(String raw) {
    final group = RegExp(r'Group\s+(.+)', caseSensitive: false).firstMatch(raw);
    if (group != null) return '${group.group(1)} Grubu';
    if (raw.toLowerCase().contains('league phase')) return 'Lig aşaması';
    return raw;
  }

  StandingRow _standingRow(Map<String, dynamic> entry, int fallbackPosition) {
    final stats = <String, double>{};
    for (final stat in tryMapList(entry['stats'])) {
      final key = tryString(stat['name']);
      if (key == null) continue;
      final value = tryDouble(stat['value']) ?? _numberFrom(tryString(stat['displayValue']) ?? '');
      if (value != null) stats[key] = value;
    }

    int numberOf(String key) => (stats[key] ?? 0).round();
    final note = entry['note'];

    return StandingRow(
      position: numberOf('rank') == 0 ? fallbackPosition : numberOf('rank'),
      team: _teamRef(tryMap(entry['team']) ?? const {}),
      matches: numberOf('gamesPlayed'),
      won: numberOf('wins'),
      drawn: numberOf('ties'),
      lost: numberOf('losses'),
      goalsFor: numberOf('pointsFor'),
      goalsAgainst: numberOf('pointsAgainst'),
      points: numberOf('points'),
      promotionText: note is String
          ? note
          : tryString(tryMap(note)?['text']),
    );
  }

  // ---------------------------------------------------------------------- arama

  /// Takım dizini: slug -> o ligdeki tüm takımlar.
  ///
  /// ESPN'in arama ucu metin araması yapmaz (popülerlik listesi döner), bu
  /// yüzden arama izlenen liglerin kadroları üzerinden yerel yapılır.
  static final Map<String, List<SearchItem>> _teamIndex = {};

  Future<void> _ensureTeamIndex() async {
    final missing = [
      for (final league in leagues)
        if (!_teamIndex.containsKey(league.slug)) league,
    ];
    if (missing.isEmpty) return;

    for (var start = 0; start < missing.length; start += _concurrency) {
      final end = start + _concurrency > missing.length
          ? missing.length
          : start + _concurrency;
      await Future.wait(missing.sublist(start, end).map((league) async {
        try {
          final json = await _client
              .get('/apis/site/v2/sports/soccer/${league.slug}/teams');
          final items = <SearchItem>[];
          for (final sport in tryMapList(json['sports'])) {
            for (final leagueEntry in tryMapList(sport['leagues'])) {
              for (final entry in tryMapList(leagueEntry['teams'])) {
                final team = tryMap(entry['team']) ?? entry;
                final id = tryInt(team['id']);
                final name = tryString(team['displayName'] ?? team['name']);
                if (id == null || id == 0 || name == null) continue;
                items.add(SearchItem(
                  kind: SearchKind.team,
                  id: id,
                  name: name,
                  subtitle: league.name,
                  sourceKey: league.slug,
                  logoUrl: _firstLogo(team) ??
                      'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png',
                ));
              }
            }
          }
          _teamIndex[league.slug] = items;
        } on ApiException {
          _teamIndex[league.slug] = const [];
        }
      }));
    }
  }

  @override
  Future<List<SearchItem>> search(String query) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return const [];

    // İlk aramada tüm izlenen liglerden takım dizini kurulur (sonrasi anlık).
    await _ensureTeamIndex();

    final scored = <MapEntry<SearchItem, int>>[];

    // 1) Lig / turnuva adları (yerel konfigürasyon).
    for (var i = 0; i < leagues.length; i++) {
      final league = leagues[i];
      if (!_normalize('${league.name} ${league.country}').contains(normalized)) {
        continue;
      }
      scored.add(MapEntry(
        SearchItem(
          kind: SearchKind.tournament,
          id: i + 1,
          name: league.name,
          subtitle: league.country,
          sourceKey: league.slug,
          logoUrl: _leagueLogos[league.slug],
        ),
        _normalize(league.name).startsWith(normalized) ? 0 : 1,
      ));
    }

    // 2) Takım dizini (tüm izlenen ligler).
    for (final teams in _teamIndex.values) {
      for (final item in teams) {
        if (!_normalize('${item.name} ${item.subtitle ?? ''}')
            .contains(normalized)) {
          continue;
        }
        scored.add(MapEntry(
          item,
          _normalize(item.name).startsWith(normalized) ? 0 : 1,
        ));
      }
    }

    scored.sort((a, b) {
      if (a.value != b.value) return a.value.compareTo(b.value);
      return a.key.name.compareTo(b.key.name);
    });
    final seen = <String>{};
    return [
      for (final entry in scored)
        if (seen.add('${entry.key.kind.name}-${entry.key.id}')) entry.key,
    ];
  }

  /// Türkçe karakter/boşluk duyarsız normalizasyon ("Süper Lig" -> "superlig").
  static String _normalize(String value) {
    var text = value.toLowerCase();
    const map = <String, String>{
      'ı': 'i', 'i̇': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c',
      'â': 'a', 'î': 'i', 'û': 'u',
    };
    map.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAll(RegExp('[^a-z0-9]'), '');
  }

  String? _firstLogo(Map<String, dynamic> json) {
    final logos = tryMapList(json['logos']);
    if (logos.isNotEmpty) return tryString(logos.first['href']);
    return tryString(json['logo']);
  }

  // -------------------------------------------------------------------- oyuncu

  @override
  Future<PlayerProfile?> fetchPlayer(int playerId) async {
    final json = await _client.getAt(
      _coreBase,
      '/v2/sports/soccer/athletes/$playerId',
    );
    final id = tryInt(json['id']);
    if (id == null) return null;

    final position = tryMap(json['position']);
    final heightInches = tryDouble(json['height']);
    final weightPounds = tryDouble(json['weight']);
    final team = tryMap(json['team']);

    return PlayerProfile(
      id: id,
      name: tryString(json['displayName'] ?? json['fullName']) ?? 'Oyuncu',
      teamName: tryString(team?['displayName']),
      position: tryString(position?['abbreviation']),
      countryName:
          tryString(json['citizenship']) ?? tryString(tryMap(json['flag'])?['alt']),
      jerseyNumber: tryInt(json['jersey']),
      photoUrl: '$_headshot$id.png',
      age: tryInt(json['age']),
      height: heightInches == null ? null : (heightInches * 2.54).round(),
      weight: weightPounds == null ? null : (weightPounds * 0.45359237).round(),
      preferredFoot: tryString(json['preferredFoot']),
    );
  }

  @override
  Future<List<PlayerSummary>> fetchTeamSquad(
    int teamId, {
    String? leagueSlug,
  }) async {
    if (leagueSlug == null) {
      throw ApiException('Lig anahtarı gerekli', statusCode: 400);
    }

    final json = await _client.get(
      '/apis/site/v2/sports/soccer/$leagueSlug/teams/$teamId/roster',
    );

    final teamName = tryString(tryMap(json['team'])?['displayName']);
    return [
      for (final raw in tryMapList(json['athletes']))
        _athleteSummary(raw, teamName),
    ];
  }

  PlayerSummary _athleteSummary(Map<String, dynamic> json, String? teamName) {
    final id = tryInt(json['id']) ?? 0;
    final position = tryMap(json['position']);
    final headshot = tryMap(json['headshot']);
    return PlayerSummary(
      id: id,
      name: tryString(json['displayName'] ?? json['fullName']) ?? 'Oyuncu',
      teamName: teamName,
      position: tryString(position?['abbreviation']),
      countryName: tryString(json['citizenship']),
      jerseyNumber: tryInt(json['jersey']),
      photoUrl: tryString(headshot?['href']) ??
          (id > 0 ? '$_headshot$id.png' : null),
    );
  }

  // ---------------------------------------------------------------- yardımcılar

  /// "58%" / "11" / "+3" gibi metinlerden sayı çıkarır.
  static double? _numberFrom(String raw) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }
}
