import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/services/auth_service.dart';
import 'package:rxdart/rxdart.dart';

class QuizRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<QuizMetadata>> getAvailableQuizzesStream() {
    final userQuizzes = _firestore
        .collection('quiz')
        .where('ownerID', isEqualTo: AuthService().currentUser!.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return QuizMetadata.fromFirestore(doc.data(), doc.id);
          }).toList();
        });

    final myQuizzes = _firestore
        .collection('quiz')
        .where('accessType', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return QuizMetadata.fromFirestore(doc.data(), doc.id);
          }).toList();
        });

      //TODO Friens quizes

      return Rx.combineLatest2(
      myQuizzes, 
      userQuizzes,
      (List<QuizMetadata> myQuizzes, List<QuizMetadata> userQuizzes) {

        final allQuizzes = [...myQuizzes, ...userQuizzes];

        final uniqueQuizzes = <String, QuizMetadata>{};
        for (var quiz in allQuizzes) {
          uniqueQuizzes[quiz.id] = quiz;
        }
        return uniqueQuizzes.values.toList();
      },
    );
      
  }

  Stream<List<QuizMetadata>> getMyQuizzesStream(String currentUserId) {
    return _firestore
        .collection('quiz')
        .where('ownerId', isEqualTo: AuthService().currentUser!.uid) // Filtrowanie po właścicielu
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return QuizMetadata.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

}