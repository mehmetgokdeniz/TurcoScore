import '../models/event_details.dart';
import '../models/match_models.dart';
import '../models/player_models.dart';
import '../models/tournament_models.dart';

/// Uygulamanın tek veri sözleşmesi. Kaynak değişse de ekranlar aynı kalır.
abstract class ScoreDataSource {
  /// UI'da gösterilecek kaynak adı.
  String get name;

  Future<List<MatchEvent>> fetchEventsForDate(DateTime date);

  Future<List<MatchEvent>> fetchLiveEvents();

  Future<EventBundle> fetchEventBundle(MatchEvent preview);

  Future<List<Tournament>> fetchTournaments();

  Future<List<Season>> fetchSeasons(int tournamentId);

  Future<StandingsTable> fetchStandings(int tournamentId, int seasonId);

  Future<List<SearchItem>> search(String query);

  Future<PlayerProfile?> fetchPlayer(int playerId);

  /// [leagueSlug] bazı kaynaklarda kadro sorgusu için zorunludur (ESPN).
  Future<List<PlayerSummary>> fetchTeamSquad(int teamId, {String? leagueSlug});
}
