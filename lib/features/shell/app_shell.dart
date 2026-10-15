import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/favorite_watcher.dart';
import '../../data/repositories/score_repository.dart';
import '../leagues/leagues_screen.dart';
import '../matches/matches_screen.dart';
import '../search/search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  Timer? _watchTimer;
  Timer? _firstCheck;

  @override
  void initState() {
    super.initState();
    // Uygulama açıkken favori maçları60 saniyede bir kontrol et
    // (başlangıç / gol / kırmızı kart bildirimi).
    _watchTimer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
    _firstCheck = Timer(const Duration(seconds: 8), _check);
  }

  Future<void> _check() async {
    if (!mounted) return;
    try {
      await FavoriteWatcher.check(context.read<ScoreRepository>());
    } catch (_) {
      // Tek kontrol hatası uygulamayı etkilemesin.
    }
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _firstCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          MatchesScreen(),
          LeaguesScreen(),
          SearchScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Maçlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ligler',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search),
            label: 'Arama',
          ),
        ],
      ),
    );
  }
}
