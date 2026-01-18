import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:new_grad/ai/landmark_classifier.dart';
import 'package:new_grad/pages/favs.dart';
import 'package:new_grad/pages/profile_page.dart';
import 'package:new_grad/pages/terms_and_conditions.dart';
import 'package:new_grad/pages/done.dart';
import 'package:new_grad/pages/home_page.dart';
import 'package:new_grad/pages/sign_up.dart';
import 'package:new_grad/pages/start_page.dart';
import 'package:new_grad/pages/Login_page.dart';
import 'package:new_grad/pages/welcome_page.dart';
import 'package:new_grad/pages/preferences_page.dart';
import 'package:new_grad/pages/chatbot_page.dart';
import 'package:new_grad/pages/chatmock_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase init
  await Firebase.initializeApp();

  // 🧠 Load ML model once
  final classifier = LandmarkClassifier();
  await classifier.loadModel();

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
      routes: {
        '/start': (context) => const FirstPage(),
        '/home': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/preferences': (context) => const PreferencesPage(),
        '/homescreen': (context) => const HomePage(),
        '/terms': (context) => const TermsAndConditions(),
        '/profile': (context) => const ProfilePage(),
        '/done': (context) => const DonePage(),
        '/chatbot': (context) => const ChatbotPage(),
        '/favs': (context) => const FavsPage(),
        '/mocka': (context) => ChatMockPage(authService: authService),
      },
    );
  }
}
