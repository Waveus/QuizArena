import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/repositories/QuizRepository.dart';

class MeQuizes extends StatefulWidget {
  const MeQuizes({super.key});
  @override
  State<MeQuizes> createState() => _MeQuizesState(); 
}

class _MeQuizesState extends State<MeQuizes> {
  final QuizRepository quizRepository = QuizRepository();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text("Błąd: Użytkownik nie jest zalogowany."));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Moje Quizy')),
      body: StreamBuilder<List<QuizMetadata>>(
        stream: quizRepository.getAvailableQuizzesStream(), 
        
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Błąd ładowania: ${snapshot.error}'));
          }

          final myQuizzes = snapshot.data ?? [];

          if (myQuizzes.isEmpty) {
            return const Center(
              child: Text(
                'Nie masz jeszcze żadnych utworzonych quizów.',
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
                    'Dostęp: ${quiz.accessType == 'public' ? 'Publiczny' : 'Prywatny'}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    print('Wybrano quiz do edycji: ${quiz.name}');
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}