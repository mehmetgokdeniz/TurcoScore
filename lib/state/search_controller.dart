import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/errors.dart';
import '../data/models/player_models.dart';
import '../data/repositories/score_repository.dart';
import 'load_state.dart';

class AppSearchController extends ChangeNotifier {
  AppSearchController(this._repository);

  final ScoreRepository _repository;

  LoadState state = LoadState.initial;
  String? errorMessage;
  String query = '';
  List<SearchItem> results = const [];
  Timer? _debounce;

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = LoadState.initial;
      results = const [];
      errorMessage = null;
      notifyListeners();
      return;
    }
    state = LoadState.loading;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(trimmed));
  }

  Future<void> _run(String value) async {
    try {
      results = await _repository.search(value);
      errorMessage = null;
      state = LoadState.ready;
    } catch (e) {
      errorMessage = humanError(e);
      state = LoadState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
