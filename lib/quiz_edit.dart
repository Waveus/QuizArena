import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/models/QuizQustion'; // Poprawiono nazwę: QuizQuestion
import 'package:flutter_quizarena/repositories/QuizRepository.dart';

class QuizEdit extends StatefulWidget {
  
  final QuizMetadata quizMetadata;

  const QuizEdit({
      super.key,
      required this.quizMetadata,
    });

  @override
  State<QuizEdit> createState() => _QuizEditState(); 
}

class _QuizEditState extends State<QuizEdit> {
  final QuizRepository _quizRepository = QuizRepository();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  late Stream<List<QuizQuestion>> _questionsStream;
  late bool _canEdit;

  @override
  void initState() {
    super.initState();
    
    final String quizOwnerId = widget.quizMetadata.ownerId;
    
    _canEdit = _currentUserId != null && _currentUserId == quizOwnerId;

    _questionsStream = _quizRepository.getQuestionsStream(widget.quizMetadata.id);
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: ${widget.quizMetadata.name}'),
      ),
      body: StreamBuilder<List<QuizQuestion>>(
        stream: _questionsStream,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Snapshot error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('This quiz have no data yet.'));
          }

          final questions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              
              final options = question.answers.entries
                  .map((e) => "${e.key}: ${e.value}")
                  .join('\n');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  isThreeLine: true,
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    question.text,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Answer: ${question.correctAnswer}\n$options',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _canEdit ? Icon(Icons.edit_note) : null,
                  onTap: _canEdit ? () {
                    
                  } : null,
                ),
              );
            },
          );
        },
      ),
      
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () {
                
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}