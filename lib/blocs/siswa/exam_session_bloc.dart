import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _pendingSubmit = false;
  bool _pendingSubmitIsAuto = false;
  ExamSessionModel? _cachedSession;
  List<QuestionModel>? _cachedQuestions;

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
    on<AppResumed>(_onAppResumed);
    on<ConnectivityChanged>(_onConnectivityChanged);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      add(ConnectivityChanged(isOffline: isOffline));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }

  void _onConnectivityChanged(ConnectivityChanged event, Emitter<ExamSessionState> emit) {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      emit(currentState.copyWith(isOffline: event.isOffline));

      // If we got back online and there is a pending submission, trigger the submission!
      if (!event.isOffline && _pendingSubmit) {
        _pendingSubmit = false;
        add(ExamSubmitted(isAutoSubmit: _pendingSubmitIsAuto));
      }
    } else if (currentState is ExamSessionSubmitting) {
      if (!event.isOffline && _pendingSubmit) {
        _pendingSubmit = false;
        add(ExamSubmitted(isAutoSubmit: _pendingSubmitIsAuto));
      } else {
        emit(ExamSessionSubmitting(isOffline: event.isOffline));
      }
    }
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
        final sessionId = '${event.userId}_${event.examId}_${DateTime.now().millisecondsSinceEpoch}';
        final seed = _getSeedFromString(sessionId);
        final random = Random(seed);

        final questionList = List<QuestionModel>.from(questions);
        if (exam.shuffleQuestions) {
          _fisherYatesShuffle(questionList, random);
        } else {
          questionList.sort((a, b) => a.order.compareTo(b.order));
        }

        final questionOrder = questionList.map((q) => q.id).toList();

        // Shuffle options for PG questions
        final optionOrders = <String, List<int>>{};
        for (final q in questionList) {
          if (q.isPg && q.options != null && q.options!.isNotEmpty) {
            final indices = List<int>.generate(q.options!.length, (index) => index);
            if (exam.shuffleOptions) {
              _fisherYatesShuffle(indices, random);
            }
            optionOrders[q.id] = indices;
          } else {
            optionOrders[q.id] = const [];
          }
        }

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
        if (session.questionOrder.isEmpty || session.optionOrders.isEmpty) {
          final seed = _getSeedFromString(session.id);
          final random = Random(seed);

          final questionList = List<QuestionModel>.from(questions);
          if (exam.shuffleQuestions) {
            _fisherYatesShuffle(questionList, random);
          } else {
            questionList.sort((a, b) => a.order.compareTo(b.order));
          }

          final questionOrder = questionList.map((q) => q.id).toList();

          final optionOrders = <String, List<int>>{};
          for (final q in questionList) {
            if (q.isPg && q.options != null && q.options!.isNotEmpty) {
              final indices = List<int>.generate(q.options!.length, (index) => index);
              if (exam.shuffleOptions) {
                _fisherYatesShuffle(indices, random);
              }
              optionOrders[q.id] = indices;
            } else {
              optionOrders[q.id] = const [];
            }
          }

          session = session.copyWith(
            questionOrder: questionOrder,
            optionOrders: optionOrders,
          );

          await _firestoreService.updateDocument(
            path: FirestoreService.examSessionsPath,
            docId: session.id,
            data: {
              'questionOrder': questionOrder,
              'optionOrders': optionOrders,
            },
          );
        }
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

      // Define visited questions: first question + any questions that have answers
      final initialVisited = <String>{
        if (orderedQuestions.isNotEmpty) orderedQuestions.first.id,
        ...session.answers.keys,
      };

      // Check initial connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none);

      if (remainingSeconds <= 0) {
        emit(ExamSessionActive(
          exam: exam,
          session: session,
          questions: orderedQuestions,
          currentIndex: 0,
          remainingTime: 0,
          flaggedQuestions: const {},
          visitedQuestions: initialVisited,
          isOffline: isOffline,
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
        visitedQuestions: initialVisited,
        isOffline: isOffline,
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
        final targetQuestionId = currentState.questions[event.index].id;
        final nextVisited = Set<String>.from(currentState.visitedQuestions)..add(targetQuestionId);
        emit(currentState.copyWith(
          currentIndex: event.index,
          visitedQuestions: nextVisited,
        ));
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
    
    if (currentState is ExamSessionActive) {
      _cachedSession = currentState.session;
      _cachedQuestions = currentState.questions;
    }

    if (_cachedSession == null || _cachedQuestions == null) return;

    _timer?.cancel();

    // Check if offline
    bool isOffline = false;
    if (currentState is ExamSessionActive) {
      isOffline = currentState.isOffline;
    } else if (currentState is ExamSessionSubmitting) {
      isOffline = currentState.isOffline;
    } else {
      final connectivityResult = await Connectivity().checkConnectivity();
      isOffline = connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none);
    }

    if (isOffline) {
      _pendingSubmit = true;
      _pendingSubmitIsAuto = event.isAutoSubmit;
      emit(const ExamSessionSubmitting(isOffline: true));
      return;
    }

    emit(const ExamSessionSubmitting(isOffline: false));

    try {
      final session = _cachedSession!;
      final questions = _cachedQuestions!;
      final answers = session.answers;

      // Grade PG questions
      num pgScore = 0;
      bool hasEssay = false;

      for (final q in questions) {
        if (q.isPg) {
          final studentAnswer = answers[q.id];
          if (studentAnswer != null && studentAnswer is int) {
            final optionOrder = session.optionOrders[q.id] ?? [];
            final originalSelectedIndex = optionOrder.isNotEmpty &&
                    studentAnswer >= 0 &&
                    studentAnswer < optionOrder.length
                ? optionOrder[studentAnswer]
                : studentAnswer;
            if (originalSelectedIndex == q.correctAnswer) {
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
        appSwitchCount: session.appSwitchCount,
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

  void _onAppResumed(AppResumed event, Emitter<ExamSessionState> emit) {
    final currentState = state;
    if (currentState is ExamSessionActive) {
      final now = DateTime.now();
      final elapsedSeconds = now.difference(currentState.session.startedAt).inSeconds;
      final totalDurationSeconds = currentState.exam.duration * 60;
      final remainingSeconds = totalDurationSeconds - elapsedSeconds;

      if (remainingSeconds <= 0) {
        emit(currentState.copyWith(remainingTime: 0));
        add(const ExamSubmitted(isAutoSubmit: true));
      } else {
        emit(currentState.copyWith(remainingTime: remainingSeconds));
        _startTimer();
      }
    }
  }

  int _getSeedFromString(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash.abs();
  }

  void _fisherYatesShuffle<T>(List<T> list, Random random) {
    for (int i = list.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }
}
