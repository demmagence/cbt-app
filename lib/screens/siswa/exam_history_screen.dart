import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/siswa/exam_history_cubit.dart';
import '../../models/exam_result_model.dart';
import '../../models/exam_session_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  late final ExamHistoryCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ExamHistoryCubit(
      firestoreService: context.read<FirestoreService>(),
    );
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _cubit.loadHistory(authState.user.uid);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Tidak terautentikasi')));
    }

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Ujian'),
        ),
        body: BlocBuilder<ExamHistoryCubit, ExamHistoryState>(
          builder: (context, state) {
            if (state is ExamHistoryLoading) {
              return const LoadingWidget(message: 'Memuat riwayat ujian...');
            }

            if (state is ExamHistoryError) {
              return AppErrorWidget(
                errorMessage: state.message,
                onRetry: () {
                  _cubit.loadHistory(authState.user.uid);
                },
              );
            }

            if (state is ExamHistoryLoaded) {
              if (state.sessions.isEmpty) {
                return const EmptyStateWidget(
                  title: 'Belum Ada Riwayat',
                  description: 'Anda belum menyelesaikan ujian apapun. Ikuti ujian untuk melihat riwayat di sini.',
                  icon: Icons.history_toggle_off_rounded,
                );
              }

              return RefreshIndicator(
                onRefresh: () => _cubit.loadHistory(authState.user.uid),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildSummaryHeader(state),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final session = state.sessions[index];
                            final exam = state.examDetails[session.examId];
                            final result = state.results[session.id];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildHistoryCard(session, exam?.title ?? 'Ujian Tidak Diketahui', result, context),
                            );
                          },
                          childCount: state.sessions.length,
                        ),
                      ),
                    ),
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

  Widget _buildSummaryHeader(ExamHistoryLoaded state) {
    final theme = Theme.of(context);
    final totalExams = state.sessions.length;

    // Calculate average score from graded results
    final gradedResults = state.results.values.where((r) => r.gradingStatus == 'graded').toList();
    double avgScore = 0;
    if (gradedResults.isNotEmpty) {
      final total = gradedResults.fold<num>(0, (sum, r) => sum + r.totalScore);
      avgScore = total / gradedResults.length;
    }

    final highestResult = gradedResults.isEmpty
        ? null
        : gradedResults.reduce((a, b) => a.totalScore > b.totalScore ? a : b);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Ringkasan Prestasi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatBox('$totalExams', 'Ujian Selesai', Icons.check_circle_outline, theme.colorScheme.primary, theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  gradedResults.isEmpty ? '-' : avgScore.toStringAsFixed(1),
                  'Rata-Rata Nilai',
                  Icons.bar_chart_rounded,
                  Colors.blue,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  highestResult == null ? '-' : '${highestResult.totalScore}',
                  'Nilai Tertinggi',
                  Icons.emoji_events_outlined,
                  Colors.amber[700]!,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    ExamSessionModel session,
    String examTitle,
    ExamResultModel? result,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final isAutoSubmitted = session.status == 'auto_submitted';
    final endDate = session.endedAt ?? session.startedAt;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isAutoSubmitted) {
      statusColor = Colors.deepOrange;
      statusLabel = 'Selesai Otomatis';
      statusIcon = Icons.timer_off_rounded;
    } else {
      statusColor = Colors.green;
      statusLabel = 'Selesai';
      statusIcon = Icons.check_circle_rounded;
    }

    // Grading info
    Widget gradeWidget;
    if (result == null) {
      gradeWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Nilai', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text('–', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      );
    } else if (result.gradingStatus == 'graded') {
      final score = result.totalScore;
      Color scoreColor;
      if (score >= 80) {
        scoreColor = Colors.green;
      } else if (score >= 60) {
        scoreColor = Colors.orange;
      } else {
        scoreColor = Colors.red;
      }
      gradeWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Nilai', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(
            '$score',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: scoreColor),
          ),
        ],
      );
    } else {
      gradeWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Nilai', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Pending',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                gradeWidget,
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEE, dd MMM yyyy').format(endDate),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm').format(endDate),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (session.appSwitchCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    '${session.appSwitchCount}x keluar aplikasi terdeteksi',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
