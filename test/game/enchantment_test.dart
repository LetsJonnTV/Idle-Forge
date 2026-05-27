import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Rune bonusValue', () {
    test('bonusValue scales with tier', () {
      const r1 = Rune(id: 'r1', type: RuneType.fire, tier: 1);
      const r2 = Rune(id: 'r2', type: RuneType.fire, tier: 2);
      const r3 = Rune(id: 'r3', type: RuneType.fire, tier: 3);
      expect(r2.bonusValue, greaterThan(r1.bonusValue));
      expect(r3.bonusValue, greaterThan(r2.bonusValue));
    });

    test('toJson / fromJson roundtrip', () {
      const rune = Rune(id: 'rj', type: RuneType.gold, tier: 2);
      final json = rune.toJson();
      final restored = Rune.fromJson(json);
      expect(restored.id, rune.id);
      expect(restored.type, rune.type);
      expect(restored.tier, rune.tier);
    });
  });

  group('enchantItem', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('enchantItem succeeds when item has fewer than 2 enchantments', () {
      const item = GameItem(
        id: 'enc_item',
        name: 'Test',
        slot: ItemSlot.weapon,
        tier: ItemTier.rare,
        setId: ItemSet.ember,
        power: 10,
        sellValue: 5,
      );
      const rune = Rune(id: 'r_enc', type: RuneType.fire, tier: 1);
      ctrl.inventory.add(item);
      ctrl.runeInventory.add(rune);
      final result = ctrl.enchantItem('enc_item', 0);
      expect(result, isTrue);
      expect(ctrl.inventory.firstWhere((i) => i.id == 'enc_item').enchantments.length, 1);
      expect(ctrl.runeInventory.isEmpty, isTrue);
    });

    test('enchantItem fails when item already has 2 enchantments', () {
      const rune1 = Rune(id: 'r1_e', type: RuneType.fire, tier: 1);
      const rune2 = Rune(id: 'r2_e', type: RuneType.ice, tier: 1);
      const rune3 = Rune(id: 'r3_e', type: RuneType.life, tier: 1);
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

    test('enchantItem fails with invalid item id', () {
      const rune = Rune(id: 'r_noop', type: RuneType.speed, tier: 1);
      ctrl.runeInventory.add(rune);
      final result = ctrl.enchantItem('nonexistent', 0);
      expect(result, isFalse);
      expect(ctrl.runeInventory.length, 1);
    });
  });

  group('removeEnchantment', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('removeEnchantment removes rune at correct index and returns it to inventory', () {
      const rune1 = Rune(id: 'dis_r1', type: RuneType.fire, tier: 1);
      const rune2 = Rune(id: 'dis_r2', type: RuneType.ice, tier: 2);
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
      expect(updated.enchantments.first.id, 'dis_r2');
      expect(ctrl.runeInventory.any((r) => r.id == 'dis_r1'), isTrue);
    });

    test('removeEnchantment fails with invalid slot index', () {
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

  group('PetState Serialization', () {
    test('PetState toJson / fromJson roundtrip', () {
      const pet = PetState(type: PetType.phoenix, level: 5, xp: 42, isActive: false);
      final json = pet.toJson();
      final restored = PetState.fromJson(json);
      expect(restored.type, PetType.phoenix);
      expect(restored.level, 5);
      expect(restored.xp, 42);
      expect(restored.isActive, false);
    });
  });
}
