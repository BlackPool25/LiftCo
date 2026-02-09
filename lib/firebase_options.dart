// File generated manually with Firebase config for LiftCo
// To regenerate, run: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBMxb4Kbs69CiEtLZsiEgVfI3vfrqY9Yi8',
    appId: '1:447275736592:web:df8b4231556c7307b4f495',
    messagingSenderId: '447275736592',
    projectId: 'liftco',
    authDomain: 'liftco.firebaseapp.com',
    storageBucket: 'liftco.firebasestorage.app',
    measurementId: 'G-4JD4C22E22',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCECIO3-QOU7mjd9CfPDabonX3Hd3af_E',
    appId: '1:447275736592:android:c6c858ca403d6966b4f495',
    messagingSenderId: '447275736592',
    projectId: 'liftco',
    storageBucket: 'liftco.firebasestorage.app',
  );

  // iOS config - update with your iOS app credentials from Firebase Console
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBMxb4Kbs69CiEtLZsiEgVfI3vfrqY9Yi8',
    appId: '1:447275736592:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '447275736592',
    projectId: 'liftco',
    storageBucket: 'liftco.firebasestorage.app',
    iosBundleId: 'com.liftco.liftco',
  );

  // macOS config - same as iOS for now
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBMxb4Kbs69CiEtLZsiEgVfI3vfrqY9Yi8',
    appId: '1:447275736592:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '447275736592',
    projectId: 'liftco',
    storageBucket: 'liftco.firebasestorage.app',
    iosBundleId: 'com.liftco.liftco',
  );

  // Windows config
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBMxb4Kbs69CiEtLZsiEgVfI3vfrqY9Yi8',
    appId: '1:447275736592:web:df8b4231556c7307b4f495',
    messagingSenderId: '447275736592',
    projectId: 'liftco',
    authDomain: 'liftco.firebaseapp.com',
    storageBucket: 'liftco.firebasestorage.app',
    measurementId: 'G-4JD4C22E22',
  );
}
