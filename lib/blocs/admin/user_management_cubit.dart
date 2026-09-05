import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// States
abstract class UserManagementState extends Equatable {
  const UserManagementState();

  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {
  const UserManagementInitial();
}

class UserManagementLoading extends UserManagementState {
  const UserManagementLoading();
}

class UserManagementLoaded extends UserManagementState {
  final List<UserModel> allUsers;
  final List<UserModel> filteredUsers;
  final String searchQuery;
  final String roleFilter; // 'all' | 'guru' | 'siswa'

  const UserManagementLoaded({
    required this.allUsers,
    required this.filteredUsers,
    required this.searchQuery,
    required this.roleFilter,
  });

  UserManagementLoaded copyWith({
    List<UserModel>? allUsers,
    List<UserModel>? filteredUsers,
    String? searchQuery,
    String? roleFilter,
  }) {
    return UserManagementLoaded(
      allUsers: allUsers ?? this.allUsers,
      filteredUsers: filteredUsers ?? this.filteredUsers,
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: roleFilter ?? this.roleFilter,
    );
  }

  @override
  List<Object?> get props => [allUsers, filteredUsers, searchQuery, roleFilter];
}

class UserManagementError extends UserManagementState {
  final String message;

  const UserManagementError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class UserManagementCubit extends Cubit<UserManagementState> {
  final FirestoreService _firestoreService;

  UserManagementCubit({required FirestoreService firestoreService})
    : _firestoreService = firestoreService,
      super(const UserManagementInitial());

  Future<void> loadUsers() async {
    emit(const UserManagementLoading());
    try {
      final users = await _firestoreService.getCollection<UserModel>(
        path: FirestoreService.usersPath,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      // Sort alphabetically by name
      users.removeWhere((user) => user.deleted);
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      emit(
        UserManagementLoaded(
          allUsers: users,
          filteredUsers: users,
          searchQuery: '',
          roleFilter: 'all',
        ),
      );
    } catch (e) {
      emit(UserManagementError('Gagal memuat pengguna: ${e.toString()}'));
    }
  }

  void updateFilters({String? search, String? role}) {
    final currentState = state;
    if (currentState is! UserManagementLoaded) {
      return;
    }

    final newSearchQuery = search ?? currentState.searchQuery;
    final newRoleFilter = role ?? currentState.roleFilter;

    final filtered = currentState.allUsers.where((user) {
      // 1. Role filter
      final matchesRole = newRoleFilter == 'all' || user.role == newRoleFilter;

      // 2. Search query filter
      final query = newSearchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);

      return matchesRole && matchesSearch;
    }).toList();

    emit(
      currentState.copyWith(
        filteredUsers: filtered,
        searchQuery: newSearchQuery,
        roleFilter: newRoleFilter,
      ),
    );
  }

  Future<void> toggleUserStatus(UserModel user) async {
    final currentState = state;
    if (currentState is! UserManagementLoaded) {
      return;
    }

    try {
      final updatedStatus = !user.isActive;
      await _firestoreService.updateDocument(
        path: FirestoreService.usersPath,
        docId: user.uid,
        data: {'isActive': updatedStatus},
      );

      // Update the user locally to avoid full re-fetch
      final updatedAllUsers = currentState.allUsers.map((u) {
        return u.uid == user.uid ? u.copyWith(isActive: updatedStatus) : u;
      }).toList();

      emit(currentState.copyWith(allUsers: updatedAllUsers));
      // Re-apply filters with new lists
      updateFilters();
    } catch (e) {
      emit(
        UserManagementError('Gagal mengubah status pengguna: ${e.toString()}'),
      );
    }
  }

  Future<void> deleteUser(String uid) async {
    final currentState = state;
    if (currentState is! UserManagementLoaded) {
      return;
    }

    try {
      await _firestoreService.deleteDocument(
        path: FirestoreService.usersPath,
        docId: uid,
      );

      // Update local list
      final updatedAllUsers = currentState.allUsers
          .where((u) => u.uid != uid)
          .toList();

      emit(currentState.copyWith(allUsers: updatedAllUsers));
      // Re-apply filters with new lists
      updateFilters();
    } catch (e) {
      emit(UserManagementError('Gagal menghapus pengguna: ${e.toString()}'));
    }
  }
}
