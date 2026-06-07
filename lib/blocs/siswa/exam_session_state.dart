import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/exam_result_model.dart';

abstract class ExamSessionState extends Equatable {
  const ExamSessionState();

  @override
  List<Object?> get props => [];
}

class ExamSessionInitial extends ExamSessionState {
  const ExamSessionInitial();
}

class ExamSessionLoading extends ExamSessionState {
  const ExamSessionLoading();
}

class ExamSessionActive extends ExamSessionState {
  final ExamModel exam;
  final ExamSessionModel session;
  final List<QuestionModel> questions; // ordered questions
  final int currentIndex;
  final int remainingTime; // in seconds
  final Set<String> flaggedQuestions;
  final Set<String> visitedQuestions;
  final bool isOffline;

  const ExamSessionActive({
    required this.exam,
    required this.session,
    required this.questions,
    required this.currentIndex,
    required this.remainingTime,
    required this.flaggedQuestions,
    required this.visitedQuestions,
    this.isOffline = false,
  });

  ExamSessionActive copyWith({
    ExamModel? exam,
    ExamSessionModel? session,
    List<QuestionModel>? questions,
    int? currentIndex,
    int? remainingTime,
    Set<String>? flaggedQuestions,
    Set<String>? visitedQuestions,
    bool? isOffline,
  }) {
    return ExamSessionActive(
      exam: exam ?? this.exam,
      session: session ?? this.session,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingTime: remainingTime ?? this.remainingTime,
      flaggedQuestions: flaggedQuestions ?? this.flaggedQuestions,
      visitedQuestions: visitedQuestions ?? this.visitedQuestions,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => [
        exam,
        session,
        questions,
        currentIndex,
        remainingTime,
        flaggedQuestions,
        visitedQuestions,
        isOffline,
      ];
}

class ExamSessionSubmitting extends ExamSessionState {
  final bool isOffline;
  const ExamSessionSubmitting({this.isOffline = false});

  @override
  List<Object?> get props => [isOffline];
}

class ExamSessionCompleted extends ExamSessionState {
  final ExamResultModel result;

  const ExamSessionCompleted(this.result);

  @override
  List<Object?> get props => [result];
}

class ExamSessionError extends ExamSessionState {
  final String message;

  const ExamSessionError(this.message);

  @override
  List<Object?> get props => [message];
}
