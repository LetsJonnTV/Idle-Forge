import 'package:flutter_test/flutter_test.dart';
import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
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

    test('storm 6-piece gives 25% speed bonus', () {
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

    test('tide 6-piece gives 15% flask bonus', () {
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

  group('Login Streak', () {
    test('streak increments on first login', () {
      final gc = GameController();
      expect(gc.loginStreakDays, 0);
      gc.checkAndClaimLoginStreak();
      expect(gc.loginStreakDays, 1);
      expect(gc.streakClaimedToday, true);
    });

    test('streak does not double-claim same day', () {
      final gc = GameController();
      gc.checkAndClaimLoginStreak();
      final firstStreak = gc.loginStreakDays;
      gc.checkAndClaimLoginStreak();
      expect(gc.loginStreakDays, firstStreak);
    });
  });

  group('Smart Equip Diff', () {
    test('diff is positive when new item is stronger', () {
      final gc = GameController();
      final weakItem = const GameItem(
        id: 'w1',
        name: 'Weak Sword',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 5,
        sellValue: 10,
      );
      final strongItem = const GameItem(
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
      final strongItem = const GameItem(
        id: 's1',
        name: 'Strong Sword',
        slot: ItemSlot.weapon,
        tier: ItemTier.epic,
        setId: ItemSet.ember,
        power: 50,
        sellValue: 100,
      );
      final weakItem = const GameItem(
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
  });

  group('Pet System', () {
    test('wolf grants gold bonus', () {
      final gc = GameController();
      gc.gold = 500;
      gc.adoptPet(PetType.wolf);
      expect(gc.activePet, isNotNull);
      expect(gc.activePet!.type, PetType.wolf);
      expect(gc.petGoldBonus, closeTo(0.005, 0.0001));
    });

    test('pet levels up correctly', () {
      final gc = GameController();
      gc.gold = 500;
      gc.adoptPet(PetType.wolf);
      gc.hammers = 100;
      gc.feedPet(10);
      expect(gc.activePet!.level, greaterThanOrEqualTo(1));
      final prevLevel = gc.activePet!.level;
      gc.feedPet(50);
      expect(gc.activePet!.level, greaterThanOrEqualTo(prevLevel));
    });
  });
}
