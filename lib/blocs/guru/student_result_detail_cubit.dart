import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class StudentResultDetailState extends Equatable {
  const StudentResultDetailState();

  @override
  List<Object?> get props => [];
}

class StudentResultDetailInitial extends StudentResultDetailState {
  const StudentResultDetailInitial();
}

class StudentResultDetailLoading extends StudentResultDetailState {
  const StudentResultDetailLoading();
}

class StudentResultDetailLoaded extends StudentResultDetailState {
  final ExamModel exam;
  final ExamResultModel result;
  final ExamSessionModel session;
  final List<QuestionModel> questions;
  final UserModel student;

  const StudentResultDetailLoaded({
    required this.exam,
    required this.result,
    required this.session,
    required this.questions,
    required this.student,
  });

  @override
  List<Object?> get props => [exam, result, session, questions, student];
}

class StudentResultDetailError extends StudentResultDetailState {
  final String message;

  const StudentResultDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class StudentResultDetailCubit extends Cubit<StudentResultDetailState> {
  final FirestoreService _firestoreService;

  StudentResultDetailCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const StudentResultDetailInitial());

  Future<void> loadDetail(String examId, String userId) async {
    emit(const StudentResultDetailLoading());
    try {
      // 1. Fetch Student/User Info
      final student = await _firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: userId,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (student == null) {
        emit(const StudentResultDetailError('Siswa tidak ditemukan'));
        return;
      }

      // 2. Fetch Exam Info
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const StudentResultDetailError('Ujian tidak ditemukan'));
        return;
      }

      // 3. Fetch Exam Result
      final results = await _firestoreService.getCollection<ExamResultModel>(
        path: FirestoreService.examResultsPath,
        fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        queryBuilder: (query) => query
            .where('examId', isEqualTo: examId)
            .where('userId', isEqualTo: userId),
      );

      if (results.isEmpty) {
        emit(const StudentResultDetailError('Hasil ujian siswa belum terdaftar'));
        return;
      }
      final result = results.first;

      // 4. Fetch Exam Session using sessionId
      final session = await _firestoreService.getDocument<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        docId: result.sessionId,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
      );

      if (session == null) {
        emit(const StudentResultDetailError('Sesi ujian siswa tidak ditemukan'));
        return;
      }

      // 5. Fetch Exam Questions
      final qPath = _firestoreService.questionsPath(examId);
      final questions = await _firestoreService.getCollection<QuestionModel>(
        path: qPath,
        fromJson: (json, id) => QuestionModel.fromJson(json, id: id),
      );

      // Sort by order ascending
      questions.sort((a, b) => a.order.compareTo(b.order));

      emit(StudentResultDetailLoaded(
        exam: exam,
        result: result,
        session: session,
        questions: questions,
        student: student,
      ));
    } catch (e) {
      emit(StudentResultDetailError('Gagal memuat detail hasil: ${e.toString()}'));
    }
  }
}
