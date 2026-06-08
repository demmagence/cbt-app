import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/guru/exam_results_cubit.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/csv_export_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class ExamResultsScreen extends StatelessWidget {
  final String examId;
  const ExamResultsScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExamResultsCubit>(
      create: (context) => ExamResultsCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadExamResults(examId),
      child: ExamResultsView(examId: examId),
    );
  }
}

class ExamResultsView extends StatefulWidget {
  final String examId;
  const ExamResultsView({super.key, required this.examId});

  @override
  State<ExamResultsView> createState() => _ExamResultsViewState();
}

class _ExamResultsViewState extends State<ExamResultsView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | graded | pending_essay

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<ExamResultsCubit>().loadExamResults(widget.examId);
  }

  double _calculateAverageScore(List<ExamResultModel> results) {
    if (results.isEmpty) return 0.0;
    final total = results.fold<double>(0.0, (sum, item) => sum + item.totalScore.toDouble());
    return total / results.length;
  }

  void _exportToCsv(
    ExamModel exam,
    List<ExamResultModel> results,
    Map<String, UserModel> studentMap,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menyiapkan berkas ekspor CSV...')),
      );
      await CsvExportService().exportAndShareResults(
        exam: exam,
        results: results,
        studentMap: studentMap,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor data: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Ujian'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/guru/dashboard');
            }
          },
        ),
        actions: [
          BlocBuilder<ExamResultsCubit, ExamResultsState>(
            builder: (context, state) {
              if (state is ExamResultsLoaded && state.results.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Ekspor ke CSV',
                  onPressed: () => _exportToCsv(state.exam, state.results, state.studentMap),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocBuilder<ExamResultsCubit, ExamResultsState>(
        builder: (context, state) {
          if (state is ExamResultsInitial || state is ExamResultsLoading) {
            return const LoadingWidget(message: 'Memuat hasil ujian...');
          }

          if (state is ExamResultsError) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: _refresh,
            );
          }

          if (state is ExamResultsLoaded) {
            final exam = state.exam;
            final studentMap = state.studentMap;
            var filteredResults = state.results;

            // Apply Search Query
            if (_searchQuery.isNotEmpty) {
              filteredResults = filteredResults.where((r) {
                final student = studentMap[r.userId];
                final name = student?.name.toLowerCase() ?? '';
                final email = student?.email.toLowerCase() ?? '';
                return name.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();
            }

            // Apply Status Filter
            if (_statusFilter != 'all') {
              filteredResults = filteredResults.where((r) => r.gradingStatus == _statusFilter).toList();
            }

            final averageScore = _calculateAverageScore(state.results);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: Column(
                children: [
                  // Exam Details & Stats Header Card
                  _buildStatsHeader(exam, state.results.length, averageScore, theme),

                  // Search & Filter Panel
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Cari Siswa',
                            hintText: 'Cari berdasarkan nama atau email...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Filter Status: ',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Semua'),
                                      selected: _statusFilter == 'all',
                                      onSelected: (selected) {
                                        if (selected) setState(() => _statusFilter = 'all');
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: const Text('Selesai Dinilai'),
                                      selected: _statusFilter == 'graded',
                                      onSelected: (selected) {
                                        if (selected) setState(() => _statusFilter = 'graded');
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: const Text('Koreksi Essay'),
                                      selected: _statusFilter == 'pending_essay',
                                      onSelected: (selected) {
                                        if (selected) setState(() => _statusFilter = 'pending_essay');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Results List
                  Expanded(
                    child: filteredResults.isEmpty
                        ? const EmptyStateWidget(
                            title: 'Tidak Ada Hasil',
                            description: 'Tidak ada data pengerjaan siswa yang sesuai dengan filter pencarian.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: filteredResults.length,
                            itemBuilder: (context, index) {
                              final result = filteredResults[index];
                              final student = studentMap[result.userId];
                              return _buildResultCard(result, student, theme);
                            },
                          ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatsHeader(ExamModel exam, int totalParticipants, double avgScore, ThemeData theme) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Kode Ujian: ${exam.code}  |  Durasi: ${exam.duration} mnt',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Stat 1: Participants
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Text(
                        totalParticipants.toString(),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Peserta',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Stat 2: Average Score
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Text(
                        avgScore.toStringAsFixed(1),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rata-rata Nilai',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ExamResultModel result, UserModel? student, ThemeData theme) {
    final name = student?.name ?? 'Siswa Tidak Dikenal';
    final email = student?.email ?? 'Tidak ada email';
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(result.submittedAt);
    final isPendingEssay = result.gradingStatus == 'pending_essay';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info & Score Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPendingEssay 
                        ? Colors.orange.withValues(alpha: 0.15) 
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPendingEssay 
                          ? Colors.orange.withValues(alpha: 0.5) 
                          : Colors.green.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isPendingEssay ? '---' : result.totalScore.toStringAsFixed(0),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPendingEssay ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'Skor',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: isPendingEssay ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Submission Time & Scores Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dikumpulkan pada:',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildScorePart('PG', result.pgScore, theme),
                    const SizedBox(width: 16),
                    _buildScorePart(
                      'Essay', 
                      isPendingEssay ? null : (result.essayScore ?? 0), 
                      theme, 
                      isPending: isPendingEssay,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/guru/results/${widget.examId}/${result.userId}'),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Detail Jawaban'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ),
                if (isPendingEssay) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/guru/grading/${widget.examId}/${result.userId}'),
                      icon: const Icon(Icons.rate_review, size: 16),
                      label: const Text('Koreksi Essay'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScorePart(String label, num? score, ThemeData theme, {bool isPending = false}) {
    String scoreText = score?.toStringAsFixed(0) ?? '---';
    if (isPending) {
      scoreText = 'Koreksi';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          scoreText,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isPending ? Colors.orange.shade800 : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
