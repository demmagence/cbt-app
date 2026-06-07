import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class MonitoringState extends Equatable {
  const MonitoringState();

  @override
  List<Object?> get props => [];
}

class MonitoringInitial extends MonitoringState {
  const MonitoringInitial();
}

class MonitoringLoading extends MonitoringState {
  const MonitoringLoading();
}

class MonitoringActive extends MonitoringState {
  final List<ExamModel> activeExams;
  final String? selectedExamId;
  final List<ExamSessionModel> sessions;
  final Map<String, UserModel> studentMap;

  const MonitoringActive({
    required this.activeExams,
    this.selectedExamId,
    required this.sessions,
    required this.studentMap,
  });

  MonitoringActive copyWith({
    List<ExamModel>? activeExams,
    String? selectedExamId,
    List<ExamSessionModel>? sessions,
    Map<String, UserModel>? studentMap,
  }) {
    return MonitoringActive(
      activeExams: activeExams ?? this.activeExams,
      selectedExamId: selectedExamId ?? this.selectedExamId,
      sessions: sessions ?? this.sessions,
      studentMap: studentMap ?? this.studentMap,
    );
  }

  @override
  List<Object?> get props => [activeExams, selectedExamId, sessions, studentMap];
}

class MonitoringError extends MonitoringState {
  final String message;

  const MonitoringError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class MonitoringCubit extends Cubit<MonitoringState> {
  final FirestoreService _firestoreService;
  StreamSubscription<List<ExamSessionModel>>? _sessionsSubscription;

  MonitoringCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const MonitoringInitial());

  @override
  Future<void> close() {
    _sessionsSubscription?.cancel();
    return super.close();
  }

  Future<void> loadInitialData(String guruId) async {
    emit(const MonitoringLoading());
    try {
      // 1. Load exams created by Guru
      final exams = await _firestoreService.getCollection<ExamModel>(
        path: FirestoreService.examsPath,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('createdBy', isEqualTo: guruId),
      );

      // Filter only active exams or currently scheduled exams
      final activeExams = exams.where((e) => e.isActive).toList();

      // 2. Fetch all student users to populate profile map
      final students = await _firestoreService.getCollection<UserModel>(
        path: FirestoreService.usersPath,
        fromJson: (json, id) => UserModel.fromJson(json),
        queryBuilder: (query) => query.where('role', isEqualTo: 'siswa'),
      );

      final Map<String, UserModel> studentMap = {for (var s in students) s.uid: s};

      emit(MonitoringActive(
        activeExams: activeExams,
        selectedExamId: null,
        sessions: const [],
        studentMap: studentMap,
      ));
    } catch (e) {
      emit(MonitoringError('Gagal menginisialisasi pemantauan: ${e.toString()}'));
    }
  }

  void selectExam(String examId) {
    final currentState = state;
    if (currentState is! MonitoringActive) return;

    // Cancel existing subscription
    _sessionsSubscription?.cancel();

    emit(currentState.copyWith(
      selectedExamId: examId,
      sessions: const [], // temporary clear
    ));

    // Subscribe to real-time session changes for selected exam
    _sessionsSubscription = _firestoreService.streamCollection<ExamSessionModel>(
      path: FirestoreService.examSessionsPath,
      fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
      queryBuilder: (query) => query.where('examId', isEqualTo: examId),
    ).listen((sessions) {
      final updatedState = state;
      if (updatedState is MonitoringActive && updatedState.selectedExamId == examId) {
        // Sort sessions: in_progress first, then newest startedAt
        sessions.sort((a, b) {
          if (a.status == 'in_progress' && b.status != 'in_progress') return -1;
          if (a.status != 'in_progress' && b.status == 'in_progress') return 1;
          return b.startedAt.compareTo(a.startedAt);
        });

        emit(updatedState.copyWith(sessions: sessions));
      }
    }, onError: (error) {
      emit(MonitoringError('Terjadi kesalahan saat memantau real-time: ${error.toString()}'));
    });
  }

  Future<void> forceSubmit(String sessionId) async {
    try {
      final updateData = {
        'status': 'auto_submitted',
        'endedAt': DateTime.now().toIso8601String(),
      };

      await _firestoreService.updateDocument(
        path: FirestoreService.examSessionsPath,
        docId: sessionId,
        data: updateData,
      );
    } catch (e) {
      emit(MonitoringError('Gagal memaksa pengumpulan sesi: ${e.toString()}'));
    }
  }
}
