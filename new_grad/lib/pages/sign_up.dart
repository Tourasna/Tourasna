import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);
  final Color inputColor = const Color(0xFFEAE2D1);

  final AuthService _authService = AuthService();
  final _picker = ImagePicker();
  File? _avatarFile;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Address (optional)
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();

  // Safety contact (optional)
  final _contactNameController = TextEditingController();
  final _contactRelationController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _termsAccepted = false;

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
    _countryController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _contactNameController.dispose();
    _contactRelationController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: darkColor,
            onPrimary: Colors.white,
            surface: bgColor,
          ),
        ),
        child: child!,
      ),
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
    // Cache avatar path if picked
    if (_avatarFile != null) {
      await prefs.setString('onboarding_avatar_path', _avatarFile!.path);
    }
  }

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
      _showMessage("Please fill in all required fields", error: true);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match", error: true);
      return;
    }

    if (!_termsAccepted) {
      _showMessage("Please accept the Terms & Conditions", error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      await _cacheSignupData();
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

  void _showTermsSheet(BuildContext context) {
    final darkColor = const Color(0xFF1A3C3C);
    final goldColor = const Color(0xFFC5A059);
    final papyrus = const Color(0xFFF2EADC);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: papyrus,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: darkColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: goldColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: goldColor.withOpacity(0.25)),
                      ),
                      child: Icon(
                        Icons.gavel_rounded,
                        color: goldColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontFamily: 'Gambetta',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: darkColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: darkColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                height: 1,
                color: goldColor.withOpacity(0.15),
              ),

              // scrollable content
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  children: [
                    _termsSection(
                      darkColor,
                      goldColor,
                      '1. About Tourathna',
                      'Tourathna is a tourism application providing AI-based monument recognition, 3D model viewing, location-based discovery, personalized recommendations, and user profiles.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '2. User Accounts',
                      'You must provide accurate information and are responsible for securing your account. Accounts involved in abuse or illegal activity may be suspended.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '3. AI Recognition Disclaimer',
                      'AI results are predictions and may not be accurate. Tourathna is not responsible for incorrect outputs.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '4. Location & Map Data',
                      'Location is used to enhance recommendations. We do not guarantee route accuracy or safety.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '5. 3D Models & Media',
                      '3D models are for reference only. Some assets may be inaccurate or unavailable. Reuse or redistribution is prohibited.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '6. User Content',
                      'You grant us permission to store and display submitted content. You must own the rights to what you upload.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '7. Data & Privacy',
                      'Data is handled according to our Privacy Policy. Authentication and storage use secure services.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '8. Limitation of Liability',
                      'Tourathna is not liable for inaccurate tourism information, travel issues, injuries, losses, or third-party services.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '9. Intellectual Property',
                      'All assets and designs belong to Tourathna. Copying or reverse engineering is prohibited.',
                    ),
                    _termsSection(
                      darkColor,
                      goldColor,
                      '10. Contact',
                      'Email: Tourathnahelpcenter@gmail.com',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: goldColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: goldColor.withOpacity(0.20)),
                      ),
                      child: Text(
                        'A simple agreement built on respect.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Gambetta',
                          fontSize: 14,
                          color: darkColor.withOpacity(0.60),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // close button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: darkColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: darkColor.withOpacity(0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'I UNDERSTAND',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsSection(Color dark, Color gold, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gambetta',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              body,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 13,
                color: dark.withOpacity(0.60),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : darkColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: darkColor.withOpacity(0.05)),
                      ),
                      child: Icon(Icons.arrow_back, color: darkColor, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // TITLE
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: 'Gambetta',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join Tourathna and start your journey',
                      style: TextStyle(
                        color: darkColor.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // AVATAR
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: inputColor,
                                border: Border.all(
                                  color: goldColor,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: ClipOval(
                                child: _avatarFile != null
                                    ? Image.file(
                                        _avatarFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        Icons.camera_alt,
                                        size: 32,
                                        color: goldColor.withOpacity(0.6),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: darkColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: bgColor, width: 2),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // IDENTITY FIELDS
                    _inputField(
                      label: 'First Name',
                      hint: 'Enter your first name',
                      controller: _firstNameController,
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      label: 'Last Name',
                      hint: 'Enter your last name',
                      controller: _lastNameController,
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      label: 'Username',
                      hint: 'Choose a username',
                      controller: _usernameController,
                      icon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      label: 'Email Address',
                      hint: 'example@mail.com',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // DATE OF BIRTH
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: _inputField(
                          label: 'Date of Birth',
                          hint: 'DD/MM/YYYY',
                          controller: _dateOfBirthController,
                          icon: Icons.cake_outlined,
                          suffix: Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: darkColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // GENDER DROPDOWN
                    _dropdownField(
                      label: 'Gender',
                      icon: Icons.person_2_outlined,
                      value: _selectedGender,
                      items: ['Male', 'Female'],
                      onChanged: (v) => setState(() => _selectedGender = v),
                    ),
                    const SizedBox(height: 12),

                    // NATIONALITY DROPDOWN
                    _dropdownField(
                      label: 'Nationality',
                      icon: Icons.flag_outlined,
                      value: _selectedNationality,
                      items: nationalities,
                      onChanged: (v) =>
                          setState(() => _selectedNationality = v),
                    ),
                    const SizedBox(height: 12),

                    // PASSWORD
                    _inputField(
                      label: 'Password',
                      hint: 'Minimum 8 characters',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: !_passwordVisible,
                      suffix: GestureDetector(
                        onTap: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        child: Icon(
                          _passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: darkColor.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CONFIRM PASSWORD
                    _inputField(
                      label: 'Confirm Password',
                      hint: 'Repeat password',
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      obscureText: !_confirmVisible,
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _confirmVisible = !_confirmVisible),
                        child: Icon(
                          _confirmVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: darkColor.withOpacity(0.4),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // TERMS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _termsAccepted = !_termsAccepted),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: goldColor),
                              color: _termsAccepted
                                  ? darkColor
                                  : Colors.transparent,
                            ),
                            child: _termsAccepted
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showTermsSheet(context),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: darkColor.withOpacity(0.7),
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: goldColor,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: goldColor,
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: goldColor,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: goldColor,
                                    ),
                                  ),
                                  const TextSpan(text: ' of Tourathna.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ), //

                    const SizedBox(height: 24),

                    // SUBMIT
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // LOGIN LINK
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: darkColor.withOpacity(0.6),
                          ),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                ),
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: goldColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                    decorationColor: goldColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── INPUT FIELD ────────────────────────────────
  Widget _inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    bool isRed = false,
  }) {
    final accentColor = isRed ? Colors.red.shade300 : goldColor;
    final iconBg = isRed ? Colors.red.shade50 : Colors.white.withOpacity(0.4);

    return Container(
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: darkColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: darkColor.withOpacity(0.5),
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: TextStyle(
                    color: darkColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: darkColor.withOpacity(0.3),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 8),
                  ),
                ),
              ],
            ),
          ),
          if (suffix != null)
            Padding(padding: const EdgeInsets.only(right: 16), child: suffix),
        ],
      ),
    );
  }

  // ── DROPDOWN FIELD ─────────────────────────────
  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: darkColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: goldColor, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: darkColor.withOpacity(0.5),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    hint: Text(
                      'Select...',
                      style: TextStyle(
                        color: darkColor.withOpacity(0.3),
                        fontSize: 13,
                      ),
                    ),
                    isExpanded: true,
                    isDense: true,
                    style: TextStyle(
                      color: darkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: darkColor.withOpacity(0.4),
                      size: 18,
                    ),
                    items: items
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  // ── ACCORDION ──────────────────────────────────
  Widget _accordion({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
    bool isRed = false,
  }) {
    final borderColor = isRed
        ? Colors.red.withOpacity(0.2)
        : goldColor.withOpacity(0.2);
    final headerBg = isRed
        ? Colors.red.shade50.withOpacity(0.4)
        : goldColor.withOpacity(0.05);
    final titleColor = isRed ? Colors.red : goldColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(24),
                  bottom: isExpanded ? Radius.zero : const Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: titleColor,
                        ),
                      ),
                      if (isRed) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.red,
                        ),
                      ],
                    ],
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: titleColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(children: children),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
