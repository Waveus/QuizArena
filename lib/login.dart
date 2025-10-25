import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/services/auth_service.dart';

class Login extends StatefulWidget{
  const Login({
    super.key,
  });
  @override
  State<Login> createState() => _LoginState(); 
}

class _LoginState extends State<Login> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPassword = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = '';

  @override
  void dispose(){
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  void signIn() async {
    try {
      await authService.value.signIn(email: controllerEmail.text, password: controllerPassword.text);
      popPage();
    } on FirebaseAuthException catch (e) {
      setState(() {
          errorMessage = e.message ?? 'Error';
      });
    }
  }

  void popPage() {
    Navigator.pop(context);
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("QuizArena"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sign in',
              style: TextStyle(
                fontSize: 20.0,
              )),
            SizedBox(height: 32),

            TextField(
              controller: controllerEmail,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),

            TextField(
              controller: controllerPassword,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 8.0,
                color: Color.fromARGB(255, 255, 0, 0)
              ), 
            ),

            ElevatedButton(
              onPressed: signIn,
              child: Text("sign in"),
            ),
          ],
        ),
      ),
    );
  }
}