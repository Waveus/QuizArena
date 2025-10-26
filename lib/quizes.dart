import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/quiz_page.dart';

class Quizes extends StatelessWidget {
  const Quizes({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybierz Quiz'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        // Używamy StreamBuilder, żeby lista odświeżała się na żywo,
        // gdybyś dodał nowy quiz w bazie.
        child: StreamBuilder<QuerySnapshot>(
          // 1. Łączymy się z kolekcją 'quiz_data'
          stream: FirebaseFirestore.instance.collection('quiz_data').snapshots(),
          
          builder: (context, snapshot) {
            // 2. Co pokazać, gdy dane jeszcze lecą (ładowanie)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 3. Co pokazać, jeśli jest błąd
            if (snapshot.hasError) {
              return Center(child: Text('Wystąpił błąd: ${snapshot.error}'));
            }

            // 4. Co pokazać, jeśli nie ma danych
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Nie znaleziono żadnych quizów.'));
            }

            // 5. Mamy dane! Budujemy listę.
            final quizDocs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: quizDocs.length,
              itemBuilder: (context, index) {
                final quizDoc = quizDocs[index];
                final String quizId = quizDoc.id; 
                final quizData = quizDoc.data() as Map<String, dynamic>;

                // 👇 NOWE LINIE 👇
                // Pobieramy NOWE pole 'name'
                final String name = quizData['name'] ?? 'Brak nazwy';
                // Pole 'description' też pobieramy, ale dla podtytułu
                final String description = quizData['description'] ?? 'Brak opisu';
                
                final int quizType = quizData['type'] ?? 1;

                return Card(
                  elevation: 4.0,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple[100],
                      child: Icon(
                        _getIconForType(quizType),
                        color: Colors.deepPurple,
                      ),
                    ),
                    // 👇 ZMIANA TUTAJ 👇
                    title: Text(
                      name, // Używamy 'name' jako głównego tytułu
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // 👇 ZMIANA TUTAJ 👇
                    subtitle: Text(description), // A 'description' jako podtytułu
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // 6. Nawigacja do strony z pytaniami
                       debugPrint("Wybrano quiz: $quizId");
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           // Przekazujemy ID do następnego ekranu
                           builder: (context) => QuizPage(quizId: quizId),
                      ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Mała funkcja pomocnicza do wybierania ikonek na podstawie 'type'
  IconData _getIconForType(int type) {
    switch (type) {
      case 1:
        return Icons.history_edu; // Historia / Biologia
      case 2:
        return Icons.public; // Geografia / IT
      case 3:
        return Icons.movie; // Popkultura
      default:
        return Icons.quiz;
    }
  }
}