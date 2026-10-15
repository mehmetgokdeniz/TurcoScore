import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../core/notifications/favorite_watcher.dart';
import '../core/notifications/match_notifier.dart';
import '../data/repositories/score_repository.dart';

/// Arka plan periyodik görevi: favori maçları kontrol et (min.15 dk).
const String kFavoriteCheckTask = 'favorite_match_check';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kFavoriteCheckTask) return true;
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await MatchNotifier.init();
      await FavoriteWatcher.check(ScoreRepository());
    } catch (_) {
      // Arka plan kontrolü hatası sessiz geçer; bir sonraki denemede tekrar.
    }
    return true;
  });
}
