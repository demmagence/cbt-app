import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../models/exam_model.dart';
import '../../services/firestore_service.dart';
import '../../services/exam_code_service.dart';

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
  final ExamCodeService _examCodeService;

  CreateExamCubit({
    required FirestoreService firestoreService,
    required ExamCodeService examCodeService,
  })  : _firestoreService = firestoreService,
        _examCodeService = examCodeService,
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
      // 1. Generate unique exam code
      final uniqueCode = await _examCodeService.generateUniqueCode();

      // 2. Generate random exam ID (UUID)
      final examId = const Uuid().v4();

      // 3. Construct ExamModel
      final exam = ExamModel(
        id: examId,
        title: title,
        description: description,
        code: uniqueCode,
        createdBy: guruId,
        duration: duration,
        startDate: startDate,
        endDate: endDate,
        isActive: true,
        shuffleQuestions: shuffleQuestions,
        shuffleOptions: shuffleOptions,
        totalQuestions: 0,
      );

      // 4. Save to Firestore
      await _firestoreService.addDocument(
        path: FirestoreService.examsPath,
        docId: examId,
        data: exam.toJson(),
      );

      emit(CreateExamSuccess(exam));
    } catch (e) {
      emit(CreateExamError('Gagal membuat ujian: ${e.toString()}'));
    }
  }
}
