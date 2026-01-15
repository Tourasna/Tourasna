import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _idToken;

  String? get token => _idToken;

  // ─────────────────────────────────────────────
  // SIGN UP
  // ─────────────────────────────────────────────
  Future<void> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user!.sendEmailVerification();
  }

  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (!cred.user!.emailVerified) {
      throw Exception('Email not verified');
    }

    // Force refresh to always get a valid ID token
    _idToken = await cred.user!.getIdToken(true);
  }

  // ─────────────────────────────────────────────
  // RESET PASSWORD
  // ─────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────
  Future<void> logout() async {
    _idToken = null;
    await _auth.signOut();
  }
}
