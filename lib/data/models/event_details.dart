import '../../core/utils/json_utils.dart';
import 'match_models.dart';
import 'player_models.dart';

/// Bir takımın son maçları (G/B/M form dizisi).
class TeamForm {
  const TeamForm({
    required this.teamId,
    required this.teamName,
    this.logoUrl,
    required this.results,
  });

  final int teamId;
  final String teamName;
  final String? logoUrl;

  /// Sıralı sonuçlar: 'W' galibiyet, 'D' beraberlik, 'L' mağlubiyet.
  final List<String> results;
}

/// İki takım arasındaki geçmiş maçlar (H2H).
class HeadToHeadMatch {
  const HeadToHeadMatch({
    required this.id,
    required this.startTimestamp,
    required this.homeName,
    required this.awayName,
    this.homeLogoUrl,
    this.awayLogoUrl,
    this.homeScore,
    this.awayScore,
    required this.isFinished,
  });

  final int id;
  final int startTimestamp;
  final String homeName;
  final String awayName;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final int? homeScore;
  final int? awayScore;
  final bool isFinished;
}

/// Maç detay ekranı için tek seferde toplanan veri paketi.
class EventBundle {
  const EventBundle({
    required this.event,
    required this.statistics,
    required this.incidents,
    required this.homeLineup,
    required this.awayLineup,
    this.form = const [],
    this.headToHead = const [],
  });

  final MatchEvent event;
  final MatchStatistics statistics;
  final List<MatchIncident> incidents;
  final Lineup homeLineup;
  final Lineup awayLineup;

  /// İki takımın son maçları (varsa).
  final List<TeamForm> form;

  /// İki takım arasındaki geçmiş maçlar (varsa).
  final List<HeadToHeadMatch> headToHead;
}

class StatItem {
  const StatItem({
    required this.name,
    required this.home,
    required this.away,
    this.homeValue,
    this.awayValue,
  });

  final String name;
  final String home;
  final String away;
  final double? homeValue;
  final double? awayValue;

  /// Bar çizmek için 0-1 arası oran; yorumlanabilir değilse null.
  double? get homeRatio {
    final h = homeValue;
    final a = awayValue;
    if (h == null || a == null) return null;
    final total = h + a;
    if (total <= 0) return null;
    return h / total;
  }

  factory StatItem.fromJson(Map<String, dynamic> json) {
    return StatItem(
      name: tryString(json['name']) ?? '',
      home: tryString(json['home']) ?? '-',
      away: tryString(json['away']) ?? '-',
      homeValue: tryDouble(json['homeValue']),
      awayValue: tryDouble(json['awayValue']),
    );
  }
}

class StatGroup {
  const StatGroup({required this.name, required this.items});

  final String name;
  final List<StatItem> items;
}

class MatchStatistics {
  const MatchStatistics({required this.groups});

  final List<StatGroup> groups;

  static const MatchStatistics empty = MatchStatistics(groups: []);

  factory MatchStatistics.fromJson(Map<String, dynamic> json) {
    final periods = tryMapList(json['statistics']);
    if (periods.isEmpty) return empty;

    // Tüm maçın verisi 'ALL'; yoksa en dolu dönem.
    final chosen = periods.firstWhere(
      (p) => (tryString(p['period']) ?? '').toUpperCase() == 'ALL',
      orElse: () => periods.first,
    );

    final groups = <StatGroup>[];
    for (final group in tryMapList(chosen['groups'])) {
      final items = [
        for (final item in tryMapList(group['statisticsItems']))
          if ((tryString(item['name']) ?? '').isNotEmpty) StatItem.fromJson(item),
      ];
      if (items.isNotEmpty) {
        groups.add(StatGroup(name: tryString(group['groupName']) ?? 'İstatistik', items: items));
      }
    }
    return MatchStatistics(groups: groups);
  }
}

class LineupPlayer {
  const LineupPlayer({
    required this.player,
    required this.isHome,
    this.jerseyNumber,
    this.position,
    this.rating,
    this.isStarter = true,
  });

  final PlayerSummary player;
  final bool isHome;
  final int? jerseyNumber;
  final String? position;
  final double? rating;
  final bool isStarter;
}

class Lineup {
  const Lineup({required this.formation, required this.players});

  final String? formation;
  final List<LineupPlayer> players;

  static const Lineup empty = Lineup(formation: null, players: []);

  factory Lineup.fromJson(Map<String, dynamic> json, {required bool isHome}) {
    final players = <LineupPlayer>[];
    for (final entry in tryMapList(json['players'])) {
      final stats = tryMap(entry['statistics']);
      players.add(
        LineupPlayer(
          player: PlayerSummary.fromJson(tryMap(entry['player']) ?? const {}),
          isHome: isHome,
          jerseyNumber: tryInt(tryMap(entry['player'])?['jerseyNumber']),
          position: tryString(tryMap(entry['player'])?['position']),
          rating: tryDouble(stats?['rating']),
          isStarter: entry['starter'] != false,
        ),
      );
    }
    return Lineup(formation: tryString(json['formation']), players: players);
  }
}

class MatchIncident {
  const MatchIncident({
    required this.type,
    required this.minute,
    this.playerName,
    this.teamId,
    this.homeScore,
    this.awayScore,
    this.text,
  });

  final String type;
  final String minute;
  final String? playerName;
  final int? teamId;
  final int? homeScore;
  final int? awayScore;
  final String? text;

  bool get isGoal => type == 'goal';
  bool get isCard => type == 'card';
  bool get isSubstitution => type == 'substitution';

  factory MatchIncident.fromJson(Map<String, dynamic> json) {
    final player = tryMap(json['player']);
    final team = tryMap(json['team']);
    final type = tryString(json['type']) ?? 'unknown';
    var minute = tryString(json['matchTime']);
    minute ??= switch (tryInt(json['time'])) {
      final m? => "$m'",
      _ => null,
    };
    return MatchIncident(
      type: type,
      minute: minute ?? '-',
      playerName: tryString(player?['name'] ?? tryMap(json['assist'])?['name']),
      teamId: tryInt(team?['id']),
      homeScore: tryInt(json['homeScore']),
      awayScore: tryInt(json['awayScore']),
      text: tryString(json['text'] ?? tryMap(json['incidentClass'])?['text']),
    );
  }
}
