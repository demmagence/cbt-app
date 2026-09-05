import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/guru/create_exam_cubit.dart';
import '../../services/firestore_service.dart';
import '../../models/exam_model.dart';
import '../../widgets/common/loading_widget.dart';

class CreateExamScreen extends StatelessWidget {
  const CreateExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateExamCubit>(
      create: (context) =>
          CreateExamCubit(firestoreService: context.read<FirestoreService>()),
      child: const CreateExamForm(),
    );
  }
}

class CreateExamForm extends StatefulWidget {
  const CreateExamForm({super.key});

  @override
  State<CreateExamForm> createState() => _CreateExamFormState();
}

class _CreateExamFormState extends State<CreateExamForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _startDate ?? now.add(const Duration(hours: 1));
    final DateTime? picked = await _selectDateTime(context, initialDate);
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date is before new start date, reset end date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate =
        _endDate ?? (_startDate ?? now).add(const Duration(hours: 2));
    final DateTime? picked = await _selectDateTime(context, initialDate);
    if (picked != null) {
      if (!context.mounted) {
        return;
      }
      if (_startDate != null && picked.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waktu selesai harus setelah waktu mulai!'),
          ),
        );
        return;
      }
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<DateTime?> _selectDateTime(
    BuildContext context,
    DateTime initialValue,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) {
      return null;
    }

    if (!context.mounted) {
      return null;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih waktu mulai ujian!')),
        );
        return;
      }
      if (_endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih waktu selesai ujian!')),
        );
        return;
      }

      final authState = context.read<AuthBloc>().state;
      String guruId = '';
      if (authState is AuthAuthenticated) {
        guruId = authState.user.uid;
      }

      context.read<CreateExamCubit>().createExam(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        duration: int.parse(_durationController.text.trim()),
        startDate: _startDate!,
        endDate: _endDate!,
        shuffleQuestions: _shuffleQuestions,
        shuffleOptions: _shuffleOptions,
        guruId: guruId,
      );
    }
  }

  void _showSuccessDialog(ExamModel exam) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Ujian Berhasil Dibuat'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ujian "${exam.title}" disimpan sebagai draf. Tambahkan soal, lalu aktifkan ujian di daftar ujian sebelum membagikan kode:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exam.code,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: exam.code));
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Kode ujian disalin ke clipboard!'),
                            ),
                          );
                        },
                        tooltip: 'Salin Kode',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup Dialog
                context.go('/guru/dashboard'); // Kembali ke Dashboard
              },
              child: const Text('Ke Dashboard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup Dialog
                context.go(
                  '/guru/exams/${exam.id}/questions',
                ); // Kelola Pertanyaan
              },
              child: const Text('Kelola Soal'),
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
        title: const Text('Buat Ujian Baru'),
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
      body: BlocListener<CreateExamCubit, CreateExamState>(
        listener: (context, state) {
          if (state is CreateExamSuccess) {
            _showSuccessDialog(state.exam);
          } else if (state is CreateExamError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: BlocBuilder<CreateExamCubit, CreateExamState>(
          builder: (context, state) {
            if (state is CreateExamLoading) {
              return const LoadingWidget(message: 'Membuat ujian...');
            }

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Fields
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Ujian',
                        hintText: 'Masukkan judul ujian',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Judul ujian wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi Ujian (Opsional)',
                        hintText: 'Masukkan deskripsi atau petunjuk ujian',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Durasi Ujian (Menit)',
                        hintText: 'Masukkan durasi dalam menit',
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Durasi ujian wajib diisi';
                        }
                        final duration = int.tryParse(value);
                        if (duration == null || duration <= 0) {
                          return 'Durasi harus lebih besar dari 0 menit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Date & Time Pickers
                    Text(
                      'Jadwal Ujian',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectStartDate(context),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Waktu Mulai',
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _startDate == null
                                    ? 'Pilih Waktu'
                                    : DateFormat(
                                        'dd MMM yyyy, HH:mm',
                                      ).format(_startDate!),
                                style: _startDate == null
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.hintColor,
                                      )
                                    : theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectEndDate(context),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Waktu Selesai',
                                prefixIcon: const Icon(Icons.event),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _endDate == null
                                    ? 'Pilih Waktu'
                                    : DateFormat(
                                        'dd MMM yyyy, HH:mm',
                                      ).format(_endDate!),
                                style: _endDate == null
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.hintColor,
                                      )
                                    : theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Shuffling Toggles
                    Text(
                      'Pengaturan Tambahan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      title: const Text('Acak Urutan Soal'),
                      subtitle: const Text(
                        'Mengacak urutan soal secara unik untuk tiap siswa',
                      ),
                      value: _shuffleQuestions,
                      onChanged: (bool value) {
                        setState(() {
                          _shuffleQuestions = value;
                        });
                      },
                      secondary: const Icon(Icons.shuffle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Acak Opsi Pilihan Ganda'),
                      subtitle: const Text(
                        'Mengacak pilihan jawaban untuk soal pilihan ganda',
                      ),
                      value: _shuffleOptions,
                      onChanged: (bool value) {
                        setState(() {
                          _shuffleOptions = value;
                        });
                      },
                      secondary: const Icon(Icons.format_list_bulleted),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Simpan & Buat Kode Ujian',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
