import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class EssayGradingDetailState extends Equatable {
  const EssayGradingDetailState();

  @override
  List<Object?> get props => [];
}

class EssayGradingDetailInitial extends EssayGradingDetailState {
  const EssayGradingDetailInitial();
}

class EssayGradingDetailLoading extends EssayGradingDetailState {
  const EssayGradingDetailLoading();
}

class EssayGradingDetailLoaded extends EssayGradingDetailState {
  final ExamModel exam;
  final ExamResultModel result;
  final ExamSessionModel session;
  final List<QuestionModel> essayQuestions;
  final UserModel student;

  const EssayGradingDetailLoaded({
    required this.exam,
    required this.result,
    required this.session,
    required this.essayQuestions,
    required this.student,
  });

  @override
  List<Object?> get props => [exam, result, session, essayQuestions, student];
}

class EssayGradingDetailSuccess extends EssayGradingDetailState {
  const EssayGradingDetailSuccess();
}

class EssayGradingDetailError extends EssayGradingDetailState {
  final String message;

  const EssayGradingDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class EssayGradingDetailCubit extends Cubit<EssayGradingDetailState> {
  final FirestoreService _firestoreService;

  EssayGradingDetailCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const EssayGradingDetailInitial());

  Future<void> loadDetail(String examId, String userId) async {
    emit(const EssayGradingDetailLoading());
    try {
      // 1. Fetch Student/User Info
      final student = await _firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: userId,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (student == null) {
        emit(const EssayGradingDetailError('Siswa tidak ditemukan'));
        return;
      }

      // 2. Fetch Exam Info
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const EssayGradingDetailError('Ujian tidak ditemukan'));
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
        emit(
          const EssayGradingDetailError('Hasil ujian siswa belum terdaftar'),
        );
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
        emit(const EssayGradingDetailError('Sesi ujian siswa tidak ditemukan'));
        return;
      }

      // Grade the same immutable snapshot used by the server.
      final content = await _firestoreService.getDocument<Map<String, dynamic>>(
        path: 'session_content',
        docId: result.sessionId,
        fromJson: (json, id) => json,
      );
      if (content == null) {
        throw StateError(
          'Snapshot sesi belum tersedia. Migrasikan sesi lama terlebih dahulu.',
        );
      }
      final questions = (content['questions'] as List)
          .map(
            (q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)),
          )
          .toList();

      final essayQuestions = questions.where((q) => q.isEssay).toList();
      essayQuestions.sort((a, b) => a.order.compareTo(b.order));

      emit(
        EssayGradingDetailLoaded(
          exam: exam,
          result: result,
          session: session,
          essayQuestions: essayQuestions,
          student: student,
        ),
      );
    } catch (e) {
      emit(
        EssayGradingDetailError(
          'Gagal memuat detail pengerjaan: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> submitGrades({
    required String resultId,
    required num pgScore,
    required Map<String, EssayGrade> grades,
    required String guruId,
  }) async {
    final previous = state;
    try {
      emit(const EssayGradingDetailLoading());

      await _firestoreService.call('submitGrades', {
        'resultId': resultId,
        'grades': grades.map((key, value) => MapEntry(key, value.toJson())),
      });

      emit(const EssayGradingDetailSuccess());
    } catch (e) {
      emit(
        EssayGradingDetailError('Gagal menyimpan penilaian: ${e.toString()}'),
      );
      if (previous is EssayGradingDetailLoaded) {
        emit(previous);
      }
    }
  }
}
