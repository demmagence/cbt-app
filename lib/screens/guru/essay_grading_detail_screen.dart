import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/essay_grading_detail_cubit.dart';
import '../../models/exam_result_model.dart';
import '../../models/question_model.dart';
import '../../models/exam_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class EssayGradingDetailScreen extends StatelessWidget {
  final String examId;
  final String userId;
  const EssayGradingDetailScreen({
    super.key,
    required this.examId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EssayGradingDetailCubit>(
      create: (context) => EssayGradingDetailCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadDetail(examId, userId),
      child: EssayGradingDetailView(examId: examId, userId: userId),
    );
  }
}

class EssayGradingDetailView extends StatefulWidget {
  final String examId;
  final String userId;
  const EssayGradingDetailView({super.key, required this.examId, required this.userId});

  @override
  State<EssayGradingDetailView> createState() => _EssayGradingDetailViewState();
}

class _EssayGradingDetailViewState extends State<EssayGradingDetailView> {
  final _formKey = GlobalKey<FormState>();

  // Maps to store controllers dynamically: key: questionId
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _feedbackControllers = {};
  bool _isDataLoaded = false;

  @override
  void dispose() {
    for (var controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (var controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitGrading(ExamResultModel result, List<QuestionModel> questions) {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthBloc>().state;
      String guruId = '';
      if (authState is AuthAuthenticated) {
        guruId = authState.user.uid;
      }

      final Map<String, EssayGrade> grades = {};

      for (final q in questions) {
        final scoreText = _scoreControllers[q.id]?.text.trim() ?? '0';
        final feedbackText = _feedbackControllers[q.id]?.text.trim() ?? '';
        final score = num.tryParse(scoreText) ?? 0;

        grades[q.id] = EssayGrade(
          score: score,
          feedback: feedbackText,
        );
      }

      context.read<EssayGradingDetailCubit>().submitGrades(
            resultId: result.id,
            pgScore: result.pgScore,
            grades: grades,
            guruId: guruId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Koreksi Lembar Essay'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/guru/grading');
            }
          },
        ),
      ),
      body: BlocConsumer<EssayGradingDetailCubit, EssayGradingDetailState>(
        listener: (context, state) {
          if (state is EssayGradingDetailSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Penilaian essay berhasil disimpan!')),
            );
            Navigator.pop(context, true); // Return true to request parent refresh
          } else if (state is EssayGradingDetailError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is EssayGradingDetailLoaded && !_isDataLoaded) {
            // Initialize controllers with current grades if available
            final result = state.result;
            for (final q in state.essayQuestions) {
              final existingGrade = result.essayGrades?[q.id];
              _scoreControllers[q.id] = TextEditingController(
                text: existingGrade != null ? existingGrade.score.toString() : '',
              );
              _feedbackControllers[q.id] = TextEditingController(
                text: existingGrade != null ? existingGrade.feedback : '',
              );
            }
            _isDataLoaded = true;
          }
        },
        builder: (context, state) {
          if (state is EssayGradingDetailInitial || (state is EssayGradingDetailLoading && !_isDataLoaded)) {
            return const LoadingWidget(message: 'Memuat lembar pengerjaan esai...');
          }

          if (state is EssayGradingDetailError && !_isDataLoaded) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: () => context.read<EssayGradingDetailCubit>().loadDetail(widget.examId, widget.userId),
            );
          }

          if (state is EssayGradingDetailLoaded) {
            final exam = state.exam;
            final result = state.result;
            final session = state.session;
            final essayQuestions = state.essayQuestions;
            final student = state.student;

            if (essayQuestions.isEmpty) {
              return const EmptyStateWidget(
                title: 'Tidak Ada Soal Essay',
                description: 'Ujian ini tidak memiliki tipe soal essay untuk dinilai.',
              );
            }

            return Stack(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Header Info Card
                      _buildHeaderSummary(student, exam, result, theme),

                      // Questions Input Form List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: essayQuestions.length,
                          itemBuilder: (context, index) {
                            final question = essayQuestions[index];
                            final answer = session.answers[question.id] ?? 'Siswa tidak menjawab.';
                            return _buildGradingFormCard(index, question, answer, theme);
                          },
                        ),
                      ),

                      // Save Button Section
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => _submitGrading(result, essayQuestions),
                            icon: const Icon(Icons.check),
                            label: const Text(
                              'Simpan Penilaian',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state is EssayGradingDetailLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black26,
                      child: LoadingWidget(message: 'Menyimpan penilaian...'),
                    ),
                  ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHeaderSummary(UserModel student, ExamModel exam, ExamResultModel result, ThemeData theme) {
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
            'Siswa: ${student.name} (${student.email})',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Skor Pilihan Ganda (PG) Saat Ini: ${result.pgScore.toStringAsFixed(0)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingFormCard(int index, QuestionModel question, dynamic answer, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
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
            // Question Header
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text(
                    (index + 1).toString(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Essay • Skor Maksimal: ${question.maxScore}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 16),

            // Student's Answer
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
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answer?.toString() ?? 'Siswa tidak menjawab.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Grading Guideline
            if (question.essayGuideline != null && question.essayGuideline!.isNotEmpty) ...[
              Text(
                'Pedoman Penilaian:',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                question.essayGuideline!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ],

            const Divider(),
            const SizedBox(height: 12),

            // Input Score
            TextFormField(
              controller: _scoreControllers[question.id],
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Allows float scores
              ],
              decoration: InputDecoration(
                labelText: 'Masukkan Skor Siswa',
                hintText: 'Nilai dari 0 s/d ${question.maxScore}',
                prefixIcon: const Icon(Icons.star),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Skor wajib diisi';
                }
                final score = double.tryParse(value);
                if (score == null) {
                  return 'Skor harus berupa angka';
                }
                if (score < 0 || score > question.maxScore) {
                  return 'Skor harus di antara 0 s/d ${question.maxScore}';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Input Feedback
            TextFormField(
              controller: _feedbackControllers[question.id],
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Feedback / Catatan (Opsional)',
                hintText: 'Berikan saran atau catatan koreksi...',
                prefixIcon: const Icon(Icons.chat_bubble_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
