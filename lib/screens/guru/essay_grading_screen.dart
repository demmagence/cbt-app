import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/essay_grading_list_cubit.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class EssayGradingScreen extends StatelessWidget {
  const EssayGradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String guruId = '';
    if (authState is AuthAuthenticated) {
      guruId = authState.user.uid;
    }

    return BlocProvider<EssayGradingListCubit>(
      create: (context) => EssayGradingListCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadPendingEssayResults(guruId),
      child: EssayGradingListView(guruId: guruId),
    );
  }
}

class EssayGradingListView extends StatefulWidget {
  final String guruId;
  const EssayGradingListView({super.key, required this.guruId});

  @override
  State<EssayGradingListView> createState() => _EssayGradingListViewState();
}

class _EssayGradingListViewState extends State<EssayGradingListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<EssayGradingListCubit>().loadPendingEssayResults(widget.guruId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Koreksi Essay'),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocBuilder<EssayGradingListCubit, EssayGradingListState>(
        builder: (context, state) {
          if (state is EssayGradingListInitial || state is EssayGradingListLoading) {
            return const LoadingWidget(message: 'Memuat daftar koreksi...');
          }

          if (state is EssayGradingListError) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: _refresh,
            );
          }

          if (state is EssayGradingListLoaded) {
            final examMap = state.examMap;
            final studentMap = state.studentMap;
            var filteredResults = state.pendingResults;

            // Apply Search Query (Student Name or Exam Title)
            if (_searchQuery.isNotEmpty) {
              filteredResults = filteredResults.where((r) {
                final student = studentMap[r.userId];
                final exam = examMap[r.examId];
                final studentName = student?.name.toLowerCase() ?? '';
                final examTitle = exam?.title.toLowerCase() ?? '';
                return studentName.contains(_searchQuery) || examTitle.contains(_searchQuery);
              }).toList();
            }

            if (state.pendingResults.isEmpty) {
              return const EmptyStateWidget(
                title: 'Tidak Ada Koreksi',
                description: 'Seluruh pengerjaan essay siswa telah dinilai atau belum ada siswa yang mengumpulkan ujian essay.',
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Cari Siswa atau Ujian',
                        hintText: 'Cari nama siswa atau judul ujian...',
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
                  ),

                  // Results List
                  Expanded(
                    child: filteredResults.isEmpty
                        ? const EmptyStateWidget(
                            title: 'Tidak Ada Hasil Pencarian',
                            description: 'Tidak ada data koreksi pending yang cocok dengan kata kunci pencarian Anda.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: filteredResults.length,
                            itemBuilder: (context, index) {
                              final result = filteredResults[index];
                              final student = studentMap[result.userId];
                              final exam = examMap[result.examId];
                              return _buildPendingGradingCard(result, student, exam, theme);
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

  Widget _buildPendingGradingCard(
    ExamResultModel result,
    UserModel? student,
    ExamModel? exam,
    ThemeData theme,
  ) {
    final studentName = student?.name ?? 'Siswa Tidak Dikenal';
    final studentEmail = student?.email ?? 'Tidak ada email';
    final examTitle = exam?.title ?? 'Ujian Tidak Diketahui';
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(result.submittedAt);

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
            // Row 1: Exam Title & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    examTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Koreksi Essay',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Student Info
            Text(
              studentName,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              studentEmail,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Row 3: Submission Info & Action
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
                ElevatedButton.icon(
                  onPressed: () async {
                    // Navigate to grading detail page and refresh on return
                    final refreshNeeded = await context.push<bool>(
                      '/guru/grading/${result.examId}/${result.userId}',
                    );
                    if (refreshNeeded == true && mounted) {
                      _refresh();
                    }
                  },
                  icon: const Icon(Icons.rate_review, size: 16),
                  label: const Text('Mulai Koreksi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
