import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  // NEW FIELDS
  String? _selectedGender;
  String? _selectedNationality;

  final List<String> nationalities = [
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
    "Netherlands",
    "Sweden",
    "Switzerland",
    "Austria",
    "Belgium",
    "Poland",
    "Czech Republic",
    "Turkey",
    "India",
    "South Africa",
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text =
        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim();
    final dob = _dateOfBirthController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        username.isEmpty ||
        dob.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        _selectedGender == null ||
        _selectedNationality == null) {
      _message("Please fill in all fields");
      return;
    }

    if (password != confirmPassword) {
      _message("Passwords do not match", error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      final authRes = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final signInRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = signInRes.user;
      if (user == null) throw Exception("Could not create user session.");

      await supabase.from('profiles').insert({
        'id': user.id,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'dob': dob,
        'email': email,
        'gender': _selectedGender,
        'nationality': _selectedNationality,
        'first_login': true,
        'preferences': [],
      });

      _message("Account created!");

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _message("Signup failed: $e", error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String msg, {bool error = false}) {
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
    final focusedBorder = const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Colors.black, width: 1),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ORIGINAL PROFILE AVATAR — NOT MODIFIED
                        Center(
                          child: Stack(
                            children: [
                              const CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.black,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.black,
                                  ),
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

                        // NEW: Gender dropdown
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

                        // NEW: Nationality dropdown
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

                        const Spacer(),
                        const SizedBox(height: 30),

                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.black,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _loading ? null : _signUp,
                              borderRadius: BorderRadius.circular(10),
                              child: Center(
                                child: _loading
                                    ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                    : const Text(
                                  "Next",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Already have an Account?",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                  Navigator.pushNamed(context, '/login');
                                },
                                child: const Text(
                                  "Sign-in",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 15,
            ),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            border: enabledBorder,
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
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
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 15,
                ),
                enabledBorder: enabledBorder,
                focusedBorder: focusedBorder,
                border: enabledBorder,
                suffixIcon: const Icon(
                  Icons.calendar_today,
                  color: Colors.grey,
                ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 12,
            ),
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
            border: enabledBorder,
          ),
          icon: const Icon(Icons.arrow_drop_down),
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(e),
            ),
          )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
