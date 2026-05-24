import 'package:flutter_test/flutter_test.dart';

import 'package:idle_forge/main.dart';

void main() {
  testWidgets('Idle Forge shell starts', (WidgetTester tester) async {
    await tester.pumpWidget(const IdleForgeApp());
    expect(find.text('Idle Forge'), findsNothing);
  });
}
