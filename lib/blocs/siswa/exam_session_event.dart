import 'package:equatable/equatable.dart';
import '../../models/exam_session_model.dart';

abstract class ExamSessionEvent extends Equatable {
  const ExamSessionEvent();

  @override
  List<Object?> get props => [];
}

class ExamStarted extends ExamSessionEvent {
  final String examId;
  final String userId;

  const ExamStarted({required this.examId, required this.userId});

  @override
  List<Object?> get props => [examId, userId];
}

class AnswerSelected extends ExamSessionEvent {
  final String questionId;
  final int answerIndex;

  const AnswerSelected({required this.questionId, required this.answerIndex});

  @override
  List<Object?> get props => [questionId, answerIndex];
}

class EssayAnswerUpdated extends ExamSessionEvent {
  final String questionId;
  final String text;

  const EssayAnswerUpdated({required this.questionId, required this.text});

  @override
  List<Object?> get props => [questionId, text];
}

class QuestionNavigated extends ExamSessionEvent {
  final int index;

  const QuestionNavigated(this.index);

  @override
  List<Object?> get props => [index];
}

class ExamSubmitted extends ExamSessionEvent {
  final bool isAutoSubmit;

  const ExamSubmitted({this.isAutoSubmit = false});

  @override
  List<Object?> get props => [isAutoSubmit];
}

class TimerTicked extends ExamSessionEvent {
  final int remainingSeconds;

  const TimerTicked(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

class TimerExpired extends ExamSessionEvent {
  const TimerExpired();
}

class AppSwitchDetected extends ExamSessionEvent {
  final AppSwitchLog log;

  const AppSwitchDetected(this.log);

  @override
  List<Object?> get props => [log];
}

class FlagToggled extends ExamSessionEvent {
  final String questionId;

  const FlagToggled(this.questionId);

  @override
  List<Object?> get props => [questionId];
}

class AppResumed extends ExamSessionEvent {
  const AppResumed();
}

class ConnectivityChanged extends ExamSessionEvent {
  final bool isOffline;

  const ConnectivityChanged({required this.isOffline});

  @override
  List<Object?> get props => [isOffline];
}

class SyncAnswersRequested extends ExamSessionEvent {
  const SyncAnswersRequested();
}

class RemoteSessionChanged extends ExamSessionEvent {
  final ExamSessionModel session;
  const RemoteSessionChanged(this.session);
  @override
  List<Object?> get props => [session];
}
