import 'dart:async';
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
  StreamSubscription<UserModel?>? _profile;
  String? _watchedUid;

  AuthBloc({required this.authService, required this.firestoreService})
    : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthProfileChanged>((event, emit) async {
      if (event.uid != _watchedUid) {
        return;
      }
      if (event.user == null || !event.user!.isActive) {
        _watchedUid = null;
        _profile?.cancel();
        await authService.signOut();
        emit(const AuthUnauthenticated());
      } else {
        emit(AuthAuthenticated(event.user!));
      }
    });
  }

  void _watchProfile(String uid) {
    _watchedUid = uid;
    _profile?.cancel();
    _profile = firestoreService
        .streamDocument<UserModel>(
          path: FirestoreService.usersPath,
          docId: uid,
          fromJson: (json, id) => UserModel.fromJson({...json, 'uid': id}),
        )
        .listen(
          (user) {
            if (!isClosed) {
              add(AuthProfileChanged(user, uid));
            }
          },
          onError: (Object _) {
            if (!isClosed) {
              add(AuthProfileChanged(null, uid));
            }
          },
        );
  }

  @override
  Future<void> close() async {
    await _profile?.cancel();
    return super.close();
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final uid = authService.getCurrentUid();
      if (uid == null) {
        emit(const AuthUnauthenticated());
        return;
      }

      final userModel = await firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: uid,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (userModel != null && userModel.isActive) {
        emit(AuthAuthenticated(userModel));
        _watchProfile(uid);
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
      final uid = await authService.signIn(event.email, event.password);

      final userModel = await firestoreService.getDocument<UserModel>(
        path: FirestoreService.usersPath,
        docId: uid,
        fromJson: (json, id) => UserModel.fromJson(json),
      );

      if (userModel == null) {
        await authService.signOut();
        emit(const AuthError('Data user tidak ditemukan di database.'));
        return;
      }

      if (!userModel.isActive) {
        await authService.signOut();
        emit(
          const AuthError('Akun Anda dinonaktifkan. Silakan hubungi Admin.'),
        );
        return;
      }

      emit(AuthAuthenticated(userModel));
      _watchProfile(uid);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat login.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Email atau password salah.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Akun ini telah dinonaktifkan.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'too-many-requests') {
        errorMessage =
            'Terlalu banyak percobaan masuk yang gagal. Silakan coba beberapa saat lagi.';
      } else if (e.code == 'network-request-failed') {
        errorMessage =
            'Koneksi internet terputus. Silakan periksa jaringan Anda.';
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
      _watchedUid = null;
      _profile?.cancel();
      _profile = null;
      await authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Gagal keluar: ${e.toString()}'));
    }
  }
}
