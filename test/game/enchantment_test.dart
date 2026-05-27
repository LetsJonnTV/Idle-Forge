import 'package:flutter_test/flutter_test.dart';
import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Rune serialization', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      const rune = Rune(type: RuneType.gold, tier: 2, bonusValue: 0.08);
      final json = rune.toJson();
      final restored = Rune.fromJson(json);
      expect(restored.type, RuneType.gold);
      expect(restored.tier, 2);
      expect(restored.bonusValue, closeTo(0.08, 0.0001));
    });
  });

  group('enchantItem', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('succeeds when item has fewer than 2 enchantments', () {
      const item = GameItem(
        id: 'enc_item',
        name: 'Test',
        slot: ItemSlot.weapon,
        tier: ItemTier.rare,
        setId: ItemSet.ember,
        power: 10,
        sellValue: 5,
      );
      const rune = Rune(type: RuneType.fire, tier: 1, bonusValue: 0.05);
      ctrl.inventory.add(item);
      ctrl.runeInventory.add(rune);
      final result = ctrl.enchantItem('enc_item', 0);
      expect(result, isTrue);
      expect(ctrl.inventory.firstWhere((i) => i.id == 'enc_item').enchantments.length, 1);
      expect(ctrl.runeInventory.isEmpty, isTrue);
    });

    test('fails when item already has 2 enchantments', () {
      const rune1 = Rune(type: RuneType.fire, tier: 1, bonusValue: 0.05);
      const rune2 = Rune(type: RuneType.ice, tier: 1, bonusValue: 0.05);
      const rune3 = Rune(type: RuneType.life, tier: 1, bonusValue: 0.05);
      final item = GameItem(
        id: 'enc_full',
        name: 'Full',
        slot: ItemSlot.weapon,
        tier: ItemTier.rare,
        setId: ItemSet.ember,
        power: 10,
        sellValue: 5,
        enchantments: const [rune1, rune2],
      );
      ctrl.inventory.add(item);
      ctrl.runeInventory.add(rune3);
      final result = ctrl.enchantItem('enc_full', 0);
      expect(result, isFalse);
      expect(ctrl.runeInventory.length, 1);
    });

    test('fails with invalid item id', () {
      const rune = Rune(type: RuneType.speed, tier: 1, bonusValue: 0.03);
      ctrl.runeInventory.add(rune);
      final result = ctrl.enchantItem('nonexistent', 0);
      expect(result, isFalse);
      expect(ctrl.runeInventory.length, 1);
    });

    test('fails with invalid rune index', () {
      const item = GameItem(
        id: 'enc_idx',
        name: 'I',
        slot: ItemSlot.helm,
        tier: ItemTier.common,
        setId: ItemSet.tide,
        power: 3,
        sellValue: 1,
      );
      ctrl.inventory.add(item);
      final result = ctrl.enchantItem('enc_idx', 0);
      expect(result, isFalse);
    });
  });

  group('removeEnchantment', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('removes rune at correct index and returns it to inventory', () {
      const rune1 = Rune(type: RuneType.fire, tier: 1, bonusValue: 0.05);
      const rune2 = Rune(type: RuneType.ice, tier: 2, bonusValue: 0.08);
      final item = GameItem(
        id: 'dis_item',
        name: 'D',
        slot: ItemSlot.armor,
        tier: ItemTier.uncommon,
        setId: ItemSet.tide,
        power: 5,
        sellValue: 2,
        enchantments: const [rune1, rune2],
      );
      ctrl.inventory.add(item);
      final result = ctrl.removeEnchantment('dis_item', 0);
      expect(result, isTrue);
      final updated = ctrl.inventory.firstWhere((i) => i.id == 'dis_item');
      expect(updated.enchantments.length, 1);
      expect(updated.enchantments.first.type, RuneType.ice);
      expect(ctrl.runeInventory.any((r) => r.type == RuneType.fire), isTrue);
    });

    test('fails with invalid slot index', () {
      const item = GameItem(
        id: 'empty_enc',
        name: 'E',
        slot: ItemSlot.helm,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 2,
        sellValue: 1,
      );
      ctrl.inventory.add(item);
      expect(ctrl.removeEnchantment('empty_enc', 0), isFalse);
    });
  });

  group('PetState serialization', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final pet = PetState(type: PetType.phoenix, level: 5, xp: 42, isActive: false);
      final json = pet.toJson();
      final restored = PetState.fromJson(json);
      expect(restored.type, PetType.phoenix);
      expect(restored.level, 5);
      expect(restored.xp, 42);
      expect(restored.isActive, false);
    });
  });
}
