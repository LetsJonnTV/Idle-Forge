import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
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
        controller.inventory.add(
          GameItem(
            id: 'test_weapon_$i',
            name: 'Test Weapon $i',
            slot: ItemSlot.weapon,
            tier: ItemTier.uncommon,
            setId: ItemSet.ember,
            power: 20,
            sellValue: 30,
          ),
        );
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
        controller.inventory.add(
          GameItem(
            id: 'test_weapon_$i',
            name: 'Test $i',
            slot: ItemSlot.weapon,
            tier: ItemTier.uncommon,
            setId: ItemSet.ember,
            power: 20,
            sellValue: 30,
          ),
        );
      }
      expect(controller.getMissingIngredients('recipe_shadow_dagger'), isEmpty);
    });

    test(
      'getMissingIngredients returns non-empty when ingredients missing',
      () {
        controller.discoveredRecipes.add('recipe_shadow_dagger');
        expect(
          controller.getMissingIngredients('recipe_shadow_dagger'),
          isNotEmpty,
        );
      },
    );
  });
}
