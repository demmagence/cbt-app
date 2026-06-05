import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/exam_session_model.dart';
import '../../models/exam_result_model.dart';

class SiswaProfileState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final int totalExams;
  final double avgScore;
  final num highestScore;

  const SiswaProfileState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.totalExams = 0,
    this.avgScore = 0.0,
    this.highestScore = 0,
  });

  SiswaProfileState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    int? totalExams,
    double? avgScore,
    num? highestScore,
  }) {
    return SiswaProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      successMessage: successMessage,
      totalExams: totalExams ?? this.totalExams,
      avgScore: avgScore ?? this.avgScore,
      highestScore: highestScore ?? this.highestScore,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSubmitting,
        errorMessage,
        successMessage,
        totalExams,
        avgScore,
        highestScore,
      ];
}

class SiswaProfileCubit extends Cubit<SiswaProfileState> {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  SiswaProfileCubit({
    required FirestoreService firestoreService,
    required AuthService authService,
  })  : _firestoreService = firestoreService,
        _authService = authService,
        super(const SiswaProfileState());

  Future<void> loadStats(String userId) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 1. Fetch completed sessions
      final allSessions = await _firestoreService.getCollection<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('userId', isEqualTo: userId),
      );

      final completedSessions = allSessions
          .where((s) => s.status == 'completed' || s.status == 'auto_submitted')
          .toList();

      final totalExams = completedSessions.length;

      // 2. Fetch results
      final resultsList = await _firestoreService.getCollection<ExamResultModel>(
        path: FirestoreService.examResultsPath,
        fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('userId', isEqualTo: userId),
      );

      final gradedResults = resultsList.where((r) => r.gradingStatus == 'graded').toList();

      double avgScore = 0.0;
      num highestScore = 0;

      if (gradedResults.isNotEmpty) {
        final total = gradedResults.fold<num>(0, (sum, r) => sum + r.totalScore);
        avgScore = total / gradedResults.length;
        highestScore = gradedResults.map((r) => r.totalScore).reduce((a, b) => a > b ? a : b);
      }

      emit(state.copyWith(
        isLoading: false,
        totalExams: totalExams,
        avgScore: avgScore,
        highestScore: highestScore,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat statistik profile: ${e.toString()}',
      ));
    }
  }

  Future<void> changePassword(String newPassword) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _authService.updatePassword(newPassword);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'Password berhasil diperbarui!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal memperbarui password: ${e.toString()}',
      ));
    }
  }
}
