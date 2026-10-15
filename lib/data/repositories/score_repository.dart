import '../../core/network/api_client.dart';
import '../demo/demo_data.dart';
import '../models/event_details.dart';
import '../models/match_models.dart';
import '../models/player_models.dart';
import '../models/tournament_models.dart';
import '../sources/espn_source.dart';
import '../sources/mackolik_client.dart';
import '../sources/score_data_source.dart';

/// Oyuncu profili hangi kaynaktan geleceği (arama sonucundan taşınır).
class PlayerProvider {
  PlayerProvider._();

  static const String espn = 'espn';
  static const String mackolik = 'mackolik';
}

/// Uygulamanın tek veri kapısı: aktif kaynağı çalıştırır ve kaynak
/// erişilemezse (ağ/403/429) demo veriye düşürür.
///
/// Kaynak değiştirme: `ScoreRepository(source: SofaScoreSource())`
/// (SofaScore'un WAF/captcha engeli kalktığında).
class ScoreRepository {
  ScoreRepository({ScoreDataSource? source}) : _source = source ?? EspnSource();

  final ScoreDataSource _source;
  final MackolikClient _mackolik = MackolikClient();
  bool _demo = false;

  bool get isDemo => _demo;
  String get sourceName => _source.name;

  MackolikClient get mackolik => _mackolik;

  Future<T> _live<T>(Future<T> Function() run, T Function() demo) async {
    if (_demo) return demo();
    try {
      return await run();
    } on ApiException catch (e) {
      if (e.isSourceUnavailable) {
        _demo = true;
        return demo();
      }
      rethrow;
    }
  }

  Future<List<MatchEvent>> fetchEventsForDate(DateTime date) => _live(
        () => _source.fetchEventsForDate(date),
        () => DemoData.eventsFor(date),
      );

  Future<List<MatchEvent>> fetchLiveEvents() =>
      _live(_source.fetchLiveEvents, DemoData.liveEvents);

  Future<EventBundle> fetchEventBundle(MatchEvent preview) => _live(
        () => _source.fetchEventBundle(preview),
        () => DemoData.bundleFor(preview),
      );

  Future<List<Tournament>> fetchTournaments() =>
      _live(_source.fetchTournaments, DemoData.tournaments);

  Future<List<Season>> fetchSeasons(int tournamentId) => _live(
        () => _source.fetchSeasons(tournamentId),
        () => DemoData.seasons(tournamentId),
      );

  /// Puan tablosu: önce ana kaynak; Türk liglerinde boşsa Maçkolik JSON'u.
  Future<StandingsTable> fetchStandings(int tournamentId, int seasonId) async {
    final table = await _live(
      () => _source.fetchStandings(tournamentId, seasonId),
      () => DemoData.standings(tournamentId),
    );
    if (table.rows.isNotEmpty || table.sections.isNotEmpty) return table;

    final mackolikSeason = MackolikClient.espnTournamentToSeason[tournamentId];
    if (mackolikSeason == null) return table;

    return _live(
      () => _mackolik.fetchStandings(mackolikSeason),
      () => DemoData.standings(tournamentId),
    );
  }

  /// Arama: Maçkolik (futbolcular) + ESPN (takım/lig).
  ///
  /// Oyuncu adı yazıldığında sonuç Maçkolik'ten gelir; bir kaynak
  /// erişilemezse diğeriyle sınırlı kalır.
  Future<List<SearchItem>> search(String query) async {
    List<SearchItem> espnResults = const [];
    try {
      espnResults = await _live(
        () => _source.search(query),
        () => DemoData.search(query),
      );
    } on ApiException {
      // ESPN kapalıysa Maçkolik sonucu yeterli olabilir.
    }

    List<SearchItem> mackolikResults = const [];
    try {
      mackolikResults = await _mackolik.search(query);
    } catch (_) {
      // Maçkolik erişilemezse arama ESPN ile devam eder.
    }

    final seen = <String>{};
    return [
      // Oyuncular en başta (kullanıcının aradığı genelde futbolcudur).
      for (final item in [...mackolikResults, ...espnResults])
        if (seen.add('${item.kind.name}-${item.id}')) item,
    ];
  }

  Future<PlayerProfile?> fetchPlayer(int playerId, {String? provider}) {
    if (provider == PlayerProvider.mackolik) {
      return _live(
        () => _mackolik.fetchPlayer(playerId),
        () => DemoData.player(playerId),
      );
    }
    return _live(
      () => _source.fetchPlayer(playerId),
      () => DemoData.player(playerId),
    );
  }

  Future<List<PlayerSummary>> fetchTeamSquad(int teamId, {String? leagueSlug}) =>
      _live(
        () => _source.fetchTeamSquad(teamId, leagueSlug: leagueSlug),
        () => DemoData.squad(teamId),
      );

  /// Kaynak durumunu sıfırla (yeniden denemek için).
  void resetSource() => _demo = false;
}
