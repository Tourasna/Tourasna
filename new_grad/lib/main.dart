import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:new_grad/ai/landmark_classifier.dart';
import 'package:new_grad/interactive_map_feature.dart';
import 'package:new_grad/pages/agenda_page.dart';
import 'package:new_grad/pages/discovery_page.dart';
import 'package:new_grad/pages/favs.dart';
import 'package:new_grad/pages/hieroglyph_translator_page.dart';
import 'package:new_grad/pages/profile_page.dart';
import 'package:new_grad/pages/storytelling_page.dart';
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
import 'package:new_grad/pages/offline_page.dart';

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
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/preferences': (context) => const PreferencesPage(),
        '/homescreen': (context) => const HomePage(),
        '/storytelling': (context) => const StorytellingPage(),
        '/terms': (context) => const TermsAndConditions(),
        '/profile': (context) => const ProfilePage(),
        '/done': (context) => const DonePage(),
        '/chatbot': (context) => const ChatbotPage(),
        '/favs': (context) => const FavsPage(),
        '/mocka': (context) => ChatMockPage(),
        '/hieroglyph': (context) => HieroglyphTranslatorPage(),
        '/discovery': (context) => const DiscoveryPage(),
        '/agenda': (context) => AgendaPage(),
        '/offline': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return OfflinePage(
            returnRoute: args?['returnRoute'] ?? '/homescreen',
            returnArguments: args?['returnArguments'],
          );
        },
        '/interactive_map': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final placeIds = args?['placeIds'] as List<String>? ?? [];

          return InteractiveMapScreen(placeIds: placeIds);
        },
      },
    );
  }
}
