import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  String? _selectedGender;
  String? _selectedNationality;

  final List<String> nationalities = [
    "Egypt",
    "United States",
    "United Kingdom",
    "Germany",
    "France",
    "Italy",
    "Spain",
    "Russia",
    "Saudi Arabia",
    "United Arab Emirates",
    "Kuwait",
    "Qatar",
    "Oman",
    "Jordan",
    "Lebanon",
    "China",
    "Japan",
    "South Korea",
    "Canada",
    "Brazil",
    "Australia",
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _dateOfBirthController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATE PICKER
  // ─────────────────────────────────────────────
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      _dateOfBirthController.text =
          "${picked.day.toString().padLeft(2, '0')}/"
          "${picked.month.toString().padLeft(2, '0')}/"
          "${picked.year}";
    }
  }

  Future<void> _cacheSignupData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'onboarding_firstName',
      _firstNameController.text.trim(),
    );
    await prefs.setString(
      'onboarding_lastName',
      _lastNameController.text.trim(),
    );
    await prefs.setString(
      'onboarding_username',
      _usernameController.text.trim(),
    );
    await prefs.setString('onboarding_gender', _selectedGender!);
    await prefs.setString('onboarding_nationality', _selectedNationality!);
    await prefs.setString('onboarding_dob', _dateOfBirthController.text.trim());
  }

  // ─────────────────────────────────────────────
  // SIGN UP (ONLY FIREBASE + VERIFY EMAIL)
  // ─────────────────────────────────────────────
  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _dateOfBirthController.text.isEmpty ||
        _selectedGender == null ||
        _selectedNationality == null) {
      _showMessage("Please fill in all fields", error: true);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match", error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Firebase signup ONLY
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 2️⃣ Cache signup data locally
      await _cacheSignupData();

      // 3️⃣ Inform user
      _showMessage("Account created. Verify your email, then log in.");

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showMessage("Signup failed: $e", error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBackgroundColor = Color(0xFFF5E5D1);
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
    );
    const focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Colors.black, width: 1),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 80, color: Colors.black),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "First Name",
                      "Enter your Name",
                      _firstNameController,
                      enabledBorder,
                      focusedBorder,
                      pageBackgroundColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      "Last Name",
                      "Enter Last Name",
                      _lastNameController,
                      enabledBorder,
                      focusedBorder,
                      pageBackgroundColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                "Username",
                "Enter Unique Name",
                _usernameController,
                enabledBorder,
                focusedBorder,
                pageBackgroundColor,
              ),
              const SizedBox(height: 16),
              _buildDateField(
                "Date of Birth",
                "DD/MM/YYYY",
                _dateOfBirthController,
                enabledBorder,
                focusedBorder,
                pageBackgroundColor,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                "Email Address",
                "Enter your Email",
                _emailController,
                enabledBorder,
                focusedBorder,
                pageBackgroundColor,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: "Gender",
                value: _selectedGender,
                items: const ["Male", "Female"],
                onChanged: (val) => setState(() => _selectedGender = val),
                enabledBorder: enabledBorder,
                focusedBorder: focusedBorder,
                fillColor: pageBackgroundColor,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: "Nationality",
                value: _selectedNationality,
                items: nationalities,
                onChanged: (val) => setState(() => _selectedNationality = val),
                enabledBorder: enabledBorder,
                focusedBorder: focusedBorder,
                fillColor: pageBackgroundColor,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                "Password",
                "Enter your Password",
                _passwordController,
                enabledBorder,
                focusedBorder,
                pageBackgroundColor,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                "Confirm Password",
                "Re-enter your Password",
                _confirmPasswordController,
                enabledBorder,
                focusedBorder,
                pageBackgroundColor,
                obscureText: true,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Next",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
    OutlineInputBorder enabledBorder,
    OutlineInputBorder focusedBorder,
    Color fillColor, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fillColor,
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    String label,
    String hint,
    TextEditingController controller,
    OutlineInputBorder enabledBorder,
    OutlineInputBorder focusedBorder,
    Color fillColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: fillColor,
                enabledBorder: enabledBorder,
                focusedBorder: focusedBorder,
                suffixIcon: const Icon(Icons.calendar_today),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required OutlineInputBorder enabledBorder,
    required OutlineInputBorder focusedBorder,
    required Color fillColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
