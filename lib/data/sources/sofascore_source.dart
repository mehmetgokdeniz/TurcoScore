import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/event_details.dart';
import '../models/match_models.dart';
import '../models/player_models.dart';
import '../models/tournament_models.dart';
import 'score_data_source.dart';

/// SofaScore resmi olmayan v1 uç noktaları.
///
/// Not: 2026-10 itibarıyla bu ağdan tüm SofaScore alan adları WAF/captcha
/// ile 403 döndüğü için kaynak pasif; kod ve uç noktalar korunmuştur.
/// Yeniden etkinleştirmek için `ScoreRepository(source: SofaScoreSource())`.
class SofaScoreSource implements ScoreDataSource {
  SofaScoreSource({ApiClient? client})
      : _client = client ??
            ApiClient(
              baseUrls: ApiConstants.baseUrls,
              headers: const {
                'Accept-Language': 'tr-TR,tr;q=0.9',
                'Referer': 'https://www.sofascore.com/tr',
              },
            );

  final ApiClient _client;

  @override
  String get name => 'SofaScore';

  Future<Map<String, dynamic>> _getAny(
    List<String> paths, {
    Map<String, String>? queryParameters,
  }) async {
    ApiException? last;
    for (final path in paths) {
      try {
        return await _client.get(path, queryParameters: queryParameters);
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          last = e;
          continue;
        }
        rethrow;
      }
    }
    throw last ?? ApiException('Uç nokta bulunamadı');
  }

  @override
  Future<List<MatchEvent>> fetchEventsForDate(DateTime date) async {
    final json = await _getAny(ApiConstants.eventsByDate(date));
    return tryMapList(json['events']).map(MatchEvent.fromJson).toList();
  }

  @override
  Future<List<MatchEvent>> fetchLiveEvents() async {
    final json = await _client.get(ApiConstants.liveEvents());
    return tryMapList(json['events']).map(MatchEvent.fromJson).toList();
  }

  @override
  Future<EventBundle> fetchEventBundle(MatchEvent preview) async {
    final detail = await _client.get(ApiConstants.event(preview.id));
    final event = MatchEvent.fromJson(tryMap(detail['event']) ?? detail);

    final results = await Future.wait([
      _client.get(ApiConstants.eventStatistics(preview.id)).catchError(
            (Object _) => <String, dynamic>{'statistics': <dynamic>[]},
          ),
      _client.get(ApiConstants.eventIncidents(preview.id)).catchError(
            (Object _) => <String, dynamic>{'incidents': <dynamic>[]},
          ),
      _client.get(ApiConstants.eventLineups(preview.id)).catchError(
            (Object _) => <String, dynamic>{},
          ),
    ]);

    final lineups = results[2];
    return EventBundle(
      event: event.id == 0 ? preview : event,
      statistics: MatchStatistics.fromJson(results[0]),
      incidents: tryMapList(results[1]['incidents'])
          .map(MatchIncident.fromJson)
          .toList(),
      homeLineup:
          Lineup.fromJson(tryMap(lineups['home']) ?? const {}, isHome: true),
      awayLineup:
          Lineup.fromJson(tryMap(lineups['away']) ?? const {}, isHome: false),
    );
  }

  @override
  Future<List<Tournament>> fetchTournaments() async {
    final json = await _client.get(ApiConstants.tournaments());
    final list = tryMapList(json['uniqueTournaments'] ?? json['tournaments']);
    return list.map(Tournament.fromJson).toList();
  }

  @override
  Future<List<Season>> fetchSeasons(int tournamentId) async {
    final json = await _client.get(ApiConstants.seasons(tournamentId));
    final current = tryMap(json['currentSeason']);
    final currentId = tryInt(current?['id']);
    final seasons = tryMapList(json['seasons']).map((s) {
      final season = Season.fromJson(s);
      return Season(
        id: season.id,
        name: season.name,
        isCurrent: season.id == currentId,
      );
    }).toList();
    if (seasons.isEmpty && current != null) {
      return [Season.fromJson(current, isCurrent: true)];
    }
    return seasons;
  }

  @override
  Future<StandingsTable> fetchStandings(int tournamentId, int seasonId) async {
    final json = await _getAny(ApiConstants.standings(tournamentId, seasonId));
    return StandingsTable.fromJson(json);
  }

  @override
  Future<List<SearchItem>> search(String query) async {
    final json = await _client.get(ApiConstants.search(),
        queryParameters: {'q': query});
    return _parseSearch(json);
  }

  @override
  Future<PlayerProfile?> fetchPlayer(int playerId) async {
    final json = await _client.get(ApiConstants.player(playerId));
    final player = tryMap(json['player']);
    if (player == null || player['id'] == null) return null;
    return PlayerProfile.fromJson(player);
  }

  @override
  Future<List<PlayerSummary>> fetchTeamSquad(
    int teamId, {
    String? leagueSlug,
  }) async {
    final json = await _client.get(ApiConstants.teamPlayers(teamId));
    return tryMapList(json['players']).map((entry) {
      return PlayerSummary.fromJson(tryMap(entry['player']) ?? entry);
    }).toList();
  }

  List<SearchItem> _parseSearch(Map<String, dynamic> json) {
    final items = <SearchItem>[];

    void addByType(String rawType, Map<String, dynamic> entity) {
      final type = rawType.toLowerCase();
      final id = tryInt(entity['id']);
      if (id == null || id == 0) return;
      final name = tryString(entity['name']);
      if (name == null) return;
      if (type.contains('player')) {
        items.add(SearchItem(
          kind: SearchKind.player,
          id: id,
          name: name,
          subtitle: tryString(
              tryMap(entity['team'])?['name'] ?? entity['position']),
        ));
      } else if (type.contains('team')) {
        items.add(SearchItem(
          kind: SearchKind.team,
          id: id,
          name: name,
          subtitle: tryString(tryMap(entity['tournament'])?['name'] ??
              tryMap(entity['category'])?['name']),
        ));
      } else if (type.contains('tournament') || type.contains('competition')) {
        items.add(SearchItem(
          kind: SearchKind.tournament,
          id: id,
          name: name,
          subtitle: tryString(tryMap(entity['category'])?['name']),
        ));
      }
    }

    // Şekil 1: {searchResults: [{entityType, entity}]}
    for (final entry in tryMapList(json['searchResults'])) {
      addByType(
        tryString(entry['entityType']) ?? '',
        tryMap(entry['entity']) ?? entry,
      );
    }

    // Şekil 2: {players:[{player:{}}], teams:[{team:{}}], tournaments:[...]}
    const buckets = {
      'players': 'player',
      'teams': 'team',
      'tournaments': 'tournament',
      'categories': 'tournament',
    };
    for (final bucket in buckets.entries) {
      for (final entry in tryMapList(json[bucket.key])) {
        final singular =
            bucket.key.endsWith('s') ? bucket.key.substring(0, bucket.key.length - 1) : bucket.key;
        addByType(bucket.value, tryMap(entry[singular]) ?? entry);
      }
    }

    final seen = <String>{};
    return items.where((i) => seen.add('${i.kind.name}-${i.id}')).toList();
  }
}
