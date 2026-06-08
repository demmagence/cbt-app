import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/guru/edit_exam_cubit.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class EditExamScreen extends StatelessWidget {
  final String examId;
  const EditExamScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditExamCubit>(
      create: (context) => EditExamCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadExam(examId),
      child: EditExamForm(examId: examId),
    );
  }
}

class EditExamForm extends StatefulWidget {
  final String examId;
  const EditExamForm({super.key, required this.examId});

  @override
  State<EditExamForm> createState() => _EditExamFormState();
}

class _EditExamFormState extends State<EditExamForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;
  bool _isActive = true;
  bool _isDataLoaded = false;

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
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _endDate ?? (_startDate ?? now).add(const Duration(hours: 2));
    final DateTime? picked = await _selectDateTime(context, initialDate);
    if (picked != null) {
      if (!context.mounted) return;
      if (_startDate != null && picked.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waktu selesai harus setelah waktu mulai!')),
        );
        return;
      }
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<DateTime?> _selectDateTime(BuildContext context, DateTime initialValue) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // allow past dates for already started exams
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;

    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
    );
    if (time == null) return null;

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

      context.read<EditExamCubit>().updateExam(
            examId: widget.examId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            duration: int.parse(_durationController.text.trim()),
            startDate: _startDate!,
            endDate: _endDate!,
            shuffleQuestions: _shuffleQuestions,
            shuffleOptions: _shuffleOptions,
            isActive: _isActive,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Ujian'),
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
      body: BlocConsumer<EditExamCubit, EditExamState>(
        listener: (context, state) {
          if (state is EditExamSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Detail ujian berhasil diperbarui!')),
            );
            Navigator.pop(context); // Kembali ke daftar ujian
          } else if (state is EditExamError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is EditExamLoaded && !_isDataLoaded) {
            // Populate form once when loaded
            final exam = state.exam;
            _titleController.text = exam.title;
            _descriptionController.text = exam.description;
            _durationController.text = exam.duration.toString();
            _startDate = exam.startDate;
            _endDate = exam.endDate;
            _shuffleQuestions = exam.shuffleQuestions;
            _shuffleOptions = exam.shuffleOptions;
            _isActive = exam.isActive;
            _isDataLoaded = true;
          }
        },
        builder: (context, state) {
          if (state is EditExamInitial || (state is EditExamLoading && !_isDataLoaded)) {
            return const LoadingWidget(message: 'Memuat detail ujian...');
          }

          if (state is EditExamError && !_isDataLoaded) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: () => context.read<EditExamCubit>().loadExam(widget.examId),
            );
          }

          return Stack(
            children: [
              Form(
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
                                      : DateFormat('dd MMM yyyy, HH:mm').format(_startDate!),
                                  style: _startDate == null
                                      ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)
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
                                      : DateFormat('dd MMM yyyy, HH:mm').format(_endDate!),
                                  style: _endDate == null
                                      ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)
                                      : theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Status & Shuffling Toggles
                      Text(
                        'Pengaturan Tambahan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        title: const Text('Ujian Aktif'),
                        subtitle: const Text('Siswa hanya dapat mengakses ujian jika status aktif'),
                        value: _isActive,
                        onChanged: (bool value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        secondary: const Icon(Icons.toggle_on_outlined),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Acak Urutan Soal'),
                        subtitle: const Text('Mengacak urutan soal secara unik untuk tiap siswa'),
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
                        subtitle: const Text('Mengacak pilihan jawaban untuk soal pilihan ganda'),
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
                            'Simpan Perubahan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              ),
              if (state is EditExamLoading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: LoadingWidget(message: 'Menyimpan perubahan...'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
