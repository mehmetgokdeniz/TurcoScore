import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/favorites/favorite_store.dart';
import '../../data/models/event_details.dart';
import '../../data/repositories/score_repository.dart';
import '../notifications/match_notifier.dart';

/// Favori maçları kontrol eder ve bildirim atar:
///  - Maç başlangıcı
///  - Gol (yeni)
///  - Kırmızı kart (yeni)
///
/// İlk gözlem referans (snapshot) alınır; sonraki kontrollerdeki farklar
/// bildirime çevrilir (spam yok).
class FavoriteWatcher {
  FavoriteWatcher._();

  static Future<void> check(ScoreRepository repository) async {
    final favorites = await FavoriteStore.readAll();
    if (favorites.isEmpty) return;

    final now = DateTime.now();
    for (final favorite in favorites) {
      final kickoff =
          DateTime.fromMillisecondsSinceEpoch(favorite.startTimestamp * 1000);
      // Maçla ilgilenme penceresi: başlamasına<=4 saat ve bitmesine<=3 saat.
      final delta = kickoff.difference(now);
      if (delta.inHours > 4 || delta.inHours < -3) continue;

      try {
        final bundle = await repository.fetchEventBundle(favorite.toEvent());
        await _process(favorite, bundle);
      } catch (_) {
        // Tek maçın hatası diğer kontrolleri bozmasın.
      }
    }
  }

  static Future<void> _process(
    FavoriteMatch favorite,
    EventBundle bundle,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final stateKey = 'notify_state_${favorite.id}';
    final raw = prefs.getString(stateKey);

    if (raw == null) {
      // İlk gözlem: referans kaydı, bildirim yok.
      await prefs.setString(
        stateKey,
        jsonEncode({'started': false, 'count': bundle.incidents.length}),
      );
      return;
    }

    var started = false;
    var count = 0;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      started = map['started'] == true;
      count = map['count'] is int ? map['count'] as int : 0;
    } catch (_) {
      // Bozuk kayıt: sıfırla.
    }

    final event = bundle.event;
    final isRunning = !event.isUpcoming; // canlı veya bitmiş

    if (!started && isRunning) {
      started = true;
      await MatchNotifier.show(
        favorite.id,
        'Maç başladı: ${favorite.title}',
        '${favorite.tournamentName} · ${event.statusDescription ?? ''}',
      );
    }

    if (started && bundle.incidents.length > count) {
      for (var i = count; i < bundle.incidents.length; i++) {
        final incident = bundle.incidents[i];
        if (incident.isGoal) {
          final score = incident.homeScore != null && incident.awayScore != null
              ? ' (${incident.homeScore}-${incident.awayScore})'
              : '';
          await MatchNotifier.show(
            favorite.id * 100 + i,
            'GOL! ${incident.playerName ?? favorite.homeName}',
            '${favorite.title}$score · ${incident.minute}',
          );
        } else if (incident.isCard &&
            (incident.text ?? '').toLowerCase().contains('kırmızı')) {
          await MatchNotifier.show(
            favorite.id * 1000 + i,
            'Kırmızı kart: ${incident.playerName ?? '-'}',
            '${favorite.title} · ${incident.minute}',
          );
        }
      }
    }

    await prefs.setString(
      stateKey,
      jsonEncode({'started': started, 'count': bundle.incidents.length}),
    );
  }
}
