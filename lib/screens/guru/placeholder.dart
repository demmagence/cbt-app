import 'package:flutter/material.dart';

class GuruDashboardScreen extends StatelessWidget {
  const GuruDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Guru Dashboard Screen')),
    );
  }
}

class ExamListScreen extends StatelessWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Exam List Screen')),
    );
  }
}

class CreateExamScreen extends StatelessWidget {
  const CreateExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Create Exam Screen')),
    );
  }
}

class EditExamScreen extends StatelessWidget {
  final String examId;
  const EditExamScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Edit Exam Screen: $examId')),
    );
  }
}

class AddQuestionScreen extends StatelessWidget {
  final String examId;
  const AddQuestionScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Questions Setup for Exam: $examId')),
    );
  }
}

class QuestionBankScreen extends StatelessWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Question Bank Screen')),
    );
  }
}

class ExamResultsScreen extends StatelessWidget {
  final String examId;
  const ExamResultsScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Exam Results: $examId')),
    );
  }
}

class StudentResultDetailScreen extends StatelessWidget {
  final String examId;
  final String userId;
  const StudentResultDetailScreen({super.key, required this.examId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Result Detail: Exam $examId, User $userId')),
    );
  }
}

class EssayGradingScreen extends StatelessWidget {
  const EssayGradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Essay Grading Screen')),
    );
  }
}

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
