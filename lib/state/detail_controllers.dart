import 'package:flutter/foundation.dart';

import '../core/utils/errors.dart';
import '../data/models/event_details.dart';
import '../data/models/match_models.dart';
import '../data/models/player_models.dart';
import '../data/repositories/score_repository.dart';
import 'load_state.dart';

class MatchDetailController extends ChangeNotifier {
  MatchDetailController(this._repository, this.preview) {
    load();
  }

  final ScoreRepository _repository;
  final MatchEvent preview;

  LoadState state = LoadState.initial;
  String? errorMessage;
  EventBundle? bundle;

  MatchEvent get event => bundle?.event ?? preview;

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      bundle = await _repository.fetchEventBundle(preview);
      state = LoadState.ready;
    } catch (e) {
      errorMessage = humanError(e);
      state = LoadState.error;
    }
    notifyListeners();
  }
}

class PlayerController extends ChangeNotifier {
  PlayerController(this._repository, this.playerId, {this.provider}) {
    load();
  }

  final ScoreRepository _repository;
  final int playerId;

  /// Profil kaynağı: [PlayerProvider.mackolik] veya ESPN.
  final String? provider;

  LoadState state = LoadState.initial;
  String? errorMessage;
  PlayerProfile? player;

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      player = await _repository.fetchPlayer(playerId, provider: provider);
      state = LoadState.ready;
    } catch (e) {
      errorMessage = humanError(e);
      state = LoadState.error;
    }
    notifyListeners();
  }
}
