import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/models/QuizQustion';
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
  void _showAddQuestionDialog() {
    final formKey = GlobalKey<FormState>();
    final questionCtrl = TextEditingController();
    final answerACtrl = TextEditingController();
    final answerBCtrl = TextEditingController();
    final answerCCtrl = TextEditingController();
    final answerDCtrl = TextEditingController();
    String selectedCorrectAnswer = 'a';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Question'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: questionCtrl,
                  decoration: const InputDecoration(labelText: 'Question'),
                  validator: (v) => v!.isEmpty ? 'Answer' : null,
                ),
                const SizedBox(height: 10),
                
                for (var entry in {'a': answerACtrl, 'b': answerBCtrl, 'c': answerCCtrl, 'd': answerDCtrl}.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextFormField(
                      controller: entry.value,
                      decoration: InputDecoration(labelText: 'Answer ${entry.key}'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  
                const SizedBox(height: 10),
                
                DropdownButtonFormField<String>(
                  value: selectedCorrectAnswer,
                  decoration: const InputDecoration(labelText: 'Correct answer'),
                  // <--- ZMIANA: lista małych liter
                  items: ['a', 'b', 'c', 'd'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => selectedCorrectAnswer = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newQ = QuizQuestion(
                  id: '', 
                  text: questionCtrl.text,
                  answers: {
                    'a': answerACtrl.text,
                    'b': answerBCtrl.text,
                    'c': answerCCtrl.text,
                    'd': answerDCtrl.text,
                  },
                  correctAnswer: selectedCorrectAnswer,
                );
                await _quizRepository.addQuestion(widget.quizMetadata.id, newQ);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                  trailing: _canEdit ? IconButton(
                    icon: const Icon(Icons.delete,color: Colors.red),
                    onPressed: (){
                      _quizRepository.deleteQuestion(widget.quizMetadata.id, question.id);
                    },
                    ) : null,
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
              onPressed: () {_showAddQuestionDialog();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
