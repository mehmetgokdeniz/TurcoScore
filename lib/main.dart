import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'background.dart';
import 'core/notifications/match_notifier.dart';
import 'core/theme/app_theme.dart';
import 'data/favorites/favorite_store.dart';
import 'data/repositories/score_repository.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  // Bildirim izni + kanal (Android13+ izin isteği dahil).
  try {
    await MatchNotifier.init();
  } catch (_) {
    // Desteklenmeyen platformda sessiz geç.
  }

  // Arka plan kontrolü: favori maçlar için15 dakikada bir.
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      kFavoriteCheckTask,
      kFavoriteCheckTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {
    // Workmanager desteklemiyorsa uygulama içi zamanlayıcı yeterli.
  }

  runApp(const TurcoScoreApp());
}

class TurcoScoreApp extends StatelessWidget {
  const TurcoScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ScoreRepository>.value(value: ScoreRepository()),
        ChangeNotifierProvider(create: (_) => FavoriteStore()),
      ],
      child: MaterialApp(
        title: 'TurcoScore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppShell(),
      ),
    );
  }
}
