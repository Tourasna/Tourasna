import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class _C {
  static const papyrus = Color(0xFFF2EADC);
  static const teal = Color(0xFF1A3C3C);
  static const gold = Color(0xFFC5A059);
  static const surface = Color(0xFFEAE2D1);
  static const glass = Color(0x66FFFFFF);
  static const glassBorder = Color(0x33C5A059);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _ornamentCtrl;

  @override
  void initState() {
    super.initState();
    _ornamentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ornamentCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── auth ──────────────────────────────────────
  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _msg('Enter your email first', error: true);
      return;
    }
    try {
      await _authService.resetPassword(email);
      _msg('Password reset email sent');
    } catch (e) {
      _msg(e.toString(), error: true);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      final res = await ApiClient.get('/api/profiles/me');
      if (res.statusCode != 200) throw Exception('Failed to load profile');
      final profile = jsonDecode(res.body);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        profile['first_name'] == null ? '/preferences' : '/homescreen',
      );
    } catch (e) {
      _msg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );

  TextStyle get _serif => const TextStyle(
    fontFamily: 'Gambetta',
    fontWeight: FontWeight.w700,
    color: _C.teal,
  );
  TextStyle get _sans => const TextStyle(fontFamily: 'Satoshi', color: _C.teal);

  // ── build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.papyrus,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildTopOrnament(),
                const SizedBox(height: 20),
                _buildHeading(),
                const SizedBox(height: 32),
                _buildCard(),
                const SizedBox(height: 28),
                _buildRegisterRow(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── top ornament line ─────────────────────────
  Widget _buildTopOrnament() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 64, height: 1, color: _C.gold.withValues(alpha: 0.40)),
        const SizedBox(width: 10),
        RotationTransition(
          turns: _ornamentCtrl,
          child: Text(
            '✦',
            style: _sans.copyWith(
              color: _C.gold.withValues(alpha: 0.60),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 64, height: 1, color: _C.gold.withValues(alpha: 0.40)),
      ],
    );
  }

  // ── heading ───────────────────────────────────
  Widget _buildHeading() {
    return Column(
      children: [
        Text(
          'Welcome Back',
          style: _serif.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'CONTINUE YOUR DISCOVERY WITH TOURATHNA',
          textAlign: TextAlign.center,
          style: _sans.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: _C.teal.withValues(alpha: 0.50),
          ),
        ),
      ],
    );
  }

  // ── glass card ────────────────────────────────
  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.glass,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _C.glassBorder),
        boxShadow: [
          BoxShadow(
            color: _C.teal.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInputField(
            label: 'Email Address',
            hint: 'email@domain.com',
            controller: _emailCtrl,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your email' : null,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Password',
            hint: '••••••••',
            controller: _passwordCtrl,
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _C.teal.withValues(alpha: 0.35),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 16),
          // remember me + forgot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildCheckbox(),
                  const SizedBox(width: 8),
                  Text(
                    'Remember Me',
                    style: _sans.copyWith(
                      fontSize: 12,
                      color: _C.teal.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _resetPassword,
                child: Text(
                  'Forgot Password?',
                  style: _sans.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _C.gold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _C.gold.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          _buildLoginButton(),
        ],
      ),
    );
  }

  // ── input field ───────────────────────────────
  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: _sans.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: _C.gold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: _sans.copyWith(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _sans.copyWith(
              fontSize: 14,
              color: _C.teal.withValues(alpha: 0.30),
            ),
            filled: true,
            fillColor: _C.surface.withValues(alpha: 0.50),
            prefixIcon: Container(
              margin: const EdgeInsets.all(6),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _C.teal, size: 18),
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: _C.teal.withValues(alpha: 0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: _C.teal.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: _C.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ── checkbox ──────────────────────────────────
  bool _rememberMe = false;
  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _rememberMe = !_rememberMe),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: _rememberMe ? _C.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: _rememberMe ? _C.teal : _C.gold.withValues(alpha: 0.40),
          ),
        ),
        child: _rememberMe
            ? const Icon(Icons.check, color: Colors.white, size: 13)
            : null,
      ),
    );
  }

  // ── login button ──────────────────────────────
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 60,
        decoration: BoxDecoration(
          color: _isLoading ? _C.teal.withValues(alpha: 0.55) : _C.teal,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _C.teal.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else ...[
              Text(
                'Sign-In',
                style: _sans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, color: _C.gold, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  // ── divider ───────────────────────────────────

  // ── register row ──────────────────────────────
  Widget _buildRegisterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New explorer? ',
          style: _sans.copyWith(
            fontSize: 13,
            color: _C.teal.withValues(alpha: 0.55),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/signup'),
          child: Text(
            'Register',
            style: _sans.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.gold,
              decoration: TextDecoration.underline,
              decorationColor: _C.gold.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}
