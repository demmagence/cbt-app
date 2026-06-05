import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class ExamHistoryState extends Equatable {
  const ExamHistoryState();

  @override
  List<Object?> get props => [];
}

class ExamHistoryInitial extends ExamHistoryState {
  const ExamHistoryInitial();
}

class ExamHistoryLoading extends ExamHistoryState {
  const ExamHistoryLoading();
}

class ExamHistoryLoaded extends ExamHistoryState {
  final List<ExamSessionModel> sessions; // sorted desc by endedAt
  final Map<String, ExamModel> examDetails; // key: examId
  final Map<String, ExamResultModel> results; // key: sessionId

  const ExamHistoryLoaded({
    required this.sessions,
    required this.examDetails,
    required this.results,
  });

  @override
  List<Object?> get props => [sessions, examDetails, results];
}

class ExamHistoryError extends ExamHistoryState {
  final String message;

  const ExamHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ExamHistoryCubit extends Cubit<ExamHistoryState> {
  final FirestoreService _firestoreService;

  ExamHistoryCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const ExamHistoryInitial());

  Future<void> loadHistory(String userId) async {
    emit(const ExamHistoryLoading());
    try {
      // 1. Fetch all completed/auto-submitted sessions for this user
      final allSessions = await _firestoreService.getCollection<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('userId', isEqualTo: userId),
      );

      final completedSessions = allSessions
          .where((s) => s.status == 'completed' || s.status == 'auto_submitted')
          .toList();

      // Sort descending by endedAt or startedAt
      completedSessions.sort((a, b) {
        final dateA = a.endedAt ?? a.startedAt;
        final dateB = b.endedAt ?? b.startedAt;
        return dateB.compareTo(dateA);
      });

      // 2. Fetch exam details for each unique examId
      final examIds = completedSessions.map((s) => s.examId).toSet();
      final examDetails = <String, ExamModel>{};

      for (final examId in examIds) {
        final exam = await _firestoreService.getDocument<ExamModel>(
          path: FirestoreService.examsPath,
          docId: examId,
          fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        );
        if (exam != null) {
          examDetails[examId] = exam;
        }
      }

      // 3. Fetch results for each session
      final resultsList = await _firestoreService.getCollection<ExamResultModel>(
        path: FirestoreService.examResultsPath,
        fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('userId', isEqualTo: userId),
      );

      final results = <String, ExamResultModel>{};
      for (final r in resultsList) {
        results[r.sessionId] = r;
      }

      emit(ExamHistoryLoaded(
        sessions: completedSessions,
        examDetails: examDetails,
        results: results,
      ));
    } catch (e) {
      emit(ExamHistoryError('Gagal memuat riwayat ujian: ${e.toString()}'));
    }
  }
}
