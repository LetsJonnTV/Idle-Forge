import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_forge/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches into the main shell', (tester) async {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    SharedPreferences.setMockInitialValues({
      'idle_forge.save.v1': jsonEncode({
        'tutorialCompleted': true,
        'lastLoginDateKey': todayKey,
        'playerName': 'Rookie',
      }),
    });

    await app.main();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline) && find.text('Rookie').evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Rookie'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}