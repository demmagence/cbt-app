import 'package:flutter/material.dart';

// Placeholders for Guru Screens

class EssayGradingDetailScreen extends StatelessWidget {
  final String examId;
  final String userId;
  const EssayGradingDetailScreen({super.key, required this.examId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Essay Grading Detail: Exam $examId, User $userId')),
    );
  }
}

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Real-time Monitoring Screen')),
    );
  }
}
