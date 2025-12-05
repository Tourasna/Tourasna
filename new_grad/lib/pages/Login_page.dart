import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _msg("Enter your email first");
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      _msg("Password reset link sent");
    } catch (e) {
      _msg("Error: $e", error: true);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;
      if (user == null) {
        _msg("Login failed.", error: true);
        return;
      }

      final userData = await supabase
          .from('profiles')
          .select('first_login')
          .eq('id', user.id)
          .maybeSingle();

      final bool firstLogin = userData?['first_login'] ?? true;

      if (firstLogin) {
        Navigator.pushReplacementNamed(context, '/terms');
      } else {
        Navigator.pushReplacementNamed(context, '/homescreen');
      }
    } on AuthException catch (e) {
      _msg(e.message, error: true);
    } catch (e) {
      _msg("Login failed. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF5E5D1),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 44),

              const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Image(
                    image: AssetImage('assets/images/loginnn.png'),
                    width: 342,
                    height: 333,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter Email' : null,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter Email',
                        hintStyle: const TextStyle(color: Colors.black26),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      obscuringCharacter: '*',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter Password'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter Password',
                        hintStyle: const TextStyle(color: Colors.black26),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isLoading ? null : _signIn,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        Icon(Icons.facebook, color: Colors.blue, size: 35),
                        Icon(Icons.share, color: Colors.red, size: 35),
                        Icon(Icons.mail, color: Colors.black, size: 35),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.black45),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
