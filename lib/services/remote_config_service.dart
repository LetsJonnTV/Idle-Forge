import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../game/game_controller.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const _defaults = {
    'gold_gain_multiplier': 1.0,
    'offline_reward_multiplier': 1.0,
    'player_damage_multiplier': 1.0,
    'enemy_hp_multiplier': 1.0,
    'auto_attack_interval_sec': 1.0,
    'kills_per_stage': 10,
    'forge_extra_bonus': 0.0,
    'event_gold_bonus': 0.0,
  };

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported) return;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(_defaults);
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await rc.fetchAndActivate();
      debugPrint('[RemoteConfig] fetched and activated');
    } catch (e) {
      debugPrint('[RemoteConfig] init failed, using defaults: $e');
    }
  }

  BalanceTuning get tuning {
    if (!_supported) return const BalanceTuning();
    try {
      final rc = FirebaseRemoteConfig.instance;
      final eventBonus = rc.getDouble('event_gold_bonus');
      return BalanceTuning(
        goldGainMultiplier: rc.getDouble('gold_gain_multiplier') + eventBonus,
        offlineRewardMultiplier: rc.getDouble('offline_reward_multiplier'),
        playerDamageMultiplier: rc.getDouble('player_damage_multiplier'),
        enemyHpMultiplier: rc.getDouble('enemy_hp_multiplier'),
        autoAttackIntervalSec: rc.getDouble('auto_attack_interval_sec'),
        killsPerStage: rc.getInt('kills_per_stage'),
        forgeExtraBonus: rc.getDouble('forge_extra_bonus'),
      );
    } catch (e) {
      debugPrint('[RemoteConfig] tuning read failed, using defaults: $e');
      return const BalanceTuning();
    }
  }
}
