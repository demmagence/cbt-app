import 'package:flutter/material.dart';
import 'config/theme/app_theme.dart';

class CbtApp extends StatelessWidget {
  const CbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CBT App',
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: Text('CBT App Initialized'),
        ),
      ),
    );
  }
}
