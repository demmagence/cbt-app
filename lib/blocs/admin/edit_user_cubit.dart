import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

// States
abstract class EditUserState extends Equatable {
  const EditUserState();

  @override
  List<Object?> get props => [];
}

class EditUserInitial extends EditUserState {
  const EditUserInitial();
}

class EditUserLoading extends EditUserState {
  const EditUserLoading();
}

class EditUserLoaded extends EditUserState {
  final UserModel user;
  final bool isSubmitting;

  const EditUserLoaded(this.user, {this.isSubmitting = false});

  EditUserLoaded copyWith({UserModel? user, bool? isSubmitting}) {
    return EditUserLoaded(
      user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [user, isSubmitting];
}

class EditUserSuccess extends EditUserState {
  final String message;
  final UserModel? user;

  const EditUserSuccess(this.message, {this.user});

  @override
  List<Object?> get props => [message, user];
}

class EditUserError extends EditUserState {
  final String message;

  const EditUserError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class EditUserCubit extends Cubit<EditUserState> {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  EditUserCubit({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService,
        super(const EditUserInitial());

  Future<void> loadUser(String uid, {UserModel? initialUser}) async {
    if (initialUser != null) {
      emit(EditUserLoaded(initialUser));
      return;
    }

    emit(const EditUserLoading());
    try {
      final user = await _firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: uid,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (user == null) {
        emit(const EditUserError('Pengguna tidak ditemukan.'));
        return;
      }

      emit(EditUserLoaded(user));
    } catch (e) {
      emit(EditUserError('Gagal memuat pengguna: ${e.toString()}'));
    }
  }

  Future<void> updateUser({
    required String uid,
    required String name,
    required String role,
    required bool isActive,
  }) async {
    final currentState = state;
    if (currentState is! EditUserLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));
    try {
      final updatedData = {
        'name': name,
        'role': role,
        'isActive': isActive,
      };

      await _firestoreService.updateDocument(
        path: FirestoreService.usersPath,
        docId: uid,
        data: updatedData,
      );

      final updatedUser = currentState.user.copyWith(
        name: name,
        role: role,
        isActive: isActive,
      );

      emit(EditUserSuccess('Data pengguna berhasil diperbarui.', user: updatedUser));
    } catch (e) {
      emit(EditUserError('Gagal memperbarui data: ${e.toString()}'));
      // Restore loaded state
      emit(currentState.copyWith(isSubmitting: false));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final currentState = state;
    if (currentState is! EditUserLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));
    try {
      await _authService.sendPasswordResetEmail(email);
      emit(const EditUserSuccess('Email reset sandi berhasil dikirim ke pengguna.'));
      // Restore loaded state
      emit(currentState.copyWith(isSubmitting: false));
    } catch (e) {
      emit(EditUserError('Gagal mengirim email reset sandi: ${e.toString()}'));
      // Restore loaded state
      emit(currentState.copyWith(isSubmitting: false));
    }
  }

  Future<void> deactivateUser(String uid) async {
    final currentState = state;
    if (currentState is! EditUserLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));
    try {
      await _firestoreService.updateDocument(
        path: FirestoreService.usersPath,
        docId: uid,
        data: {'isActive': false},
      );

      final updatedUser = currentState.user.copyWith(isActive: false);
      emit(EditUserSuccess('Pengguna berhasil dinonaktifkan.', user: updatedUser));
    } catch (e) {
      emit(EditUserError('Gagal menonaktifkan pengguna: ${e.toString()}'));
      // Restore loaded state
      emit(currentState.copyWith(isSubmitting: false));
    }
  }
}
