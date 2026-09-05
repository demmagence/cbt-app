import '../models/exam_model.dart';
import 'firestore_service.dart';

class ExamCodeService {
  final FirestoreService _firestoreService;
  ExamCodeService({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  Future<ExamModel?> validateCode(String code) async {
    final data = await _firestoreService.call('previewExam', {
      'code': code.trim().toUpperCase(),
    });
    return ExamModel.fromJson(data);
  }
}
