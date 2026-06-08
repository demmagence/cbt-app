import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class GuruDashboardState extends Equatable {
  const GuruDashboardState();

  @override
  List<Object?> get props => [];
}

class GuruDashboardInitial extends GuruDashboardState {
  const GuruDashboardInitial();
}

class GuruDashboardLoading extends GuruDashboardState {
  const GuruDashboardLoading();
}

class GuruDashboardLoaded extends GuruDashboardState {
  final List<ExamModel> exams;
  final int totalExams;
  final int activeExamsCount;
  final int totalStudentsCount;
  final int pendingGradingCount;
  final List<ExamModel> recentExams;

  const GuruDashboardLoaded({
    required this.exams,
    required this.totalExams,
    required this.activeExamsCount,
    required this.totalStudentsCount,
    required this.pendingGradingCount,
    required this.recentExams,
  });

  @override
  List<Object?> get props => [
        exams,
        totalExams,
        activeExamsCount,
        totalStudentsCount,
        pendingGradingCount,
        recentExams,
      ];
}

class GuruDashboardError extends GuruDashboardState {
  final String message;

  const GuruDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class GuruDashboardCubit extends Cubit<GuruDashboardState> {
  final FirestoreService _firestoreService;

  GuruDashboardCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const GuruDashboardInitial());

  Future<void> loadDashboardData(String guruId) async {
    emit(const GuruDashboardLoading());
    try {
      // 1. Fetch exams created by this guru
      final exams = await _firestoreService.getCollection<ExamModel>(
        path: FirestoreService.examsPath,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('createdBy', isEqualTo: guruId),
      );

      // 2. Fetch exam results for each of the guru's exams in parallel to satisfy Firestore security rules
      final List<ExamResultModel> guruExamResults = [];
      if (exams.isNotEmpty) {
        final resultsList = await Future.wait(
          exams.map((exam) => _firestoreService.getCollection<ExamResultModel>(
            path: FirestoreService.examResultsPath,
            fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
            queryBuilder: (query) => query.where('examId', isEqualTo: exam.id),
          ))
        );
        for (final list in resultsList) {
          guruExamResults.addAll(list);
        }
      }

      // Calculate stats
      final totalExams = exams.length;

      // Active exams count
      final now = DateTime.now();
      int activeExamsCount = 0;
      for (final exam in exams) {
        if (exam.isActive && now.isAfter(exam.startDate) && now.isBefore(exam.endDate)) {
          activeExamsCount++;
        }
      }

      // Total unique students count
      final uniqueStudentIds = guruExamResults.map((r) => r.userId).toSet();
      final totalStudentsCount = uniqueStudentIds.length;

      // Pending grading count
      int pendingGradingCount = 0;
      for (final res in guruExamResults) {
        if (res.gradingStatus == 'pending_essay') {
          pendingGradingCount++;
        }
      }

      // Sort exams by startDate descending to get the most recent ones
      final sortedExams = List<ExamModel>.from(exams)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      final recentExams = sortedExams.take(5).toList();

      emit(GuruDashboardLoaded(
        exams: exams,
        totalExams: totalExams,
        activeExamsCount: activeExamsCount,
        totalStudentsCount: totalStudentsCount,
        pendingGradingCount: pendingGradingCount,
        recentExams: recentExams,
      ));
    } catch (e) {
      emit(GuruDashboardError('Gagal memuat data dashboard: ${e.toString()}'));
    }
  }
}
