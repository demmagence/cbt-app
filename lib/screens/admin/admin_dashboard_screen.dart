import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../blocs/admin/admin_dashboard_cubit.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../config/theme/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminDashboardCubit>(
      create: (context) => AdminDashboardCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadDashboardData(),
      child: const AdminDashboardView(),
    );
  }
}

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<AdminDashboardCubit>().loadDashboardData(),
        child: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
          builder: (context, state) {
            if (state is AdminDashboardLoading) {
              return const LoadingWidget(message: 'Memuat data dashboard...');
            }

            if (state is AdminDashboardError) {
              return AppErrorWidget(
                errorMessage: state.message,
                onRetry: () => context.read<AdminDashboardCubit>().loadDashboardData(),
              );
            }

            if (state is AdminDashboardLoaded) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildHeader(theme),
                    const SizedBox(height: 24),

                    // Stats Section
                    _buildStatsGrid(context, state),
                    const SizedBox(height: 24),

                    // Quick Actions Section
                    _buildQuickActions(context, theme),
                    const SizedBox(height: 24),

                    // Chart Section
                    _buildChartSection(theme, state),
                    const SizedBox(height: 24),

                    // Recent Activity Section
                    _buildRecentActivity(theme, state),
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

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Utama',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selamat datang kembali di CBT Admin Portal.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, AdminDashboardLoaded state) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.5 : 1.3,
      children: [
        _buildStatCard(
          title: 'Total User',
          value: state.totalUsers.toString(),
          icon: Icons.people_alt_rounded,
          color: Theme.of(context).colorScheme.primaryContainer,
          textColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        _buildStatCard(
          title: 'Total Guru',
          value: state.totalGuru.toString(),
          icon: Icons.school_rounded,
          color: Theme.of(context).colorScheme.secondaryContainer,
          textColor: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        _buildStatCard(
          title: 'Total Siswa',
          value: state.totalSiswa.toString(),
          icon: Icons.face_rounded,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          textColor: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        _buildStatCard(
          title: 'Total Ujian',
          value: state.totalUjian.toString(),
          icon: Icons.assignment_rounded,
          color: AppColors.successContainer,
          textColor: AppColors.onSuccessContainer,
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
    return Card(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: textColor.withValues(alpha: 0.8), size: 28),
                const SizedBox.shrink(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildActionCard(
                  theme: theme,
                  title: 'Tambah User',
                  subtitle: 'Buat akun baru',
                  icon: Icons.person_add_alt_1_rounded,
                  color: theme.colorScheme.primary,
                  onTap: () => context.push('/admin/users/create'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  theme: theme,
                  title: 'Semua User',
                  subtitle: 'Kelola data user',
                  icon: Icons.manage_accounts_rounded,
                  color: theme.colorScheme.secondary,
                  onTap: () => context.go('/admin/users'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          theme: theme,
          title: 'Statistik Analitis',
          subtitle: 'Lihat data analitis & performa ujian',
          icon: Icons.analytics_rounded,
          color: theme.colorScheme.tertiary,
          onTap: () => context.push('/admin/statistics'),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        color: theme.colorScheme.surface,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, AdminDashboardLoaded state) {
    final months = state.examsPerMonth.keys.toList();
    final counts = state.examsPerMonth.values.toList();

    // Determine the max Y for the chart, adding some padding
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
              'Aktivitas Ujian (6 Bulan Terakhir)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tren penyelesaian ujian oleh siswa per bulan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: state.examsPerMonth.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada data aktivitas',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => theme.colorScheme.primaryContainer,
                            tooltipBorder: BorderSide(color: theme.colorScheme.primary, width: 1),
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  final fullLabel = months[index];
                                  final parts = fullLabel.split(' ');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      parts[0], // Only display the month abbreviation (e.g. "Jun")
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
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
                                if (value % 1 != 0) return const SizedBox.shrink(); // Integers only
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
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.surfaceVariant,
                            strokeWidth: 1,
                          ),
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

  Widget _buildRecentActivity(ThemeData theme, AdminDashboardLoaded state) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivitas Terbaru',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            state.recentActivities.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'Belum ada aktivitas terekam.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.recentActivities.length > 8 ? 8 : state.recentActivities.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 16,
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                    itemBuilder: (context, index) {
                      final item = state.recentActivities[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _getActivityColor(item.type, theme).withValues(alpha: 0.1),
                            child: Icon(
                              _getActivityIcon(item.type),
                              color: _getActivityColor(item.type, theme),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimeAgo(item.timestamp),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
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

  IconData _getActivityIcon(AdminActivityType type) {
    switch (type) {
      case AdminActivityType.newUser:
        return Icons.person_add_rounded;
      case AdminActivityType.examCreated:
        return Icons.assignment_rounded;
      case AdminActivityType.examSubmitted:
        return Icons.assignment_turned_in_rounded;
    }
  }

  Color _getActivityColor(AdminActivityType type, ThemeData theme) {
    switch (type) {
      case AdminActivityType.newUser:
        return theme.colorScheme.primary;
      case AdminActivityType.examCreated:
        return theme.colorScheme.tertiary;
      case AdminActivityType.examSubmitted:
        return AppColors.success;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    }
  }
}
