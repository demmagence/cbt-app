import 'package:firebase_auth/firebase_auth.dart';
import '../config/firebase_runtime.dart';

abstract class AuthService {
  String? getCurrentUid();
  Future<String> signIn(String email, String password);
  Future<void> signOut();
  Future<void> updatePassword(String newPassword);
  Future<void> sendPasswordResetEmail(String email);
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instanceFor(app: FirebaseRuntime.app);

  // Stream auth state changes
  @override
  String? getCurrentUid() => _auth.currentUser?.uid;

  // Sign in
  @override
  Future<String> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return uid;
  }

  // Sign out
  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // User updates password
  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw Exception('No user is currently signed in.');
    }
  }

  // Send password reset email
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
