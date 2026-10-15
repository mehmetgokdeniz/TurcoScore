import 'dart:convert';

import '../../core/network/api_client.dart';
import '../models/match_models.dart';
import '../models/player_models.dart';
import '../models/tournament_models.dart';

/// Maçkolik'in (arsiv.mackolik.com) resmi olmayan uçları.
///
/// Kullanılan uçlar (2026-10'da canlı doğrulandı):
///  - Arama:      `/AjaxHandlers/SearchHandler.aspx?q=`  → JS dizi literal
///  - Puan tablosu: `/AjaxHandlers/StandingHandler.ashx?op=standing&id={seasonId}`
///                → JSON (`s` alanı: [teamId, ad, ...istatistik])
///  - Oyuncu:     `/Player/Default.aspx?id={id}` → HTML (bio + sezon istatistiği)
///
/// Sayfalar UTF-8'dir. Oyuncu görseli: `im.mackolik.com/img/Oyuncu/{id}_01.jpg`.
class MackolikClient {
  MackolikClient({ApiClient? client})
      : _client = client ??
            ApiClient(baseUrls: const ['https://arsiv.mackolik.com']);

  final ApiClient _client;

  /// ESPN turnuva id -> Maçkolik sezon id (Türk ligleri).
  static const Map<int, int> espnTournamentToSeason = {
    1: 73482, // Trendyol Süper Lig
    2: 73487, // Trendyol 1. Lig
  };

  /// Oyuncu araması. Sonuç JS dizi literalidir (`[{text:'..', ...}]`).
  Future<List<SearchItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final text = await _client.getText('/AjaxHandlers/SearchHandler.aspx',
        queryParameters: {'q': trimmed});

    final items = <SearchItem>[];
    for (final chunk in text.split('},{')) {
      final url = RegExp(r"url:'([^']*)'").firstMatch(chunk)?.group(1);
      if (url == null) continue;

      final playerMatch =
          RegExp(r'/Futbolcu/(\d+)/').firstMatch(url);
      if (playerMatch == null) continue; // yalnızca futbolcular

      final id = int.tryParse(playerMatch.group(1)!);
      final name = RegExp(r"text:'((?:\\'|[^'])*)'")
          .firstMatch(chunk)
          ?.group(1)
          ?.replaceAll("\\'", "'");
      final desc = RegExp(r"desc:'((?:\\'|[^'])*)'")
          .firstMatch(chunk)
          ?.group(1)
          ?.replaceAll("\\'", "'");
      if (id == null || name == null || name.isEmpty) continue;

      items.add(SearchItem(
        kind: SearchKind.player,
        id: id,
        name: name,
        subtitle: desc,
        sourceKey: 'mackolik',
        logoUrl: 'https://im.mackolik.com/img/Oyuncu/${id}_01.jpg',
      ));
    }
    return items;
  }

  /// Puan tablosu (JSON). Sütunlar (Standing2.js render'ından doğrulandı):
  /// [2]/[3] O(g/i), [4]/[5] G, [6]/[7] B, [8]/[9] M,
  /// [10]/[11] A(g/i), [12]/[13] Y(g/i), [14]/[15] P(g/i), [17] ek puan.
  Future<StandingsTable> fetchStandings(int seasonId) async {
    final text = await _client.getText(
      '/AjaxHandlers/StandingHandler.ashx',
      queryParameters: {'op': 'standing', 'id': '$seasonId'},
    );

    final decoded = jsonDecode(text);
    final rawRows = decoded is Map<String, dynamic> ? decoded['s'] : null;
    final rows = rawRows is List ? rawRows : const [];

    final standings = <StandingRow>[];
    for (final row in rows) {
      if (row is! List || row.length < 16) continue;
      final teamId = row[0] is num ? (row[0] as num).toInt() : 0;
      final name = '${row[1]}';

      int numOf(int index) => row[index] is num ? (row[index] as num).toInt() : 0;
      final extraPoint = numOf(17);

      standings.add(StandingRow(
        position: 0, // sıralama aşağıda yapılacak
        team: TeamRef(
          id: teamId,
          name: name,
          logoUrl: teamId > 0
              ? 'https://im.mackolik.com/img/logo/buyuk/$teamId.gif'
              : null,
        ),
        matches: numOf(2) + numOf(3),
        won: numOf(4) + numOf(5),
        drawn: numOf(6) + numOf(7),
        lost: numOf(8) + numOf(9),
        goalsFor: numOf(10) + numOf(11),
        goalsAgainst: numOf(12) + numOf(13),
        points: numOf(14) + numOf(15) + extraPoint,
        promotionText: extraPoint > 0 ? '-$extraPoint puan' : null,
      ));
    }

    // Sıralama: puan > averaj > atılan gol.
    standings.sort((a, b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      if (a.goalDifference != b.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      return b.goalsFor.compareTo(a.goalsFor);
    });

    return StandingsTable(rows: [
      for (var i = 0; i < standings.length; i++)
        StandingRow(
          position: i + 1,
          team: standings[i].team,
          matches: standings[i].matches,
          won: standings[i].won,
          drawn: standings[i].drawn,
          lost: standings[i].lost,
          goalsFor: standings[i].goalsFor,
          goalsAgainst: standings[i].goalsAgainst,
          points: standings[i].points,
          promotionText: standings[i].promotionText,
        ),
    ]);
  }

  /// Oyuncu profili (HTML): bio + güncel sezon istatistikleri.
  Future<PlayerProfile?> fetchPlayer(int playerId) async {
    final html =
        await _client.getText('/Player/Default.aspx', queryParameters: {'id': '$playerId'});
    if (html.isEmpty) return null;

    String? label(String labelText) {
      final pattern = RegExp(
        '>${RegExp.escape(labelText)}[^<]*</b></div>\\s*<div[^>]*><b>:</b>\\s*([^<]+)',
        caseSensitive: false,
      );
      final value = pattern.firstMatch(html)?.group(1);
      if (value == null) return null;
      final cleaned = value
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return cleaned.isEmpty ? null : cleaned;
    }

    final name = label('Uzun Ad');
    final birthMatch = RegExp(r'itemprop="birthDate" datetime="([^"]+)"')
        .firstMatch(html);
    final birthDate =
        birthMatch == null ? null : DateTime.tryParse(birthMatch.group(1)!);
    int? age;
    if (birthMatch != null) {
      final ageMatch = RegExp(r'</time>\s*\((\d+)\)').firstMatch(html);
      age = ageMatch == null ? null : int.tryParse(ageMatch.group(1)!);
    }

    final heightText = label('Boy');
    final weightText = label('Kilo');
    final positionText = label('Pozisyon');
    final contractText = label('Kontrat Sonu');
    final birthPlace = label('D.Yeri');

    final photo = RegExp(r'itemprop="image" src="([^"]+)"').firstMatch(html);
    var photoUrl = photo?.group(1);
    if (photoUrl != null && photoUrl.startsWith('//')) photoUrl = 'https:$photoUrl';

    // Güncel sezon: başlıklar Maç | Gol | Asist | Şut/M → opta-stat satırı.
    int? appearances;
    int? goals;
    int? assists;
    int? shots;
    final headerIndex = html.indexOf('>Maç<');
    if (headerIndex >= 0) {
      final window = html.substring(
          headerIndex, headerIndex + 600 < html.length ? headerIndex + 600 : html.length);
      final headerCells = RegExp(r'>([^<>]{1,12})</td>')
          .allMatches(window)
          .map((m) => m.group(1)!.trim())
          .toList();
      final optaIndex = window.indexOf('class="opta-stat"');
      final values = optaIndex < 0
          ? <int>[]
          : RegExp(r'<td[^>]*><b>(\d+)</b></td>')
              .allMatches(window.substring(optaIndex))
              .map((m) => int.tryParse(m.group(1)!))
              .whereType<int>()
              .toList();
      for (var i = 0; i < headerCells.length && i < values.length; i++) {
        switch (headerCells[i].toLowerCase()) {
          case 'maç':
            appearances = values[i];
          case 'gol':
            goals = values[i];
          case 'asist':
            assists = values[i];
        }
        if (headerCells[i].toLowerCase().startsWith('şut')) shots = values[i];
      }
    }

    // Transfer değeri: #playerValueTab tablosunda en güncel satır (EUR).
    String? marketValue;
    final valueIndex = html.indexOf('id="playerValueTab"');
    if (valueIndex >= 0) {
      final valueMatch = RegExp(r'<td[^>]*>([\d.]+\s*EUR)</td>')
          .firstMatch(html.substring(valueIndex));
      marketValue = valueMatch?.group(1)?.replaceAll(RegExp(r'\s+'), ' ');
    }

    return PlayerProfile(
      id: playerId,
      name: (name ?? '').isEmpty ? 'Oyuncu' : name!,
      photoUrl: photoUrl,
      marketValue: marketValue,
      birthDate: birthDate,
      age: age,
      birthPlace: birthPlace,
      height: int.tryParse(RegExp(r'(\d+)').firstMatch(heightText ?? '')?.group(1) ?? ''),
      weight: int.tryParse(RegExp(r'(\d+)').firstMatch(weightText ?? '')?.group(1) ?? ''),
      position: _positionCode(positionText),
      contractUntil: contractText,
      appearances: appearances,
      goals: goals,
      assists: assists,
      shots: shots,
    );
  }

  /// "Forvet" → F, "Kaleci" → G ... (mevcut kodlama ile uyumlu).
  static String? _positionCode(String? text) {
    if (text == null) return null;
    final lower = text.toLowerCase();
    if (lower.contains('kaleci')) return 'G';
    if (lower.contains('defans') || lower.contains('stoper')) return 'D';
    if (lower.contains('orta saha') || lower.contains('ortasaha')) return 'M';
    if (lower.contains('forvet') || lower.contains('santra')) return 'F';
    return text;
  }
}
