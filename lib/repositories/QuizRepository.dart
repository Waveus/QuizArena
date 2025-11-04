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

  Stream<List<QuizMetadata>> getFriendsQuizzes() {
    String currentUserID = AuthService().currentUser!.uid;
    return _friendRepository.streamFriendList(currentUserID).switchMap((List<UserModel> friends){
      final List<String> friendIds = friends
        .map((userModel) => userModel.uid)
        .toList();

      if(friendIds.isEmpty){
        return Stream.value(<QuizMetadata>[]);
      }

      final List<Stream<List<QuizMetadata>>> quizStreams = friendIds
        .map((friendId) => this.getMyQuizzesStream(friendId))
        .toList();

        return CombineLatestStream.list(quizStreams)
          .map((List<List<QuizMetadata>> listOfQuizLists){

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

}
