import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';

void main() {
  group('Ascension System', () {
    late GameController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = GameController(localeCode: 'de');
    });

    test('starts with 0 ascension points', () {
      expect(controller.ascensionPoints, equals(0));
    });

    test('cannot unlock node without points', () {
      expect(controller.canUnlockAscensionNode('warrior_1_attack'), isFalse);
    });

    test('can unlock tier-1 node with enough points', () {
      controller.ascensionPoints = 1;
      expect(controller.canUnlockAscensionNode('warrior_1_attack'), isTrue);
    });

    test('cannot unlock tier-2 node without prerequisite', () {
      controller.ascensionPoints = 5;
      expect(controller.canUnlockAscensionNode('warrior_2_attack'), isFalse);
    });

    test('can unlock tier-2 node after prerequisite is met', () {
      controller.ascensionPoints = 5;
      controller.unlockAscensionNode('warrior_1_attack');
      expect(controller.canUnlockAscensionNode('warrior_2_attack'), isTrue);
    });

    test('points are deducted on unlock', () {
      controller.ascensionPoints = 3;
      controller.unlockAscensionNode('warrior_1_attack');
      expect(controller.ascensionPoints, equals(2));
    });

    test('attack multiplier increases after warrior attack node unlock', () {
      final before = controller.ascensionAttackMultiplier;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('warrior_1_attack');
      expect(controller.ascensionAttackMultiplier, greaterThan(before));
    });

    test('hp multiplier increases after warrior hp node unlock', () {
      final before = controller.ascensionHpMultiplier;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('warrior_1_hp');
      expect(controller.ascensionHpMultiplier, greaterThan(before));
    });

    test('forge bonus increases after smith node unlock', () {
      final before = controller.ascensionForgeBonusChance;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('smith_1_forge');
      expect(controller.ascensionForgeBonusChance, greaterThan(before));
    });

    test('gold multiplier increases after rogue node unlock', () {
      final before = controller.ascensionGoldMultiplier;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('rogue_1_gold');
      expect(controller.ascensionGoldMultiplier, greaterThan(before));
    });
  });
}
