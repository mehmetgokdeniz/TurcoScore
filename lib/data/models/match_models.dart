import '../../core/utils/json_utils.dart';

class TeamRef {
  const TeamRef({
    required this.id,
    required this.name,
    this.shortName,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String? shortName;
  final String? logoUrl;

  factory TeamRef.fromJson(Map<String, dynamic>? json) {
    final id = tryInt(json?['id']) ?? 0;
    final logo = tryString(json?['userImage'] ?? json?['mediumImage'] ?? json?['logoUrl']);
    return TeamRef(
      id: id,
      name: tryString(json?['name'] ?? json?['shortName']) ?? 'Bilinmiyor',
      shortName: tryString(json?['shortName']),
      // SofaScore görselleri ayrı CDN'de; sabit URL yedek olarak çalışır.
      logoUrl: (logo == null || logo.isEmpty) && id > 0
          ? 'https://api.sofascore.com/api/v1/team/$id/image'
          : logo,
    );
  }

  String get displayInitials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) return list.first.initial;
    return list.first.initial + list.last.initial;
  }
}

extension on String {
  /// İlk harfi büyük; emoji/aksan korunur.
  String get initial => isEmpty ? '' : substring(0, 1).toUpperCase();
}

class MatchEvent {
  const MatchEvent({
    required this.id,
    required this.startTimestamp,
    required this.tournamentName,
    required this.tournamentId,
    required this.countryName,
    required this.tournamentFlagUrl,
    required this.home,
    required this.away,
    required this.statusType,
    required this.statusDescription,
    this.homeScore,
    this.awayScore,
    this.homePenalties,
    this.awayPenalties,
    this.winnerCode,
    this.sourceKey,
    this.tournamentLogoUrl,
  });

  final int id;
  final int startTimestamp;
  final String tournamentName;
  final int? tournamentId;
  final String? countryName;
  final String? tournamentFlagUrl;
  final TeamRef home;
  final TeamRef away;
  final String statusType;
  final String? statusDescription;
  final int? homeScore;
  final int? awayScore;
  final int? homePenalties;
  final int? awayPenalties;
  final String? winnerCode;

  /// Kaynağa özel lig anahtarı (ör. ESPN `eng.1`); detay çağrılarında gerekir.
  final String? sourceKey;

  /// Lig logosu (maç listesi başlığında gösterilir).
  final String? tournamentLogoUrl;

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    final tournament = tryMap(json['tournament']);
    final unique = tryMap(tournament?['uniqueTournament']) ?? tournament;
    final category = tryMap(tournament?['category']);
    final status = tryMap(json['status']);
    final home = tryMap(json['homeScore']);
    final away = tryMap(json['awayScore']);

    return MatchEvent(
      id: tryInt(json['id']) ?? 0,
      startTimestamp: tryInt(json['startTimestamp']) ?? 0,
      tournamentName:
          tryString(unique?['name'] ?? tournament?['name']) ?? 'Turnuva',
      tournamentId: tryInt(unique?['id'] ?? tournament?['id']),
      countryName: tryString(category?['name']),
      tournamentFlagUrl: tryString(category?['flagUrl']),
      home: TeamRef.fromJson(tryMap(json['homeTeam'])),
      away: TeamRef.fromJson(tryMap(json['awayTeam'])),
      statusType: tryString(status?['type']) ?? 'notstarted',
      statusDescription:
          tryString(status?['description'] ?? status?['shortDescription']),
      homeScore: tryInt(home?['display'] ?? home?['current'] ?? home?['normaltime']),
      awayScore: tryInt(away?['display'] ?? away?['current'] ?? away?['normaltime']),
      homePenalties: tryInt(home?['penalties']),
      awayPenalties: tryInt(away?['penalties']),
      winnerCode: tryString(json['winnerCode']),
    );
  }

  static const Set<String> _finished = {'finished', 'awarded', 'abandoned', 'aet'};
  static const Set<String> _upcoming = {'notstarted', 'scheduled', 'postponed', 'cancelled'};

  bool get isFinished => _finished.contains(statusType);
  bool get isUpcoming => _upcoming.contains(statusType);
  bool get isLive => !isFinished && !isUpcoming;

  DateTime get kickoff => DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000);

  /// Gruplama anahtarı: aynı id'ye sahip turnuvalar tek başlıkta toplanır.
  String get tournamentKey => '${tournamentId ?? ''}|$tournamentName';

  String get headerTitle =>
      countryName == null || countryName!.isEmpty
          ? tournamentName
          : '$countryName · $tournamentName';
}

/// Turnuva adına göre korumalı sıralı gruplama.
Map<String, List<MatchEvent>> groupByTournament(List<MatchEvent> events) {
  final grouped = <String, List<MatchEvent>>{};
  for (final event in events) {
    grouped.putIfAbsent(event.tournamentKey, () => []).add(event);
  }
  return grouped;
}
