import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class ExamListState extends Equatable {
  const ExamListState();

  @override
  List<Object?> get props => [];
}

class ExamListInitial extends ExamListState {
  const ExamListInitial();
}

class ExamListLoading extends ExamListState {
  const ExamListLoading();
}

class ExamListLoaded extends ExamListState {
  final List<ExamModel> exams;

  const ExamListLoaded(this.exams);

  @override
  List<Object?> get props => [exams];
}

class ExamListError extends ExamListState {
  final String message;

  const ExamListError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ExamListCubit extends Cubit<ExamListState> {
  final FirestoreService _firestoreService;

  ExamListCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const ExamListInitial());

  Future<void> loadExams(String guruId) async {
    emit(const ExamListLoading());
    try {
      final exams = await _firestoreService.getCollection<ExamModel>(
        path: FirestoreService.examsPath,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('createdBy', isEqualTo: guruId),
      );

      // Sort by startDate descending (newest first)
      exams.sort((a, b) => b.startDate.compareTo(a.startDate));

      emit(ExamListLoaded(exams));
    } catch (e) {
      emit(ExamListError('Gagal memuat daftar ujian: ${e.toString()}'));
    }
  }

  Future<void> toggleExamStatus(
    String examId,
    bool isActive,
    String guruId,
  ) async {
    try {
      await _firestoreService.updateDocument(
        path: FirestoreService.examsPath,
        docId: examId,
        data: {'isActive': isActive},
      );
      await loadExams(guruId);
    } catch (e) {
      emit(ExamListError('Gagal memperbarui status ujian: ${e.toString()}'));
    }
  }

  Future<void> deleteExam(String examId, String guruId) async {
    emit(const ExamListLoading());
    try {
      await _firestoreService.call('deleteExam', {'examId': examId});

      // 4. Reload exams
      await loadExams(guruId);
    } catch (e) {
      emit(ExamListError('Gagal menghapus ujian: ${e.toString()}'));
    }
  }
}
