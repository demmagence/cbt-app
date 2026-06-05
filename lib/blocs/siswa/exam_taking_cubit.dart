import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class ExamTakingState extends Equatable {
  const ExamTakingState();

  @override
  List<Object?> get props => [];
}

class ExamTakingLoading extends ExamTakingState {
  const ExamTakingLoading();
}

class ExamTakingActive extends ExamTakingState {
  final ExamModel exam;
  final ExamSessionModel session;
  final List<QuestionModel> orderedQuestions;
  final int currentIndex;
  final Map<String, dynamic> answers;
  final Set<String> flaggedQuestions;
  final int remainingSeconds; // Countdown

  const ExamTakingActive({
    required this.exam,
    required this.session,
    required this.orderedQuestions,
    required this.currentIndex,
    required this.answers,
    required this.flaggedQuestions,
    required this.remainingSeconds,
  });

  ExamTakingActive copyWith({
    ExamModel? exam,
    ExamSessionModel? session,
    List<QuestionModel>? orderedQuestions,
    int? currentIndex,
    Map<String, dynamic>? answers,
    Set<String>? flaggedQuestions,
    int? remainingSeconds,
  }) {
    return ExamTakingActive(
      exam: exam ?? this.exam,
      session: session ?? this.session,
      orderedQuestions: orderedQuestions ?? this.orderedQuestions,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      flaggedQuestions: flaggedQuestions ?? this.flaggedQuestions,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  @override
  List<Object?> get props => [
        exam,
        session,
        orderedQuestions,
        currentIndex,
        answers,
        flaggedQuestions,
        remainingSeconds,
      ];
}

class ExamTakingSubmitting extends ExamTakingState {
  const ExamTakingSubmitting();
}

class ExamTakingSubmitted extends ExamTakingState {
  const ExamTakingSubmitted();
}

class ExamTakingError extends ExamTakingState {
  final String message;

  const ExamTakingError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ExamTakingCubit extends Cubit<ExamTakingState> {
  final FirestoreService _firestoreService;
  Timer? _timer;

  ExamTakingCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const ExamTakingLoading());

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> loadSession(String examId, String userId) async {
    emit(const ExamTakingLoading());
    try {
      // 1. Fetch the exam details
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const ExamTakingError('Ujian tidak ditemukan.'));
        return;
      }

      // 2. Fetch the session
      final sessions = await _firestoreService.getCollection<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
        queryBuilder: (q) => q
            .where('examId', isEqualTo: examId)
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'in_progress'),
      );

      if (sessions.isEmpty) {
        emit(const ExamTakingError('Sesi ujian tidak aktif atau sudah disubmit.'));
        return;
      }

      final session = sessions.first;

      // 3. Fetch questions
      final questions = await _firestoreService.getCollection<QuestionModel>(
        path: _firestoreService.questionsPath(examId),
        fromJson: (json, id) => QuestionModel.fromJson(json, id: id),
      );

      // Map questions by ID for ordered lookups
      final questionMap = {for (var q in questions) q.id: q};
      final orderedQuestions = session.questionOrder
          .map((id) => questionMap[id])
          .whereType<QuestionModel>()
          .toList();

      // Calculate remaining time
      final now = DateTime.now();
      final elapsedSeconds = now.difference(session.startedAt).inSeconds;
      final totalDurationSeconds = exam.duration * 60;
      final remainingSeconds = totalDurationSeconds - elapsedSeconds;

      if (remainingSeconds <= 0) {
        // Automatically submit if elapsed time is already over
        emit(ExamTakingActive(
          exam: exam,
          session: session,
          orderedQuestions: orderedQuestions,
          currentIndex: 0,
          answers: Map<String, dynamic>.from(session.answers),
          flaggedQuestions: const {},
          remainingSeconds: 0,
        ));
        await submitExam(isAutoSubmit: true);
        return;
      }

      emit(ExamTakingActive(
        exam: exam,
        session: session,
        orderedQuestions: orderedQuestions,
        currentIndex: 0,
        answers: Map<String, dynamic>.from(session.answers),
        flaggedQuestions: const {},
        remainingSeconds: remainingSeconds,
      ));

      // Start countdown timer
      _startTimer();
    } catch (e) {
      emit(ExamTakingError('Gagal memuat sesi ujian: ${e.toString()}'));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final currentState = state;
      if (currentState is ExamTakingActive) {
        final nextRemaining = currentState.remainingSeconds - 1;
        if (nextRemaining <= 0) {
          _timer?.cancel();
          emit(currentState.copyWith(remainingSeconds: 0));
          await submitExam(isAutoSubmit: true);
        } else {
          emit(currentState.copyWith(remainingSeconds: nextRemaining));
        }
      }
    });
  }

  void updateIndex(int index) {
    final currentState = state;
    if (currentState is ExamTakingActive) {
      if (index >= 0 && index < currentState.orderedQuestions.length) {
        emit(currentState.copyWith(currentIndex: index));
      }
    }
  }

  void toggleFlag(String questionId) {
    final currentState = state;
    if (currentState is ExamTakingActive) {
      final flags = Set<String>.from(currentState.flaggedQuestions);
      if (flags.contains(questionId)) {
        flags.remove(questionId);
      } else {
        flags.add(questionId);
      }
      emit(currentState.copyWith(flaggedQuestions: flags));
    }
  }

  Future<void> saveAnswer(String questionId, dynamic value) async {
    final currentState = state;
    if (currentState is ExamTakingActive) {
      final updatedAnswers = Map<String, dynamic>.from(currentState.answers);
      updatedAnswers[questionId] = value;

      // Optimistic state update
      emit(currentState.copyWith(answers: updatedAnswers));

      try {
        // Save to Firestore autosave
        await _firestoreService.updateDocument(
          path: FirestoreService.examSessionsPath,
          docId: currentState.session.id,
          data: {
            'answers.$questionId': value,
          },
        );
      } catch (_) {
        // Log or handle silent failure
      }
    }
  }

  Future<void> logAppSwitch(AppSwitchLog log) async {
    final currentState = state;
    if (currentState is ExamTakingActive) {
      final updatedLogs = List<AppSwitchLog>.from(currentState.session.appSwitchLogs)..add(log);
      final updatedCount = currentState.session.appSwitchCount + 1;
      final updatedSession = currentState.session.copyWith(
        appSwitchLogs: updatedLogs,
        appSwitchCount: updatedCount,
      );

      emit(currentState.copyWith(session: updatedSession));

      try {
        await _firestoreService.updateDocument(
          path: FirestoreService.examSessionsPath,
          docId: currentState.session.id,
          data: {
            'appSwitchCount': updatedCount,
            'appSwitchLogs': updatedLogs.map((e) => e.toJson()).toList(),
          },
        );
      } catch (_) {}
    }
  }

  Future<void> submitExam({bool isAutoSubmit = false}) async {
    final currentState = state;
    if (currentState is! ExamTakingActive) return;

    _timer?.cancel();
    emit(const ExamTakingSubmitting());

    try {
      final session = currentState.session;
      final questions = currentState.orderedQuestions;
      final answers = currentState.answers;

      // Grade PG questions
      num pgScore = 0;
      bool hasEssay = false;

      for (final q in questions) {
        if (q.isPg) {
          final studentAnswer = answers[q.id];
          if (studentAnswer != null && studentAnswer is int) {
            if (studentAnswer == q.correctAnswer) {
              pgScore += q.points;
            }
          }
        } else if (q.isEssay) {
          hasEssay = true;
        }
      }

      // Update session status in Firestore
      final endedAt = DateTime.now();
      final finalStatus = isAutoSubmit ? 'auto_submitted' : 'completed';

      await _firestoreService.updateDocument(
        path: FirestoreService.examSessionsPath,
        docId: session.id,
        data: {
          'status': finalStatus,
          'endedAt': endedAt,
        },
      );

      // Save Exam Result
      final resultId = '${session.userId}_${session.examId}';
      final result = ExamResultModel(
        id: resultId,
        examId: session.examId,
        userId: session.userId,
        sessionId: session.id,
        pgScore: pgScore,
        essayScore: null,
        totalScore: pgScore,
        gradingStatus: hasEssay ? 'pending_essay' : 'graded',
        essayGrades: const {},
        submittedAt: endedAt,
      );

      await _firestoreService.addDocument(
        path: FirestoreService.examResultsPath,
        docId: resultId,
        data: result.toJson(),
      );

      emit(const ExamTakingSubmitted());
    } catch (e) {
      emit(ExamTakingError('Gagal mengirimkan ujian: ${e.toString()}'));
    }
  }
}
