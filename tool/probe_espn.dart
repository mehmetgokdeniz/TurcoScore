// Diagnostik: canlı API uçlarını uçtan uca doğrular.
// Çalıştırma: dart run tool/probe_espn.dart
// ignore_for_file: avoid_print

import 'package:turcoscore/data/models/player_models.dart';
import 'package:turcoscore/data/sources/espn_source.dart';
import 'package:turcoscore/data/sources/mackolik_client.dart';

int _idOf(String slug) {
  final index = EspnSource.leagues.indexWhere((l) => l.slug == slug);
  if (index < 0) throw StateError('slug yok: $slug');
  return index + 1;
}

Future<void> main() async {
  final src = EspnSource();
  var failures = 0;

  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      failures++;
      print('FAIL $name -> $e');
    }
  }

  print('turnuva=${EspnSource.leagues.length} | '
      'tur.1=${EspnSource.leagues[0].name} | tur.2=${EspnSource.leagues[1].name}');

  await step('günlük maçlar + logolar', () async {
    final events = await src.fetchEventsForDate(DateTime.now());
    final withLogo =
        events.where((e) => e.home.logoUrl != null && e.away.logoUrl != null).length;
    print('OK gunluk=${events.length} logo=$withLogo/${events.length}');
  });

  await step('arama kelimeye göre', () async {
    for (final q in ['arsenal', 'galatasaray', 'süper lig', 'premier']) {
      final results = await src.search(q);
      print('   "$q" -> ${results.length}: '
          '${results.take(4).map((r) => r.name).join(', ')}');
    }
  });

  await step('lig logoları', () async {
    final sw = Stopwatch()..start();
    final tournaments = await src.fetchTournaments();
    final withLogo = tournaments.where((t) => t.logoUrl != null).length;
    print('OK lig=${tournaments.length} logo=$withLogo ${sw.elapsedMilliseconds}ms');
    final t2 = tournaments.firstWhere((t) => t.slug == 'tur.2');
    print('   tur.2 -> ${t2.name} logo=${t2.logoUrl != null}');
  });

  await step('bitmiş maç: olay / form / H2H / istatistik', () async {
    final events = await src.fetchEventsForDate(
        DateTime.now().subtract(const Duration(days: 4)));
    final finished = events
        .where((e) => e.isFinished && ((e.homeScore ?? 0) + (e.awayScore ?? 0)) > 0)
        .toList();
    // H2H bilinen maçta dolu: varsa onu seç.
    final target = finished.firstWhere((e) => e.id == 401888279,
        orElse: () => finished.first);
    final bundle = await src.fetchEventBundle(target);
    print('OK ${bundle.event.home.name} ${bundle.event.homeScore}-'
        '${bundle.event.awayScore} ${bundle.event.away.name}');

    print('   olay=${bundle.incidents.length}');
    for (final i in bundle.incidents) {
      print('     ${i.minute} [${i.type}] ${i.playerName ?? '-'} '
          '${i.text ?? ''} ${i.homeScore ?? ''}-${i.awayScore ?? ''}');
    }

    for (final f in bundle.form) {
      print('   form ${f.teamName}: ${f.results.join(',')} logo=${f.logoUrl != null}');
    }
    print('   h2h=${bundle.headToHead.length}');
    for (final h in bundle.headToHead.take(3)) {
      print('     ${h.homeName} ${h.homeScore ?? '-'}-${h.awayScore ?? '-'} '
          '${h.awayName} (id=${h.id}, bitmis=${h.isFinished})');
    }

    final stats = bundle.statistics.groups;
    if (stats.isNotEmpty) {
      final names = stats.first.items.take(8).map((i) => i.name).join(' | ');
      print('   istatistik(TR): $names');
    }
  });

  await step('oynanmamış maç tarihi', () async {
    final events = await src.fetchEventsForDate(DateTime.now().add(const Duration(days: 1)));
    final upcoming = events.where((e) => e.isUpcoming).toList();
    if (upcoming.isEmpty) throw StateError('yaklaşan maç yok');
    final target = upcoming.first;
    final bundle = await src.fetchEventBundle(target);
    final source = DateTime.fromMillisecondsSinceEpoch(target.startTimestamp * 1000);
    final detail = DateTime.fromMillisecondsSinceEpoch(bundle.event.startTimestamp * 1000);
    print('OK kaynak=${source.toIso8601String()} detay=${detail.toIso8601String()} '
        'esit=${source.difference(detail).inMinutes.abs() <= 1}');
    if (source.difference(detail).inMinutes.abs() > 1) {
      throw StateError('detay tarihi kaynakla uyuşmuyor');
    }
  });

  await step('puan tablosu', () async {
    final table = await src.fetchStandings(_idOf('tur.1'), DateTime.now().year);
    print('OK trendysuperlig=${table.rows.length} satir');
    final t2 = await src.fetchStandings(_idOf('tur.2'), DateTime.now().year);
    print('   trendyol1lig=${t2.rows.length} satir');
  });

  await step('kadrolar + puan', () async {
    final events = await src.fetchEventsForDate(
        DateTime.now().subtract(const Duration(days: 4)));
    final finished = events.where((e) => e.isFinished).toList();
    final bundle = await src.fetchEventBundle(finished.first);
    final rated = bundle.homeLineup.players.where((p) => p.rating != null).length;
    print('OK kadro=${bundle.homeLineup.players.length} puanli=$rated');
  });

  await step('maçkolik: oyuncu arama', () async {
    final mk = MackolikClient();
    final results = await mk.search('messi');
    print('OK maçkolik arama: ${results.length} sonuc');
    for (final r in results.take(3)) {
      print('   ${r.kind.name} | ${r.name} | ${r.subtitle} | id=${r.id}'
          ' | foto=${r.logoUrl != null}');
    }
    final messi = results.firstWhere((r) => r.name.contains('Messi'),
        orElse: () => results.first);
    if (messi.kind != SearchKind.player) throw StateError('oyuncu bulunamadı');

    await step('maçkolik: oyuncu profili', () async {
      final profile = await mk.fetchPlayer(messi.id);
      if (profile == null) throw StateError('profil boş');
      print('   profil: ${profile.name} | yaş=${profile.age} | '
          '${profile.height ?? '-'}cm/${profile.weight ?? '-'}kg | '
          'mevki=${profile.position ?? '-'} | doğum=${profile.birthDate} | '
          'yer=${profile.birthPlace ?? '-'} | kontrat=${profile.contractUntil ?? '-'}');
      print('   sezon: maç=${profile.appearances} gol=${profile.goals} '
          'asist=${profile.assists} şut=${profile.shots} '
          'değer=${profile.marketValue ?? '-'} '
          'foto=${profile.photoUrl}');
    });
  });

  await step('maçkolik: Trendyol 1. Lig puan tablosu', () async {
    final mk = MackolikClient();
    final table = await mk.fetchStandings(73487);
    print('OK maçkolik tablo: ${table.rows.length} satir');
    for (final r in table.rows.take(5)) {
      print('   ${r.position}. ${r.team.name} O=${r.matches} G=${r.won}'
          ' B=${r.drawn} M=${r.lost} AV=${r.goalDifference} P=${r.points}'
          ' logo=${r.team.logoUrl != null}');
    }
  });

  print(failures == 0 ? 'TÜM ADIMLAR GEÇTİ' : 'HATALI ADIM: $failures');
}
