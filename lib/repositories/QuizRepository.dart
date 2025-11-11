import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/services/auth_service.dart';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:rxdart/rxdart.dart';

import 'package:flutter_quizarena/models/QuizModelData';

class QuizRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendRepository _friendRepository = FriendRepository();

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

    final publicQuizzes = _firestore
        .collection('quiz')
        .where('accessType', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return QuizMetadata.fromFirestore(doc.data(), doc.id);
      }).toList();
    });

    return Rx.combineLatest2(
      publicQuizzes,
      userQuizzes,
      (List<QuizMetadata> publicQuizzes, List<QuizMetadata> userQuizzes) { 
        final allQuizzes = [...publicQuizzes, ...userQuizzes];

        final uniqueQuizzes = <String, QuizMetadata>{};
        for (var quiz in allQuizzes) {
          uniqueQuizzes[quiz.id] = quiz;
        }
        return uniqueQuizzes.values.toList();
      },
    );
  }

  Stream<List<QuizMetadata>> getFriendsQuizzes() {
    String currentUserID = AuthService().currentUser!.uid;
    return _friendRepository
        .streamFriendList(currentUserID)
        .switchMap((List<UserModel> friends) {
      final List<String> friendIds =
          friends.map((userModel) => userModel.uid).toList();

      if (friendIds.isEmpty) {
        return Stream.value(<QuizMetadata>[]);
      }

      final List<Stream<List<QuizMetadata>>> quizStreams = friendIds
          .map((friendId) => this.getMyQuizzesStream(friendId))
          .toList();

      return CombineLatestStream.list(quizStreams)
          .map((List<List<QuizMetadata>> listOfQuizLists) {
        return listOfQuizLists.expand((quizList) => quizList).toList();
      });
    });
  }

  Stream<List<QuizMetadata>> getMyQuizzesStream(String? userId) {
    userId ??= AuthService().currentUser!.uid;
    return _firestore
        .collection('quiz')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return QuizMetadata.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<Quiz> getFullQuiz(String quizId) async {
    try {
      final quizDoc = await _firestore.collection('quiz').doc(quizId).get();
      if (!quizDoc.exists) {
        throw Exception('Quiz not found!');
      }
      final quizData = quizDoc.data()!;

      final questionsSnapshot = await _firestore
          .collection('quiz')
          .doc(quizId)
          .collection('questions')
          .get();

      final List<Question> questions = questionsSnapshot.docs
          .map((doc) => Question.fromFirestore(doc))
          .toList();
          
      questions.sort((a, b) => a.index.compareTo(b.index));
          
      return Quiz(
        id: quizDoc.id,
        name: quizData['name'] ?? 'Brak nazwy',
        questions: questions,
      );
    } catch (e) {
      print('Błąd podczas pobierania quizu: $e');
      rethrow;
    }
  }
}