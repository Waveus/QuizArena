import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/repositories/UserRepository.dart';
import 'package:flutter_quizarena/services/auth_service.dart';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_quizarena/models/QuizQustion';

import 'package:flutter_quizarena/models/QuizModelData';



class QuizRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendRepository _friendRepository = FriendRepository();
  final UserRepository _userRepository = UserRepository();

  Stream<List<QuizQuestion>> getQuestionsStream(String quizId) {
    return _firestore
        .collection('quiz')
        .doc(quizId)
        .collection('questions')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return QuizQuestion.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> deleteQuestion(String quizId, String questionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('quiz')
        .doc(quizId)
        .collection('questions')
        .doc(questionId) 
        .delete(); 
  } catch (e) {
    print('Error: $e');
    rethrow;
  }
}

  Future<void> addQuestion(String quizId, QuizQuestion question) async {
    await FirebaseFirestore.instance
        .collection('quiz')
        .doc(quizId)
        .collection('questions')
        .add({
          'text': question.text,
          'answers': question.answers, 
          'correctAnswer': question.correctAnswer
        });
  }


  Future<void> createQuiz({
    required String name,
    required String accessType,
  }) async {
    if(_auth.currentUser == null) {
      throw Exception("Unauthorized user, please reauth");
    }
    String ownerId = _auth.currentUser!.uid;
    if (name.trim().isEmpty) {
      throw Exception("Quiz name cannot be empty");
    }
    if (!['public', 'private', 'friendsOnly'].contains(accessType)) {
      throw Exception("Error: AccessType must be public', 'private', 'friendsOnly");
    }

    final newQuizData = {
      'ownerID': ownerId,
      'name': name.trim(),
      'accessType': accessType,
    };

    try {
      await _firestore.collection('quiz').add(newQuizData);
    } on FirebaseException catch (e) {
      throw Exception('Firebase Error: ${e.message}');
    } catch (e) {
      throw Exception('Unknown Error: $e');
    }
  }

  Stream<List<QuizMetadata>> getAvailableQuizzesStream() {
    final userQuizzes = _firestore
        .collection('quiz')
        // .where('accessType', isEqualTo: 'private') // check if correct
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

  Stream<List<QuizMetadata>> getAvailableQuizzesStream2() {
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

    final friendUidsStream = _friendRepository
        .streamFriendList(_auth.currentUser!.uid)
        .map((userList) => userList.map((user) => user.uid).toList());

    final friendQuizzesStream = friendUidsStream.switchMap((friendUids) {
      if (friendUids.isEmpty) {
        return Stream.value(<QuizMetadata>[]);
      }

      final chunks = _chunkList(friendUids, 10);
      final streams = chunks.map((chunk) {
        return _firestore
            .collection('quiz')
            .where('accessType', isEqualTo: 'friendsOnly')
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
      final combinedStream = Rx.combineLatest3(
        publicQuizzes,
        userQuizzes,
        friendQuizzesStream,
        (List<QuizMetadata> pubQuizzes, List<QuizMetadata> userQuizzes, List<QuizMetadata> friendQuizzes) {
          final allQuizzes = [...pubQuizzes, ...friendQuizzes, ...userQuizzes];
          final uniqueQuizzes = <String, QuizMetadata>{};
          for (var quiz in allQuizzes) {
            uniqueQuizzes[quiz.id] = quiz;
          }
          return uniqueQuizzes.values.toList();
        },
      );
      return combinedStream.switchMap((quizzes) {
        if (quizzes.isEmpty) {
          return Stream.value(<QuizMetadata>[]);
        }
        return Stream.fromFuture(_fetchOwnerNames(quizzes));
      });
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

  Future<List<QuizMetadata>> _fetchOwnerNames(List<QuizMetadata> quizzes) async {
  if (quizzes.isEmpty) return [];
  final Set<String> ownerIds = quizzes.map((q) => q.ownerId).toSet();
  late final Map<String, UserModel> ownersMap;
  try {
    ownersMap = await _userRepository.getUsersMap(ownerIds); 
  } catch (e) {
    print("Błąd pobierania danych właścicieli: $e");
    ownersMap = {};
  }
  return quizzes.map((quiz) {
    final ownerData = ownersMap[quiz.ownerId];
    final ownerName = ownerData?.username ?? 'Unknown';
    return quiz.copyWith(ownerName: ownerName); 
  }).toList();
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
    userId = AuthService().currentUser!.uid;
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