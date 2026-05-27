import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/game/game_controller.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Login Streak', () {
    test('streak increments on first login', () {
      final gc = GameController();
      expect(gc.loginStreakDays, 0);
      gc.checkAndClaimLoginStreak();
      expect(gc.loginStreakDays, 1);
      expect(gc.streakClaimedToday, true);
    });

    test('streak does not double-claim on same day', () {
      final gc = GameController();
      gc.checkAndClaimLoginStreak();
      final firstStreak = gc.loginStreakDays;
      gc.checkAndClaimLoginStreak();
      expect(gc.loginStreakDays, firstStreak);
    });
  });
}
