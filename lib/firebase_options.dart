import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3OqXNWcOa2LAMv-jhAadAha8TOT3I3Bo',
    appId: '1:488908762572:web:cab616b7335ec9069ec169',
    messagingSenderId: '488908762572',
    projectId: 'eventmate-ecb46',
    authDomain: 'eventmate-ecb46.firebaseapp.com',
    storageBucket: 'eventmate-ecb46.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3OqXNWcOa2LAMv-jhAadAha8TOT3I3Bo',
    appId: '1:488908762572:android:cab616b7335ec9069ec169',
    messagingSenderId: '488908762572',
    projectId: 'eventmate-ecb46',
    storageBucket: 'eventmate-ecb46.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3OqXNWcOa2LAMv-jhAadAha8TOT3I3Bo',
    appId: '1:488908762572:ios:cab616b7335ec9069ec169',
    messagingSenderId: '488908762572',
    projectId: 'eventmate-ecb46',
    storageBucket: 'eventmate-ecb46.firebasestorage.app',
    iosBundleId: 'com.example.clubevents',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3OqXNWcOa2LAMv-jhAadAha8TOT3I3Bo',
    appId: '1:488908762572:ios:cab616b7335ec9069ec169',
    messagingSenderId: '488908762572',
    projectId: 'eventmate-ecb46',
    storageBucket: 'eventmate-ecb46.firebasestorage.app',
    iosBundleId: 'com.example.clubevents',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB3OqXNWcOa2LAMv-jhAadAha8TOT3I3Bo',
    appId: '1:488908762572:android:cab616b7335ec9069ec169',
    messagingSenderId: '488908762572',
    projectId: 'eventmate-ecb46',
    storageBucket: 'eventmate-ecb46.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyB3OqXNWcOa2LAMv-jhAadAha8TOT3I3Bo',
    appId: '1:488908762572:android:cab616b7335ec9069ec169',
    messagingSenderId: '488908762572',
    projectId: 'eventmate-ecb46',
    storageBucket: 'eventmate-ecb46.firebasestorage.app',
  );
}
