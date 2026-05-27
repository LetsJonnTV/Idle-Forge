import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';

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

    test('expedition is not immediately complete when started', () {
      controller.startExpedition(0, 'hunt_1h');
      final expedition = controller.expeditionSlots[0]!;
      expect(expedition.isComplete, isFalse);
    });

    test('remaining duration is positive when expedition started', () {
      controller.startExpedition(0, 'hunt_1h');
      final expedition = controller.expeditionSlots[0]!;
      expect(expedition.remaining.inMinutes, greaterThan(50));
    });
  });
}
