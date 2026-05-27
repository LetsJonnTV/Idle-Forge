import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;
    // Windows not supported by flutter_local_notifications v17
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> scheduleOfflineRewardFull() async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        1,
        'Idle Forge',
        'Deine Offline-Belohnung ist voll! Komm zurück.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'idle_forge_channel',
            'Idle Forge',
            channelDescription: 'Game Notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
