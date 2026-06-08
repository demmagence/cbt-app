import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/admin/create_user_cubit.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../config/theme/app_colors.dart';

class CreateUserScreen extends StatelessWidget {
  const CreateUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateUserCubit>(
      create: (context) => CreateUserCubit(
        authService: context.read<AuthService>(),
        firestoreService: context.read<FirestoreService>(),
      ),
      child: const CreateUserView(),
    );
  }
}

class CreateUserView extends StatefulWidget {
  const CreateUserView({super.key});

  @override
  State<CreateUserView> createState() => _CreateUserViewState();
}

class _CreateUserViewState extends State<CreateUserView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'siswa';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    return List.generate(8, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  void _onGeneratePasswordPressed() {
    final newPassword = _generateRandomPassword();
    setState(() {
      _passwordController.text = newPassword;
      _obscurePassword = false; // Show password so admin can see/record it
    });
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      context.read<CreateUserCubit>().createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );
    }
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _selectedRole = 'siswa';
      _obscurePassword = true;
    });
    context.read<CreateUserCubit>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Pengguna Baru'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
      ),
      body: BlocConsumer<CreateUserCubit, CreateUserState>(
        listener: (context, state) {
          if (state is CreateUserError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CreateUserLoading) {
            return const LoadingWidget(message: 'Mendaftarkan pengguna baru...');
          }

          if (state is CreateUserSuccess) {
            return _buildSuccessScreen(context, state, theme);
          }

          return _buildFormScreen(theme);
        },
      ),
    );
  }

  Widget _buildFormScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Pengguna',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Masukkan data pendaftaran untuk membuat akun baru.',
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
                hintText: 'Masukkan nama lengkap',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama lengkap wajib diisi.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Alamat Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Alamat Email',
                prefixIcon: Icon(Icons.email_outlined),
                hintText: 'nama@sekolah.com',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alamat email wajib diisi.';
                }
                final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegExp.hasMatch(value.trim())) {
                  return 'Format email tidak valid.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kata Sandi / Password
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Kata Sandi',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                hintText: 'Minimal 6 karakter',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    TextButton(
                      onPressed: _onGeneratePasswordPressed,
                      child: const Text('Acak'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kata sandi wajib diisi.';
                }
                if (value.length < 6) {
                  return 'Kata sandi minimal 6 karakter.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Pilihan Peran (Role)
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
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),
            const SizedBox(height: 32),

            // Tombol Kirim / Submit
            ElevatedButton.icon(
              onPressed: _onSubmit,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Buat Akun Baru'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen(BuildContext context, CreateUserSuccess state, ThemeData theme) {
    final credentialsText = 'Nama: ${state.name}\nEmail: ${state.email}\nSandi: ${state.password}\nPeran: ${state.role.toUpperCase()}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Checkmark Animation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Akun Berhasil Dibuat!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kredensial berikut hanya ditampilkan sekali untuk keamanan. Silakan salin dan berikan kepada pengguna terkait.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Credentials Display Card
          Card(
            color: AppColors.surfaceVariant.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildCredentialRow('Nama Lengkap', state.name, theme),
                  const Divider(height: 20),
                  _buildCredentialRow('Alamat Email', state.email, theme),
                  const Divider(height: 20),
                  _buildCredentialRow('Kata Sandi', state.password, theme, isBoldValue: true),
                  const Divider(height: 20),
                  _buildCredentialRow('Peran Akun', state.role.toUpperCase(), theme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: credentialsText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kredensial berhasil disalin ke clipboard!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Salin Kredensial'),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => context.go('/admin/users'),
                    child: const Text(
                      'Ke Daftar',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _resetForm,
                    child: const Text(
                      'Buat Akun Lain',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, ThemeData theme, {bool isBoldValue = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
