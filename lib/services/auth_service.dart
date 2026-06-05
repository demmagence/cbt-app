import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current Firebase Auth user
  User? getCurrentUser() => _auth.currentUser;

  // Sign in
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Admin creates user account without logging out the current admin
  Future<UserCredential> createUserAccount(String email, String password) async {
    final String tempAppName = 'tempApp_${DateTime.now().millisecondsSinceEpoch}';
    final FirebaseApp tempApp = await Firebase.initializeApp(
      name: tempAppName,
      options: Firebase.app().options,
    );
    try {
      final UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } finally {
      await tempApp.delete();
    }
  }

  // User updates password
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw Exception('No user is currently signed in.');
    }
  }
}
