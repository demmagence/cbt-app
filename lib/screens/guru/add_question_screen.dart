import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/guru/add_question_cubit.dart';
import '../../blocs/guru/question_bank_cubit.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../services/firestore_service.dart';
import '../../models/question_model.dart';
import '../../models/exam_model.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class AddQuestionScreen extends StatelessWidget {
  final String examId;
  const AddQuestionScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AddQuestionCubit>(
      create: (context) => AddQuestionCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadQuestions(examId),
      child: AddQuestionView(examId: examId),
    );
  }
}

class AddQuestionView extends StatefulWidget {
  final String examId;
  const AddQuestionView({super.key, required this.examId});

  @override
  State<AddQuestionView> createState() => _AddQuestionViewState();
}

class _AddQuestionViewState extends State<AddQuestionView> {
  Future<void> _refresh() async {
    await context.read<AddQuestionCubit>().loadQuestions(widget.examId);
  }

  void _openQuestionForm({QuestionModel? question, required int nextOrder}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return BlocProvider.value(
          value: this.context.read<AddQuestionCubit>(),
          child: QuestionFormDialog(
            examId: widget.examId,
            question: question,
            nextOrder: nextOrder,
          ),
        );
      },
    );
  }

  void _confirmDelete(String questionId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Hapus Soal?'),
          content: const Text('Apakah Anda yakin ingin menghapus soal ini? Jumlah soal ujian akan diperbarui secara otomatis.'),
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
                context.read<AddQuestionCubit>().deleteQuestion(widget.examId, questionId);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _openImportDialog() async {
    final authState = context.read<AuthBloc>().state;
    String guruId = '';
    if (authState is AuthAuthenticated) {
      guruId = authState.user.uid;
    }

    final selected = await showModalBottomSheet<List<QuestionModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return ImportQuestionsDialog(guruId: guruId);
      },
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      context.read<AddQuestionCubit>().importQuestions(widget.examId, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Soal Ujian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_add),
            tooltip: 'Import dari Bank Soal',
            onPressed: _openImportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocBuilder<AddQuestionCubit, AddQuestionState>(
        builder: (context, state) {
          if (state is AddQuestionInitial || state is AddQuestionLoading) {
            return const LoadingWidget(message: 'Memuat daftar soal...');
          }

          if (state is AddQuestionError) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: _refresh,
            );
          }

          if (state is AddQuestionLoaded) {
            final exam = state.exam;
            final questions = state.questions;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exam Info Summary Card
                _buildExamSummaryHeader(exam, theme),

                // Helper drag indicator if list is not empty
                if (questions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Tekan lama dan seret soal untuk mengurutkan kembali.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: questions.isEmpty
                      ? const EmptyStateWidget(
                          title: 'Belum Ada Soal',
                          description: 'Tambahkan soal pilihan ganda atau essay pertama Anda menggunakan tombol di bawah.',
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: questions.length,
                          itemBuilder: (context, index) {
                            final question = questions[index];
                            return _buildQuestionCard(
                              key: ValueKey(question.id),
                              question: question,
                              index: index,
                              theme: theme,
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            if (oldIndex == newIndex) return;

                            final reordered = List<QuestionModel>.from(questions);
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);

                            context.read<AddQuestionCubit>().reorderQuestions(widget.examId, reordered);
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: BlocBuilder<AddQuestionCubit, AddQuestionState>(
        builder: (context, state) {
          if (state is AddQuestionLoaded) {
            return FloatingActionButton.extended(
              onPressed: () => _openQuestionForm(nextOrder: state.questions.length),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Soal'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildExamSummaryHeader(ExamModel exam, ThemeData theme) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Kode: ${exam.code}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${exam.duration} mnt',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              Icon(Icons.format_list_numbered, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${exam.totalQuestions} soal terdaftar',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required Key key,
    required QuestionModel question,
    required int index,
    required ThemeData theme,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
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
            // Row 1: Question Number & Actions
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text(
                    (index + 1).toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: question.isPg 
                        ? theme.colorScheme.secondaryContainer 
                        : theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    question.isPg ? 'Pilihan Ganda' : 'Essay',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: question.isPg 
                          ? theme.colorScheme.onSecondaryContainer 
                          : theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _openQuestionForm(question: question, nextOrder: index),
                  tooltip: 'Edit Soal',
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(question.id),
                  tooltip: 'Hapus Soal',
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Question Text
            Text(
              question.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Row 3: Option List (if PG) or Scoring Guideline (if Essay)
            if (question.isPg && question.options != null) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: question.options!.length,
                itemBuilder: (context, optIndex) {
                  final isCorrect = question.correctAnswer == optIndex;
                  final prefix = String.fromCharCode(65 + optIndex); // A, B, C, ...
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: isCorrect ? Colors.green : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$prefix. ${question.options![optIndex]}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isCorrect ? Colors.green.shade800 : theme.colorScheme.onSurface,
                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Bobot Poin: ${question.points}',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ] else if (question.isEssay) ...[
              if (question.essayGuideline != null && question.essayGuideline!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedoman Penilaian:',
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.essayGuideline!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Skor Maksimal: ${question.maxScore}',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QuestionFormDialog extends StatefulWidget {
  final String examId;
  final QuestionModel? question;
  final int nextOrder;

  const QuestionFormDialog({
    super.key,
    required this.examId,
    this.question,
    required this.nextOrder,
  });

  @override
  State<QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<QuestionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _pointsController = TextEditingController(text: '1');
  final _maxScoreController = TextEditingController(text: '10');
  final _guidelineController = TextEditingController();

  String _type = 'pg'; // pg or essay
  List<TextEditingController> _optionControllers = [];
  int? _correctAnswerIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      final q = widget.question!;
      _type = q.type;
      _textController.text = q.text;
      _pointsController.text = q.points.toString();
      _maxScoreController.text = q.maxScore.toString();
      _guidelineController.text = q.essayGuideline ?? '';
      
      if (q.isPg && q.options != null) {
        _optionControllers = q.options!.map((opt) => TextEditingController(text: opt)).toList();
        _correctAnswerIndex = q.correctAnswer;
      }
    } else {
      // Default multiple choice with 4 options
      _optionControllers = List.generate(4, (_) => TextEditingController());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _pointsController.dispose();
    _maxScoreController.dispose();
    _guidelineController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilihan ganda maksimal 10 opsi!')),
      );
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilihan ganda minimal 2 opsi!')),
      );
      return;
    }
    setState(() {
      _optionControllers.removeAt(index);
      if (_correctAnswerIndex != null && _correctAnswerIndex! >= _optionControllers.length) {
        _correctAnswerIndex = _optionControllers.length - 1;
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final text = _textController.text.trim();
      final points = num.tryParse(_pointsController.text.trim()) ?? 1;
      final maxScore = num.tryParse(_maxScoreController.text.trim()) ?? 10;
      final guideline = _guidelineController.text.trim();

      List<String>? options;
      int? correctAnswer;

      if (_type == 'pg') {
        options = _optionControllers.map((c) => c.text.trim()).toList();
        correctAnswer = _correctAnswerIndex;

        // Validation for PG options
        for (int i = 0; i < options.length; i++) {
          if (options[i].isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opsi ${String.fromCharCode(65 + i)} tidak boleh kosong!')),
            );
            return;
          }
        }

        if (correctAnswer == null || correctAnswer < 0 || correctAnswer >= options.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan pilih salah satu jawaban yang benar!')),
          );
          return;
        }
      }

      final isEdit = widget.question != null;
      final question = QuestionModel(
        id: isEdit ? widget.question!.id : const Uuid().v4(),
        type: _type,
        text: text,
        points: _type == 'pg' ? points : 1,
        maxScore: _type == 'essay' ? maxScore : 1,
        essayGuideline: _type == 'essay' ? guideline : null,
        options: _type == 'pg' ? options : null,
        correctAnswer: _type == 'pg' ? correctAnswer : null,
        order: isEdit ? widget.question!.order : widget.nextOrder,
      );

      final cubit = context.read<AddQuestionCubit>();
      if (isEdit) {
        cubit.updateQuestion(widget.examId, question);
      } else {
        cubit.addQuestion(widget.examId, question);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: mediaQuery.viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.question == null ? 'Tambah Soal Baru' : 'Edit Soal',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Segmented Type Selector
              if (widget.question == null) ...[
                Text('Tipe Soal', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pilihan Ganda (PG)'),
                        selected: _type == 'pg',
                        onSelected: (selected) {
                          if (selected) setState(() => _type = 'pg');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Essay / Esai'),
                        selected: _type == 'essay',
                        onSelected: (selected) {
                          if (selected) setState(() => _type = 'essay');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Question Text Field
              TextFormField(
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Teks Pertanyaan',
                  hintText: 'Tuliskan detail pertanyaan di sini...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Teks pertanyaan wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dynamic Option Inputs (for PG)
              if (_type == 'pg') ...[
                Text(
                  'Pilihan Jawaban (Pilih salah satu jawaban benar)',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _optionControllers.length,
                  itemBuilder: (context, index) {
                    final prefix = String.fromCharCode(65 + index); // A, B, C, ...
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: index,
                            groupValue: _correctAnswerIndex,
                            onChanged: (val) {
                              setState(() {
                                _correctAnswerIndex = val;
                              });
                            },
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _optionControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Opsi $prefix',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeOption(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Opsi Jawaban'),
                ),
                const SizedBox(height: 12),

                // Points Field (for PG)
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Bobot Poin Soal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.score),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Bobot poin wajib diisi';
                    final points = int.tryParse(value);
                    if (points == null || points <= 0) return 'Bobot poin harus > 0';
                    return null;
                  },
                ),
              ] else if (_type == 'essay') ...[
                // Max Score Field (for Essay)
                TextFormField(
                  controller: _maxScoreController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Skor Maksimal Soal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.star_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Skor maksimal wajib diisi';
                    final score = int.tryParse(value);
                    if (score == null || score <= 0) return 'Skor maksimal harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Grading Guideline Field (for Essay)
                TextFormField(
                  controller: _guidelineController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Pedoman Penilaian / Kunci Jawaban (Opsional)',
                    hintText: 'Panduan penskoran jawaban siswa untuk guru...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _save,
                      child: const Text('Simpan Soal'),
                    ),
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

class ImportQuestionsDialog extends StatefulWidget {
  final String guruId;
  const ImportQuestionsDialog({super.key, required this.guruId});

  @override
  State<ImportQuestionsDialog> createState() => _ImportQuestionsDialogState();
}

class _ImportQuestionsDialogState extends State<ImportQuestionsDialog> {
  final List<QuestionModel> _selectedQuestions = [];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return BlocProvider<QuestionBankCubit>(
      create: (context) => QuestionBankCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadQuestions(widget.guruId),
      child: Container(
        height: mediaQuery.size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Import dari Bank Soal',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            TextField(
              decoration: InputDecoration(
                labelText: 'Cari Soal',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<QuestionBankCubit, QuestionBankState>(
                builder: (context, state) {
                  if (state is QuestionBankInitial || state is QuestionBankLoading) {
                    return const LoadingWidget(message: 'Memuat bank soal...');
                  }
                  if (state is QuestionBankError) {
                    return AppErrorWidget(
                      errorMessage: state.message,
                      onRetry: () => context.read<QuestionBankCubit>().loadQuestions(widget.guruId),
                    );
                  }
                  if (state is QuestionBankLoaded) {
                    var list = state.questions;
                    if (_searchQuery.isNotEmpty) {
                      list = list.where((q) => q.text.toLowerCase().contains(_searchQuery)).toList();
                    }

                    if (list.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'Soal Tidak Ditemukan',
                        description: 'Tidak ada soal di Bank Soal yang sesuai.',
                      );
                    }

                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final question = list[index];
                        final isSelected = _selectedQuestions.any((q) => q.id == question.id);

                        return CheckboxListTile(
                          title: Text(
                            question.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            question.isPg 
                                ? 'Pilihan Ganda • Bobot: ${question.points}' 
                                : 'Essay • Skor Maks: ${question.maxScore}',
                            style: theme.textTheme.bodySmall,
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedQuestions.add(question);
                              } else {
                                _selectedQuestions.removeWhere((q) => q.id == question.id);
                              }
                            });
                          },
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedQuestions.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedQuestions),
                    child: Text('Import (${_selectedQuestions.length}) Soal'),
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
