import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseConfig {
  static bool _isReady = false;
  static dynamic initializationError;

  static bool get isReady => _isReady || Firebase.apps.isNotEmpty;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        // Use the generated DefaultFirebaseOptions for all platforms.
        // This is the recommended approach when using FlutterFire CLI.
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _isReady = true;
      initializationError = null;
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        _isReady = true;
        initializationError = null;
        debugPrint('Firebase already initialized (duplicate-app handled)');
      } else {
        _isReady = false;
        initializationError = e;
        debugPrint('Firebase initialization error: $e');
      }
    }
  }
}
