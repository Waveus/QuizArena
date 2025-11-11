import 'package:flutter/material.dart';

class QuizPage extends StatelessWidget {
  final String quizId;

  const QuizPage({
    Key? key,
    required this.quizId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: $quizId'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Rozpoczynasz quiz!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'ID Quizu: $quizId',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 40),
            Text(
              'Tutaj wczytamy pytania z kolekcji "question_data",\nużywając filtra "quizId == $quizId".',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}