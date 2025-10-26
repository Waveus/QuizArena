import 'dart:math';
<<<<<<< HEAD
//Rumun cwel
=======

  //Conflict
  //Conflict
>>>>>>> c7e93eaf4c486605c7072565910360350ba7e4c1
import 'package:cloud_firestore/cloud_firestore.dart';
  //Conflict
    //Conflict
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/services/auth_service.dart';
  //Conflict
import 'package:flutter/material.dart';

//Konflikt
  //Conflict
class Me extends StatefulWidget {
  const Me({super.key});
  //Conflict
  @override
  State<Me> createState() => _MeState();
}

class _MeState extends State<Me> {
  String _userName = 'User';
  bool _isLoadingName = true;
    //Conflict
  @override
  void initState() {
    super.initState();
    loadUserName();
  }

  //Conflict

  Future<void> signOut() async {
    try {
        await authService.value.signOut();
    } on FirebaseException catch (e) {
      print(e);
    }
  }

  void loadUserName() async {
    await Future.delayed(const Duration(milliseconds: 500)); 
    //TODO Prawidzwe fetchowane z bazy ogniowej
    if (mounted) {
      setState(() {
        _userName = 'Alicja';
        _isLoadingName = false;
      });
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
        String email = authService.value.currentUser!.email!;
        await authService.value.resetPasswordFromCurrentPassword(currentPassword: oldPassword, newPassword: newPassword, email: email);
    } on FirebaseException catch (e) {
      print(e);
      rethrow;
    }
  }

    Future<void> deleteAccount(String email, String password) async {
    try {
        String email = authService.value.currentUser!.email!;
        await authService.value.deleteAccount(email: email, password: password);
    } on FirebaseException catch (e) {
      print(e);
      rethrow;
    }
  }
  
  void showLogoutConfirmationDialog() {

    String statusMessage = '';
    final BuildContext safeContext = context;

    showDialog(
      context: safeContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign out confirmation'),
          content: const Text('Do you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                try {
                  signOut();
                  statusMessage = 'Succesfully sign out';
                } on FirebaseException catch (e) {
                  statusMessage = e.toString();
                } 
                if(safeContext.mounted){
                  ScaffoldMessenger.of(safeContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        statusMessage
                      ), 
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void showChangeUsernameDialog() {

  final TextEditingController nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Change Username'),
        content: TextField(controller: nameController),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'TODO: Add username change ${nameController.text}'
                  ), 
                  duration: Duration(seconds: 3),
                ),
              );
              //TODO: Change Username in bazie ogniowej
            },
            child: const Text('Change username'),
          ),
          ],
        );
      },
    );
  }

  void showChangePasswordDialog() {
  String statusMessage = '';
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final BuildContext safeContext = context;

  showDialog(
    context: safeContext,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[   
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline)
              ),
              ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline)
              ),
              ),
            ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                  await changePassword(
                    oldPasswordController.text, 
                    newPasswordController.text
                  );
                  statusMessage = 'Password Succesfully Changed';
              } on FirebaseException catch (e){
                statusMessage = e.toString();
              }
                if(safeContext.mounted){
                  ScaffoldMessenger.of(safeContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        statusMessage
                      ), 
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
            },
            child: const Text('Change password'),
          ),
          ],
        );
      },
    );
  }

  void showDeleteAccountDialog() {

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String statusMessage = '';
  final BuildContext safeContext = context;

  showDialog(
    context: safeContext,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[   
            TextField(
              controller: emailController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.lock_outline)
              ),
              ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline)
              ),
              ),
            ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await deleteAccount(
                    emailController.text, 
                    passwordController.text
                  );
                  statusMessage = 'Account Succesfully Deleted';
              } on FirebaseException catch (e){
                statusMessage = e.toString();
              }
              if(safeContext.mounted) {
                ScaffoldMessenger.of(safeContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      statusMessage
                    ), 
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Delete Account'),
          ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: <Widget>[
            if (_isLoadingName)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                'Welcome, $_userName!',
                style: const TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            const Spacer(), 

            ElevatedButton(
              onPressed: showChangeUsernameDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'Change Username',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: showChangePasswordDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'Change Password',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: showLogoutConfirmationDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: showDeleteAccountDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'DELETE ACCOUNT',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
