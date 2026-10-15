/// SofaScore'in resmi olmayan (internal) v1 endpoint'leri.
/// Tek merkezden yönetilir: API değişirse sadece bu dosya güncellenir.
class ApiConstants {
  ApiConstants._();

  /// Siteye ait API yolu birincil; resmi alt alan adı yedektir.
  /// İkisi de 403/ağ hatası verirse ApiClient sıradakine döner.
  static const List<String> baseUrls = [
    'https://www.sofascore.com/api/v1',
    'https://api.sofascore.com/api/v1',
  ];
  static const String sport = 'football';

  /// WAF, tarayıcı gibi görünmeyen istekleri 403 ile reddediyor.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String liveEvents() => '/sport/$sport/events/live';

  /// Günün maçları: birincil ve yedek yol.
  static List<String> eventsByDate(DateTime d) => [
        '/sport/$sport/scheduled-events/${date(d)}',
        '/sport/$sport/events/${date(d)}',
      ];

  static String event(int id) => '/event/$id';
  static String eventStatistics(int id) => '/event/$id/statistics';
  static String eventIncidents(int id) => '/event/$id/incidents';
  static String eventLineups(int id) => '/event/$id/lineups';

  static String tournaments() => '/sport/$sport/unique-tournaments';
  static String seasons(int tournamentId) =>
      '/unique-tournament/$tournamentId/seasons';

  static List<String> standings(int tournamentId, int seasonId) => [
        '/unique-tournament/$tournamentId/season/$seasonId/standings/total',
        '/unique-tournament/$tournamentId/season/$seasonId/standings',
      ];

  static String search() => '/search/all';
  static String player(int id) => '/player/$id';
  static String team(int id) => '/team/$id';
  static String teamPlayers(int id) => '/team/$id/players';
}
