import 'package:flutter/material.dart';



class ExamTakingScreen extends StatelessWidget {
  final String examId;
  const ExamTakingScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Taking Exam: $examId')),
    );
  }
}

class ExamHistoryScreen extends StatelessWidget {
  const ExamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Exam History Screen')),
    );
  }
}

class SiswaProfileScreen extends StatelessWidget {
  const SiswaProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Siswa Profile Screen')),
    );
  }
}
