import 'package:flutter/material.dart';
import 'package:flutter_quizarena/login.dart';
import 'package:flutter_quizarena/register.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  Widget build(BuildContext context){
    return Scaffold (
        appBar: AppBar(
          title: const Text("Quiz Arena"),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centrowanie pionowe
            children: <Widget>[
              Image.asset(
                'assets/logo.png',
                height: 250,
              ),
              const SizedBox(height: 50), // Odstęp

              // Przycisk 1: Getting Started (do Register)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: ElevatedButton(
                  onPressed: () {
                    // Przejście do RegisterScreen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const Register(), // Użyj swojej klasy Register
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50), // Przycisk na całą szerokość
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              // Przycisk 2: Login (do Login)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: OutlinedButton(
                  onPressed: () {
                    // Przejście do LoginScreen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const Login(), // Użyj swojej klasy Login
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50), // Przycisk na całą szerokość
                  ),
                  child: const Text(
                    "Sign In",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }
}