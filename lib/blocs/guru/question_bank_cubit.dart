import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/question_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class QuestionBankState extends Equatable {
  const QuestionBankState();

  @override
  List<Object?> get props => [];
}

class QuestionBankInitial extends QuestionBankState {
  const QuestionBankInitial();
}

class QuestionBankLoading extends QuestionBankState {
  const QuestionBankLoading();
}

class QuestionBankLoaded extends QuestionBankState {
  final List<QuestionModel> questions;

  const QuestionBankLoaded(this.questions);

  @override
  List<Object?> get props => [questions];
}

class QuestionBankError extends QuestionBankState {
  final String message;

  const QuestionBankError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class QuestionBankCubit extends Cubit<QuestionBankState> {
  final FirestoreService _firestoreService;

  QuestionBankCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const QuestionBankInitial());

  Future<void> loadQuestions(String guruId) async {
    emit(const QuestionBankLoading());
    try {
      final questions = await _firestoreService.getCollection<QuestionModel>(
        path: FirestoreService.questionBankPath,
        fromJson: (json, id) => QuestionModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('createdBy', isEqualTo: guruId),
      );

      // Sort by order/text/creation
      questions.sort(
        (a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()),
      );

      emit(QuestionBankLoaded(questions));
    } catch (e) {
      emit(QuestionBankError('Gagal memuat bank soal: ${e.toString()}'));
    }
  }

  Future<void> addQuestion(String guruId, QuestionModel question) async {
    emit(const QuestionBankLoading());
    try {
      final data = {...question.toJson(), 'createdBy': guruId};

      await _firestoreService.addDocument(
        path: FirestoreService.questionBankPath,
        docId: question.id,
        data: data,
      );

      await loadQuestions(guruId);
    } catch (e) {
      emit(
        QuestionBankError(
          'Gagal menambahkan soal ke bank soal: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> updateQuestion(String guruId, QuestionModel question) async {
    emit(const QuestionBankLoading());
    try {
      await _firestoreService.addDocument(
        path: FirestoreService.questionBankPath,
        docId: question.id,
        data: {...question.toJson(), 'createdBy': guruId},
      );

      await loadQuestions(guruId);
    } catch (e) {
      emit(
        QuestionBankError(
          'Gagal memperbarui soal di bank soal: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> deleteQuestion(String guruId, String questionId) async {
    emit(const QuestionBankLoading());
    try {
      await _firestoreService.deleteDocument(
        path: FirestoreService.questionBankPath,
        docId: questionId,
      );

      await loadQuestions(guruId);
    } catch (e) {
      emit(
        QuestionBankError(
          'Gagal menghapus soal dari bank soal: ${e.toString()}',
        ),
      );
    }
  }
}
