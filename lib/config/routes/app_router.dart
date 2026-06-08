import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/user_management_screen.dart';
import '../../screens/admin/edit_user_screen.dart';
import '../../screens/admin/create_user_screen.dart';
import '../../screens/admin/admin_statistics_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../models/user_model.dart';
import '../../screens/guru/guru_dashboard_screen.dart';
import '../../screens/guru/create_exam_screen.dart';
import '../../screens/guru/add_question_screen.dart';
import '../../screens/guru/exam_list_screen.dart';
import '../../screens/guru/edit_exam_screen.dart';
import '../../screens/guru/question_bank_screen.dart';
import '../../screens/guru/exam_results_screen.dart';
import '../../screens/guru/student_result_detail_screen.dart';
import '../../screens/guru/essay_grading_screen.dart';
import '../../screens/guru/essay_grading_detail_screen.dart';
import '../../screens/guru/monitoring_screen.dart';
import '../../screens/siswa/profile_screen.dart';
import '../../screens/siswa/dashboard_screen.dart';
import '../../screens/siswa/join_exam_screen.dart';
import '../../screens/siswa/exam_taking_screen.dart';
import '../../screens/siswa/exam_history_screen.dart';
import '../../screens/siswa/exam_success_screen.dart';
import '../../widgets/common/app_drawer.dart';

// Helper class to notify GoRouter of AuthBloc state changes
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  AppRouter._();

  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isLoggingIn = state.uri.toString() == '/login';

        if (authState is AuthInitial || authState is AuthLoading) {
          return null;
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          return isLoggingIn ? null : '/login';
        }

        if (authState is AuthAuthenticated) {
          final role = authState.user.role;
          
          if (isLoggingIn) {
            if (role == 'admin') return '/admin/dashboard';
            if (role == 'guru') return '/guru/dashboard';
            return '/siswa/dashboard';
          }

          // Role-based Guards
          if (state.uri.toString().startsWith('/admin') && role != 'admin') {
            if (role == 'guru') return '/guru/dashboard';
            return '/siswa/dashboard';
          }

          if (state.uri.toString().startsWith('/guru') && role != 'guru') {
            if (role == 'admin') return '/admin/dashboard';
            return '/siswa/dashboard';
          }

          if (state.uri.toString().startsWith('/siswa') && role != 'siswa') {
            if (role == 'admin') return '/admin/dashboard';
            return '/guru/dashboard';
          }
        }

        return null;
      },
      routes: [
        // Login Route (Fullscreen)
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Admin Shell Route (Persistent Navigation Drawer)
        ShellRoute(
          builder: (context, state, child) => AdminShellScaffold(child: child),
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              builder: (context, state) => const AdminDashboardScreen(),
            ),
          ],
        ),

        // Fullscreen User Management Route
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserManagementScreen(),
        ),

        // Fullscreen Create User Route
        GoRoute(
          path: '/admin/users/create',
          builder: (context, state) => const CreateUserScreen(),
        ),

        // Fullscreen Edit User Route
        GoRoute(
          path: '/admin/users/:uid/edit',
          builder: (context, state) {
            final uid = state.pathParameters['uid'] ?? '';
            final extra = state.extra as UserModel?;
            return EditUserScreen(uid: uid, initialUser: extra);
          },
        ),

        // Fullscreen Statistics Route
        GoRoute(
          path: '/admin/statistics',
          builder: (context, state) => const StatisticsScreen(),
        ),

        // Guru Shell Route (Persistent Navigation Drawer)
        ShellRoute(
          builder: (context, state, child) => GuruShellScaffold(child: child),
          routes: [
            GoRoute(
              path: '/guru/dashboard',
              builder: (context, state) => const GuruDashboardScreen(),
            ),
            GoRoute(
              path: '/guru/exams',
              builder: (context, state) => const ExamListScreen(),
            ),
            GoRoute(
              path: '/guru/exams/create',
              builder: (context, state) => const CreateExamScreen(),
            ),
            GoRoute(
              path: '/guru/exams/:id/edit',
              builder: (context, state) {
                final examId = state.pathParameters['id'] ?? '';
                return EditExamScreen(examId: examId);
              },
            ),
            GoRoute(
              path: '/guru/exams/:id/questions',
              builder: (context, state) {
                final examId = state.pathParameters['id'] ?? '';
                return AddQuestionScreen(examId: examId);
              },
            ),
            GoRoute(
              path: '/guru/question-bank',
              builder: (context, state) => const QuestionBankScreen(),
            ),
            GoRoute(
              path: '/guru/results',
              builder: (context, state) => const ExamResultsScreen(examId: ''),
            ),
            GoRoute(
              path: '/guru/results/:examId',
              builder: (context, state) {
                final examId = state.pathParameters['examId'] ?? '';
                return ExamResultsScreen(examId: examId);
              },
            ),
            GoRoute(
              path: '/guru/results/:examId/:userId',
              builder: (context, state) {
                final examId = state.pathParameters['examId'] ?? '';
                final userId = state.pathParameters['userId'] ?? '';
                return StudentResultDetailScreen(examId: examId, userId: userId);
              },
            ),
            GoRoute(
              path: '/guru/grading',
              builder: (context, state) => const EssayGradingScreen(),
            ),
            GoRoute(
              path: '/guru/grading/:examId/:userId',
              builder: (context, state) {
                final examId = state.pathParameters['examId'] ?? '';
                final userId = state.pathParameters['userId'] ?? '';
                return EssayGradingDetailScreen(examId: examId, userId: userId);
              },
            ),
            GoRoute(
              path: '/guru/monitoring',
              builder: (context, state) => const MonitoringScreen(),
            ),
          ],
        ),

        // Siswa Shell Route (Persistent Bottom Navigation Bar)
        ShellRoute(
          builder: (context, state, child) => SiswaShellScaffold(child: child),
          routes: [
            GoRoute(
              path: '/siswa/dashboard',
              builder: (context, state) => const SiswaDashboardScreen(),
            ),
            GoRoute(
              path: '/siswa/join',
              builder: (context, state) => const JoinExamScreen(),
            ),
            GoRoute(
              path: '/siswa/history',
              builder: (context, state) => const ExamHistoryScreen(),
            ),
            GoRoute(
              path: '/siswa/profile',
              builder: (context, state) => const SiswaProfileScreen(),
            ),
          ],
        ),

        // Siswa Exam Screen (Fullscreen - outside the bottom nav shell to prevent navigation distraction)
        GoRoute(
          path: '/siswa/exam/:id',
          builder: (context, state) {
            final examId = state.pathParameters['id'] ?? '';
            return ExamTakingScreen(examId: examId);
          },
        ),
        GoRoute(
          path: '/siswa/exam-success',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final examTitle = extra['examTitle'] as String? ?? 'Ujian';
            final pgScore = extra['pgScore'] as double?;
            final gradingStatus = extra['gradingStatus'] as String? ?? 'graded';
            return ExamSuccessScreen(
              examTitle: examTitle,
              pgScore: pgScore?.toDouble(),
              gradingStatus: gradingStatus,
            );
          },
        ),
      ],
    );
  }
}

// Shell Scaffolds
class AdminShellScaffold extends StatelessWidget {
  final Widget child;
  const AdminShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBT Admin Portal')),
      drawer: const AppDrawer(),
      body: child,
    );
  }
}

class GuruShellScaffold extends StatelessWidget {
  final Widget child;
  const GuruShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBT Guru Portal')),
      drawer: const AppDrawer(),
      body: child,
    );
  }
}

class SiswaShellScaffold extends StatelessWidget {
  final Widget child;
  const SiswaShellScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/siswa/join')) return 1;
    if (location.startsWith('/siswa/history')) return 2;
    if (location.startsWith('/siswa/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/siswa/dashboard');
        break;
      case 1:
        context.go('/siswa/join');
        break;
      case 2:
        context.go('/siswa/history');
        break;
      case 3:
        context.go('/siswa/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Ikut Ujian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
