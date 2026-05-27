import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';
import 'package:idle_forge/game/models.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
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

    test('pet levels up after feeding', () {
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

    test('phoenix grants forge bonus', () {
      final gc = GameController();
      gc.gold = 500;
      gc.adoptPet(PetType.phoenix);
      expect(gc.activePet!.type, PetType.phoenix);
      expect(gc.petForgeBonus, greaterThan(0));
    });

    test('golem grants defense bonus', () {
      final gc = GameController();
      gc.gold = 500;
      gc.adoptPet(PetType.golem);
      expect(gc.activePet!.type, PetType.golem);
      expect(gc.petDefenseBonus, greaterThan(0));
    });
  });
}
