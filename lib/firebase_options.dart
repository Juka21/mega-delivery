import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase options are not configured for web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAahes19d6nCSWaaw6xVCglkEi5K5_f64o',
    appId: '1:158452862906:android:0a5386b760c54445b59783',
    messagingSenderId: '158452862906',
    projectId: 'mega-delivery-44580',
    storageBucket: 'mega-delivery-44580.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyATkWCDqtU5gbEz-5kYq_1feS7mgfOVNRA',
    appId: '1:158452862906:ios:b595510eaa15e0cab59783',
    messagingSenderId: '158452862906',
    projectId: 'mega-delivery-44580',
    storageBucket: 'mega-delivery-44580.firebasestorage.app',
    iosBundleId: 'pt.megacachorro.megadelivery',
  );

  static const FirebaseOptions macos = ios;
}
