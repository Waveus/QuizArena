import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/repositories/UserRepository.dart';
import 'package:flutter_quizarena/services/auth_service.dart';

import 'quiz_seeder.dart';

class Register extends StatefulWidget{
  const Register({
    super.key,
  });
  @override
  State<Register> createState() => _RegisterState(); 
}

class _RegisterState extends State<Register> {
  UserRepository userRepository = UserRepository();
  TextEditingController controllerUsername = TextEditingController();
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

  void register() async {
    try {
      String username = controllerUsername.text;
      bool isUnique = await userRepository.isUsernameUnique(username);
      if(!isUnique) {
        setState(() {
          errorMessage = 'This username is already taken';
        });
        return;
      } 

      await authService.value.createAccount(
        email: controllerEmail.text, 
        password: controllerPassword.text
      );
      String currentUserId = authService.value.currentUser!.uid;

      try {
        await userRepository.createUser(currentUserId, username);
        await QuizSeeder.seedData();
        popPage();
        //Ok
      } catch (e) {
        //Rollback
        await authService.value.currentUser!.delete();
        setState(() {
            errorMessage = 'Cannot save profie data, try again';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
          errorMessage = e.message ?? 'Error';
      });
    } on Exception catch (e)  {
      setState(() {
          errorMessage = 'Unknown exception';
      });
    }
  }

  void popPage() {
    Navigator.pop(context);
  }

@override
  Widget build(BuildContext context) {
    // Zazwyczaj używa się Scaffold jako podstawy ekranu
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
              'Create Account',
              style: TextStyle(
                fontSize: 20.0,
              )),
            SizedBox(height: 32),
            
            TextField(
              controller: controllerUsername,
              decoration: InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.name,
            ),
            SizedBox(height: 16),

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
              onPressed: register,
              child: Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}