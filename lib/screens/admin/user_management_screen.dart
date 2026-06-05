import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../blocs/admin/user_management_cubit.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../config/theme/app_colors.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserManagementCubit>(
      create: (context) => UserManagementCubit(
        firestoreService: context.read<FirestoreService>(),
      )..loadUsers(),
      child: const UserManagementView(),
    );
  }
}

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
      ),
      body: BlocConsumer<UserManagementCubit, UserManagementState>(
        listener: (context, state) {
          if (state is UserManagementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is UserManagementLoading) {
            return const LoadingWidget(message: 'Memuat daftar pengguna...');
          }

          if (state is UserManagementError && state.message.contains('Gagal memuat')) {
            return AppErrorWidget(
              errorMessage: state.message,
              onRetry: () => context.read<UserManagementCubit>().loadUsers(),
            );
          }

          if (state is UserManagementLoaded) {
            return Column(
              children: [
                // Search & Filter Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          context.read<UserManagementCubit>().updateFilters(search: value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau email...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    context.read<UserManagementCubit>().updateFilters(search: '');
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter Chips
                      Row(
                        children: [
                          _buildFilterChip(
                            context: context,
                            label: 'Semua',
                            roleValue: 'all',
                            currentRole: state.roleFilter,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context: context,
                            label: 'Guru',
                            roleValue: 'guru',
                            currentRole: state.roleFilter,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context: context,
                            label: 'Siswa',
                            roleValue: 'siswa',
                            currentRole: state.roleFilter,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Users List
                Expanded(
                  child: state.filteredUsers.isEmpty
                      ? const EmptyStateWidget(
                          title: 'Pengguna Tidak Ditemukan',
                          description: 'Tidak ada pengguna yang cocok dengan kriteria pencarian.',
                          icon: Icons.person_off_rounded,
                        )
                      : RefreshIndicator(
                          onRefresh: () => context.read<UserManagementCubit>().loadUsers(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: state.filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = state.filteredUsers[index];
                              return _buildUserCard(context, user, theme);
                            },
                          ),
                        ),
                ),
              ],
            );
          }

          return const Center(child: Text('Inisialisasi...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/admin/users/create'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required String roleValue,
    required String currentRole,
  }) {
    final isSelected = currentRole == roleValue;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        context.read<UserManagementCubit>().updateFilters(role: roleValue);
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel user, ThemeData theme) {
    final formattedDate = DateFormat('dd MMM yyyy').format(user.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Tap to edit -> goes to edit screen or displays a toast.
          // Since edit screen is implemented in issue 14, we will show a SnackBar or navigate
          // to /admin/users/edit/:id if that's what issue 14 will define.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mengedit user: ${user.name} (Gunakan menu edit/Issue #14)'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onLongPress: () => _showActionMenu(context, user, theme),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // User Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _getRoleColor(user.role, theme).withValues(alpha: 0.1),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(user.role, theme),
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // User Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(
                          text: user.role.toUpperCase(),
                          color: _getRoleColor(user.role, theme).withValues(alpha: 0.15),
                          textColor: _getRoleColor(user.role, theme),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Terdaftar: $formattedDate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        _buildBadge(
                          text: user.isActive ? 'AKTIF' : 'NONAKTIF',
                          color: user.isActive
                              ? AppColors.successContainer
                              : theme.colorScheme.errorContainer,
                          textColor: user.isActive
                              ? AppColors.onSuccessContainer
                              : theme.colorScheme.onErrorContainer,
                        ),
                      ],
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

  Widget _buildBadge({
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getRoleColor(String role, ThemeData theme) {
    switch (role) {
      case 'admin':
        return theme.colorScheme.error;
      case 'guru':
        return theme.colorScheme.primary;
      case 'siswa':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.secondary;
    }
  }

  void _showActionMenu(BuildContext context, UserModel user, ThemeData theme) {
    final cubit = context.read<UserManagementCubit>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    user.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                    color: user.isActive ? theme.colorScheme.error : AppColors.success,
                  ),
                  title: Text(
                    user.isActive ? 'Nonaktifkan Pengguna' : 'Aktifkan Pengguna',
                    style: TextStyle(
                      color: user.isActive ? theme.colorScheme.error : AppColors.success,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    cubit.toggleUserStatus(user);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit Data Pengguna'),
                  onTap: () {
                    Navigator.pop(context);
                    // Edit action SnackBar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Edit ${user.name} (Implementasi di Issue #14)'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                  title: Text(
                    'Hapus Pengguna',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, user, cubit, theme);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    UserModel user,
    UserManagementCubit cubit,
    ThemeData theme,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Pengguna?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menghapus akun "${user.name}" dari basis data?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PENTING: Aksi ini hanya menghapus dokumen di Firestore. Anda harus menghapus akun Authentication dari Firebase Console secara manual jika ingin menghapus akses loginnya sepenuhnya.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                cubit.deleteUser(user.uid);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
}
