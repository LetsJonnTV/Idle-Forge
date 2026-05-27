import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
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
