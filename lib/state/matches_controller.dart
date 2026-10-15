import 'package:flutter/foundation.dart';

import '../core/utils/errors.dart';
import '../data/models/match_models.dart';
import '../data/repositories/score_repository.dart';
import 'load_state.dart';

class MatchesController extends ChangeNotifier {
  MatchesController(this._repository) {
    load();
  }

  final ScoreRepository _repository;

  LoadState state = LoadState.initial;
  String? errorMessage;
  bool isDemo = false;
  bool showLive = false;
  bool showFavorites = false;
  DateTime date = DateTime.now();
  List<MatchEvent> events = const [];

  /// Favoriler görünümüne geç/çık (ağ isteği yok).
  void toggleFavorites() {
    showFavorites = !showFavorites;
    notifyListeners();
  }

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      events = showLive
          ? await _repository.fetchLiveEvents()
          : await _repository.fetchEventsForDate(date);
      isDemo = _repository.isDemo;
      state = LoadState.ready;
    } catch (e) {
      errorMessage = humanError(e);
      state = LoadState.error;
    }
    notifyListeners();
  }

  void selectLive() {
    if (showLive) return;
    showLive = true;
    showFavorites = false;
    load();
  }

  void selectDate(DateTime value) {
    final sameDay = value.year == date.year &&
        value.month == date.month &&
        value.day == date.day;
    final wasLive = showLive;
    final wasFavorites = showFavorites;
    showLive = false;
    showFavorites = false;
    date = value;
    if (!sameDay || wasLive || wasFavorites) load();
  }
}
