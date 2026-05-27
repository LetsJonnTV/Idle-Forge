import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Smart Equip Diff', () {
    test('diff is positive when new item is stronger', () {
      final gc = GameController();
      const weakItem = GameItem(
        id: 'w1',
        name: 'Weak Sword',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 5,
        sellValue: 10,
      );
      const strongItem = GameItem(
        id: 's1',
        name: 'Strong Sword',
        slot: ItemSlot.weapon,
        tier: ItemTier.epic,
        setId: ItemSet.ember,
        power: 50,
        sellValue: 100,
      );
      gc.inventory.add(weakItem);
      gc.equippedBySlot[ItemSlot.weapon] = 'w1';
      final diff = gc.calculateEquipDiff(strongItem);
      expect(diff.delta, greaterThan(0));
      expect(diff.delta, 45);
    });

    test('diff is negative when new item is weaker', () {
      final gc = GameController();
      const strongItem = GameItem(
        id: 's1',
        name: 'Strong Sword',
        slot: ItemSlot.weapon,
        tier: ItemTier.epic,
        setId: ItemSet.ember,
        power: 50,
        sellValue: 100,
      );
      const weakItem = GameItem(
        id: 'w1',
        name: 'Weak Sword',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 5,
        sellValue: 10,
      );
      gc.inventory.add(strongItem);
      gc.equippedBySlot[ItemSlot.weapon] = 's1';
      final diff = gc.calculateEquipDiff(weakItem);
      expect(diff.delta, lessThan(0));
      expect(diff.delta, -45);
    });

    test('diff is zero when items have same power', () {
      final gc = GameController();
      const itemA = GameItem(
        id: 'a1',
        name: 'Sword A',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 20,
        sellValue: 10,
      );
      const itemB = GameItem(
        id: 'b1',
        name: 'Sword B',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.tide,
        power: 20,
        sellValue: 10,
      );
      gc.inventory.add(itemA);
      gc.equippedBySlot[ItemSlot.weapon] = 'a1';
      final diff = gc.calculateEquipDiff(itemB);
      expect(diff.delta, equals(0));
    });
  });
}
