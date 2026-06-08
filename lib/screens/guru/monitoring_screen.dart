import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/monitoring_cubit.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String guruId = '';
    if (authState is AuthAuthenticated) {
      guruId = authState.user.uid;
    }

    return BlocProvider<MonitoringCubit>(
      create: (context) => MonitoringCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadInitialData(guruId),
      child: MonitoringView(guruId: guruId),
    );
  }
}

class MonitoringView extends StatefulWidget {
  final String guruId;
  const MonitoringView({super.key, required this.guruId});

  @override
  State<MonitoringView> createState() => _MonitoringViewState();
}

class _MonitoringViewState extends State<MonitoringView> {
  Future<void> _refresh() async {
    await context.read<MonitoringCubit>().loadInitialData(widget.guruId);
  }

  void _confirmForceSubmit(ExamSessionModel session, UserModel? student) {
    final name = student?.name ?? 'Siswa';
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Paksa Kumpul Ujian?'),
          content: Text(
            'Apakah Anda yakin ingin memaksa mengumpulkan ujian milik siswa "$name"? \n\nTindakan ini akan langsung mengakhiri sesi ujian siswa tersebut di perangkatnya.',
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
                context.read<MonitoringCubit>().forceSubmit(session.id);
              },
              child: const Text('Kumpul Paksa'),
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
        title: const Text('Live Monitoring Ujian'),
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
      body: BlocBuilder<MonitoringCubit, MonitoringState>(
        builder: (context, state) {
          if (state is MonitoringInitial || state is MonitoringLoading) {
            return const LoadingWidget(message: 'Memuat data pemantauan...');
          }

          if (state is MonitoringError) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: _refresh,
            );
          }

          if (state is MonitoringActive) {
            final activeExams = state.activeExams;
            final selectedExamId = state.selectedExamId;
            final sessions = state.sessions;
            final studentMap = state.studentMap;

            final selectedExam = activeExams.where((e) => e.id == selectedExamId).firstOrNull;

            return Column(
              children: [
                // Exam Selector Panel
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedExamId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pilih Ujian Aktif',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.quiz_outlined),
                    ),
                    items: activeExams.map((exam) {
                      return DropdownMenuItem<String>(
                        value: exam.id,
                        child: Text(
                          '${exam.title} (${exam.code})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        context.read<MonitoringCubit>().selectExam(val);
                      }
                    },
                    hint: const Text(
                      'Pilih salah satu ujian aktif untuk dipantau',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Sessions List / Placeholder
                Expanded(
                  child: selectedExamId == null
                      ? RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 60),
                              EmptyStateWidget(
                                title: 'Ujian Belum Dipilih',
                                description: 'Silakan pilih salah satu ujian aktif di atas untuk memulai live monitoring.',
                              ),
                            ],
                          ),
                        )
                      : sessions.isEmpty
                          ? RefreshIndicator(
                              onRefresh: () async {
                                context.read<MonitoringCubit>().selectExam(selectedExamId);
                              },
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 60),
                                  EmptyStateWidget(
                                    title: 'Belum Ada Peserta',
                                    description: 'Tidak ada siswa yang sedang atau telah memulai ujian ini.',
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                context.read<MonitoringCubit>().selectExam(selectedExamId);
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                itemCount: sessions.length,
                                itemBuilder: (context, index) {
                                  final session = sessions[index];
                                  final student = studentMap[session.userId];
                                  return _buildSessionCard(session, student, selectedExam, theme);
                                },
                              ),
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

  Widget _buildSessionCard(
    ExamSessionModel session,
    UserModel? student,
    ExamModel? exam,
    ThemeData theme,
  ) {
    final name = student?.name ?? 'Siswa Tidak Dikenal';
    final email = student?.email ?? 'Tidak ada email';
    final startTime = DateFormat('HH:mm:ss').format(session.startedAt);
    final isRunning = session.status == 'in_progress';

    Color statusColor;
    String statusText;
    if (session.status == 'in_progress') {
      statusColor = Colors.green;
      statusText = 'Sedang Mengerjakan';
    } else if (session.status == 'completed') {
      statusColor = theme.colorScheme.outline;
      statusText = 'Selesai';
    } else {
      statusColor = theme.colorScheme.error;
      statusText = 'Kumpul Paksa';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: session.appSwitchCount > 0 && isRunning
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Student Profile & Status Badge
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
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      if (isRunning) ...[
                        _buildBlinkingIndicator(statusColor),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
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

            // Row 2: Stats & Dynamic Countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mulai Pukul:',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      startTime,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (isRunning && exam != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Sisa Waktu:',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      LiveCountdownWidget(
                        startedAt: session.startedAt,
                        durationMinutes: exam.duration,
                        theme: theme,
                      ),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Pelanggaran (App Switch):',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '${session.appSwitchCount} kali',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: session.appSwitchCount > 0 ? theme.colorScheme.error : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Row 3: Action Buttons
            if (isRunning) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmForceSubmit(session, student),
                  icon: Icon(Icons.cancel_presentation, size: 16, color: theme.colorScheme.error),
                  label: Text('Kumpul Paksa Ujian', style: TextStyle(color: theme.colorScheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkingIndicator(Color color) {
    return _BlinkingWidget(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Stateful blinking helper
class _BlinkingWidget extends StatefulWidget {
  final Widget child;
  const _BlinkingWidget({required this.child});

  @override
  State<_BlinkingWidget> createState() => _BlinkingWidgetState();
}

class _BlinkingWidgetState extends State<_BlinkingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: widget.child,
    );
  }
}

// Live Countdown timer per item
class LiveCountdownWidget extends StatefulWidget {
  final DateTime startedAt;
  final int durationMinutes;
  final ThemeData theme;

  const LiveCountdownWidget({
    super.key,
    required this.startedAt,
    required this.durationMinutes,
    required this.theme,
  });

  @override
  State<LiveCountdownWidget> createState() => _LiveCountdownWidgetState();
}

class _LiveCountdownWidgetState extends State<LiveCountdownWidget> {
  Timer? _timer;
  String _timeString = '00:00';
  bool _isTimeUp = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  void _updateTime() {
    final deadline = widget.startedAt.add(Duration(minutes: widget.durationMinutes));
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      _timer?.cancel();
      setState(() {
        _timeString = 'Waktu Habis';
        _isTimeUp = true;
      });
      return;
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    final String hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');

    setState(() {
      _timeString = '$hoursStr$minutesStr:$secondsStr';
      _isTimeUp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeString,
      style: widget.theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: _isTimeUp ? widget.theme.colorScheme.error : widget.theme.colorScheme.primary,
      ),
    );
  }
}
