import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Dla debugPrint

class QuizSeeder {
  
  // Funkcja statyczna - wywołujesz ją przez QuizSeeder.seedData()
  static Future<void> seedData() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    debugPrint("Rozpoczynam seedowanie GLOBALNYCH quizów z DWÓCH plików...");

    try {
      // 1. Sprawdź, czy quizy już istnieją (w 'quiz_data')
      final check = await firestore.collection('quiz_data').limit(1).get();
      if (check.docs.isNotEmpty) {
        debugPrint("KOLEKCJE 'quiz_data' i 'question_data' JUŻ ISTNIEJĄ.");
        debugPrint("Pomijam seedowanie. Jeśli chcesz wgrać od nowa, usuń je ręcznie w Firebase.");
        return;
      }

      // 2. Wczytaj OBA pliki JSON
      final String quizzesJsonString = await rootBundle.loadString('assets/quizy.json');
      final String questionsJsonString = await rootBundle.loadString('assets/pytania.json');
      
      final List<dynamic> quizzesList = jsonDecode(quizzesJsonString);
      final List<dynamic> questionsList = jsonDecode(questionsJsonString);

      if (quizzesList.isEmpty || questionsList.isEmpty) {
        debugPrint("Jeden z plików JSON jest pusty. Nic nie dodano.");
        return;
      }

      // 3. Połącz się z globalnymi kolekcjami
      final quizDataCollection = firestore.collection('quiz_data');
      final questionDataCollection = firestore.collection('question_data');
          
      final batch = firestore.batch();

      // 4. Pętla przez PLIK 1 (quizy.json) - Metadane quizów
      debugPrint("Przetwarzam ${quizzesList.length} quizów (z quizy.json)...");
      for (var quiz in quizzesList) {
        final quizMap = quiz as Map<String, dynamic>;
        
        // 🔥 TUTAJ MAGIA nr 1 🔥
        // Pobieramy pre-definiowane ID (np. "historia_swiata")
        final String quizDocId = quizMap.remove('quizId');
        
        // Używamy tego ID jako NAZWY DOKUMENTU w 'quiz_data'
        final quizDocRef = quizDataCollection.doc(quizDocId);
        
        // Zapisujemy resztę danych (description, type) w tym dokumencie
        batch.set(quizDocRef, quizMap);
      }

      // 5. Pętla przez PLIK 2 (pytania.json) - Pytania
      debugPrint("Przetwarzam ${questionsList.length} pytań (z pytania.json)...");
      for (var question in questionsList) {
        final questionMap = question as Map<String, dynamic>;
        
        // 🔥 TUTAJ MAGIA nr 2 🔥
        // 'questionMap' już zawiera 'quizId' (np. "historia_swiata")
        // Po prostu dodajemy cały obiekt pytania jako NOWY dokument
        // w 'question_data'. Nie musimy nic mapować.
        final questionDocRef = questionDataCollection.doc();
        batch.set(questionDocRef, questionMap);
      }

      // 6. Wrzuć wszystko do bazy
      await batch.commit();
      
      debugPrint("-------------------------------------------------");
      debugPrint("SEEDOWANIE Z DWÓCH PLIKÓW ZAKOŃCZONE POMYŚLNIE!");
      debugPrint("Dodano ${quizzesList.length} quizów do 'quiz_data'.");
      debugPrint("Dodano ${questionsList.length} pytań do 'question_data'.");
      debugPrint("Połączenie przez pole 'quizId' powinno działać.");
      debugPrint("-------------------------------------------------");

    } catch (e) {
      debugPrint("=================================================");
      debugPrint("BŁĄD SEEDOWANIA QUIZÓW: $e");
      debugPrint("Sprawdź, czy pliki 'assets/quizy.json' i 'assets/pytania.json' istnieją.");
      debugPrint("Sprawdź, czy są dodane w 'pubspec.yaml'.");
      debugPrint("=================================================");
    }
  }
}