import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = state.user;
          final role = user.role.toUpperCase();

          return Column(
            children: [
              // User Info Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 24.0,
                  left: 20.0,
                  right: 20.0,
                  bottom: 24.0,
                ),
                color: theme.colorScheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dynamic Menu Items based on role
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (user.role == 'admin') ..._buildAdminMenu(context),
                    if (user.role == 'guru') ..._buildGuruMenu(context),
                    if (user.role == 'siswa') ..._buildSiswaMenu(context),
                  ],
                ),
              ),

              // Logout Button
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  'Keluar',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context); // Close Drawer
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildAdminMenu(BuildContext context) {
    return const [];
  }

  List<Widget> _buildGuruMenu(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.dashboard),
        title: const Text('Dashboard'),
        onTap: () {
          Navigator.pop(context);
          context.go('/guru/dashboard');
        },
      ),
      ListTile(
        leading: const Icon(Icons.assignment),
        title: const Text('Daftar Ujian'),
        onTap: () {
          Navigator.pop(context);
          context.go('/guru/exams');
        },
      ),
      ListTile(
        leading: const Icon(Icons.book),
        title: const Text('Bank Soal'),
        onTap: () {
          Navigator.pop(context);
          context.go('/guru/question-bank');
        },
      ),
      ListTile(
        leading: const Icon(Icons.grade),
        title: const Text('Penilaian Essay'),
        onTap: () {
          Navigator.pop(context);
          context.go('/guru/grading');
        },
      ),
      ListTile(
        leading: const Icon(Icons.live_tv),
        title: const Text('Monitoring Sesi'),
        onTap: () {
          Navigator.pop(context);
          context.go('/guru/monitoring');
        },
      ),
    ];
  }

  List<Widget> _buildSiswaMenu(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.dashboard),
        title: const Text('Dashboard'),
        onTap: () {
          Navigator.pop(context);
          context.go('/siswa/dashboard');
        },
      ),
      ListTile(
        leading: const Icon(Icons.add_circle),
        title: const Text('Ikut Ujian'),
        onTap: () {
          Navigator.pop(context);
          context.go('/siswa/join');
        },
      ),
      ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Riwayat Ujian'),
        onTap: () {
          Navigator.pop(context);
          context.go('/siswa/history');
        },
      ),
      ListTile(
        leading: const Icon(Icons.person),
        title: const Text('Profil Saya'),
        onTap: () {
          Navigator.pop(context);
          context.go('/siswa/profile');
        },
      ),
    ];
  }
}
