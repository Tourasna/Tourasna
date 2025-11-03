import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:new_grad/Terms_and_conditions.dart';
import 'package:new_grad/home_page.dart';
import 'package:new_grad/sign_up.dart';
import 'package:new_grad/start_page.dart';
import 'package:new_grad/Login_page.dart';
import 'package:new_grad/OTP_page.dart';
import 'package:new_grad/welcome_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tourasna',
      theme: ThemeData(primarySwatch: Colors.blue),

      initialRoute: '/start',

      // ✅ All registered routes
      routes: {
        '/start': (context) => const FirstPage(),
        '/home': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/otp': (context) => const OTPPage(),
        '/signup': (context) => const SignUpPage(),
        '/homescreen': (context) => const HomePage(),
      },
    );
  }
}
