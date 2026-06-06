import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';
import 'exam_session_event.dart';
import 'exam_session_state.dart';

class ExamSessionBloc extends Bloc<ExamSessionEvent, ExamSessionState> {
  final FirestoreService _firestoreService;
  Timer? _timer;

  ExamSessionBloc({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const ExamSessionInitial()) {
    on<ExamStarted>(_onExamStarted);
    on<AnswerSelected>(_onAnswerSelected);
    on<EssayAnswerUpdated>(_onEssayAnswerUpdated);
    on<QuestionNavigated>(_onQuestionNavigated);
    on<ExamSubmitted>(_onExamSubmitted);
    on<TimerTicked>(_onTimerTicked);
    on<TimerExpired>(_onTimerExpired);
    on<AppSwitchDetected>(_onAppSwitchDetected);
    on<FlagToggled>(_onFlagToggled);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> _onExamStarted(ExamStarted event, Emitter<ExamSessionState> emit) async {
    emit(const ExamSessionLoading());
    try {
      // 1. Fetch the exam details
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: event.examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const ExamSessionError('Ujian tidak ditemukan.'));
        return;
      }

      // 2. Query Firestore for active session
      final sessions = await _firestoreService.getCollection<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
        queryBuilder: (q) => q
            .where('examId', isEqualTo: event.examId)
            .where('userId', isEqualTo: event.userId)
            .where('status', isEqualTo: 'in_progress'),
      );

      ExamSessionModel session;

      // 3. Get questions
      final questions = await _firestoreService.getCollection<QuestionModel>(
        path: _firestoreService.questionsPath(event.examId),
        fromJson: (json, id) => QuestionModel.fromJson(json, id: id),
      );

      if (questions.isEmpty) {
        emit(const ExamSessionError('Ujian tidak dapat dimulai karena belum memiliki soal.'));
        return;
      }

      if (sessions.isEmpty) {
        // Create new session if one does not exist (robust fallback)
        final questionList = List<QuestionModel>.from(questions);
        if (exam.shuffleQuestions) {
          questionList.shuffle();
        } else {
          questionList.sort((a, b) => a.order.compareTo(b.order));
        }

        final questionOrder = questionList.map((q) => q.id).toList();

        // Shuffle options for PG questions
        final optionOrders = <String, List<int>>{};
        final random = Random();

        for (final q in questionList) {
          if (q.isPg && q.options != null && q.options!.isNotEmpty) {
            final indices = List<int>.generate(q.options!.length, (index) => index);
            if (exam.shuffleOptions) {
              indices.shuffle(random);
            }
            optionOrders[q.id] = indices;
          } else {
            optionOrders[q.id] = const [];
          }
        }

        final sessionId = '${event.userId}_${event.examId}_${DateTime.now().millisecondsSinceEpoch}';
        session = ExamSessionModel(
          id: sessionId,
          examId: event.examId,
          userId: event.userId,
          startedAt: DateTime.now(),
          status: 'in_progress',
          questionOrder: questionOrder,
          optionOrders: optionOrders,
          answers: const {},
          appSwitchCount: 0,
          appSwitchLogs: const [],
        );

        await _firestoreService.addDocument(
          path: FirestoreService.examSessionsPath,
          docId: sessionId,
          data: session.toJson(),
        );
      } else {
        session = sessions.first;
      }

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
        emit(ExamSessionActive(
          exam: exam,
          session: session,
          questions: orderedQuestions,
          currentIndex: 0,
          remainingTime: 0,
          flaggedQuestions: const {},
        ));
        add(const ExamSubmitted(isAutoSubmit: true));
        return;
      }

      emit(ExamSessionActive(
        exam: exam,
        session: session,
        questions: orderedQuestions,
        currentIndex: 0,
        remainingTime: remainingSeconds,
        flaggedQuestions: const {},
      ));

      _startTimer();
    } catch (e) {
      emit(ExamSessionError('Gagal memuat sesi ujian: ${e.toString()}'));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentState = state;
      if (currentState is ExamSessionActive) {
        final nextRemaining = currentState.remainingTime - 1;
        if (nextRemaining <= 0) {
          _timer?.cancel();
          add(const TimerExpired());
        } else {
          add(TimerTicked(nextRemaining));
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  void _onTimerTicked(TimerTicked event, Emitter<ExamSessionState> emit) {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      emit(currentState.copyWith(remainingTime: event.remainingSeconds));
    }
  }

  void _onTimerExpired(TimerExpired event, Emitter<ExamSessionState> emit) {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      emit(currentState.copyWith(remainingTime: 0));
      add(const ExamSubmitted(isAutoSubmit: true));
    }
  }

  void _onQuestionNavigated(QuestionNavigated event, Emitter<ExamSessionState> emit) {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      if (event.index >= 0 && event.index < currentState.questions.length) {
        emit(currentState.copyWith(currentIndex: event.index));
      }
    }
  }

  void _onFlagToggled(FlagToggled event, Emitter<ExamSessionState> emit) {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      final flags = Set<String>.from(currentState.flaggedQuestions);
      if (flags.contains(event.questionId)) {
        flags.remove(event.questionId);
      } else {
        flags.add(event.questionId);
      }
      emit(currentState.copyWith(flaggedQuestions: flags));
    }
  }

  Future<void> _onAnswerSelected(AnswerSelected event, Emitter<ExamSessionState> emit) async {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      final updatedAnswers = Map<String, dynamic>.from(currentState.session.answers);
      updatedAnswers[event.questionId] = event.answerIndex;

      final updatedSession = currentState.session.copyWith(answers: updatedAnswers);
      emit(currentState.copyWith(session: updatedSession));

      try {
        await _firestoreService.updateDocument(
          path: FirestoreService.examSessionsPath,
          docId: currentState.session.id,
          data: {
            'answers.${event.questionId}': event.answerIndex,
          },
        );
      } catch (_) {
        // Silent failure for autosave
      }
    }
  }

  Future<void> _onEssayAnswerUpdated(EssayAnswerUpdated event, Emitter<ExamSessionState> emit) async {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      final updatedAnswers = Map<String, dynamic>.from(currentState.session.answers);
      updatedAnswers[event.questionId] = event.text;

      final updatedSession = currentState.session.copyWith(answers: updatedAnswers);
      emit(currentState.copyWith(session: updatedSession));

      try {
        await _firestoreService.updateDocument(
          path: FirestoreService.examSessionsPath,
          docId: currentState.session.id,
          data: {
            'answers.${event.questionId}': event.text,
          },
        );
      } catch (_) {
        // Silent failure for autosave
      }
    }
  }

  Future<void> _onAppSwitchDetected(AppSwitchDetected event, Emitter<ExamSessionState> emit) async {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      final updatedLogs = List<AppSwitchLog>.from(currentState.session.appSwitchLogs)..add(event.log);
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
      } catch (_) {
        // Silent failure
      }
    }
  }

  Future<void> _onExamSubmitted(ExamSubmitted event, Emitter<ExamSessionState> emit) async {
    final currentState = state;
    if (currentState is! ExamSessionActive) return;

    _timer?.cancel();
    emit(const ExamSessionSubmitting());

    try {
      final session = currentState.session;
      final questions = currentState.questions;
      final answers = currentState.session.answers;

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

      final endedAt = DateTime.now();
      final finalStatus = event.isAutoSubmit ? 'auto_submitted' : 'completed';

      await _firestoreService.updateDocument(
        path: FirestoreService.examSessionsPath,
        docId: session.id,
        data: {
          'status': finalStatus,
          'endedAt': endedAt,
        },
      );

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

      emit(ExamSessionCompleted(result));
    } catch (e) {
      emit(ExamSessionError('Gagal mengirimkan ujian: ${e.toString()}'));
    }
  }
}
