import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/admin/edit_user_cubit.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../config/theme/app_colors.dart';

class EditUserScreen extends StatelessWidget {
  final String uid;
  final UserModel? initialUser;

  const EditUserScreen({
    super.key,
    required this.uid,
    this.initialUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditUserCubit>(
      create: (context) => EditUserCubit(
        authService: context.read<AuthService>(),
        firestoreService: context.read<FirestoreService>(),
      )..loadUser(uid, initialUser: initialUser),
      child: const EditUserView(),
    );
  }
}

class EditUserView extends StatefulWidget {
  const EditUserView({super.key});

  @override
  State<EditUserView> createState() => _EditUserViewState();
}


class _EditUserViewState extends State<EditUserView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  String _selectedRole = 'siswa';
  bool _isActive = true;
  bool _initialized = false;

  @override
  void dispose() {
    if (_initialized) {
      _nameController.dispose();
      _emailController.dispose();
    }
    super.dispose();
  }

  void _initializeFields(UserModel user) {
    if (_initialized) return;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _selectedRole = user.role;
    _isActive = user.isActive;
    _initialized = true;
  }

  void _onSubmit(String uid) {
    if (_formKey.currentState!.validate()) {
      context.read<EditUserCubit>().updateUser(
        uid: uid,
        name: _nameController.text.trim(),
        role: _selectedRole,
        isActive: _isActive,
      );
    }
  }

  void _showDeactivateConfirmation(BuildContext context, String uid, String name) {
    final theme = Theme.of(context);
    final cubit = context.read<EditUserCubit>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nonaktifkan Akun?'),
          content: Text(
            'Apakah Anda yakin ingin menonaktifkan akun "$name"? Pengguna ini tidak akan bisa login ke aplikasi setelah dinonaktifkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                cubit.deactivateUser(uid);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Nonaktifkan'),
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
        title: const Text('Edit Pengguna'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/users'),
        ),
      ),
      body: BlocConsumer<EditUserCubit, EditUserState>(
        listener: (context, state) {
          if (state is EditUserSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            if (state.message.contains('berhasil diperbarui') ||
                state.message.contains('dinonaktifkan')) {
              context.go('/admin/users');
            }
          }
          if (state is EditUserError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is EditUserLoading) {
            return const LoadingWidget(message: 'Memuat data pengguna...');
          }


          // Use Widget's uid when retrying
          if (state is EditUserError && !_initialized) {
            final uid = (widget as EditUserScreen).uid;
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: () => context.read<EditUserCubit>().loadUser(uid),
            );
          }

          UserModel? user;
          bool isSubmitting = false;

          if (state is EditUserLoaded) {
            user = state.user;
            isSubmitting = state.isSubmitting;
            _initializeFields(user);
          }

          if (user != null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Profil',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ubah data profil pengguna di bawah ini.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nama Lengkap
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !isSubmitting,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama lengkap wajib diisi.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Alamat Email (Read-only)
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Alamat Email (Tidak dapat diubah)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        fillColor: AppColors.surfaceVariant.withValues(alpha: 0.15),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Peran Akun (Role)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Peran Pengguna (Role)',
                        prefixIcon: Icon(Icons.manage_accounts_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'siswa',
                          child: Text('Siswa'),
                        ),
                        DropdownMenuItem(
                          value: 'guru',
                          child: Text('Guru'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedRole = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 20),

                    // Status Aktif Switch
                    Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Status Akun Aktif',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          _isActive
                              ? 'Pengguna dapat masuk ke dalam aplikasi.'
                              : 'Akun dinonaktifkan dan tidak bisa masuk.',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _isActive,
                        activeThumbColor: AppColors.success,
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Reset Password & Deactivate Quick Cards
                    Text(
                      'Tindakan Keamanan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Reset Password Button Card
                        Expanded(
                          child: InkWell(
                            onTap: isSubmitting
                                ? null
                                : () => context.read<EditUserCubit>().sendPasswordReset(user!.email),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                                color: theme.colorScheme.surface,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    child: Icon(Icons.lock_reset_rounded, color: theme.colorScheme.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Reset Sandi',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kirim email link pemulihan kata sandi',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Soft Delete / Deactivate Card
                        Expanded(
                          child: InkWell(
                            onTap: isSubmitting || !_isActive
                                ? null
                                : () => _showDeactivateConfirmation(context, user!.uid, user.name),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                                color: _isActive
                                    ? theme.colorScheme.surface
                                    : AppColors.surfaceVariant.withValues(alpha: 0.3),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.error.withValues(alpha: 0.1),
                                    child: Icon(Icons.block_rounded, color: theme.colorScheme.error),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nonaktifkan',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isActive
                                        ? 'Blokir akses masuk pengguna ini'
                                        : 'Akun ini sudah dinonaktifkan',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    ElevatedButton.icon(
                      onPressed: isSubmitting ? null : () => _onSubmit(user!.uid),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const Center(child: Text('Inisialisasi...'));
        },
      ),
    );
  }
}
