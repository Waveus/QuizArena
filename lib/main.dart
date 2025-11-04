import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_quizarena/auth_layout.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const MyApp()); // Uruchom aplikację po ustawieniu orientacji
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizArena',
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 24, 24, 24),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal, // Używamy turkusowego akcentu
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 24, 24, 24), // Tło AppBar minimalnie jaśniejsze
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: AuthLayout()
    );
  }
}

