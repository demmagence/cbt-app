import 'package:flutter/material.dart';
import 'config/firebase_runtime.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseRuntime.initialize(
      options: FirebaseRuntime.useEmulators
          ? null
          : DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const CbtApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aplikasi belum dapat dimulai. Periksa konfigurasi Firebase dan koneksi, lalu buka kembali.\n\n$error',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
