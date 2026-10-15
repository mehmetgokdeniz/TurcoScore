import '../../core/utils/json_utils.dart';

enum SearchKind { player, team, tournament, unknown }

class SearchItem {
  const SearchItem({
    required this.kind,
    required this.id,
    required this.name,
    this.subtitle,
    this.sourceKey,
    this.logoUrl,
  });

  final SearchKind kind;
  final int id;
  final String name;
  final String? subtitle;

  /// Takım/lig için kaynak lig anahtarı (ör. ESPN `eng.1`).
  final String? sourceKey;

  /// Sonuç satırında gösterilecek görsel (takım/lig logosu).
  final String? logoUrl;
}

class PlayerSummary {
  const PlayerSummary({
    required this.id,
    required this.name,
    this.teamName,
    this.position,
    this.countryName,
    this.photoUrl,
    this.jerseyNumber,
  });

  final int id;
  final String name;
  final String? teamName;
  final String? position;
  final String? countryName;
  final String? photoUrl;
  final int? jerseyNumber;

  factory PlayerSummary.fromJson(Map<String, dynamic> json) {
    final team = tryMap(json['team']);
    final country = tryMap(json['country']);
    final id = tryInt(json['id']) ?? 0;
    return PlayerSummary(
      id: id,
      name: tryString(json['name']) ?? 'Bilinmeyen oyuncu',
      teamName: tryString(team?['name']),
      position: tryString(json['position']),
      countryName: tryString(country?['name'] ?? json['countryCode']),
      photoUrl: tryString(json['proposalImage'] ?? json['image'] ?? json['userImage']) ??
          (id > 0 ? 'https://api.sofascore.com/api/v1/player/$id/image' : null),
      jerseyNumber: tryInt(json['jerseyNumber']),
    );
  }

  String get positionLabel {
    switch (position) {
      case 'G':
        return 'Kaleci';
      case 'D':
        return 'Defans';
      case 'M':
        return 'Orta Saha';
      case 'F':
        return 'Forvet';
      default:
        return position ?? '-';
    }
  }
}

class PlayerProfile extends PlayerSummary {
  const PlayerProfile({
    required super.id,
    required super.name,
    super.teamName,
    super.position,
    super.countryName,
    super.photoUrl,
    super.jerseyNumber,
    this.age,
    this.height,
    this.weight,
    this.preferredFoot,
    this.marketValue,
    this.birthDate,
    this.birthPlace,
    this.contractUntil,
    this.appearances,
    this.goals,
    this.assists,
    this.shots,
  });

  final int? age;
  final int? height;
  final int? weight;
  final String? preferredFoot;
  final String? marketValue;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? contractUntil;

  /// Güncel sezon istatistikleri (varsa).
  final int? appearances;
  final int? goals;
  final int? assists;
  final int? shots;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final base = PlayerSummary.fromJson(json);
    final birth = tryString(json['dateOfBirth'] ?? json['birthDate']);
    int? age;
    if (birth != null) {
      final parsed = DateTime.tryParse(birth);
      if (parsed != null) {
        final today = DateTime.now();
        age = today.year -
            parsed.year -
            (today.month < parsed.month ||
                    (today.month == parsed.month && today.day < parsed.day)
                ? 1
                : 0);
      }
    }
    return PlayerProfile(
      id: base.id,
      name: base.name,
      teamName: base.teamName,
      position: base.position,
      countryName: base.countryName,
      photoUrl: base.photoUrl,
      jerseyNumber: base.jerseyNumber,
      age: age,
      height: tryInt(json['height']),
      weight: tryInt(json['weight']),
      preferredFoot: tryString(json['preferredFoot']),
      marketValue: tryString(json['marketValue']?['current'] ?? json['marketValue']),
    );
  }
}
