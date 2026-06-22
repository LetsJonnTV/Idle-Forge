import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidManifest keyboard configuration', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('uses adjustNothing for windowSoftInputMode', () {
      expect(
        manifest,
        contains('android:windowSoftInputMode="adjustNothing"'),
        reason:
            'adjustNothing lets Flutter own keyboard insets via '
            'MediaQuery.viewInsets on all Android versions, including '
            'budget devices running Android 11 (e.g. Samsung Galaxy A12)',
      );
    });

    test('does not use adjustResize', () {
      expect(
        manifest,
        isNot(contains('adjustResize')),
        reason:
            'adjustResize conflicts with resizeToAvoidBottomInset:false on '
            'older Android (API <30) and causes the keyboard to not open',
      );
    });
  });
}
