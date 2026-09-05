import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class CreateExamState extends Equatable {
  const CreateExamState();

  @override
  List<Object?> get props => [];
}

class CreateExamInitial extends CreateExamState {
  const CreateExamInitial();
}

class CreateExamLoading extends CreateExamState {
  const CreateExamLoading();
}

class CreateExamSuccess extends CreateExamState {
  final ExamModel exam;

  const CreateExamSuccess(this.exam);

  @override
  List<Object?> get props => [exam];
}

class CreateExamError extends CreateExamState {
  final String message;

  const CreateExamError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class CreateExamCubit extends Cubit<CreateExamState> {
  final FirestoreService _firestoreService;

  CreateExamCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const CreateExamInitial());

  Future<void> createExam({
    required String title,
    required String description,
    required int duration,
    required DateTime startDate,
    required DateTime endDate,
    required bool shuffleQuestions,
    required bool shuffleOptions,
    required String guruId,
  }) async {
    emit(const CreateExamLoading());
    try {
      final data = await _firestoreService.call('createExam', {
        'title': title.trim(),
        'description': description.trim(),
        'duration': duration,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
      });
      final exam = ExamModel.fromJson(data);

      emit(CreateExamSuccess(exam));
    } catch (e) {
      emit(CreateExamError('Gagal membuat ujian: ${e.toString()}'));
    }
  }
}
