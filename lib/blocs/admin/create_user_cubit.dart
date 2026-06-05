import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

// States
abstract class CreateUserState extends Equatable {
  const CreateUserState();

  @override
  List<Object?> get props => [];
}

class CreateUserInitial extends CreateUserState {
  const CreateUserInitial();
}

class CreateUserLoading extends CreateUserState {
  const CreateUserLoading();
}

class CreateUserSuccess extends CreateUserState {
  final String name;
  final String email;
  final String password;
  final String role;

  const CreateUserSuccess({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [name, email, password, role];
}

class CreateUserError extends CreateUserState {
  final String message;

  const CreateUserError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class CreateUserCubit extends Cubit<CreateUserState> {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  CreateUserCubit({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService,
        super(const CreateUserInitial());

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    emit(const CreateUserLoading());
    try {
      // 1. Create auth credentials using dynamic tempApp
      final userCredential = await _authService.createUserAccount(email, password);
      final uid = userCredential.user?.uid;
      
      if (uid == null) {
        throw Exception('Gagal mendapatkan UID dari Firebase Authentication.');
      }

      // 2. Create UserModel & save to Firestore
      final newUser = UserModel(
        uid: uid,
        name: name,
        email: email,
        role: role,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _firestoreService.addDocument(
        path: FirestoreService.usersPath,
        docId: uid,
        data: newUser.toJson(),
      );

      emit(CreateUserSuccess(
        name: name,
        email: email,
        password: password,
        role: role,
      ));
    } catch (e) {
      emit(CreateUserError(_parseError(e)));
    }
  }

  void reset() {
    emit(const CreateUserInitial());
  }

  String _parseError(dynamic e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('email-already-in-use')) {
      return 'Alamat email sudah terdaftar oleh pengguna lain.';
    } else if (errStr.contains('invalid-email')) {
      return 'Format alamat email tidak valid.';
    } else if (errStr.contains('weak-password')) {
      return 'Kata sandi terlalu lemah.';
    }
    return e.toString();
  }
}
