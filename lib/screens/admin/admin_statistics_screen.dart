import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../blocs/admin/admin_statistics_cubit.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../config/theme/app_colors.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminStatisticsCubit>(
      create: (context) => AdminStatisticsCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadStatistics(),
      child: const AdminStatisticsView(),
    );
  }
}

class AdminStatisticsView extends StatefulWidget {
  const AdminStatisticsView({super.key});

  @override
  State<AdminStatisticsView> createState() => _AdminStatisticsViewState();
}

class _AdminStatisticsViewState extends State<AdminStatisticsView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Analitis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AdminStatisticsCubit>().loadStatistics(),
        child: BlocBuilder<AdminStatisticsCubit, AdminStatisticsState>(
          builder: (context, state) {
            if (state is AdminStatisticsLoading) {
              return const LoadingWidget(message: 'Memuat data statistik...');
            }

            if (state is AdminStatisticsError) {
              return AppErrorWidget(
                errorMessage: state.message,
                onRetry: () =>
                    context.read<AdminStatisticsCubit>().loadStatistics(),
              );
            }

            if (state is AdminStatisticsLoaded) {
              if (state.totalExamsCount == 0) {
                return const EmptyStateWidget(
                  title: 'Data Statistik Belum Ada',
                  description:
                      'Ujian belum dibuat oleh guru atau belum diselesaikan oleh siswa.',
                  icon: Icons.analytics_outlined,
                );
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Header Cards
                    _buildKPIIndicators(context, state),
                    const SizedBox(height: 24),

                    // Exam Activity Chart (Bar Chart)
                    _buildBarChartSection(theme, state),
                    const SizedBox(height: 24),

                    // Active Students Chart (Line Chart)
                    _buildLineChartSection(theme, state),
                    const SizedBox(height: 24),

                    // Exam Status Distribution (Progress Bars)
                    _buildDistributionSection(theme, state),
                    const SizedBox(height: 24),

                    // Top 5 Guru Ranking
                    _buildGuruRankingSection(theme, state),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            }

            return const Center(child: Text('Inisialisasi...'));
          },
        ),
      ),
    );
  }

  Widget _buildKPIIndicators(
    BuildContext context,
    AdminStatisticsLoaded state,
  ) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isWideScreen ? 1.8 : 0.95,
      children: [
        _buildKPICard(
          context: context,
          title: 'Rata-rata Nilai',
          value: state.averageScore.toStringAsFixed(1),
          icon: Icons.insights_rounded,
          color: Theme.of(context).colorScheme.primaryContainer,
          textColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        _buildKPICard(
          context: context,
          title: 'Total Ujian',
          value: state.totalExamsCount.toString(),
          icon: Icons.assignment_rounded,
          color: Theme.of(context).colorScheme.secondaryContainer,
          textColor: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        _buildKPICard(
          context: context,
          title: 'Ujian Aktif',
          value: state.activeExamsCount.toString(),
          icon: Icons.play_circle_fill_rounded,
          color: AppColors.successContainer,
          textColor: AppColors.onSuccessContainer,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
  }) {
    final isCompact = MediaQuery.of(context).size.width < 360;

    return Card(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  style: TextStyle(
                    fontSize: isCompact ? 22 : 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.8),
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

  Widget _buildBarChartSection(ThemeData theme, AdminStatisticsLoaded state) {
    final months = state.examsPerMonth.keys.toList();
    final counts = state.examsPerMonth.values.toList();

    double maxY = 5.0;
    for (final count in counts) {
      if (count > maxY) {
        maxY = count.toDouble() + 2.0;
      }
    }

    final barGroups = List.generate(months.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: counts[index].toDouble(),
            color: theme.colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: AppColors.surfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      );
    });

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivitas Penyelesaian Ujian (Bulanan)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Grafik jumlah lembar jawaban ujian siswa yang diselesaikan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          theme.colorScheme.primaryContainer,
                      tooltipBorder: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1,
                      ),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} Ujian',
                          TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < months.length) {
                            final parts = months[index].split(' ');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                parts[0],
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: AppColors.surfaceVariant, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartSection(ThemeData theme, AdminStatisticsLoaded state) {
    final months = state.activeStudentsPerMonth.keys.toList();
    final counts = state.activeStudentsPerMonth.values.toList();

    double maxY = 5.0;
    for (final count in counts) {
      if (count > maxY) {
        maxY = count.toDouble() + 2.0;
      }
    }

    final spots = List.generate(months.length, (index) {
      return FlSpot(index.toDouble(), counts[index].toDouble());
    });

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Partisipasi Siswa Aktif (Bulanan)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Grafik jumlah siswa unik yang aktif mengerjakan ujian.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: AppColors.surfaceVariant, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < months.length) {
                            final parts = months[index].split(' ');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                parts[0],
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) =>
                          theme.colorScheme.primaryContainer,
                      tooltipBorder: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1,
                      ),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} Siswa',
                            TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3.5,
                      color: theme.colorScheme.primary,
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: theme.colorScheme.primary,
                              strokeWidth: 2,
                              strokeColor: theme.colorScheme.surface,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionSection(
    ThemeData theme,
    AdminStatisticsLoaded state,
  ) {
    final activePct = state.totalExamsCount == 0
        ? 0.0
        : state.activeExamsCount / state.totalExamsCount;
    final scheduledPct = state.totalExamsCount == 0
        ? 0.0
        : state.scheduledExamsCount / state.totalExamsCount;
    final endedPct = state.totalExamsCount == 0
        ? 0.0
        : state.endedExamsCount / state.totalExamsCount;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribusi Status Ujian',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusIndicator(
              label: 'Ujian Aktif (Berlangsung)',
              count: state.activeExamsCount,
              percentage: activePct,
              color: AppColors.success,
              theme: theme,
            ),
            const Divider(height: 24),
            _buildStatusIndicator(
              label: 'Ujian Terjadwal (Belum Mulai)',
              count: state.scheduledExamsCount,
              percentage: scheduledPct,
              color: theme.colorScheme.primary,
              theme: theme,
            ),
            const Divider(height: 24),
            _buildStatusIndicator(
              label: 'Ujian Berakhir / Nonaktif',
              count: state.endedExamsCount,
              percentage: endedPct,
              color: theme.colorScheme.outline,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required String label,
    required int count,
    required double percentage,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              '$count (${(percentage * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            color: color,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGuruRankingSection(
    ThemeData theme,
    AdminStatisticsLoaded state,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Guru Paling Aktif',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Peringkat guru berdasarkan jumlah pembuatan ujian.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            state.topGurus.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Text(
                        'Belum ada pembuatan ujian.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.topGurus.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = state.topGurus[index];
                      final rank = index + 1;
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _getRankColor(rank, theme),
                            child: Text(
                              rank.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${item.count} Ujian',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank, ThemeData theme) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return theme.colorScheme.secondary.withValues(alpha: 0.5);
    }
  }
}
