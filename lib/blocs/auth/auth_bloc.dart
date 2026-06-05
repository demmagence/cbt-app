import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;
  final FirestoreService firestoreService;

  AuthBloc({
    required this.authService,
    required this.firestoreService,
  })  : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final firebaseUser = authService.getCurrentUser();
      if (firebaseUser == null) {
        emit(const AuthUnauthenticated());
        return;
      }

      final userModel = await firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: firebaseUser.uid,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (userModel != null && userModel.isActive) {
        emit(AuthAuthenticated(userModel));
      } else {
        // If user document is missing or account is inactive, force sign out
        await authService.signOut();
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final userCredential = await authService.signIn(
        event.email,
        event.password,
      );

      if (userCredential.user == null) {
        emit(const AuthError('Login gagal. User tidak valid.'));
        return;
      }

      final userModel = await firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: userCredential.user!.uid,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (userModel == null) {
        await authService.signOut();
        emit(const AuthError('Data user tidak ditemukan di database.'));
        return;
      }

      if (!userModel.isActive) {
        await authService.signOut();
        emit(const AuthError('Akun Anda dinonaktifkan. Silakan hubungi Admin.'));
        return;
      }

      emit(AuthAuthenticated(userModel));
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat login.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Email atau password salah.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Akun ini telah dinonaktifkan.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Terlalu banyak percobaan masuk yang gagal. Silakan coba beberapa saat lagi.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Koneksi internet terputus. Silakan periksa jaringan Anda.';
      }
      emit(AuthError(errorMessage));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Gagal keluar: ${e.toString()}'));
    }
  }
}
