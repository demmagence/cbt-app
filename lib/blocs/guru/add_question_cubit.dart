import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../models/exam_model.dart';
import '../../models/question_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class AddQuestionState extends Equatable {
  const AddQuestionState();

  @override
  List<Object?> get props => [];
}

class AddQuestionInitial extends AddQuestionState {
  const AddQuestionInitial();
}

class AddQuestionLoading extends AddQuestionState {
  const AddQuestionLoading();
}

class AddQuestionLoaded extends AddQuestionState {
  final List<QuestionModel> questions;
  final ExamModel exam;

  const AddQuestionLoaded({required this.questions, required this.exam});

  @override
  List<Object?> get props => [questions, exam];
}

class AddQuestionError extends AddQuestionState {
  final String message;

  const AddQuestionError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class AddQuestionCubit extends Cubit<AddQuestionState> {
  final FirestoreService _firestoreService;

  AddQuestionCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const AddQuestionInitial());

  Future<void> loadQuestions(String examId) async {
    emit(const AddQuestionLoading());
    try {
      // 1. Fetch exam document
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const AddQuestionError('Ujian tidak ditemukan'));
        return;
      }

      // 2. Fetch questions from subcollection
      final qPath = _firestoreService.questionsPath(examId);
      final questions = await _firestoreService.getCollection<QuestionModel>(
        path: qPath,
        fromJson: (json, id) => QuestionModel.fromJson(json, id: id),
      );

      // Sort by order ascending
      questions.sort((a, b) => a.order.compareTo(b.order));

      emit(AddQuestionLoaded(questions: questions, exam: exam));
    } catch (e) {
      emit(AddQuestionError('Gagal memuat soal: ${e.toString()}'));
    }
  }

  Future<void> _change(String examId, Map<String, dynamic> data) async {
    if (state is AddQuestionLoading) {
      return;
    }
    if (state is AddQuestionLoaded &&
        (state as AddQuestionLoaded).exam.locked) {
      emit(
        const AddQuestionError(
          'Soal dikunci karena ujian sudah pernah dikerjakan.',
        ),
      );
      return;
    }
    emit(const AddQuestionLoading());
    try {
      await _firestoreService.call('editQuestions', {
        'examId': examId,
        ...data,
      });
      await loadQuestions(examId);
    } catch (e) {
      emit(AddQuestionError('Gagal menyimpan soal: $e'));
    }
  }

  Future<void> addQuestion(String examId, QuestionModel question) =>
      _change(examId, {
        'action': 'add',
        'questions': [question.toJson()],
      });

  Future<void> updateQuestion(String examId, QuestionModel question) =>
      _change(examId, {'action': 'update', 'question': question.toJson()});

  Future<void> deleteQuestion(String examId, String questionId) =>
      _change(examId, {'action': 'delete', 'questionId': questionId});

  Future<void> reorderQuestions(String examId, List<QuestionModel> questions) =>
      _change(examId, {
        'action': 'reorder',
        'ids': questions.map((q) => q.id).toList(),
      });

  Future<void> importQuestions(String examId, List<QuestionModel> questions) =>
      _change(examId, {
        'action': 'add',
        'questions': questions
            .map((q) => q.copyWith(id: const Uuid().v4()).toJson())
            .toList(),
      });
}
