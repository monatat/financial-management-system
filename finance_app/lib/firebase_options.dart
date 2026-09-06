// ============================================================
// STUB FILE — DO NOT USE IN PRODUCTION
// ============================================================
// This file is a placeholder so the project compiles.
//
// Before running the app, you MUST replace this file by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// That command will connect to your Firebase project and
// overwrite this file with your real credentials.
// See "Firebase Setup Steps" in the Phase 2 documentation.
// ============================================================

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.\n'
          'Run: flutterfire configure',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDBBtzI1HCroejdRDuEtoruGVfqMMbILxA',
    appId: '1:448409995708:web:92fbc5907c1682e7a683b9',
    messagingSenderId: '448409995708',
    projectId: 'finance-app-f7cb9',
    authDomain: 'finance-app-f7cb9.firebaseapp.com',
    storageBucket: 'finance-app-f7cb9.firebasestorage.app',
  );

  // TODO: Replace by running: flutterfire configure

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDTL4xYGaZJoFjJENA3pEFfMjZrrv2hbHI',
    appId: '1:448409995708:android:b72f4d77d2b0c44da683b9',
    messagingSenderId: '448409995708',
    projectId: 'finance-app-f7cb9',
    storageBucket: 'finance-app-f7cb9.firebasestorage.app',
  );

  // TODO: Replace by running: flutterfire configure

  // TODO: Replace by running: flutterfire configure
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_IOS_API_KEY',
    appId: 'REPLACE_WITH_YOUR_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.financeapp.financeApp',
  );

  // TODO: Replace by running: flutterfire configure
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_MACOS_API_KEY',
    appId: 'REPLACE_WITH_YOUR_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.financeapp.financeApp',
  );
}