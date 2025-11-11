import 'package:flutter/material.dart';
import 'package:flutter_quizarena/models/QuizModelData';
import 'package:flutter_quizarena/repositories/QuizRepository.dart';
import 'package:firebase_database/firebase_database.dart'; 

class QuizScreen extends StatefulWidget {
  final String quizId; 
  final String roomId;
  final bool isHost;

  const QuizScreen({
    super.key,
    required this.quizId,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final QuizRepository _quizRepository = QuizRepository();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final DatabaseReference _roomRef;

  Quiz? _quiz;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _answerWasSelected = false;

  final List<Color> _buttonColors = const [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();

    _roomRef = _db.ref('rooms/${widget.roomId}');
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final quiz = await _quizRepository.getFullQuiz(widget.quizId);
      setState(() {
        _quiz = quiz;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load quiz: $e')),
      );
    }
  }

  void _handleAnswer(Answer selectedAnswer) {
    if (_answerWasSelected) return; 

    setState(() {
      _answerWasSelected = true;
    });

    bool isCorrect = selectedAnswer.isCorrect;
    if (isCorrect) {
      _score++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? 'Poprawna odpowiedź!' : 'Błędna odpowiedź.'),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        duration: const Duration(milliseconds: 1500),
      ),
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      setState(() {
        _currentQuestionIndex++;
        _answerWasSelected = false; 
       });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?.name ?? 'Ładowanie quizu...'),
        automaticallyImplyLeading: false, 
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quiz == null) {
      return const Center(child: Text('Nie udało się załadować quizu.'));
    }

    if (_currentQuestionIndex >= _quiz!.questions.length) {
      return _buildResultsScreen();
    }

    return _buildQuestionScreen();
  }

  Widget _buildQuestionScreen() {
    final Question currentQuestion = _quiz!.questions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    currentQuestion.text,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            flex: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(), 
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.5, 
              ),
              itemCount: 4, 
              itemBuilder: (context, index) {
                final Answer answer = currentQuestion.answers[index];
                
                return AnswerButton(
                  text: answer.text,
                  color: _buttonColors[index],
                  onPressed: _answerWasSelected
                      ? null 
                      : () => _handleAnswer(answer),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Quiz Zakończony!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Text(
            'Twój wynik: $_score / ${_quiz!.questions.length}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 40),
    
          ElevatedButton(
            onPressed: () async {
              
              if (widget.isHost) {
                try {
                  await _roomRef.update({
                    'status': 'waiting',
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Błąd resetowania pokoju: $e')),
                    );
                  }
                }
              }
              
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(widget.isHost 
                ? 'Zakończ i wróć do lobby' 
                : 'Wróć do lobby'),
          ),
        ],
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onPressed;

  const AnswerButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(text),
    );
  }
}