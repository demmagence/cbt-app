import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/siswa/exam_session_bloc.dart';
import '../../blocs/siswa/exam_session_event.dart';
import '../../blocs/siswa/exam_session_state.dart';
import '../../models/question_model.dart';
import '../../services/anti_cheat_manager.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/siswa/essay_answer_field.dart';
import '../../widgets/siswa/question_navigator.dart';
import '../../widgets/siswa/countdown_timer.dart';

class ExamTakingScreen extends StatefulWidget {
  final String examId;
  const ExamTakingScreen({super.key, required this.examId});

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  late final ExamSessionBloc _bloc;
  final AntiCheatManager _antiCheat = AntiCheatManager.instance;
  late final PageController _pageController;
  bool _showReview = false;
  String _examTitle = 'Ujian';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    _bloc = ExamSessionBloc(firestoreService: context.read<FirestoreService>());

    // Enable anti-cheat (immersive mode + lifecycle observer)
    _antiCheat.enable();
    _antiCheat.onAppSwitched((log) {
      _bloc.add(AppSwitchDetected(log));
      if (mounted) {
        _showAppSwitchWarningDialog(
          context,
          log.duration,
          _antiCheat.getAppSwitchCount(),
        );
      }
    });
    _antiCheat.onResumed(() {
      _bloc.add(const AppResumed());
    });

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _bloc.add(ExamStarted(examId: widget.examId, userId: authState.user.uid));
    }
  }

  @override
  void dispose() {
    _antiCheat.disable();
    _pageController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
        },
        child: Scaffold(
          body: BlocConsumer<ExamSessionBloc, ExamSessionState>(
            listener: (context, state) {
              if (state is ExamSessionCompleted) {
                context.go(
                  '/siswa/exam-success',
                  extra: {
                    'examTitle': _examTitle,
                    'pgScore': state.result.pgScore,
                    'gradingStatus': state.result.gradingStatus,
                  },
                );
              } else if (state is ExamSessionActive) {
                _examTitle = state.exam.title;
                // Animate PageView to current page
                if (_pageController.hasClients &&
                    _pageController.page?.round() != state.currentIndex) {
                  _pageController.animateToPage(
                    state.currentIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              }
            },
            builder: (context, state) {
              if (state is ExamSessionLoading) {
                return const Scaffold(
                  body: LoadingWidget(message: 'Memuat lembar ujian...'),
                );
              }

              if (state is ExamSessionSubmitting) {
                return Scaffold(
                  body: state.error != null
                      ? AppErrorWidget(
                          errorMessage: state.error!,
                          onRetry: () => _bloc.add(const ExamSubmitted()),
                        )
                      : const LoadingWidget(
                          message: 'Mengirimkan lembar jawaban...',
                        ),
                );
              }

              if (state is ExamSessionError) {
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
                        _bloc.add(
                          ExamStarted(
                            examId: widget.examId,
                            userId: authState.user.uid,
                          ),
                        );
                      }
                    },
                  ),
                );
              }

              if (state is ExamSessionActive) {
                final question = state.questions[state.currentIndex];
                final isLast = state.currentIndex == state.questions.length - 1;
                final isFirst = state.currentIndex == 0;
                final isFlagged = state.flaggedQuestions.contains(question.id);
                final theme = Theme.of(context);

                if (_showReview) {
                  return _buildReviewScaffold(context, state, theme);
                }

                return Scaffold(
                  appBar: AppBar(
                    leading: const SizedBox.shrink(), // Disable leading arrow
                    title: Column(
                      children: [
                        Text(
                          state.exam.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CountdownTimer(remainingTime: state.remainingTime),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.assignment_turned_in_rounded),
                        tooltip: 'Review Ujian',
                        onPressed: () {
                          setState(() {
                            _showReview = true;
                          });
                        },
                      ),
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
                          if (state.isOffline) _buildOfflineBanner(theme),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              state.saveMessage,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          // Question Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Soal Nomor ${state.currentIndex + 1} dari ${state.questions.length}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: question.isPg
                                      ? Colors.blue.withValues(alpha: 0.15)
                                      : Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  question.isPg ? 'Pilihan Ganda' : 'Essay',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: question.isPg
                                        ? Colors.blue
                                        : Colors.purple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Question Text Card
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.questions.length,
                              itemBuilder: (context, index) {
                                final q = state.questions[index];
                                return SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Card(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.2),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            q.text,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(height: 1.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Answer Options / Text Field
                                      if (q.isPg && q.options != null)
                                        _buildPgOptions(q, state, theme)
                                      else if (q.isEssay)
                                        EssayAnswerField(
                                          key: ValueKey(q.id),
                                          initialText:
                                              state.session.answers[q.id]
                                                  ?.toString() ??
                                              '',
                                          onChanged: (text) {
                                            _bloc.add(
                                              EssayAnswerUpdated(
                                                questionId: q.id,
                                                text: text,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
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
                                Flexible(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(60, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    onPressed: isFirst
                                        ? null
                                        : () => _bloc.add(
                                            QuestionNavigated(
                                              state.currentIndex - 1,
                                            ),
                                          ),
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                      size: 20,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Sebelumnya'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Flag / Ragu-ragu
                                Flexible(
                                  child: SizedBox(
                                    height: 48,
                                    child: InkWell(
                                      onTap: () =>
                                          _bloc.add(FlagToggled(question.id)),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFlagged
                                              ? Colors.amber.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isFlagged
                                                ? Colors.amber
                                                : theme.colorScheme.outline
                                                      .withValues(alpha: 0.3),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isFlagged
                                                    ? Icons.warning_rounded
                                                    : Icons
                                                          .warning_amber_rounded,
                                                color: isFlagged
                                                    ? Colors.amber
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Ragu-Ragu',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isFlagged
                                                          ? Colors.amber[800]
                                                          : theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Next / Selesai
                                Flexible(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isLast
                                          ? Colors.green
                                          : theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(60, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    onPressed: () {
                                      if (isLast) {
                                        setState(() {
                                          _showReview = true;
                                        });
                                      } else {
                                        _bloc.add(
                                          QuestionNavigated(
                                            state.currentIndex + 1,
                                          ),
                                        );
                                      }
                                    },
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isLast ? 'Selesai' : 'Berikutnya',
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            isLast
                                                ? Icons.check_circle_outline
                                                : Icons.chevron_right_rounded,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
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
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline — Koneksi Terputus',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  'Draf disimpan lokal. Sambungkan kembali sebelum waktu habis agar jawaban diterima server.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: Colors.amber.shade900.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPgOptions(
    QuestionModel question,
    ExamSessionActive state,
    ThemeData theme,
  ) {
    final optionOrder = state.session.optionOrders[question.id] ?? [];
    final answers = state.session.answers;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: question.options!.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final originalIndex = optionOrder.isNotEmpty
            ? optionOrder[index]
            : index;
        final optionText = question.options![originalIndex];
        final isSelected = answers[question.id] == index;
        final optionLabel = String.fromCharCode(65 + index); // A, B, C, D, E...

        return InkWell(
          onTap: () => _bloc.add(
            AnswerSelected(questionId: question.id, answerIndex: index),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.surface,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
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
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    optionLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    optionText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuestionPalette(BuildContext context, ExamSessionActive state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return QuestionNavigator(
          state: state,
          onQuestionTap: (index) {
            _bloc.add(QuestionNavigated(index));
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// Shows a warning dialog when the student switches away from the app.
  void _showAppSwitchWarningDialog(
    BuildContext context,
    int durationSeconds,
    int violationCount,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.red[700],
          size: 48,
        ),
        title: Text(
          'Pelanggaran ke-$violationCount',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Anda terdeteksi keluar dari aplikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Durasi: $durationSeconds detik',
                style: TextStyle(
                  color: Colors.red[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Semua pelanggaran dicatat dan akan dilaporkan ke pengawas ujian.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Saya Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Shows the "Waktu Habis" dialog when the exam timer expires.
  /// The BLoC will handle the actual auto-submission after the dialog is shown.

  void _onPressSubmit(BuildContext context, ExamSessionActive state) {
    int unansweredCount = 0;
    for (final q in state.questions) {
      final hasAnswer =
          state.session.answers.containsKey(q.id) &&
          (state.session.answers[q.id]?.toString().trim().isNotEmpty ?? false);
      if (!hasAnswer) {
        unansweredCount++;
      }
    }

    final contentText = unansweredCount > 0
        ? 'Anda yakin? Ada $unansweredCount soal yang belum dijawab. Jawaban tidak bisa diubah setelah submit.'
        : 'Apakah Anda yakin ingin menyelesaikan ujian dan mengirimkan jawaban Anda?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Ujian?'),
        content: Text(contentText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bloc.add(const ExamSubmitted());
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewScaffold(
    BuildContext context,
    ExamSessionActive state,
    ThemeData theme,
  ) {
    int totalPG = 0;
    int answeredPG = 0;
    int totalEssay = 0;
    int answeredEssay = 0;
    int unansweredCount = 0;

    for (final q in state.questions) {
      final hasAnswer =
          state.session.answers.containsKey(q.id) &&
          (state.session.answers[q.id]?.toString().trim().isNotEmpty ?? false);
      if (q.isPg) {
        totalPG++;
        if (hasAnswer) {
          answeredPG++;
        }
      } else if (q.isEssay) {
        totalEssay++;
        if (hasAnswer) {
          answeredEssay++;
        }
      }
      if (!hasAnswer) {
        unansweredCount++;
      }
    }

    final totalQuestions = state.questions.length;
    final totalAnswered = answeredPG + answeredEssay;
    final progress = totalQuestions > 0
        ? (totalAnswered / totalQuestions)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showReview = false),
          tooltip: 'Kembali ke Ujian',
        ),
        title: const Text('Review Jawaban Ujian'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: CountdownTimer(remainingTime: state.remainingTime),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.isOffline)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                ),
                child: _buildOfflineBanner(theme),
              ),
            // Stats Header Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ringkasan Jawaban',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalAnswered dari $totalQuestions soal terjawab',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: unansweredCount > 0
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              unansweredCount > 0
                                  ? '$unansweredCount Belum Dijawab'
                                  : 'Semua Terjawab',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: unansweredCount > 0
                                    ? Colors.orange[800]
                                    : Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            unansweredCount > 0
                                ? theme.colorScheme.primary
                                : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Pilihan Ganda',
                            '$answeredPG / $totalPG',
                            theme,
                          ),
                          _buildStatItem(
                            'Essay',
                            '$answeredEssay / $totalEssay',
                            theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Question List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: totalQuestions,
                itemBuilder: (context, index) {
                  final q = state.questions[index];
                  final hasAnswer =
                      state.session.answers.containsKey(q.id) &&
                      (state.session.answers[q.id]
                              ?.toString()
                              .trim()
                              .isNotEmpty ??
                          false);
                  final isFlagged = state.flaggedQuestions.contains(q.id);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasAnswer
                            ? theme.colorScheme.outline.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.3),
                        width: hasAnswer ? 1 : 1.5,
                      ),
                    ),
                    color: hasAnswer
                        ? theme.colorScheme.surface
                        : Colors.orange.withValues(alpha: 0.05),
                    child: ListTile(
                      onTap: () {
                        _bloc.add(QuestionNavigated(index));
                        setState(() {
                          _showReview = false;
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: hasAnswer
                            ? (q.isPg
                                  ? theme.colorScheme.primary
                                  : Colors.green[600])
                            : Colors.orange[200],
                        foregroundColor: Colors.white,
                        radius: 18,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        q.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            q.isPg ? 'Pilihan Ganda' : 'Essay',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (isFlagged) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Ragu-Ragu',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.amber[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: hasAnswer
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green[600],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BELUM DIJAWAB',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),

            // Bottom action bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => setState(() => _showReview = false),
                      child: const Text('Kembali ke Ujian'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _onPressSubmit(context, state),
                      child: const Text(
                        'Submit Ujian',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
