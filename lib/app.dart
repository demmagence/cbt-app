import 'package:flutter/material.dart';

class CbtApp extends StatelessWidget {
  const CbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CBT App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('CBT App Initialized'),
        ),
      ),
    );
  }
}
