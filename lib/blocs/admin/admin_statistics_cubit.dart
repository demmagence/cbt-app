import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';

// Guru Exam Count Model
class GuruExamCount extends Equatable {
  final String name;
  final int count;

  const GuruExamCount({required this.name, required this.count});

  @override
  List<Object?> get props => [name, count];
}

// States
abstract class AdminStatisticsState extends Equatable {
  const AdminStatisticsState();

  @override
  List<Object?> get props => [];
}

class AdminStatisticsInitial extends AdminStatisticsState {
  const AdminStatisticsInitial();
}

class AdminStatisticsLoading extends AdminStatisticsState {
  const AdminStatisticsLoading();
}

class AdminStatisticsLoaded extends AdminStatisticsState {
  final Map<String, int> examsPerMonth;
  final Map<String, int> activeStudentsPerMonth;
  final List<GuruExamCount> topGurus;
  final double averageScore;
  final int activeExamsCount;
  final int scheduledExamsCount;
  final int endedExamsCount;
  final int totalExamsCount;

  const AdminStatisticsLoaded({
    required this.examsPerMonth,
    required this.activeStudentsPerMonth,
    required this.topGurus,
    required this.averageScore,
    required this.activeExamsCount,
    required this.scheduledExamsCount,
    required this.endedExamsCount,
    required this.totalExamsCount,
  });

  @override
  List<Object?> get props => [
    examsPerMonth,
    activeStudentsPerMonth,
    topGurus,
    averageScore,
    activeExamsCount,
    scheduledExamsCount,
    endedExamsCount,
    totalExamsCount,
  ];
}

class AdminStatisticsError extends AdminStatisticsState {
  final String message;

  const AdminStatisticsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class AdminStatisticsCubit extends Cubit<AdminStatisticsState> {
  final FirestoreService _firestoreService;

  AdminStatisticsCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const AdminStatisticsInitial());

  Future<void> loadStatistics() async {
    emit(const AdminStatisticsLoading());
    try {
      // 1. Fetch Users, Exams, and Results in parallel
      final results = await Future.wait([
        _firestoreService.getCollection<UserModel>(
          path: FirestoreService.usersPath,
          fromJson: (json, id) => UserModel.fromJson(json),
        ),
        _firestoreService.getCollection<ExamModel>(
          path: FirestoreService.examsPath,
          fromJson: (json, id) => ExamModel.fromJson(json, id: id),
        ),
        _firestoreService.getCollection<ExamResultModel>(
          path: FirestoreService.examResultsPath,
          fromJson: (json, id) => ExamResultModel.fromJson(json, id: id),
        ),
      ]);

      final users = results[0] as List<UserModel>;
      final exams = results[1] as List<ExamModel>;
      final examResults = results[2] as List<ExamResultModel>;

      // 2. Average Score calculation
      double totalScoresSum = 0;
      final gradedResults = examResults
          .where((r) => r.gradingStatus == 'graded')
          .toList();
      for (final result in gradedResults) {
        totalScoresSum += result.totalScore.toDouble();
      }
      final averageScore = gradedResults.isEmpty
          ? 0.0
          : totalScoresSum / gradedResults.length;

      // 3. Exam Status Distribution calculation
      final now = DateTime.now();
      int activeExamsCount = 0;
      int scheduledExamsCount = 0;
      int endedExamsCount = 0;

      for (final exam in exams) {
        if (!exam.isActive) {
          endedExamsCount++;
        } else if (now.isBefore(exam.startDate)) {
          scheduledExamsCount++;
        } else if (now.isAfter(exam.endDate)) {
          endedExamsCount++;
        } else {
          activeExamsCount++;
        }
      }
      final totalExamsCount = exams.length;

      // 4. Group data by month for the last 6 months
      final last6MonthsKeys = <String>[];
      final examsPerMonth = <String, int>{};
      final activeStudentsPerMonth =
          <String, Set<String>>{}; // Using Set to count unique userIds

      // Initialize keys for the last 6 months
      for (int i = 5; i >= 0; i--) {
        final targetMonth = DateTime(now.year, now.month - i, 1);
        final key = DateFormat('MMM yyyy').format(targetMonth);
        last6MonthsKeys.add(key);
        examsPerMonth[key] = 0;
        activeStudentsPerMonth[key] = {};
      }

      // Group exam results
      for (final res in examResults) {
        final key = DateFormat('MMM yyyy').format(res.submittedAt);
        if (examsPerMonth.containsKey(key)) {
          examsPerMonth[key] = examsPerMonth[key]! + 1;
          activeStudentsPerMonth[key]!.add(res.userId);
        }
      }

      // Map active students count per month
      final finalActiveStudentsPerMonth = activeStudentsPerMonth.map(
        (key, value) => MapEntry(key, value.length),
      );

      // 5. Top 5 Guru by exam counts
      final userMap = {for (var u in users) u.uid: u.name};
      final guruExamsCountMap =
          <String, int>{}; // Key: createdBy (uid), Value: count

      for (final exam in exams) {
        final creatorId = exam.createdBy;
        guruExamsCountMap[creatorId] = (guruExamsCountMap[creatorId] ?? 0) + 1;
      }

      final topGurus = guruExamsCountMap.entries.map((entry) {
        final guruName = userMap[entry.key] ?? 'Guru CBT';
        return GuruExamCount(name: guruName, count: entry.value);
      }).toList();

      // Sort descending by exam count
      topGurus.sort((a, b) => b.count.compareTo(a.count));
      final finalTopGurus = topGurus.take(5).toList();

      emit(
        AdminStatisticsLoaded(
          examsPerMonth: examsPerMonth,
          activeStudentsPerMonth: finalActiveStudentsPerMonth,
          topGurus: finalTopGurus,
          averageScore: averageScore,
          activeExamsCount: activeExamsCount,
          scheduledExamsCount: scheduledExamsCount,
          endedExamsCount: endedExamsCount,
          totalExamsCount: totalExamsCount,
        ),
      );
    } catch (e) {
      emit(
        AdminStatisticsError('Gagal memuat data statistik: ${e.toString()}'),
      );
    }
  }
}
