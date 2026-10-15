import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_models.dart';

/// Favorilere eklenen maçın anlık görüntüsü (bildirim/filtre için yeterli).
class FavoriteMatch {
  const FavoriteMatch({
    required this.id,
    required this.sourceKey,
    required this.tournamentName,
    required this.countryName,
    required this.homeName,
    required this.awayName,
    required this.startTimestamp,
    this.homeLogoUrl,
    this.awayLogoUrl,
  });

  final int id;
  final String? sourceKey;
  final String tournamentName;
  final String? countryName;
  final String homeName;
  final String awayName;
  final int startTimestamp;
  final String? homeLogoUrl;
  final String? awayLogoUrl;

  factory FavoriteMatch.fromEvent(MatchEvent event) => FavoriteMatch(
        id: event.id,
        sourceKey: event.sourceKey,
        tournamentName: event.tournamentName,
        countryName: event.countryName,
        homeName: event.home.name,
        awayName: event.away.name,
        startTimestamp: event.startTimestamp,
        homeLogoUrl: event.home.logoUrl,
        awayLogoUrl: event.away.logoUrl,
      );

  MatchEvent toEvent() => MatchEvent(
        id: id,
        startTimestamp: startTimestamp,
        tournamentName: tournamentName,
        tournamentId: null,
        countryName: countryName,
        tournamentFlagUrl: null,
        home: TeamRef(id: 0, name: homeName, logoUrl: homeLogoUrl),
        away: TeamRef(id: 0, name: awayName, logoUrl: awayLogoUrl),
        statusType: 'notstarted',
        statusDescription: null,
        sourceKey: sourceKey,
      );

  String get title => '$homeName - $awayName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceKey': sourceKey,
        'tournamentName': tournamentName,
        'countryName': countryName,
        'homeName': homeName,
        'awayName': awayName,
        'startTimestamp': startTimestamp,
        'homeLogoUrl': homeLogoUrl,
        'awayLogoUrl': awayLogoUrl,
      };

  factory FavoriteMatch.fromJson(Map<String, dynamic> json) => FavoriteMatch(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        sourceKey: json['sourceKey'] as String?,
        tournamentName: '${json['tournamentName'] ?? ''}',
        countryName: json['countryName'] as String?,
        homeName: '${json['homeName'] ?? ''}',
        awayName: '${json['awayName'] ?? ''}',
        startTimestamp:
            json['startTimestamp'] is int ? json['startTimestamp'] as int : 0,
        homeLogoUrl: json['homeLogoUrl'] as String?,
        awayLogoUrl: json['awayLogoUrl'] as String?,
      );
}

/// Favori maç deposu (shared_preferences).
class FavoriteStore extends ChangeNotifier {
  FavoriteStore() {
    _load();
  }

  static const String _key = 'favorite_matches_v1';

  List<FavoriteMatch> _favorites = const [];
  bool _loaded = false;

  List<FavoriteMatch> get favorites => _favorites;
  bool get loaded => _loaded;

  bool isFavorite(int eventId) => _favorites.any((f) => f.id == eventId);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _favorites = [
          for (final item in list)
            if (item is Map)
              FavoriteMatch.fromJson(Map<String, dynamic>.from(item)),
        ];
      }
    } catch (_) {
      // Depo yoksa/bozuksa boş liste.
      _favorites = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final f in _favorites) f.toJson()]),
      );
    } catch (_) {
      // Kalıcı yazım başarısızsa bellek içi durum korunur.
    }
  }

  /// Favoriye ekle/çıkar; sonucu döndürür.
  Future<bool> toggle(MatchEvent event) async {
    final nowFavorite = !isFavorite(event.id);
    if (nowFavorite) {
      _favorites = [..._favorites, FavoriteMatch.fromEvent(event)];
    } else {
      _favorites = _favorites.where((f) => f.id != event.id).toList();
    }
    notifyListeners();
    await _save();
    return nowFavorite;
  }

  /// Bildirim kontrolü için senkron okuma (arka plan izolasyonu dahil).
  static Future<List<FavoriteMatch>> readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          if (item is Map)
            FavoriteMatch.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }
}
