import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/exam_list_cubit.dart';
import '../../models/exam_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class ExamListScreen extends StatelessWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String guruId = '';
    if (authState is AuthAuthenticated) {
      guruId = authState.user.uid;
    }

    return BlocProvider<ExamListCubit>(
      create: (context) => ExamListCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadExams(guruId),
      child: ExamListView(guruId: guruId),
    );
  }
}

class ExamListView extends StatefulWidget {
  final String guruId;
  const ExamListView({super.key, required this.guruId});

  @override
  State<ExamListView> createState() => _ExamListViewState();
}

class _ExamListViewState extends State<ExamListView> {
  Future<void> _refresh() async {
    await context.read<ExamListCubit>().loadExams(widget.guruId);
  }

  void _confirmDelete(ExamModel exam) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Hapus Ujian?'),
          content: Text(
            'Apakah Anda yakin ingin menghapus ujian "${exam.title}"? \n\nTindakan ini akan menghapus dokumen ujian dan seluruh soal di dalamnya secara permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ExamListCubit>().deleteExam(exam.id, widget.guruId);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  String _getExamStatus(ExamModel exam) {
    if (!exam.isActive) return 'Nonaktif';
    final now = DateTime.now();
    if (now.isBefore(exam.startDate)) return 'Belum Mulai';
    if (now.isAfter(exam.endDate)) return 'Selesai';
    return 'Berlangsung';
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'Berlangsung':
        return Colors.green;
      case 'Belum Mulai':
        return theme.colorScheme.primary;
      case 'Selesai':
        return theme.colorScheme.outline;
      case 'Nonaktif':
      default:
        return theme.colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Ujian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocListener<ExamListCubit, ExamListState>(
        listener: (context, state) {
          if (state is ExamListError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: BlocBuilder<ExamListCubit, ExamListState>(
          builder: (context, state) {
            if (state is ExamListInitial || state is ExamListLoading) {
              return const LoadingWidget(message: 'Memuat daftar ujian...');
            }

            if (state is ExamListError) {
              return AppErrorWidget(
                errorMessage: state.message,
                onRetry: _refresh,
              );
            }

            if (state is ExamListLoaded) {
              final exams = state.exams;

              if (exams.isEmpty) {
                return const EmptyStateWidget(
                  title: 'Belum Ada Ujian',
                  description: 'Anda belum membuat ujian apa pun. Klik tombol + di bawah untuk membuat ujian pertama.',
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: exams.length,
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    final status = _getExamStatus(exam);
                    final statusColor = _getStatusColor(status, theme);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Badge & Code
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
                                  ),
                                  child: Text(
                                    status,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Kode: ${exam.code}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: exam.code));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Kode ujian disalin!')),
                                        );
                                      },
                                      tooltip: 'Salin Kode',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Title & Description
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
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Details (Duration, Questions count, Schedule)
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text('${exam.duration} Menit', style: theme.textTheme.bodySmall),
                                const SizedBox(width: 16),
                                Icon(Icons.quiz_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text('${exam.totalQuestions} Soal', style: theme.textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.event, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${DateFormat('dd MMM, HH:mm').format(exam.startDate)} s/d ${DateFormat('dd MMM yyyy, HH:mm').format(exam.endDate)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Quick Action Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/guru/exams/${exam.id}/questions'),
                                  icon: const Icon(Icons.quiz, size: 16),
                                  label: const Text('Kelola Soal'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/guru/exams/${exam.id}/edit'),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/guru/results/${exam.id}'),
                                  icon: const Icon(Icons.bar_chart, size: 16),
                                  label: const Text('Hasil'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                Switch(
                                  value: exam.isActive,
                                  onChanged: (val) {
                                    context.read<ExamListCubit>().toggleExamStatus(exam.id, val, widget.guruId);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                  onPressed: () => _confirmDelete(exam),
                                  tooltip: 'Hapus Ujian',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/guru/exams/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
