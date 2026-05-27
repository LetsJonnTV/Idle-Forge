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
  group('Set Bonus Calculation', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('setAttackBonus is 0 with no equipment', () {
      expect(ctrl.setAttackBonus, 0);
    });

    test('Storm 2er gives +6 attack', () {
      ctrl.inventory.add(
        const GameItem(
          id: 'w1',
          name: 'W',
          slot: ItemSlot.weapon,
          tier: ItemTier.common,
          setId: ItemSet.storm,
          power: 1,
          sellValue: 1,
        ),
      );
      ctrl.inventory.add(
        const GameItem(
          id: 'a1',
          name: 'A',
          slot: ItemSlot.armor,
          tier: ItemTier.common,
          setId: ItemSet.storm,
          power: 1,
          sellValue: 1,
        ),
      );
      ctrl.equippedBySlot[ItemSlot.weapon] = 'w1';
      ctrl.equippedBySlot[ItemSlot.armor] = 'a1';
      expect(ctrl.setAttackBonus, 6);
    });

    test('Storm 4er gives +18 attack total', () {
      for (final slot in [ItemSlot.weapon, ItemSlot.armor, ItemSlot.helm, ItemSlot.gloves]) {
        final id = 'i_${slot.name}';
        ctrl.inventory.add(
          GameItem(
            id: id,
            name: 'I',
            slot: slot,
            tier: ItemTier.common,
            setId: ItemSet.storm,
            power: 1,
            sellValue: 1,
          ),
        );
        ctrl.equippedBySlot[slot] = id;
      }
      expect(ctrl.setAttackBonus, 18); // 6 + 12
    });

    test('Storm 6er gives +31 attack total', () {
      for (final slot in ItemSlot.values) {
        final id = 'i6_${slot.name}';
        ctrl.inventory.add(
          GameItem(
            id: id,
            name: 'I',
            slot: slot,
            tier: ItemTier.common,
            setId: ItemSet.storm,
            power: 1,
            sellValue: 1,
          ),
        );
        ctrl.equippedBySlot[slot] = id;
      }
      expect(ctrl.setAttackBonus, 31); // 6 + 12 + 13
    });

    test('Tide 2er gives setHpBonusMultiplier 1.1', () {
      for (final slot in [ItemSlot.weapon, ItemSlot.armor]) {
        final id = 'tide_${slot.name}';
        ctrl.inventory.add(
          GameItem(
            id: id,
            name: 'T',
            slot: slot,
            tier: ItemTier.common,
            setId: ItemSet.tide,
            power: 1,
            sellValue: 1,
          ),
        );
        ctrl.equippedBySlot[slot] = id;
      }
      expect(ctrl.setHpBonusMultiplier, closeTo(1.1, 0.001));
    });

    test('Tide 6er gives setHpBonusMultiplier 1.35', () {
      for (final slot in ItemSlot.values) {
        final id = 'tide6_${slot.name}';
        ctrl.inventory.add(
          GameItem(
            id: id,
            name: 'T',
            slot: slot,
            tier: ItemTier.common,
            setId: ItemSet.tide,
            power: 1,
            sellValue: 1,
          ),
        );
        ctrl.equippedBySlot[slot] = id;
      }
      expect(ctrl.setHpBonusMultiplier, closeTo(1.35, 0.001));
    });

    test('Ember 4er gives setForgeBonus 0.05', () {
      for (final slot in [ItemSlot.weapon, ItemSlot.armor, ItemSlot.helm, ItemSlot.gloves]) {
        final id = 'emb_${slot.name}';
        ctrl.inventory.add(
          GameItem(
            id: id,
            name: 'E',
            slot: slot,
            tier: ItemTier.common,
            setId: ItemSet.ember,
            power: 1,
            sellValue: 1,
          ),
        );
        ctrl.equippedBySlot[slot] = id;
      }
      expect(ctrl.setForgeBonus, closeTo(0.05, 0.001));
    });

    test('Ember 6er gives setForgeBonus 0.15', () {
      for (final slot in ItemSlot.values) {
        final id = 'emb6_${slot.name}';
        ctrl.inventory.add(
          GameItem(
            id: id,
            name: 'E',
            slot: slot,
            tier: ItemTier.common,
            setId: ItemSet.ember,
            power: 1,
            sellValue: 1,
          ),
        );
        ctrl.equippedBySlot[slot] = id;
      }
      expect(ctrl.setForgeBonus, closeTo(0.15, 0.001));
    });
  });

  group('EquipDiff', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('calculateEquipDiff returns positive delta for better item', () {
      const weak = GameItem(
        id: 'w_weak',
        name: 'Weak',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 1,
        sellValue: 1,
      );
      const strong = GameItem(
        id: 'w_strong',
        name: 'Strong',
        slot: ItemSlot.weapon,
        tier: ItemTier.rare,
        setId: ItemSet.ember,
        power: 50,
        sellValue: 10,
      );
      ctrl.inventory.add(weak);
      ctrl.inventory.add(strong);
      ctrl.equippedBySlot[ItemSlot.weapon] = 'w_weak';
      final diff = ctrl.calculateEquipDiff(strong);
      expect(diff.delta, greaterThan(0));
    });

    test('calculateEquipDiff returns negative delta for weaker item', () {
      const strong = GameItem(
        id: 'w_strong2',
        name: 'Strong',
        slot: ItemSlot.weapon,
        tier: ItemTier.rare,
        setId: ItemSet.ember,
        power: 50,
        sellValue: 10,
      );
      const weak = GameItem(
        id: 'w_weak2',
        name: 'Weak',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 1,
        sellValue: 1,
      );
      ctrl.inventory.add(strong);
      ctrl.inventory.add(weak);
      ctrl.equippedBySlot[ItemSlot.weapon] = 'w_strong2';
      final diff = ctrl.calculateEquipDiff(weak);
      expect(diff.delta, lessThan(0));
    });

    test('calculateEquipDiff does not mutate equippedBySlot', () {
      const item = GameItem(
        id: 'test_item',
        name: 'T',
        slot: ItemSlot.ring,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 5,
        sellValue: 1,
      );
      ctrl.inventory.add(item);
      ctrl.equippedBySlot.clear();
      ctrl.calculateEquipDiff(item);
      expect(ctrl.equippedBySlot.containsKey(ItemSlot.ring), false);
    });

    test('calculateEquipDiff restores previous equipped after simulation', () {
      const prev = GameItem(
        id: 'prev_item',
        name: 'Prev',
        slot: ItemSlot.ring,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 3,
        sellValue: 1,
      );
      const next = GameItem(
        id: 'next_item',
        name: 'Next',
        slot: ItemSlot.ring,
        tier: ItemTier.uncommon,
        setId: ItemSet.ember,
        power: 8,
        sellValue: 2,
      );
      ctrl.inventory.add(prev);
      ctrl.inventory.add(next);
      ctrl.equippedBySlot[ItemSlot.ring] = 'prev_item';
      ctrl.calculateEquipDiff(next);
      // must still point to prev after diff
      expect(ctrl.equippedBySlot[ItemSlot.ring], 'prev_item');
    });
  });

  group('Pet System', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('no pet gives no bonuses', () {
      expect(ctrl.petGoldBonus, 0.0);
      expect(ctrl.petForgeBonus, 0.0);
      expect(ctrl.petDefenseBonus, 0.0);
    });

    test('wolf pet gives gold bonus at level 1', () {
      ctrl.adoptPet(PetType.wolf);
      expect(ctrl.petGoldBonus, closeTo(0.005, 0.0001));
    });

    test('wolf pet gives no forge or defense bonus', () {
      ctrl.adoptPet(PetType.wolf);
      expect(ctrl.petForgeBonus, 0.0);
      expect(ctrl.petDefenseBonus, 0.0);
    });

    test('phoenix pet gives forge bonus', () {
      ctrl.adoptPet(PetType.phoenix);
      expect(ctrl.petForgeBonus, closeTo(0.005, 0.0001));
    });

    test('golem pet reduces incoming damage', () {
      ctrl.adoptPet(PetType.golem);
      expect(ctrl.petDefenseBonus, closeTo(0.005, 0.0001));
    });

    test('inactive pet gives no bonuses', () {
      ctrl.adoptPet(PetType.wolf);
      ctrl.pet = ctrl.pet!.copyWith(isActive: false);
      expect(ctrl.petGoldBonus, 0.0);
    });

    test('pet xpToNextLevel increases with level', () {
      const pet1 = PetState(type: PetType.wolf, level: 1, xp: 0, isActive: true);
      const pet5 = PetState(type: PetType.wolf, level: 5, xp: 0, isActive: true);
      expect(pet5.xpToNextLevel, greaterThan(pet1.xpToNextLevel));
    });

    test('pet canLevelUp is true when xp >= xpToNextLevel', () {
      const pet = PetState(type: PetType.wolf, level: 1, xp: 25, isActive: true);
      expect(pet.canLevelUp, isTrue);
    });

    test('pet canLevelUp is false at max level 20', () {
      const pet = PetState(type: PetType.wolf, level: 20, xp: 9999, isActive: true);
      expect(pet.canLevelUp, isFalse);
    });
  });

  group('Login Streak', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('getStreakReward day 1 gives 50 gold', () {
      final reward = ctrl.getStreakReward(1);
      expect(reward.gold, 50);
      expect(reward.hammers, 0);
      expect(reward.shards, 0);
    });

    test('getStreakReward day 2 gives 100 gold and 5 hammers', () {
      final reward = ctrl.getStreakReward(2);
      expect(reward.gold, 100);
      expect(reward.hammers, 5);
    });

    test('getStreakReward day 7 gives 3 shards', () {
      final reward = ctrl.getStreakReward(7);
      expect(reward.shards, 3);
      expect(reward.gold, 300);
    });

    test('streak reward cycles every 7 days', () {
      final day1 = ctrl.getStreakReward(1);
      final day8 = ctrl.getStreakReward(8);
      expect(day1.gold, day8.gold);
      expect(day1.hammers, day8.hammers);
      expect(day1.shards, day8.shards);
    });

    test('streak reward cycles: day 14 same as day 7', () {
      final day7 = ctrl.getStreakReward(7);
      final day14 = ctrl.getStreakReward(14);
      expect(day7.gold, day14.gold);
      expect(day7.shards, day14.shards);
    });
  });

  group('Rune & Enchantment System', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController(localeCode: 'de');
    });

    test('Rune bonusValue scales with tier', () {
      const r1 = Rune(id: 'r1', type: RuneType.fire, tier: 1);
      const r2 = Rune(id: 'r2', type: RuneType.fire, tier: 2);
      const r3 = Rune(id: 'r3', type: RuneType.fire, tier: 3);
      expect(r2.bonusValue, greaterThan(r1.bonusValue));
      expect(r3.bonusValue, greaterThan(r2.bonusValue));
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
      final result = ctrl.enchantItem('enc_item', rune);
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
      final result = ctrl.enchantItem('enc_full', rune3);
      expect(result, isFalse);
      expect(ctrl.runeInventory.length, 1); // rune not consumed
    });

    test('disenchantItem removes rune at correct index', () {
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
      final result = ctrl.disenchantItem('dis_item', 0);
      expect(result, isTrue);
      final updated = ctrl.inventory.firstWhere((i) => i.id == 'dis_item');
      expect(updated.enchantments.length, 1);
      expect(updated.enchantments.first.id, 'dis_r2');
    });

    test('Rune toJson / fromJson roundtrip', () {
      const rune = Rune(id: 'rj', type: RuneType.gold, tier: 2);
      final json = rune.toJson();
      final restored = Rune.fromJson(json);
      expect(restored.id, rune.id);
      expect(restored.type, rune.type);
      expect(restored.tier, rune.tier);
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

  group('EquipDiff Model', () {
    test('EquipDiff delta is newPower minus currentPower', () {
      const diff = EquipDiff(
        currentPower: 100,
        newPower: 150,
        delta: 50,
        currentHp: 300,
        newHp: 360,
      );
      expect(diff.delta, diff.newPower - diff.currentPower);
    });
  });
}
