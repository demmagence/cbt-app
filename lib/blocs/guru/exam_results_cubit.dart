import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class ExamResultsState extends Equatable {
  const ExamResultsState();

  @override
  List<Object?> get props => [];
}

class ExamResultsInitial extends ExamResultsState {
  const ExamResultsInitial();
}

class ExamResultsLoading extends ExamResultsState {
  const ExamResultsLoading();
}

class ExamResultsLoaded extends ExamResultsState {
  final ExamModel exam;
  final List<ExamResultModel> results;
  final Map<String, UserModel> studentMap;

  const ExamResultsLoaded({
    required this.exam,
    required this.results,
    required this.studentMap,
  });

  @override
  List<Object?> get props => [exam, results, studentMap];
}

class ExamResultsError extends ExamResultsState {
  final String message;

  const ExamResultsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ExamResultsCubit extends Cubit<ExamResultsState> {
  final FirestoreService _firestoreService;

  ExamResultsCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const ExamResultsInitial());

  Future<void> loadExamResults(String examId) async {
    emit(const ExamResultsLoading());
    try {
      // 1. Load Exam
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const ExamResultsError('Ujian tidak ditemukan'));
        return;
      }

      // 2. Load Exam Results for this exam
      final results = await _firestoreService.getCollection<ExamResultModel>(
        path: FirestoreService.examResultsPath,
        fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('examId', isEqualTo: examId),
      );

      // Sort by submittedAt descending
      results.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      // 3. Load students info
      final Map<String, UserModel> studentMap = {};
      final studentIds = results.map((r) => r.userId).toSet();

      for (final uid in studentIds) {
        final user = await _firestoreService.getDocument<UserModel>(
          path: FirestoreService.usersPath,
          docId: uid,
          fromJson: (json, id) => UserModel.fromJson(json),
        );
        if (user != null) {
          studentMap[uid] = user;
        }
      }

      emit(ExamResultsLoaded(
        exam: exam,
        results: results,
        studentMap: studentMap,
      ));
    } catch (e) {
      emit(ExamResultsError('Gagal memuat hasil ujian: ${e.toString()}'));
    }
  }
}
