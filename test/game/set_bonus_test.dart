import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Set Bonus', () {
    test('ember 6-piece gives 20% forge bonus', () {
      final gc = GameController();
      for (int i = 0; i < ItemSlot.values.length; i++) {
        final item = GameItem(
          id: 'ember_$i',
          name: 'Ember Item $i',
          slot: ItemSlot.values[i],
          tier: ItemTier.epic,
          setId: ItemSet.ember,
          power: 10,
          sellValue: 50,
        );
        gc.inventory.add(item);
        gc.equippedBySlot[ItemSlot.values[i]] = 'ember_$i';
      }
      expect(gc.equippedSetCounts[ItemSet.ember], 6);
      expect(gc.setForgeBonus, closeTo(0.20, 0.001));
    });

    test('storm 6-piece gives 25% attack speed bonus', () {
      final gc = GameController();
      for (int i = 0; i < ItemSlot.values.length; i++) {
        final item = GameItem(
          id: 'storm_$i',
          name: 'Storm Item $i',
          slot: ItemSlot.values[i],
          tier: ItemTier.epic,
          setId: ItemSet.storm,
          power: 10,
          sellValue: 50,
        );
        gc.inventory.add(item);
        gc.equippedBySlot[ItemSlot.values[i]] = 'storm_$i';
      }
      expect(gc.equippedSetCounts[ItemSet.storm], 6);
      expect(gc.setAttackSpeedBonus, closeTo(0.75, 0.001));
    });

    test('tide 6-piece gives 15% flask effect bonus', () {
      final gc = GameController();
      for (int i = 0; i < ItemSlot.values.length; i++) {
        final item = GameItem(
          id: 'tide_$i',
          name: 'Tide Item $i',
          slot: ItemSlot.values[i],
          tier: ItemTier.epic,
          setId: ItemSet.tide,
          power: 10,
          sellValue: 50,
        );
        gc.inventory.add(item);
        gc.equippedBySlot[ItemSlot.values[i]] = 'tide_$i';
      }
      expect(gc.equippedSetCounts[ItemSet.tide], 6);
      expect(gc.setFlaskEffectBonus, closeTo(1.15, 0.001));
    });
  });
}
