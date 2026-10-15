import 'package:flutter/foundation.dart';

import '../core/utils/errors.dart';
import '../data/models/tournament_models.dart';
import '../data/repositories/score_repository.dart';
import 'load_state.dart';

class TournamentsController extends ChangeNotifier {
  TournamentsController(this._repository) {
    load();
  }

  final ScoreRepository _repository;

  LoadState state = LoadState.initial;
  String? errorMessage;
  bool isDemo = false;
  String query = '';
  List<Tournament> tournaments = const [];

  List<Tournament> get visible {
    final q = _normalize(query);
    if (q.isEmpty) return tournaments;
    return tournaments
        .where((t) =>
            _normalize(t.name).contains(q) ||
            _normalize(t.countryName ?? '').contains(q))
        .toList();
  }

  /// "Süperlig" / "süper lig" -> "superlig": Türkçe karakter, büyük/küçük harf
  /// ve boşluk farkı aramayı etkilemesin.
  static String _normalize(String value) {
    var text = value.toLowerCase();
    const map = <String, String>{
      'ı': 'i', 'i̇': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c',
      'â': 'a', 'î': 'i', 'û': 'u',
    };
    map.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAll(RegExp('[^a-z0-9]'), '');
  }

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      tournaments = await _repository.fetchTournaments();
      isDemo = _repository.isDemo;
      state = LoadState.ready;
    } catch (e) {
      errorMessage = humanError(e);
      state = LoadState.error;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }
}

class StandingsController extends ChangeNotifier {
  StandingsController(this._repository, this.tournament) {
    load();
  }

  final ScoreRepository _repository;
  final Tournament tournament;

  LoadState state = LoadState.initial;
  String? errorMessage;
  List<Season> seasons = const [];
  Season? selectedSeason;
  StandingsTable? table;

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      if (seasons.isEmpty) {
        seasons = await _repository.fetchSeasons(tournament.id);
        Season? current;
        for (final season in seasons) {
          if (season.isCurrent) {
            current = season;
            break;
          }
        }
        selectedSeason = current ?? (seasons.isEmpty ? null : seasons.first);
      }
      if (selectedSeason == null) {
        throw Exception('Sezon bulunamadı');
      }
      table = await _repository.fetchStandings(
        tournament.id,
        selectedSeason!.id,
      );
      state = LoadState.ready;
    } catch (e) {
      errorMessage = humanError(e);
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> selectSeason(Season season) async {
    if (selectedSeason?.id == season.id) return;
    selectedSeason = season;
    await load();
  }
}
