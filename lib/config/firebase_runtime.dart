import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirebaseRuntime {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static FirebaseApp get app =>
      Firebase.app(useEmulators ? 'demo-cbt' : '[DEFAULT]');

  static Future<void> initialize({FirebaseOptions? options}) async {
    if (useEmulators) {
      // A named app avoids native production configuration. These values are
      // emulator-only placeholders and are never used for production access.
      await Firebase.initializeApp(
        name: 'demo-cbt',
        options: const FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: '1:1234567890:android:abcdef0123456789',
          messagingSenderId: '1234567890',
          projectId: 'demo-cbt',
        ),
      );
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      await FirebaseAuth.instanceFor(app: app).useAuthEmulator(host, 9099);
      FirebaseFirestore.instanceFor(
        app: app,
        databaseId: 'cbt-db',
      ).useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(
        app: app,
        region: 'asia-southeast2',
      ).useFunctionsEmulator(host, 5001);
    } else {
      await Firebase.initializeApp(options: options);
    }
  }
}
