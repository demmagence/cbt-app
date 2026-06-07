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

  Future<void> addQuestion(String examId, QuestionModel question) async {
    try {
      final state = this.state;
      if (state is! AddQuestionLoaded) return;

      emit(const AddQuestionLoading());

      final qPath = _firestoreService.questionsPath(examId);
      
      // Save question
      await _firestoreService.addDocument(
        path: qPath,
        docId: question.id,
        data: question.toJson(),
      );

      // Update total questions count in Exam
      final newTotal = state.exam.totalQuestions + 1;
      await _firestoreService.updateDocument(
        path: FirestoreService.examsPath,
        docId: examId,
        data: {'totalQuestions': newTotal},
      );

      // Reload
      await loadQuestions(examId);
    } catch (e) {
      emit(AddQuestionError('Gagal menambah soal: ${e.toString()}'));
    }
  }

  Future<void> updateQuestion(String examId, QuestionModel question) async {
    try {
      final state = this.state;
      if (state is! AddQuestionLoaded) return;

      emit(const AddQuestionLoading());

      final qPath = _firestoreService.questionsPath(examId);
      
      // Update question
      await _firestoreService.updateDocument(
        path: qPath,
        docId: question.id,
        data: question.toJson(),
      );

      // Reload
      await loadQuestions(examId);
    } catch (e) {
      emit(AddQuestionError('Gagal memperbarui soal: ${e.toString()}'));
    }
  }

  Future<void> deleteQuestion(String examId, String questionId) async {
    try {
      final state = this.state;
      if (state is! AddQuestionLoaded) return;

      emit(const AddQuestionLoading());

      final qPath = _firestoreService.questionsPath(examId);

      // Delete question
      await _firestoreService.deleteDocument(
        path: qPath,
        docId: questionId,
      );

      // Update total questions count in Exam
      final newTotal = state.exam.totalQuestions - 1 >= 0 ? state.exam.totalQuestions - 1 : 0;
      await _firestoreService.updateDocument(
        path: FirestoreService.examsPath,
        docId: examId,
        data: {'totalQuestions': newTotal},
      );

      // Adjust remaining questions' order
      final remaining = state.questions.where((q) => q.id != questionId).toList();
      for (int i = 0; i < remaining.length; i++) {
        final q = remaining[i];
        if (q.order != i) {
          await _firestoreService.updateDocument(
            path: qPath,
            docId: q.id,
            data: {'order': i},
          );
        }
      }

      // Reload
      await loadQuestions(examId);
    } catch (e) {
      emit(AddQuestionError('Gagal menghapus soal: ${e.toString()}'));
    }
  }

  Future<void> reorderQuestions(String examId, List<QuestionModel> reorderedList) async {
    try {
      emit(const AddQuestionLoading());

      final qPath = _firestoreService.questionsPath(examId);

      // Update order in Firestore for each question
      for (int i = 0; i < reorderedList.length; i++) {
        final q = reorderedList[i];
        await _firestoreService.updateDocument(
          path: qPath,
          docId: q.id,
          data: {'order': i},
        );
      }

      // Reload
      await loadQuestions(examId);
    } catch (e) {
      emit(AddQuestionError('Gagal mengurutkan soal: ${e.toString()}'));
    }
  }

  Future<void> importQuestions(String examId, List<QuestionModel> selectedQuestions) async {
    try {
      final state = this.state;
      if (state is! AddQuestionLoaded) return;

      emit(const AddQuestionLoading());

      final qPath = _firestoreService.questionsPath(examId);
      int currentOrder = state.questions.length;

      for (final q in selectedQuestions) {
        final newQuestion = q.copyWith(
          id: const Uuid().v4(),
          order: currentOrder++,
        );
        await _firestoreService.addDocument(
          path: qPath,
          docId: newQuestion.id,
          data: newQuestion.toJson(),
        );
      }

      final newTotal = state.exam.totalQuestions + selectedQuestions.length;
      await _firestoreService.updateDocument(
        path: FirestoreService.examsPath,
        docId: examId,
        data: {'totalQuestions': newTotal},
      );

      await loadQuestions(examId);
    } catch (e) {
      emit(AddQuestionError('Gagal mengimpor soal: ${e.toString()}'));
    }
  }
}
