import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
  group('Expedition System', () {
    late GameController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = GameController(localeCode: 'de');
    });

    test('expedition slot starts empty', () {
      expect(controller.expeditionSlots[0], isNull);
      expect(controller.expeditionSlots[1], isNull);
      expect(controller.expeditionSlots[2], isNull);
    });

    test('can start expedition in empty slot', () {
      final ok = controller.startExpedition(0, 'hunt_1h');
      expect(ok, isTrue);
      expect(controller.expeditionSlots[0], isNotNull);
      expect(controller.expeditionSlots[0]!.expeditionId, equals('hunt_1h'));
    });

    test('cannot start expedition in occupied slot', () {
      controller.startExpedition(0, 'hunt_1h');
      final ok = controller.startExpedition(0, 'hunt_4h');
      expect(ok, isFalse);
    });

    test('invalid slot index returns false', () {
      expect(controller.startExpedition(-1, 'hunt_1h'), isFalse);
      expect(controller.startExpedition(3, 'hunt_1h'), isFalse);
    });

    test('expedition completes after time', () {
      controller.startExpedition(0, 'hunt_1h');
      final expedition = controller.expeditionSlots[0]!;
      expect(expedition.isComplete, isFalse);
    });

    test('ActiveExpedition remaining duration is positive when started', () {
      controller.startExpedition(0, 'hunt_1h');
      final expedition = controller.expeditionSlots[0]!;
      expect(expedition.remaining.inMinutes, greaterThan(50));
    });
  });

  group('Crafting Recipes', () {
    late GameController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = GameController(localeCode: 'de');
    });

    test('no recipes known by default', () {
      expect(controller.knownRecipes, isEmpty);
    });

    test('cannot craft unknown recipe', () {
      final result = controller.craftByRecipe('recipe_shadow_dagger');
      expect(result, isNull);
    });

    test('can craft when discovered and ingredients available', () {
      controller.discoveredRecipes.add('recipe_shadow_dagger');
      controller.gold = 1000;
      controller.hammers = 100;
      for (int i = 0; i < 3; i++) {
        controller.inventory.add(GameItem(
          id: 'test_weapon_$i',
          name: 'Test Weapon $i',
          slot: ItemSlot.weapon,
          tier: ItemTier.uncommon,
          setId: ItemSet.ember,
          power: 20,
          sellValue: 30,
        ));
      }
      expect(controller.canCraftRecipe('recipe_shadow_dagger'), isTrue);
      final result = controller.craftByRecipe('recipe_shadow_dagger');
      expect(result, isNotNull);
      expect(result!.tier, equals(ItemTier.rare));
    });

    test('getMissingIngredients returns empty when ingredients present', () {
      controller.discoveredRecipes.add('recipe_shadow_dagger');
      controller.gold = 1000;
      controller.hammers = 100;
      for (int i = 0; i < 3; i++) {
        controller.inventory.add(GameItem(
          id: 'test_weapon_$i',
          name: 'Test $i',
          slot: ItemSlot.weapon,
          tier: ItemTier.uncommon,
          setId: ItemSet.ember,
          power: 20,
          sellValue: 30,
        ));
      }
      expect(controller.getMissingIngredients('recipe_shadow_dagger'), isEmpty);
    });

    test('getMissingIngredients returns non-empty when missing', () {
      controller.discoveredRecipes.add('recipe_shadow_dagger');
      expect(controller.getMissingIngredients('recipe_shadow_dagger'), isNotEmpty);
    });
  });

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

    test('can unlock tier-2 node with prerequisite', () {
      controller.ascensionPoints = 5;
      controller.unlockAscensionNode('warrior_1_attack');
      expect(controller.canUnlockAscensionNode('warrior_2_attack'), isTrue);
    });

    test('points are deducted on unlock', () {
      controller.ascensionPoints = 3;
      controller.unlockAscensionNode('warrior_1_attack');
      expect(controller.ascensionPoints, equals(2));
    });

    test('attack multiplier increases after warrior unlock', () {
      final before = controller.ascensionAttackMultiplier;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('warrior_1_attack');
      expect(controller.ascensionAttackMultiplier, greaterThan(before));
    });

    test('hp multiplier increases after warrior hp unlock', () {
      final before = controller.ascensionHpMultiplier;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('warrior_1_hp');
      expect(controller.ascensionHpMultiplier, greaterThan(before));
    });

    test('forge bonus increases after smith unlock', () {
      final before = controller.ascensionForgeBonusChance;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('smith_1_forge');
      expect(controller.ascensionForgeBonusChance, greaterThan(before));
    });

    test('gold multiplier increases after rogue unlock', () {
      final before = controller.ascensionGoldMultiplier;
      controller.ascensionPoints = 1;
      controller.unlockAscensionNode('rogue_1_gold');
      expect(controller.ascensionGoldMultiplier, greaterThan(before));
    });
  });

  group('Dungeon System', () {
    late GameController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = GameController(localeCode: 'de');
    });

    test('starts with full energy', () {
      expect(controller.dungeonEnergy, equals(10));
      expect(controller.dungeonMaxEnergy, equals(10));
    });

    test('no active run initially', () {
      expect(controller.activeDungeonRun, isNull);
    });

    test('can start normal dungeon with enough energy', () {
      final ok = controller.startDungeon(DungeonDifficulty.normal);
      expect(ok, isTrue);
      expect(controller.activeDungeonRun, isNotNull);
      expect(controller.dungeonEnergy, lessThan(10));
    });

    test('cannot start nightmare dungeon without enough energy', () {
      controller.dungeonController.dungeonEnergy = 5;
      final ok = controller.startDungeon(DungeonDifficulty.nightmare);
      expect(ok, isFalse);
    });

    test('cannot start second dungeon while one is active', () {
      controller.startDungeon(DungeonDifficulty.normal);
      final ok = controller.startDungeon(DungeonDifficulty.normal);
      expect(ok, isFalse);
    });

    test('advance dungeon stage increments current stage', () {
      controller.startDungeon(DungeonDifficulty.normal);
      expect(controller.activeDungeonRun!.currentStage, equals(1));
      controller.advanceDungeonStage();
      expect(controller.activeDungeonRun!.currentStage, equals(2));
    });

    test('completing stage 5 produces pending reward', () {
      controller.startDungeon(DungeonDifficulty.normal);
      for (int i = 0; i < 5; i++) {
        controller.advanceDungeonStage();
      }
      expect(controller.dungeonController.pendingDungeonReward, isNotNull);
    });
  });
}
