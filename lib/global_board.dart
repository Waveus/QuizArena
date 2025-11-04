import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/repositories/UserRepository.dart';
import 'package:flutter_quizarena/services/auth_service.dart';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:rxdart/rxdart.dart';

class QuizRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserRepository _userRepository = UserRepository();
  final FriendRepository _friendRepository = FriendRepository();

  /// [NOWA OPTYMALIZACJA]
  /// Łączy quizy publiczne, quizy użytkownika ORAZ quizy znajomych w jeden strumień.
  /// Idealny do użycia w oknie dialogowym tworzenia pokoju.
  Stream<List<QuizMetadata>> getAvailableQuizzesStream() {
    
    // Strumień 1: Quizy publiczne
    final publicQuizzes = _firestore
        .collection('quiz')
        .where('accessType', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return QuizMetadata.fromFirestore(doc.data(), doc.id);
      }).toList();
    });

    // Strumień 2: Twoje własne quizy
    // Wywołujemy getMyQuizzesStream(null), aby pobrać quizy zalogowanego użytkownika
    final userQuizzes = this.getMyQuizzesStream(null);

    // Strumień 3: Quizy Twoich znajomych
    final friendsQuizzes = this.getFriendsQuizzes();

    // [ZMIANA] Łączymy WSZYSTKIE TRZY strumienie za pomocą Rx.combineLatest3
    return Rx.combineLatest3(
      publicQuizzes,
      userQuizzes,
      friendsQuizzes,
      (
        List<QuizMetadata> public,
        List<QuizMetadata> user,
        List<QuizMetadata> friends,
      ) {
        // Łączymy wszystko w jedną listę
        final allQuizzes = [...public, ...user, ...friends];

        // Dedyplikacja (usunięcie powtórek, np. gdy twój quiz jest publiczny)
        final uniqueQuizzes = <String, QuizMetadata>{};
        for (var quiz in allQuizzes) {
          uniqueQuizzes[quiz.id] = quiz;
        }
        return uniqueQuizzes.values.toList();
      },
    );
  }

  /// [BEZ ZMIAN] Ta funkcja jest teraz poprawnie używana
  Stream<List<QuizMetadata>> getFriendsQuizzes() {
    String currentUserID = AuthService().currentUser!.uid;
    return _friendRepository
        .streamFriendList(currentUserID)
        .switchMap((List<UserModel> friends) {
      // Zakładam, że Twój UserModel ma pole `uid`
      final List<String> friendIds =
          friends.map((userModel) => userModel.uid).toList();

      if (friendIds.isEmpty) {
        return Stream.value(<QuizMetadata>[]);
      }

      final List<Stream<List<QuizMetadata>>> quizStreams = friendIds
          // [POPRAWKA] Wywołuje poprawną funkcję z ID znajomego
          .map((friendId) => this.getMyQuizzesStream(friendId))
          .toList();

      return CombineLatestStream.list(quizStreams)
          .map((List<List<QuizMetadata>> listOfQuizLists) {
        return listOfQuizLists.expand((quizList) => quizList).toList();
      });
    });
  }

  /// [POPRAWKA] Zmieniony parametr na (String? userId)
  /// Pozwala to pobrać quizy dla konkretnego ID LUB (jeśli null) dla zalogowanego użytkownika.
  Stream<List<QuizMetadata>> getMyQuizzesStream(String? userId) {
    // Jeśli userId jest null, użyj ID zalogowanego użytkownika
    userId ??= AuthService().currentUser!.uid;

    return _firestore
        .collection('quiz')
        // [POPRAWKA] Używa `userId` zamiast stałej wartości
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return QuizMetadata.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }
}