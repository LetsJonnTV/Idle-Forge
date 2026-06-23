import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBwzUeq6N9lALTBK7R22rvTXxermrJ8Beo',
    appId: '1:274619001220:android:516b5acf8f37dfc8be95d1',
    messagingSenderId: '274619001220',
    projectId: 'astral-theory-449511-c1',
    storageBucket: 'astral-theory-449511-c1.firebasestorage.app',
  );
}
