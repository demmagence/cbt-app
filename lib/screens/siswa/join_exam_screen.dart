import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/siswa/join_exam_cubit.dart';
import '../../services/firestore_service.dart';
import '../../services/exam_code_service.dart';
import '../../widgets/common/loading_widget.dart';

class JoinExamScreen extends StatefulWidget {
  const JoinExamScreen({super.key});

  @override
  State<JoinExamScreen> createState() => _JoinExamScreenState();
}

class _JoinExamScreenState extends State<JoinExamScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final JoinExamCubit _joinExamCubit;

  @override
  void initState() {
    super.initState();
    _joinExamCubit = JoinExamCubit(
      firestoreService: context.read<FirestoreService>(),
      examCodeService: context.read<ExamCodeService>(),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _joinExamCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Tidak terautentikasi')));
    }

    final user = authState.user;
    final theme = Theme.of(context);

    return BlocProvider.value(
      value: _joinExamCubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ikut Ujian')),
        body: BlocConsumer<JoinExamCubit, JoinExamState>(
          listener: (context, state) {
            if (state is JoinExamSuccess) {
              context.push('/siswa/exam/${state.session.examId}');
            }
          },
          builder: (context, state) {
            if (state is JoinExamSessionStarting) {
              return const LoadingWidget(message: 'Menyiapkan sesi ujian...');
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Header Illustration/Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Masukkan Kode Ujian',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan kode ujian enam karakter yang diberikan oleh guru. Jawaban harus tersinkron sebelum waktu ujian berakhir.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Code Form
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _codeController,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(6),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: 'TOKEN',
                        hintStyle: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.5,
                          ),
                          letterSpacing: 8,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Token tidak boleh kosong';
                        }
                        if (value.trim().length < 6) {
                          return 'Token harus 6 karakter';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action or Error for Validation
                  if (state is JoinExamError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (state is JoinExamVerifying)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (state is JoinExamCodeValid)
                    _buildExamDetailCard(
                      state.exam,
                      state.existingSession,
                      user.uid,
                      theme,
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _joinExamCubit.verifyCode(
                            _codeController.text,
                            user.uid,
                          );
                        }
                      },
                      child: const Text('Cek Kode'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExamDetailCard(
    dynamic exam,
    dynamic existingSession,
    String userId,
    ThemeData theme,
  ) {
    final hasActiveSession = existingSession != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    exam.code,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasActiveSession)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sedang Berjalan',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              exam.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (exam.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exam.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoColumn(
                  Icons.timer_outlined,
                  '${exam.duration} Menit',
                  'Durasi',
                  theme,
                ),
                _buildInfoColumn(
                  Icons.quiz_outlined,
                  '${exam.totalQuestions} Soal',
                  'Pertanyaan',
                  theme,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasActiveSession
                    ? Colors.orange
                    : theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (hasActiveSession) {
                  context.push('/siswa/exam/${exam.id}');
                } else {
                  _joinExamCubit.startExam(exam, userId);
                }
              },
              child: Text(hasActiveSession ? 'Lanjutkan Ujian' : 'Mulai Ujian'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    IconData icon,
    String value,
    String label,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
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
