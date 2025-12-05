import 'package:flutter/material.dart';
import 'package:new_grad/ai/landmark_classifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_grad/pages/favs.dart';
import 'package:new_grad/pages/terms_and_conditions.dart';
import 'package:new_grad/pages/done.dart';
import 'package:new_grad/pages/home_page.dart';
import 'package:new_grad/pages/sign_up.dart';
import 'package:new_grad/pages/start_page.dart';
import 'package:new_grad/pages/Login_page.dart';
import 'package:new_grad/pages/welcome_page.dart';
import 'package:new_grad/pages/preferences_page.dart';
import 'package:new_grad/pages/cahtbot_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://puipdzlgcspiyzyvwjwy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1aXBkemxnY3NwaXl6eXZ3and5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MTMwOTEsImV4cCI6MjA3OTk4OTA5MX0.IFxtxOGy7dFQH-HT8FWn8S0eiCyMtEQXFFbcD1GeMmQ',
  );
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
        '/done': (context) => const DonePage(),
        '/chatbot': (context) => const ChatbotPage(),
        '/favs': (context) => const FavsPage(),
      },
    );
  }
}
