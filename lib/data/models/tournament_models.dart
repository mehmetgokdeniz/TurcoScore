import '../../core/utils/json_utils.dart';
import 'match_models.dart';

class Season {
  const Season({required this.id, required this.name, this.isCurrent = false});

  final int id;
  final String name;
  final bool isCurrent;

  factory Season.fromJson(Map<String, dynamic> json, {bool isCurrent = false}) {
    return Season(
      id: tryInt(json['id']) ?? 0,
      name: tryString(json['name']) ?? '',
      isCurrent: isCurrent,
    );
  }
}

class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    this.countryName,
    this.flagUrl,
    this.logoUrl,
    this.currentSeasonId,
    this.slug,
    this.category,
  });

  final int id;
  final String name;
  final String? countryName;
  final String? flagUrl;
  final String? logoUrl;
  final int? currentSeasonId;

  /// Kaynağa özel lig anahtarı (ör. ESPN `tur.1`).
  final String? slug;

  /// Kaynak kategorisi (ESPN: `league` / `cup` / `national`); null = bilinmiyor.
  final String? category;

  String get title =>
      countryName == null || countryName!.isEmpty ? name : '$countryName · $name';

  factory Tournament.fromJson(Map<String, dynamic> json) {
    final category = tryMap(json['category']);
    final currentSeason = tryMap(json['currentSeason']);
    final logo = tryString(json['userLogo']?['url'] ?? json['logoUrl'] ?? json['smallImage']);
    return Tournament(
      id: tryInt(json['id']) ?? 0,
      name: tryString(json['name']) ?? 'Turnuva',
      countryName: tryString(category?['name'] ?? json['country']?['name']),
      flagUrl: tryString(category?['flagUrl']),
      logoUrl: logo,
      currentSeasonId: tryInt(currentSeason?['id']),
    );
  }
}

class StandingRow {
  const StandingRow({
    required this.position,
    required this.team,
    required this.matches,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
    this.promotionText,
  });

  final int position;
  final TeamRef team;
  final int matches;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int points;
  final String? promotionText;

  int get goalDifference => goalsFor - goalsAgainst;

  factory StandingRow.fromJson(Map<String, dynamic> json, int fallbackPosition) {
    final rawScores = json['scores'];
    final scores = rawScores is List ? rawScores : const [];
    return StandingRow(
      position: tryInt(json['rowNumber'] ?? json['position']) ?? fallbackPosition,
      team: TeamRef.fromJson(tryMap(json['team'])),
      matches: tryInt(json['matches']) ?? 0,
      won: tryInt(json['wins']) ?? 0,
      drawn: tryInt(json['draws']) ?? 0,
      lost: tryInt(json['losses']) ?? 0,
      goalsFor: tryInt(json['goalsFor'] ?? (scores.isNotEmpty ? scores[0] : null)) ?? 0,
      goalsAgainst: tryInt(json['goalsAgainst'] ?? (scores.length > 1 ? scores[1] : null)) ?? 0,
      points: tryInt(json['points']) ?? 0,
      promotionText: tryString(tryMap(json['promotion'])?['text']),
    );
  }
}

class StandingSection {
  const StandingSection({required this.name, required this.rows});

  /// Örn. "A Grubu", "Lig aşaması"; tek tabloda anlamsızdır.
  final String name;
  final List<StandingRow> rows;
}

class StandingsTable {
  const StandingsTable({required this.rows, this.sections = const []});

  final List<StandingRow> rows;

  /// Kupa/turnuvalarda grup bazlı tablolar (birden çok çocuk) burada tutulur.
  final List<StandingSection> sections;

  bool get hasSections => sections.isNotEmpty;

  /// Hem lig (`standings.rows`) hem kupa/grup (`tournamentEdges[].node.rows`) biçimi.
  factory StandingsTable.fromJson(Map<String, dynamic> json) {
    final standings = tryMap(json['standings']) ?? json;
    final rows = tryMapList(standings['rows']);
    if (rows.isNotEmpty) {
      return StandingsTable(
        rows: [for (var i = 0; i < rows.length; i++) StandingRow.fromJson(rows[i], i + 1)],
      );
    }

    final edges = tryMapList(standings['tournamentEdges']);
    final nested = <Map<String, dynamic>>[];
    for (final edge in edges) {
      nested.addAll(tryMapList(tryMap(edge)?['node']?['rows']));
    }
    return StandingsTable(
      rows: [for (var i = 0; i < nested.length; i++) StandingRow.fromJson(nested[i], i + 1)],
    );
  }
}
