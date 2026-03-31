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
      default:
        throw UnsupportedError(
          'FirebaseOptions não configurados para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBdTgD-WoJJ_vWBQRN-5no-GekyBJVD554',
    appId: '1:828522686230:web:e1425ab99031186e671237',
    messagingSenderId: '828522686230',
    projectId: 'hora-do-remedio-165b3',
    authDomain: 'hora-do-remedio-165b3.firebaseapp.com',
    storageBucket: 'hora-do-remedio-165b3.firebasestorage.app',
    measurementId: 'G-DB9RQRVWTE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_gGil9MXuz6agSXHC05vTS8c9FV7i07s',
    appId: '1:828522686230:android:1376d1593159d158671237',
    messagingSenderId: '828522686230',
    projectId: 'hora-do-remedio-165b3',
    storageBucket: 'hora-do-remedio-165b3.firebasestorage.app',
  );
}