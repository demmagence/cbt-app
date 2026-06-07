import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class EssayGradingListState extends Equatable {
  const EssayGradingListState();

  @override
  List<Object?> get props => [];
}

class EssayGradingListInitial extends EssayGradingListState {
  const EssayGradingListInitial();
}

class EssayGradingListLoading extends EssayGradingListState {
  const EssayGradingListLoading();
}

class EssayGradingListLoaded extends EssayGradingListState {
  final List<ExamResultModel> pendingResults;
  final Map<String, ExamModel> examMap;
  final Map<String, UserModel> studentMap;

  const EssayGradingListLoaded({
    required this.pendingResults,
    required this.examMap,
    required this.studentMap,
  });

  @override
  List<Object?> get props => [pendingResults, examMap, studentMap];
}

class EssayGradingListError extends EssayGradingListState {
  final String message;

  const EssayGradingListError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class EssayGradingListCubit extends Cubit<EssayGradingListState> {
  final FirestoreService _firestoreService;

  EssayGradingListCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const EssayGradingListInitial());

  Future<void> loadPendingEssayResults(String guruId) async {
    emit(const EssayGradingListLoading());
    try {
      // 1. Fetch all exams created by this Guru
      final exams = await _firestoreService.getCollection<ExamModel>(
        path: FirestoreService.examsPath,
        fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('createdBy', isEqualTo: guruId),
      );

      final Map<String, ExamModel> examMap = {for (var e in exams) e.id: e};
      final examIds = examMap.keys.toSet();

      if (examIds.isEmpty) {
        emit(const EssayGradingListLoaded(
          pendingResults: [],
          examMap: {},
          studentMap: {},
        ));
        return;
      }

      // 2. Fetch all exam results with status 'pending_essay'
      final allPendingResults = await _firestoreService.getCollection<ExamResultModel>(
        path: FirestoreService.examResultsPath,
        fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        queryBuilder: (query) => query.where('gradingStatus', isEqualTo: 'pending_essay'),
      );

      // 3. Filter results to keep only those belonging to the Guru's exams
      final pendingResults = allPendingResults.where((r) => examIds.contains(r.examId)).toList();

      // Sort by submittedAt descending
      pendingResults.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      // 4. Load students info
      final Map<String, UserModel> studentMap = {};
      final studentIds = pendingResults.map((r) => r.userId).toSet();

      for (final uid in studentIds) {
        final user = await _firestoreService.getDocument<UserModel>(
          path: FirestoreService.usersPath,
          docId: uid,
          fromJson: (json, id) => UserModel.fromJson(json),
        );
        if (user != null) {
          studentMap[uid] = user;
        }
      }

      emit(EssayGradingListLoaded(
        pendingResults: pendingResults,
        examMap: examMap,
        studentMap: studentMap,
      ));
    } catch (e) {
      emit(EssayGradingListError('Gagal memuat daftar koreksi: ${e.toString()}'));
    }
  }
}
