import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  FirebaseAnalytics? _analytics;

  void init() {
    if (!_supported) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      debugPrint('[Analytics] initialized');
    } catch (e) {
      debugPrint('[Analytics] init failed: $e');
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[Analytics] logEvent $name failed: $e');
    }
  }

  Future<void> logPrestige({
    required int newPrestigeLevel,
    required int chapter,
  }) => _log('prestige', {
    'prestige_level': newPrestigeLevel,
    'chapter': chapter,
  });

  Future<void> logChapterComplete({required int chapter}) =>
      _log('chapter_complete', {'chapter': chapter});

  Future<void> logBossDefeated({
    required int chapter,
    required int stage,
    required int totalBossDefeats,
  }) => _log('boss_defeated', {
    'chapter': chapter,
    'stage': stage,
    'total_boss_defeats': totalBossDefeats,
  });

  Future<void> logItemCrafted({
    required String itemName,
    required int totalCrafted,
  }) => _log('item_crafted', {
    'item_name': itemName,
    'total_crafted': totalCrafted,
  });

  Future<void> logPvpBattle({
    required String result,
    required String opponentUsername,
  }) => _log('pvp_battle', {'result': result, 'opponent': opponentUsername});

  Future<void> logQuestCompleted({required int questCycle}) =>
      _log('quest_completed', {'quest_cycle': questCycle});

  Future<void> logAchievementUnlocked({required String achievementId}) =>
      _log('achievement_unlocked', {'achievement_id': achievementId});

  Future<void> logLogin({required String method}) =>
      _analytics?.logLogin(loginMethod: method) ?? Future.value();

  Future<void> setUserProperties({
    required int prestigeLevel,
    required int chapter,
  }) async {
    if (_analytics == null) return;
    try {
      await _analytics!.setUserProperty(
        name: 'prestige_level',
        value: prestigeLevel.toString(),
      );
      await _analytics!.setUserProperty(
        name: 'chapter',
        value: chapter.toString(),
      );
    } catch (e) {
      debugPrint('[Analytics] setUserProperty failed: $e');
    }
  }
}
