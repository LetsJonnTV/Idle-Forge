import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:idle_forge/l10n/app_text.dart';
import 'package:idle_forge/screens/auth_screen.dart';

void main() {
  late AppText text;

  setUp(() {
    text = AppText('de');
  });

  Widget buildSubject() => MaterialApp(
    home: AuthScreen(onLoggedIn: () {}, onSkip: () {}, text: text),
  );

  testWidgets('renders username and password fields', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
  });

  testWidgets('body is wrapped in SingleChildScrollView for keyboard scroll', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(
      find.byType(SingleChildScrollView),
      findsOneWidget,
      reason:
          'SingleChildScrollView is required so the focused field stays '
          'visible when the keyboard pushes the Scaffold body upward',
    );
  });

  testWidgets(
    'Scaffold does not disable keyboard resize (resizeToAvoidBottomInset != false)',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.resizeToAvoidBottomInset,
        isNot(false),
        reason:
            'Setting resizeToAvoidBottomInset:false would prevent the Scaffold '
            'from adding bottom padding for the keyboard on older Android devices',
      );
    },
  );

  testWidgets('tapping username field opens keyboard', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.showKeyboard(find.byType(TextFormField).first);
    await tester.pump();

    expect(
      tester.testTextInput.isVisible,
      isTrue,
      reason: 'TextFormField must request keyboard input when tapped',
    );
  });

  testWidgets('tapping password field opens keyboard', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.showKeyboard(find.byType(TextFormField).last);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });
}
