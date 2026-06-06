import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../services/firestore_service.dart';
import '../../services/exam_code_service.dart';

// States
abstract class JoinExamState extends Equatable {
  const JoinExamState();

  @override
  List<Object?> get props => [];
}

class JoinExamInitial extends JoinExamState {
  const JoinExamInitial();
}

class JoinExamVerifying extends JoinExamState {
  const JoinExamVerifying();
}

class JoinExamCodeValid extends JoinExamState {
  final ExamModel exam;
  final ExamSessionModel? existingSession;

  const JoinExamCodeValid({required this.exam, this.existingSession});

  @override
  List<Object?> get props => [exam, existingSession];
}

class JoinExamSessionStarting extends JoinExamState {
  const JoinExamSessionStarting();
}

class JoinExamSuccess extends JoinExamState {
  final ExamSessionModel session;

  const JoinExamSuccess(this.session);

  @override
  List<Object?> get props => [session];
}

class JoinExamError extends JoinExamState {
  final String message;

  const JoinExamError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class JoinExamCubit extends Cubit<JoinExamState> {
  final FirestoreService _firestoreService;
  final ExamCodeService _examCodeService;

  JoinExamCubit({
    required FirestoreService firestoreService,
    required ExamCodeService examCodeService,
  })  : _firestoreService = firestoreService,
        _examCodeService = examCodeService,
        super(const JoinExamInitial());

  Future<void> verifyCode(String code, String userId) async {
    emit(const JoinExamVerifying());
    try {
      final exam = await _examCodeService.validateCode(code);
      if (exam == null) {
        emit(const JoinExamError('Kode ujian tidak valid, tidak aktif, atau sudah kadaluwarsa.'));
        return;
      }

      // Check for existing session
      final existingSessions = await _firestoreService.getCollection<ExamSessionModel>(
        path: FirestoreService.examSessionsPath,
        fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
        queryBuilder: (q) => q
            .where('examId', isEqualTo: exam.id)
            .where('userId', isEqualTo: userId),
      );

      if (existingSessions.isNotEmpty) {
        final session = existingSessions.first;
        if (session.status == 'completed' || session.status == 'auto_submitted') {
          emit(const JoinExamError('Anda sudah menyelesaikan ujian ini dan tidak dapat mengikutinya kembali.'));
        } else {
          emit(JoinExamCodeValid(exam: exam, existingSession: session));
        }
      } else {
        emit(JoinExamCodeValid(exam: exam));
      }
    } catch (e) {
      emit(JoinExamError('Terjadi kesalahan saat memverifikasi kode: ${e.toString()}'));
    }
  }

  Future<void> startExam(ExamModel exam, String userId) async {
    emit(const JoinExamSessionStarting());
    try {
      // 1. Fetch all questions for this exam
      final questions = await _firestoreService.getCollection<QuestionModel>(
        path: _firestoreService.questionsPath(exam.id),
        fromJson: (json, id) => QuestionModel.fromJson(json, id: id),
      );

      if (questions.isEmpty) {
        emit(const JoinExamError('Ujian tidak dapat dimulai karena belum memiliki soal.'));
        return;
      }

      // Generate a new session ID first to use as seed
      final sessionId = '${userId}_${exam.id}_${DateTime.now().millisecondsSinceEpoch}';
      final seed = _getSeedFromString(sessionId);
      final random = Random(seed);

      // Sort or shuffle questions using Fisher-Yates
      final questionList = List<QuestionModel>.from(questions);
      if (exam.shuffleQuestions) {
        _fisherYatesShuffle(questionList, random);
      } else {
        questionList.sort((a, b) => a.order.compareTo(b.order));
      }

      final questionOrder = questionList.map((q) => q.id).toList();

      // Shuffle options for PG questions if shuffleOptions is enabled
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

      // 2. Generate the new session
      final newSession = ExamSessionModel(
        id: sessionId,
        examId: exam.id,
        userId: userId,
        startedAt: DateTime.now(),
        status: 'in_progress',
        questionOrder: questionOrder,
        optionOrders: optionOrders,
        answers: const {},
        appSwitchCount: 0,
        appSwitchLogs: const [],
      );

      // 3. Save to Firestore
      await _firestoreService.addDocument(
        path: FirestoreService.examSessionsPath,
        docId: sessionId,
        data: newSession.toJson(),
      );

      emit(JoinExamSuccess(newSession));
    } catch (e) {
      emit(JoinExamError('Gagal memulai sesi ujian: ${e.toString()}'));
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
