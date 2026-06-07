import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class EditExamState extends Equatable {
  const EditExamState();

  @override
  List<Object?> get props => [];
}

class EditExamInitial extends EditExamState {
  const EditExamInitial();
}

class EditExamLoading extends EditExamState {
  const EditExamLoading();
}

class EditExamLoaded extends EditExamState {
  final ExamModel exam;

  const EditExamLoaded(this.exam);

  @override
  List<Object?> get props => [exam];
}

class EditExamSuccess extends EditExamState {
  const EditExamSuccess();
}

class EditExamError extends EditExamState {
  final String message;

  const EditExamError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class EditExamCubit extends Cubit<EditExamState> {
  final FirestoreService _firestoreService;

  EditExamCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const EditExamInitial());

  Future<void> loadExam(String examId) async {
    emit(const EditExamLoading());
    try {
      final exam = await _firestoreService.getDocument<ExamModel>(
        path: FirestoreService.examsPath,
        docId: examId,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
      );

      if (exam == null) {
        emit(const EditExamError('Ujian tidak ditemukan'));
        return;
      }

      emit(EditExamLoaded(exam));
    } catch (e) {
      emit(EditExamError('Gagal memuat detail ujian: ${e.toString()}'));
    }
  }

  Future<void> updateExam({
    required String examId,
    required String title,
    required String description,
    required int duration,
    required DateTime startDate,
    required DateTime endDate,
    required bool shuffleQuestions,
    required bool shuffleOptions,
    required bool isActive,
  }) async {
    try {
      final currentState = state;
      if (currentState is! EditExamLoaded) return;

      emit(const EditExamLoading());

      final updatedData = {
        'title': title,
        'description': description,
        'duration': duration,
        'startDate': startDate,
        'endDate': endDate,
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
        'isActive': isActive,
      };

      await _firestoreService.updateDocument(
        path: FirestoreService.examsPath,
        docId: examId,
        data: updatedData,
      );

      emit(const EditExamSuccess());
    } catch (e) {
      emit(EditExamError('Gagal memperbarui ujian: ${e.toString()}'));
    }
  }
}
