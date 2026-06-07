import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/exam_model.dart';
import 'firestore_service.dart';

class ExamCodeService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'cbt-db',
  );

  // Generate a 6-character alphanumeric uppercase code
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Generate code and check uniqueness in Firestore
  Future<String> generateUniqueCode() async {
    while (true) {
      final code = _generateRandomCode();
      final querySnapshot = await _db
          .collection(FirestoreService.examsPath)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isEmpty) {
        return code;
      }
    }
  }

  // Validate if code exists, is marked active, and current time fits the exam schedule
  Future<ExamModel?> validateCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final querySnapshot = await _db
        .collection(FirestoreService.examsPath)
        .where('code', isEqualTo: cleanCode)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    final doc = querySnapshot.docs.first;
    final exam = ExamModel.fromJson(doc.data(), id: doc.id);
    
    // Check if current date and time is within the exam schedule range
    final now = DateTime.now();
    if (now.isAfter(exam.startDate) && now.isBefore(exam.endDate)) {
      return exam;
    }
    
    return null;
  }
}
