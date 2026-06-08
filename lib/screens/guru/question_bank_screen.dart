import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/question_bank_cubit.dart';
import '../../models/question_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class QuestionBankScreen extends StatelessWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String guruId = '';
    if (authState is AuthAuthenticated) {
      guruId = authState.user.uid;
    }

    return BlocProvider<QuestionBankCubit>(
      create: (context) => QuestionBankCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadQuestions(guruId),
      child: QuestionBankView(guruId: guruId),
    );
  }
}

class QuestionBankView extends StatefulWidget {
  final String guruId;
  const QuestionBankView({super.key, required this.guruId});

  @override
  State<QuestionBankView> createState() => _QuestionBankViewState();
}

class _QuestionBankViewState extends State<QuestionBankView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all'; // all | pg | essay

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<QuestionBankCubit>().loadQuestions(widget.guruId);
  }

  void _openQuestionForm({QuestionModel? question}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return BlocProvider.value(
          value: this.context.read<QuestionBankCubit>(),
          child: QuestionBankFormDialog(
            guruId: widget.guruId,
            question: question,
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
          content: const Text('Apakah Anda yakin ingin menghapus soal ini dari Bank Soal?'),
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
                context.read<QuestionBankCubit>().deleteQuestion(widget.guruId, questionId);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Soal'),
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
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari Soal',
                    hintText: 'Cari berdasarkan teks soal...',
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
                      'Filter Tipe: ',
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
                              selected: _typeFilter == 'all',
                              onSelected: (selected) {
                                if (selected) setState(() => _typeFilter = 'all');
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Pilihan Ganda'),
                              selected: _typeFilter == 'pg',
                              onSelected: (selected) {
                                if (selected) setState(() => _typeFilter = 'pg');
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Essay'),
                              selected: _typeFilter == 'essay',
                              onSelected: (selected) {
                                if (selected) setState(() => _typeFilter = 'essay');
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

          // Content
          Expanded(
            child: BlocBuilder<QuestionBankCubit, QuestionBankState>(
              builder: (context, state) {
                if (state is QuestionBankInitial || state is QuestionBankLoading) {
                  return const LoadingWidget(message: 'Memuat bank soal...');
                }

                if (state is QuestionBankError) {
                  return AppErrorWidget(
                    errorMessage: state.message,
                    onRetry: _refresh,
                  );
                }

                if (state is QuestionBankLoaded) {
                  // Apply local filters
                  var filteredQuestions = state.questions;

                  if (_searchQuery.isNotEmpty) {
                    filteredQuestions = filteredQuestions
                        .where((q) => q.text.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  if (_typeFilter != 'all') {
                    filteredQuestions = filteredQuestions
                        .where((q) => q.type == _typeFilter)
                        .toList();
                  }

                  if (filteredQuestions.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          EmptyStateWidget(
                            title: 'Soal Tidak Ditemukan',
                            description: 'Tidak ada soal yang cocok dengan pencarian atau filter Anda.',
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredQuestions.length,
                      itemBuilder: (context, index) {
                        final question = filteredQuestions[index];
                        return _buildQuestionCard(question, index, theme);
                      },
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openQuestionForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, int index, ThemeData theme) {
    return Card(
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
            // Row 1: Header (Type, Actions)
            Row(
              children: [
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
                  onPressed: () => _openQuestionForm(question: question),
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
              ],
            ),
            const SizedBox(height: 12),

            // Question Text
            Text(
              question.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Options PG / Guidelines Essay
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

class QuestionBankFormDialog extends StatefulWidget {
  final String guruId;
  final QuestionModel? question;

  const QuestionBankFormDialog({
    super.key,
    required this.guruId,
    this.question,
  });

  @override
  State<QuestionBankFormDialog> createState() => _QuestionBankFormDialogState();
}

class _QuestionBankFormDialogState extends State<QuestionBankFormDialog> {
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
        order: isEdit ? widget.question!.order : 0, // In bank, order is not strictly used for listing but required by constructor
      );

      final cubit = context.read<QuestionBankCubit>();
      if (isEdit) {
        cubit.updateQuestion(widget.guruId, question);
      } else {
        cubit.addQuestion(widget.guruId, question);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.question == null ? 'Tambah Soal Baru ke Bank' : 'Edit Soal Bank',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

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

              if (_type == 'pg') ...[
                Text(
                  'Pilihan Jawaban (Pilih salah satu jawaban benar)',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RadioGroup<int>(
                  groupValue: _correctAnswerIndex,
                  onChanged: (val) {
                    setState(() {
                      _correctAnswerIndex = val;
                    });
                  },
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _optionControllers.length,
                    itemBuilder: (context, index) {
                      final prefix = String.fromCharCode(65 + index);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: index,
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
              ),
              const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Opsi Jawaban'),
                ),
                const SizedBox(height: 12),

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
