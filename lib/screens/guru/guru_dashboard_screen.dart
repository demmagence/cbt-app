import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/guru_dashboard_cubit.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../models/exam_model.dart';
import '../../config/theme/app_colors.dart';

class GuruDashboardScreen extends StatelessWidget {
  const GuruDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String guruId = '';
    if (authState is AuthAuthenticated) {
      guruId = authState.user.uid;
    }

    return BlocProvider<GuruDashboardCubit>(
      create: (context) =>
          GuruDashboardCubit(firestoreService: context.read<FirestoreService>())
            ..loadDashboardData(guruId),
      child: const GuruDashboardView(),
    );
  }
}

class GuruDashboardView extends StatefulWidget {
  const GuruDashboardView({super.key});

  @override
  State<GuruDashboardView> createState() => _GuruDashboardViewState();
}

class _GuruDashboardViewState extends State<GuruDashboardView> {
  Future<void> _refreshData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      await context.read<GuruDashboardCubit>().loadDashboardData(
        authState.user.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.read<AuthBloc>().state;
    String guruName = 'Guru';
    if (authState is AuthAuthenticated) {
      guruName = authState.user.name;
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: BlocBuilder<GuruDashboardCubit, GuruDashboardState>(
          builder: (context, state) {
            if (state is GuruDashboardInitial ||
                state is GuruDashboardLoading) {
              return const LoadingWidget(message: 'Memuat data dashboard...');
            }

            if (state is GuruDashboardError) {
              return AppErrorWidget(
                errorMessage: state.message,
                onRetry: _refreshData,
              );
            }

            if (state is GuruDashboardLoaded) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting Header
                    _buildGreetingHeader(guruName, theme),
                    const SizedBox(height: 24),

                    // Quick Stats Grid
                    _buildStatsGrid(state, theme),
                    const SizedBox(height: 28),

                    // Quick Actions
                    _buildQuickActions(context, theme),
                    const SizedBox(height: 28),

                    // Recent Exams Section Header
                    Text(
                      'Ujian Terbaru',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Recent Exams List
                    if (state.recentExams.isEmpty)
                      const EmptyStateWidget(
                        title: 'Belum Ada Ujian',
                        description:
                            'Silakan buat ujian baru atau import dari bank soal.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.recentExams.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final exam = state.recentExams[index];
                          return _buildExamCard(exam, theme, context);
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(String name, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, $name!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selamat datang kembali di CBT Guru Portal.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(GuruDashboardLoaded state, ThemeData theme) {
    final isCompact = MediaQuery.of(context).size.width < 360;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isCompact ? 1.2 : 1.4,
      children: [
        _buildStatCard(
          title: 'Total Ujian',
          value: state.totalExams.toString(),
          icon: Icons.assignment_outlined,
          color: theme.colorScheme.primaryContainer,
          textColor: theme.colorScheme.onPrimaryContainer,
        ),
        _buildStatCard(
          title: 'Ujian Aktif',
          value: state.activeExamsCount.toString(),
          icon: Icons.play_circle_outline,
          color: AppColors.successContainer,
          textColor: AppColors.onSuccessContainer,
        ),
        _buildStatCard(
          title: 'Siswa Berpartisipasi',
          value: state.totalStudentsCount.toString(),
          icon: Icons.people_outline,
          color: theme.colorScheme.tertiaryContainer,
          textColor: theme.colorScheme.onTertiaryContainer,
        ),
        _buildStatCard(
          title: 'Perlu Dinilai',
          value: state.pendingGradingCount.toString(),
          icon: Icons.pending_actions_outlined,
          color: state.pendingGradingCount > 0
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.secondaryContainer,
          textColor: state.pendingGradingCount > 0
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
                const SizedBox.shrink(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                label: 'Daftar Ujian',
                icon: Icons.assignment_outlined,
                color: theme.colorScheme.primary,
                onTap: () => context.push('/guru/exams'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context: context,
                label: 'Buat Ujian',
                icon: Icons.add_box_outlined,
                color: theme.colorScheme.primary,
                onTap: () => context.push('/guru/exams/create'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context: context,
                label: 'Bank Soal',
                icon: Icons.book_outlined,
                color: theme.colorScheme.secondary,
                onTap: () => context.push('/guru/question-bank'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                label: 'Penilaian Essay',
                icon: Icons.grade_outlined,
                color: theme.colorScheme.tertiary,
                onTap: () => context.push('/guru/grading'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context: context,
                label: 'Monitoring Sesi',
                icon: Icons.live_tv_outlined,
                color: Colors.orange,
                onTap: () => context.push('/guru/monitoring'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam, ThemeData theme, BuildContext context) {
    final now = DateTime.now();
    Color statusColor;
    String statusText;

    if (!exam.isActive) {
      statusColor = theme.colorScheme.error;
      statusText = 'Berakhir';
    } else if (now.isBefore(exam.startDate)) {
      statusColor = theme.colorScheme.primary;
      statusText = 'Terjadwal';
    } else if (now.isAfter(exam.endDate)) {
      statusColor = theme.colorScheme.error;
      statusText = 'Berakhir';
    } else {
      statusColor = AppColors.success;
      statusText = 'Aktif';
    }

    final formattedStartDate = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(exam.startDate);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.push('/guru/exams/${exam.id}/edit'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      exam.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Code and Info
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Kode: ${exam.code}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: exam.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode ujian disalin ke clipboard!'),
                        ),
                      );
                    },
                    tooltip: 'Salin Kode',
                  ),
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.duration} mnt',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.help_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.totalQuestions} soal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Row 3: Schedule Date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mulai: $formattedStartDate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
