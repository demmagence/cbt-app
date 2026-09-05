import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';

// Activity Types for UI styling
enum AdminActivityType { newUser, examCreated, examSubmitted }

// Activity Item Model
class AdminActivityItem extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final AdminActivityType type;

  const AdminActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
  });

  @override
  List<Object?> get props => [id, title, subtitle, timestamp, type];
}

// States
abstract class AdminDashboardState extends Equatable {
  const AdminDashboardState();

  @override
  List<Object?> get props => [];
}

class AdminDashboardInitial extends AdminDashboardState {
  const AdminDashboardInitial();
}

class AdminDashboardLoading extends AdminDashboardState {
  const AdminDashboardLoading();
}

class AdminDashboardLoaded extends AdminDashboardState {
  final int totalUsers;
  final int totalGuru;
  final int totalSiswa;
  final int totalUjian;
  final List<AdminActivityItem> recentActivities;
  final Map<String, int> examsPerMonth; // Key: "MMM YYYY", Value: Count

  const AdminDashboardLoaded({
    required this.totalUsers,
    required this.totalGuru,
    required this.totalSiswa,
    required this.totalUjian,
    required this.recentActivities,
    required this.examsPerMonth,
  });

  @override
  List<Object?> get props => [
    totalUsers,
    totalGuru,
    totalSiswa,
    totalUjian,
    recentActivities,
    examsPerMonth,
  ];
}

class AdminDashboardError extends AdminDashboardState {
  final String message;

  const AdminDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  final FirestoreService _firestoreService;

  AdminDashboardCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const AdminDashboardInitial());

  Future<void> loadDashboardData() async {
    emit(const AdminDashboardLoading());
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

      // 2. Compute counts
      final totalUsers = users.where((u) => !u.deleted).length;
      final totalGuru = users
          .where((u) => !u.deleted && u.role == 'guru')
          .length;
      final totalSiswa = users
          .where((u) => !u.deleted && u.role == 'siswa')
          .length;
      final totalUjian = exams.length;

      // Create quick lookup maps for descriptions
      final userMap = {for (var u in users) u.uid: u.name};
      final examMap = {for (var e in exams) e.id: e.title};

      // 3. Compile Recent Activities
      final activityList = <AdminActivityItem>[];

      // Add new users activity
      for (final user in users) {
        // Only count as recent if within some timeframe or just add all and we will sort/limit
        final roleLabel = user.role == 'admin'
            ? 'Admin'
            : (user.role == 'guru' ? 'Guru' : 'Siswa');
        activityList.add(
          AdminActivityItem(
            id: 'user_${user.uid}',
            title: 'Pengguna Baru Terdaftar',
            subtitle: '${user.name} bergabung sebagai $roleLabel',
            timestamp: user.createdAt,
            type: AdminActivityType.newUser,
          ),
        );
      }

      // Add new exams activity
      for (final exam in exams) {
        final creatorName = userMap[exam.createdBy] ?? 'Guru';
        activityList.add(
          AdminActivityItem(
            id: 'exam_${exam.id}',
            title: 'Ujian Baru Dibuat',
            subtitle: '"${exam.title}" dibuat oleh $creatorName',
            timestamp: exam.startDate, // Using startDate as reference
            type: AdminActivityType.examCreated,
          ),
        );
      }

      // Add submitted exam results activity
      for (final res in examResults) {
        final studentName = userMap[res.userId] ?? 'Siswa';
        final examTitle = examMap[res.examId] ?? 'Ujian';
        activityList.add(
          AdminActivityItem(
            id: 'result_${res.id}',
            title: 'Ujian Diselesaikan',
            subtitle: '$studentName menyelesaikan ujian "$examTitle"',
            timestamp: res.submittedAt,
            type: AdminActivityType.examSubmitted,
          ),
        );
      }

      // Sort activities descending by timestamp
      activityList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final recentActivities = activityList.take(8).toList();

      // 4. Compute exams per month for the last 6 months
      final now = DateTime.now();
      final last6MonthsKeys = <String>[];
      final examsPerMonth = <String, int>{};

      // Initialize last 6 months keys
      for (int i = 5; i >= 0; i--) {
        final targetMonth = DateTime(now.year, now.month - i, 1);
        final key = DateFormat('MMM yyyy').format(targetMonth);
        last6MonthsKeys.add(key);
        examsPerMonth[key] = 0; // Default count is 0
      }

      // Group exam results by month
      for (final res in examResults) {
        final key = DateFormat('MMM yyyy').format(res.submittedAt);
        if (examsPerMonth.containsKey(key)) {
          examsPerMonth[key] = examsPerMonth[key]! + 1;
        }
      }

      emit(
        AdminDashboardLoaded(
          totalUsers: totalUsers,
          totalGuru: totalGuru,
          totalSiswa: totalSiswa,
          totalUjian: totalUjian,
          recentActivities: recentActivities,
          examsPerMonth: examsPerMonth,
        ),
      );
    } catch (e) {
      emit(AdminDashboardError('Gagal memuat data dashboard: ${e.toString()}'));
    }
  }
}
