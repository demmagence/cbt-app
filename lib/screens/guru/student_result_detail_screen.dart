import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/guru/student_result_detail_cubit.dart';
import '../../models/exam_result_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class StudentResultDetailScreen extends StatelessWidget {
  final String examId;
  final String userId;
  const StudentResultDetailScreen({
    super.key,
    required this.examId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StudentResultDetailCubit>(
      create: (context) => StudentResultDetailCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadDetail(examId, userId),
      child: StudentResultDetailView(examId: examId, userId: userId),
    );
  }
}

class StudentResultDetailView extends StatefulWidget {
  final String examId;
  final String userId;
  const StudentResultDetailView({super.key, required this.examId, required this.userId});

  @override
  State<StudentResultDetailView> createState() => _StudentResultDetailViewState();
}

class _StudentResultDetailViewState extends State<StudentResultDetailView> {
  Future<void> _refresh() async {
    await context.read<StudentResultDetailCubit>().loadDetail(widget.examId, widget.userId);
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return '-';
    final diff = end.difference(start);
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pengerjaan Siswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocBuilder<StudentResultDetailCubit, StudentResultDetailState>(
        builder: (context, state) {
          if (state is StudentResultDetailInitial || state is StudentResultDetailLoading) {
            return const LoadingWidget(message: 'Memuat detail jawaban...');
          }

          if (state is StudentResultDetailError) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: _refresh,
            );
          }

          if (state is StudentResultDetailLoaded) {
            final result = state.result;
            final session = state.session;
            final questions = state.questions;
            final student = state.student;

            final isPendingEssay = result.gradingStatus == 'pending_essay';
            final workingDuration = _formatDuration(session.startedAt, session.endedAt);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Info Card Header
                    _buildStudentProfileHeader(student, result, workingDuration, theme),

                    // Integrity / App Switch Warnings (Inovatif)
                    if (session.appSwitchCount > 0)
                      _buildIntegrityWarningCard(session, theme),

                    // List of Questions & Answers
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Lembar Jawaban',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final question = questions[index];
                        final studentAnswer = session.answers[question.id];
                        final essayGrade = result.essayGrades?[question.id];
                        return _buildQuestionCard(
                          index: index,
                          question: question,
                          studentAnswer: studentAnswer,
                          essayGrade: essayGrade,
                          isPendingEssay: isPendingEssay,
                          theme: theme,
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStudentProfileHeader(
    UserModel student,
    ExamResultModel result,
    String durationText,
    ThemeData theme,
  ) {
    final isPendingEssay = result.gradingStatus == 'pending_essay';

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          student.email,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isPendingEssay 
                          ? Colors.orange.withValues(alpha: 0.15) 
                          : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPendingEssay 
                            ? Colors.orange.withValues(alpha: 0.5) 
                            : Colors.green.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isPendingEssay ? 'Pending' : result.totalScore.toStringAsFixed(0),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPendingEssay ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                        Text(
                          'Total Skor',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isPendingEssay ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeaderStatItem('Skor PG', result.pgScore.toStringAsFixed(0), theme),
                  _buildHeaderStatItem(
                    'Skor Essay', 
                    isPendingEssay ? 'Koreksi' : (result.essayScore?.toStringAsFixed(0) ?? '-'), 
                    theme,
                  ),
                  _buildHeaderStatItem('Durasi Kerja', durationText, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildIntegrityWarningCard(ExamSessionModel session, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: ExpansionTile(
          leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 28),
          title: Text(
            'Peringatan Integritas (${session.appSwitchCount}x Keluar App)',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Siswa terdeteksi meninggalkan aplikasi ujian beberapa kali.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: session.appSwitchLogs.map((log) {
                  final logTime = DateFormat('HH:mm:ss').format(log.timestamp);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pukul: $logTime', style: theme.textTheme.bodySmall),
                        Text('Durasi: ${log.duration} detik', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required int index,
    required QuestionModel question,
    required dynamic studentAnswer,
    required EssayGrade? essayGrade,
    required bool isPendingEssay,
    required ThemeData theme,
  }) {
    final isCorrect = question.isPg && studentAnswer is int && question.correctAnswer == studentAnswer;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: question.isPg 
              ? (isCorrect ? Colors.green.withValues(alpha: 0.5) : theme.colorScheme.error.withValues(alpha: 0.5))
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Header (No, Type, Score Badge)
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: question.isPg 
                      ? (isCorrect ? Colors.green : theme.colorScheme.error) 
                      : theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  child: Text(
                    (index + 1).toString(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  question.isPg ? 'Pilihan Ganda' : 'Essay',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: question.isPg 
                        ? (isCorrect ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.error.withValues(alpha: 0.15))
                        : (essayGrade != null ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    question.isPg 
                        ? (isCorrect ? 'Skor: ${question.points}' : 'Skor: 0')
                        : (essayGrade != null ? 'Skor: ${essayGrade.score}/${question.maxScore}' : 'Belum Dinilai'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: question.isPg 
                          ? (isCorrect ? Colors.green.shade800 : theme.colorScheme.error)
                          : (essayGrade != null ? Colors.green.shade800 : Colors.orange.shade800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Text
            Text(
              question.text,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Answer details
            if (question.isPg && question.options != null) ...[
              Column(
                children: List.generate(question.options!.length, (optIdx) {
                  final isOptionSelectedByStudent = studentAnswer == optIdx;
                  final isOptionCorrect = question.correctAnswer == optIdx;
                  final prefix = String.fromCharCode(65 + optIdx);

                  Color itemColor = theme.colorScheme.onSurface;
                  IconData? icon;
                  if (isOptionCorrect) {
                    itemColor = Colors.green.shade800;
                    icon = Icons.check_circle;
                  } else if (isOptionSelectedByStudent && !isCorrect) {
                    itemColor = theme.colorScheme.error;
                    icon = Icons.cancel;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOptionSelectedByStudent 
                            ? (isCorrect ? Colors.green.withValues(alpha: 0.1) : theme.colorScheme.error.withValues(alpha: 0.1))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon ?? (isOptionSelectedByStudent ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                            size: 16,
                            color: isOptionSelectedByStudent 
                                ? (isCorrect ? Colors.green : theme.colorScheme.error)
                                : (isOptionCorrect ? Colors.green : theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$prefix. ${question.options![optIdx]}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: itemColor,
                                fontWeight: isOptionSelectedByStudent || isOptionCorrect 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ] else if (question.isEssay) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jawaban Siswa:',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      studentAnswer?.toString() ?? 'Siswa tidak menjawab.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (question.essayGuideline != null && question.essayGuideline!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Pedoman Penilaian:',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                ),
                Text(
                  question.essayGuideline!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (essayGrade != null && essayGrade.feedback.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feedback Guru:',
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        essayGrade.feedback,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
