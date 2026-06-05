import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/siswa/exam_list_cubit.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class SiswaDashboardScreen extends StatefulWidget {
  const SiswaDashboardScreen({super.key});

  @override
  State<SiswaDashboardScreen> createState() => _SiswaDashboardScreenState();
}

class _SiswaDashboardScreenState extends State<SiswaDashboardScreen> {
  late final ExamListCubit _examListCubit;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    _examListCubit = ExamListCubit(
      firestoreService: context.read<FirestoreService>(),
    );
    if (authState is AuthAuthenticated) {
      _examListCubit.loadExams(authState.user.uid);
    }
  }

  @override
  void dispose() {
    _examListCubit.close();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: Text('Tidak terautentikasi')),
      );
    }

    final user = authState.user;

    return BlocProvider.value(
      value: _examListCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Siswa'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Keluar',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<AuthBloc>().add(const AuthLogoutRequested());
                        },
                        child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _examListCubit.loadExams(user.uid),
          child: BlocBuilder<ExamListCubit, ExamListState>(
            builder: (context, state) {
              if (state is ExamListLoading) {
                return const LoadingWidget(message: 'Memuat data dashboard...');
              }

              if (state is ExamListError) {
                return AppErrorWidget(
                  errorMessage: state.message,
                  onRetry: () => _examListCubit.loadExams(user.uid),
                );
              }

              if (state is ExamListLoaded) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting Header
                      _buildGreetingCard(user.name, state.availableExams.length, state.historySessions.length),
                      const SizedBox(height: 24),

                      // Available Exams Section
                      _buildSectionTitle('Ujian Tersedia', Icons.assignment_outlined),
                      const SizedBox(height: 12),
                      _buildAvailableExamsList(state),
                      const SizedBox(height: 24),

                      // History Section
                      _buildSectionTitle('Riwayat Ujian', Icons.history_rounded),
                      const SizedBox(height: 12),
                      _buildHistoryList(state),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard(String name, int availableCount, int historyCount) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.school_rounded,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '$availableCount',
                    'Ujian Aktif',
                    theme.colorScheme.primary,
                    theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    '$historyCount',
                    'Selesai',
                    theme.colorScheme.secondary,
                    theme.colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: bgColor,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableExamsList(ExamListLoaded state) {
    if (state.availableExams.isEmpty) {
      return const EmptyStateWidget(
        title: 'Tidak Ada Ujian',
        description: 'Tidak ada ujian aktif yang dijadwalkan untuk Anda saat ini.',
        icon: Icons.assignment_turned_in_outlined,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.availableExams.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final exam = state.availableExams[index];
        final hasActiveSession = state.activeSessions.containsKey(exam.id);
        final theme = Theme.of(context);

        final String statusLabel = hasActiveSession ? 'Sedang Berjalan' : 'Belum Dimulai';
        final Color statusColor = hasActiveSession ? Colors.orange : Colors.blue;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${exam.duration} Menit',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  exam.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (exam.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exam.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tenggat Waktu:',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(exam.endDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasActiveSession ? Colors.orange : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        if (hasActiveSession) {
                          context.push('/siswa/exam/${exam.id}');
                        } else {
                          // Route to join screen/details
                          context.push('/siswa/exam/${exam.id}');
                        }
                      },
                      child: Text(hasActiveSession ? 'Lanjutkan' : 'Mulai'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(ExamListLoaded state) {
    if (state.historySessions.isEmpty) {
      return const EmptyStateWidget(
        title: 'Belum Ada Riwayat',
        description: 'Anda belum menyelesaikan ujian apapun.',
        icon: Icons.history_toggle_off_rounded,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.historySessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = state.historySessions[index];
        final exam = state.examDetails[session.examId];
        final result = state.examResults[session.id];
        final theme = Theme.of(context);

        final title = exam?.title ?? 'Ujian Tidak Diketahui';
        final isAutoSubmitted = session.status == 'auto_submitted';
        final statusLabel = isAutoSubmitted ? 'Selesai Otomatis' : 'Selesai';
        final statusColor = isAutoSubmitted ? Colors.deepOrange : Colors.green;

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(session.endedAt ?? session.startedAt),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (result != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Nilai',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      Text(
                        result.gradingStatus == 'graded' ? '${result.totalScore}' : 'Pending',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: result.gradingStatus == 'graded'
                              ? theme.colorScheme.primary
                              : Colors.orange,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Nilai',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      Text(
                        '-',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
