import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:flutter_quizarena/repositories/UserRepository.dart';
import 'package:flutter_quizarena/services/auth_service.dart';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:rxdart/rxdart.dart';

class QuizRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  final FriendRepository _friendRepository = FriendRepository();

  Stream<List<QuizMetadata>> getAvailableQuizzesStream() {
    final userQuizzes = _firestore
        .collection('quiz')
        .where('accessType', isEqualTo: 'private')
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

    final friendUidsStream = _friendRepository
        .streamFriendList(_auth.currentUser!.uid)
        .map((userList) => userList.map((user) => user.uid).toList());

    final friendQuizzesStream= friendUidsStream.switchMap((friendUids) {
      if (friendUids.isEmpty) {
        return Stream.value(<QuizMetadata>[]);
      }

      final chunks = _chunkList(friendUids, 10);
      
      final streams = chunks.map((chunk) {
        return _firestore
            .collection('quiz')
            .where('accessType', isEqualTo: 'friendOnly')
            .where('ownerID', whereIn: chunk)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => QuizMetadata.fromFirestore(doc.data(), doc.id))
                .toList());
      }).toList();
      
      return streams.isNotEmpty
          ? Rx.combineLatestList<List<QuizMetadata>>(streams)
             .map((listOfLists) => listOfLists.expand((list) => list).toList())
          : Stream.value(<QuizMetadata>[]);
    });

      return Rx.combineLatest3(
      myQuizzes, 
      userQuizzes,
      friendQuizzesStream,
      (List<QuizMetadata> myQuizzes, List<QuizMetadata> userQuizzes, List<QuizMetadata> friendQuizzes) {

        final allQuizzes = [...myQuizzes, ...friendQuizzes, ...userQuizzes];

        final uniqueQuizzes = <String, QuizMetadata>{};
        for (var quiz in allQuizzes) {
          uniqueQuizzes[quiz.id] = quiz;
        }
        return uniqueQuizzes.values.toList();
      },
    );
      
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    int i = 0;
    while (i < list.length) {
      int size = i + chunkSize > list.length ? list.length - i : chunkSize;
      chunks.add(list.sublist(i, i + size));
      i += chunkSize;
    }
    return chunks;
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
