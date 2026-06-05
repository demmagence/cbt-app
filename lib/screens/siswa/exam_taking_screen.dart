import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/siswa/exam_taking_cubit.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class ExamTakingScreen extends StatefulWidget {
  final String examId;
  const ExamTakingScreen({super.key, required this.examId});

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> with WidgetsBindingObserver {
  late final ExamTakingCubit _cubit;
  DateTime? _appBackgroundTime;
  final TextEditingController _essayController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cubit = ExamTakingCubit(
      firestoreService: context.read<FirestoreService>(),
    );

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _cubit.loadSession(widget.examId, authState.user.uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _essayController.dispose();
    _debounceTimer?.cancel();
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // User left the app
      _appBackgroundTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // User returned to the app
      if (_appBackgroundTime != null) {
        final duration = DateTime.now().difference(_appBackgroundTime!).inSeconds;
        if (duration > 0) {
          final log = AppSwitchLog(
            timestamp: _appBackgroundTime!,
            duration: duration,
            type: 'app_switch',
          );
          _cubit.logAppSwitch(log);
          
          // Show warning toast/alert
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Terdeteksi keluar dari aplikasi selama $duration detik! Pelanggaran dicatat.',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _appBackgroundTime = null;
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _onEssayChanged(String qId, String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _cubit.saveAnswer(qId, text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        body: BlocConsumer<ExamTakingCubit, ExamTakingState>(
          listener: (context, state) {
            if (state is ExamTakingSubmitted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ujian berhasil dikirimkan.'),
                  backgroundColor: Colors.green,
                ),
              );
              context.go('/siswa/dashboard');
            }
          },
          builder: (context, state) {
            if (state is ExamTakingLoading) {
              return const Scaffold(
                body: LoadingWidget(message: 'Memuat lembar ujian...'),
              );
            }

            if (state is ExamTakingSubmitting) {
              return const Scaffold(
                body: LoadingWidget(message: 'Mengirimkan lembar jawaban...'),
              );
            }

            if (state is ExamTakingError) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/siswa/dashboard'),
                  ),
                ),
                body: AppErrorWidget(
                  errorMessage: state.message,
                  onRetry: () {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is AuthAuthenticated) {
                      _cubit.loadSession(widget.examId, authState.user.uid);
                    }
                  },
                ),
              );
            }

            if (state is ExamTakingActive) {
              final question = state.orderedQuestions[state.currentIndex];
              final isLast = state.currentIndex == state.orderedQuestions.length - 1;
              final isFirst = state.currentIndex == 0;
              final isFlagged = state.flaggedQuestions.contains(question.id);
              final theme = Theme.of(context);

              // Set controller text once when changing question
              if (question.isEssay) {
                final currentText = state.answers[question.id] ?? '';
                if (_essayController.text != currentText) {
                  _essayController.text = currentText;
                }
              }

              return Scaffold(
                appBar: AppBar(
                  leading: const SizedBox.shrink(), // Disable leading arrow
                  title: Column(
                    children: [
                      Text(state.exam.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(state.remainingSeconds),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: state.remainingSeconds < 300 ? Colors.red : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.grid_view_rounded),
                      tooltip: 'Navigasi Soal',
                      onPressed: () => _showQuestionPalette(context, state),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Soal Nomor ${state.currentIndex + 1} dari ${state.orderedQuestions.length}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: question.isPg ? Colors.blue.withValues(alpha: 0.15) : Colors.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                question.isPg ? 'Pilihan Ganda' : 'Essay',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: question.isPg ? Colors.blue : Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Question Text Card
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      question.text,
                                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Answer Options / Text Field
                                if (question.isPg && question.options != null)
                                  _buildPgOptions(question, state, theme)
                                else if (question.isEssay)
                                  _buildEssayInput(question, theme),
                              ],
                            ),
                          ),
                        ),

                        // Navigation Footer
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Previous
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(100, 48),
                                ),
                                onPressed: isFirst ? null : () => _cubit.updateIndex(state.currentIndex - 1),
                                icon: const Icon(Icons.chevron_left_rounded),
                                label: const Text('Sebelumnya'),
                              ),

                              // Flag / Ragu-ragu
                              InkWell(
                                onTap: () => _cubit.toggleFlag(question.id),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isFlagged ? Colors.amber.withValues(alpha: 0.15) : Colors.transparent,
                                    border: Border.all(
                                      color: isFlagged ? Colors.amber : theme.colorScheme.outline.withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isFlagged ? Icons.warning_rounded : Icons.warning_amber_rounded,
                                        color: isFlagged ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ragu-Ragu',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isFlagged ? Colors.amber[800] : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Next / Selesai
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLast ? Colors.green : theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 48),
                                ),
                                onPressed: () {
                                  if (isLast) {
                                    _showSubmitConfirmation(context);
                                  } else {
                                    _cubit.updateIndex(state.currentIndex + 1);
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(isLast ? 'Selesai' : 'Berikutnya'),
                                    const SizedBox(width: 4),
                                    Icon(isLast ? Icons.check_circle_outline : Icons.chevron_right_rounded),
                                  ],
                                ),
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

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildPgOptions(QuestionModel question, ExamTakingActive state, ThemeData theme) {
    final optionOrder = state.session.optionOrders[question.id] ?? [];
    final answers = state.answers;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: question.options!.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final originalIndex = optionOrder.isNotEmpty ? optionOrder[index] : index;
        final optionText = question.options![originalIndex];
        final isSelected = answers[question.id] == originalIndex;
        final optionLabel = String.fromCharCode(65 + index); // A, B, C, D, E...

        return InkWell(
          onTap: () => _cubit.saveAnswer(question.id, originalIndex),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : theme.colorScheme.surface,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    optionLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    optionText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEssayInput(QuestionModel question, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lembar Jawaban:',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _essayController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Tuliskan jawaban Anda di sini...',
          ),
          onChanged: (val) => _onEssayChanged(question.id, val),
        ),
      ],
    );
  }

  void _showQuestionPalette(BuildContext context, ExamTakingActive state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daftar Soal Ujian',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: state.orderedQuestions.length,
                  itemBuilder: (context, index) {
                    final q = state.orderedQuestions[index];
                    final isCurrent = index == state.currentIndex;
                    final hasAnswer = state.answers.containsKey(q.id) &&
                        (state.answers[q.id]?.toString().trim().isNotEmpty ?? false);
                    final isFlagged = state.flaggedQuestions.contains(q.id);

                    Color bgColor = theme.colorScheme.surface;
                    Color textColor = theme.colorScheme.onSurface;
                    BorderSide borderSide = BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3));

                    if (isFlagged) {
                      bgColor = Colors.amber;
                      textColor = Colors.white;
                      borderSide = BorderSide.none;
                    } else if (hasAnswer) {
                      bgColor = theme.colorScheme.primary;
                      textColor = Colors.white;
                      borderSide = BorderSide.none;
                    }

                    if (isCurrent) {
                      borderSide = BorderSide(color: theme.colorScheme.secondary, width: 3);
                    }

                    return InkWell(
                      onTap: () {
                        _cubit.updateIndex(index);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.fromBorderSide(borderSide),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubmitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Ujian?'),
        content: const Text(
            'Apakah Anda yakin ingin menyelesaikan ujian dan mengirimkan jawaban Anda? Pastikan semua soal telah terjawab.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cubit.submitExam();
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }
}
