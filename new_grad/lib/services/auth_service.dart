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

    // Initial token fetch
    _idToken = await cred.user!.getIdToken(true);
  }

  // ─────────────────────────────────────────────
  // ALWAYS GET A FRESH ID TOKEN
  // ─────────────────────────────────────────────
  Future<String?> getValidToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    _idToken = await user.getIdToken(true);
    return _idToken;
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
