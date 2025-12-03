import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/repositories/QuizRepository.dart';
import 'package:flutter_quizarena/quiz_edit.dart';

class MeQuizes extends StatefulWidget {
  const MeQuizes({super.key});
  @override
  State<MeQuizes> createState() => _MeQuizesState(); 
}

class _MeQuizesState extends State<MeQuizes> {
  final QuizRepository quizRepository = QuizRepository();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

void showQuizCreateDialog() {

  final TextEditingController nameController = TextEditingController();
  const List<String> accessOptions = ['public', 'private', 'friendsOnly'];
  String selectedAccessType = accessOptions.first; 
  final BuildContext safeContext = context;
  String statusMessage = '';

  showDialog(
    context: safeContext,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Create Quiz'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name of Quiz',
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Access type',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedAccessType,
                    items: accessOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() { 
                          selectedAccessType = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),

              FilledButton(
                onPressed: () async {
                  final quizName = nameController.text.trim();
                  if (quizName.isEmpty) {
                     statusMessage = 'Name cannot be empty';
                  } else {
                    Navigator.of(dialogContext).pop(); 
                    try {
                      await quizRepository.createQuiz(name: nameController.text, accessType: selectedAccessType);
                      statusMessage = 'Quiz "$quizName" created!'; 
                    } catch (e) {
                      statusMessage = 'Error: ${e.toString()}';
                    }
                  }

                  if(safeContext.mounted) {
                    ScaffoldMessenger.of(safeContext).showSnackBar(
                      SnackBar(
                        content: Text(statusMessage), 
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('Create Quiz'),
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text("Error: Current user not signed in."));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Quizes')),
      body: StreamBuilder<List<QuizMetadata>>(
        stream: quizRepository.getAvailableQuizzesStream2(), 
        
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Login issue: ${snapshot.error}'));
          }

          final myQuizzes = snapshot.data ?? [];

          if (myQuizzes.isEmpty) {
            return const Center(
              child: Text(
                'You have no quiz created yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: myQuizzes.length,
            itemBuilder: (context, index) {
              final quiz = myQuizzes[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    quiz.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Access: ${quiz.accessType}, Owner: ${quiz.ownerName}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizEdit(quizMetadata: quiz),
                    ),
                  );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () { showQuizCreateDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}