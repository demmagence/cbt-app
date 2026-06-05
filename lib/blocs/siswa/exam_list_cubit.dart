import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class ExamListState extends Equatable {
  const ExamListState();

  @override
  List<Object?> get props => [];
}

class ExamListInitial extends ExamListState {
  const ExamListInitial();
}

class ExamListLoading extends ExamListState {
  const ExamListLoading();
}

class ExamListLoaded extends ExamListState {
  final List<ExamModel> availableExams;
  final Map<String, ExamSessionModel> activeSessions; // key: examId
  final List<ExamSessionModel> historySessions;
  final Map<String, ExamModel> examDetails; // key: examId
  final Map<String, ExamResultModel> examResults; // key: sessionId

  const ExamListLoaded({
    required this.availableExams,
    required this.activeSessions,
    required this.historySessions,
    required this.examDetails,
    required this.examResults,
  });

  @override
  List<Object?> get props => [availableExams, activeSessions, historySessions, examDetails, examResults];
}

class ExamListError extends ExamListState {
  final String message;

  const ExamListError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ExamListCubit extends Cubit<ExamListState> {
  final FirestoreService _firestoreService;

  ExamListCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const ExamListInitial());

  Future<void> loadExams(String userId) async {
    emit(const ExamListLoading());
    try {
      // 1. Fetch all active exams
      final exams = await _firestoreService.getCollection<ExamModel>(
        path: FirestoreService.examsPath,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('isActive', isEqualTo: true),
      );

      // Map exams by id
      final examDetails = <String, ExamModel>{};
      for (final exam in exams) {
        examDetails[exam.id] = exam;
      }

      // 2. Fetch all user's sessions
      final sessions = await _firestoreService.getCollection<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('userId', isEqualTo: userId),
      );

      // 3. Fetch all user's results
      final resultsList = await _firestoreService.getCollection<ExamResultModel>(
        path: FirestoreService.examResultsPath,
        fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        queryBuilder: (q) => q.where('userId', isEqualTo: userId),
      );

      final examResults = <String, ExamResultModel>{};
      for (final res in resultsList) {
        examResults[res.sessionId] = res;
      }

      // Filter and organize sessions/exams
      final activeSessions = <String, ExamSessionModel>{};
      final historySessions = <ExamSessionModel>[];

      for (final session in sessions) {
        // Keep track of exam details even if not in the active exams list
        if (!examDetails.containsKey(session.examId)) {
          final examDoc = await _firestoreService.getDocument<ExamModel>(
            path: FirestoreService.examsPath,
            docId: session.examId,
            fromJson: (json, id) => ExamModel.fromJson(json, id: id),
          );
          if (examDoc != null) {
            examDetails[session.examId] = examDoc;
          }
        }

        if (session.status == 'in_progress') {
          activeSessions[session.examId] = session;
        } else {
          historySessions.add(session);
        }
      }

      // Sort history sessions by endedAt or startedAt descending
      historySessions.sort((a, b) {
        final dateA = a.endedAt ?? a.startedAt;
        final dateB = b.endedAt ?? b.startedAt;
        return dateB.compareTo(dateA);
      });

      // Filter available exams: active, within dates, and not completed/auto_submitted
      final now = DateTime.now();
      final availableExams = exams.where((exam) {
        // Must be within date range
        final isTimeValid = now.isAfter(exam.startDate) && now.isBefore(exam.endDate);
        if (!isTimeValid) return false;

        // Must not have a completed/auto_submitted session
        final hasCompletedSession = sessions.any(
          (s) => s.examId == exam.id && (s.status == 'completed' || s.status == 'auto_submitted'),
        );
        return !hasCompletedSession;
      }).toList();

      emit(ExamListLoaded(
        availableExams: availableExams,
        activeSessions: activeSessions,
        historySessions: historySessions,
        examDetails: examDetails,
        examResults: examResults,
      ));
    } catch (e) {
      emit(ExamListError('Gagal memuat daftar ujian: ${e.toString()}'));
    }
  }
}
