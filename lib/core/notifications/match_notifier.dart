import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Uygulama içi yerel bildirimler (maç başlangıcı, gol, kırmızı kart).
class MatchNotifier {
  MatchNotifier._();

  static const String channelId = 'match_updates';
  static const String channelName = 'Maç Bildirimleri';
  static const String channelDescription =
      'Favori maçlarda başlangıç, gol ve kırmızı kart bildirimleri';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    ),
  );

  static Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
      // Android13+ izni (izin verilmezse bildirimler sessizce düşer).
      await android.requestNotificationsPermission();
    }
    _ready = true;
  }

  static Future<void> show(int id, String title, String body) async {
    if (!_ready) await init();
    await _plugin.show(id, title, body, _details);
  }
}
