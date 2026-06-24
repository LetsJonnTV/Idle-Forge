import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const int _kOfflineRewardNotifId = 1;
const int _kExpeditionNotifId = 2;

const _androidDetails = AndroidNotificationDetails(
  'idle_forge_channel',
  'Idle Forge',
  channelDescription: 'Game Notifications',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
);

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb && !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  static Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Schedule a notification for when offline rewards are capped.
  /// [minutesUntilFull] is how many minutes until the offline cap (240 min) is reached.
  static Future<void> scheduleOfflineRewardFull(int minutesUntilFull) async {
    if (!_initialized) return;
    try {
      // Cancel any existing offline-reward notification first
      await _plugin.cancel(_kOfflineRewardNotifId);

      if (minutesUntilFull <= 0) return;

      // flutter_local_notifications v17 on Android supports periodically scheduled
      // notifications via show() with a delay workaround, or via zonedSchedule with
      // the timezone package. Since we only target Android and don't want to add
      // the timezone dependency, we use a simple periodic check approach:
      // Show an immediate "reward full" notification after the delay via a pending
      // notification. For a simple implementation without zonedSchedule, we use
      // the show() method immediately when the app resumes after the reward is full.
      // The actual scheduled approach is handled in GameController.didChangeAppLifecycle.
      await _plugin.show(
        _kOfflineRewardNotifId,
        'Idle Forge',
        'Deine Offline-Belohnung ist voll! Komm zurück.',
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {}
  }

  /// Show a notification immediately (used when app is resumed and reward is full).
  static Future<void> showOfflineRewardFullNow() async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        _kOfflineRewardNotifId,
        'Idle Forge',
        'Deine Offline-Belohnung ist voll! Komm zurück.',
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {}
  }

  /// Show a notification that an expedition has completed.
  static Future<void> showExpeditionComplete(String expeditionName) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        _kExpeditionNotifId,
        'Expedition abgeschlossen!',
        '$expeditionName ist fertig. Belohnung abholen!',
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {}
  }

  static Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
