import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/models/FriendRequestModel';
import 'package:rxdart/rxdart.dart';

class FriendRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String _userCollection = 'user_data';
  final String _friendCollection = 'friends';
  final String _friendRequestCollection = 'friend_request';
  

  Future<void> sendRequest(String receiverName) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) {
      throw Exception("User not authenticated.");
    }

    try {
      final userSnapshot = await _firestore
          .collection('user_data')
          .where('username', isEqualTo: receiverName)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception("User with specific name not found");
      }
      
      final receiverId = userSnapshot.docs.first.id; 
      
      if (senderId == receiverId) {
        throw Exception("You cannot send request to yourself");
      }

      final HttpsCallable callable = _functions.httpsCallable('sendFriendRequest');

      final response = await callable.call(<String, dynamic>{
        'receiverId': receiverId, 
      });
      if (response.data != null && response.data['success'] == true) {
        return; 
      } else {
         throw Exception(response.data['message'] ?? 'Unkown error.');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Firebase Error: ${e.message}');
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  Stream<List<dynamic>> streamCombinedFriendData(String userId) {
  final sendersStream = streamIncomingRequestSenders(userId);
  final friendsStream = streamFriendList(userId);
  return Rx.combineLatest2(sendersStream, friendsStream, 
      (List<UserModel> senders, List<UserModel> friends) {
    final combinedList = <dynamic>[];
    if (senders.isNotEmpty) {
      combinedList.add('HEADER_SENDERS');
      combinedList.addAll(senders); 
    }

    if (friends.isNotEmpty) {
      combinedList.add('HEADER_FRIENDS');
      combinedList.addAll(friends);
    }
    
    return combinedList;
  });
}

  Stream<List<UserModel>> streamIncomingRequestSenders(String userId) {
    return _firestore
        .collection(_friendRequestCollection)
        .where('receiver', isEqualTo: userId)
        .snapshots()
        .asyncMap((QuerySnapshot requestSnapshot) async {            
                final senderUids = requestSnapshot.docs
                .map((doc) => (doc.data()! as Map<String, dynamic>)['sender'] as String)
                .toList();  //Test
            if (senderUids.isEmpty) {
                return [];
            }
            final usersDataSnapshot = await _firestore
                .collection(_userCollection)
                .where(FieldPath.documentId, whereIn: senderUids)
                .get();
            return usersDataSnapshot.docs.map((doc) {
                return UserModel.fromFirestore(doc.data(), doc.id);
            }).toList();
        });
}

Stream<List<UserModel>> streamFriendList(String userId) {
  return _firestore
      .collection(_userCollection)
      .doc(userId)
      .collection(_friendCollection)
      .snapshots()
      .asyncMap((QuerySnapshot subcollectionSnapshot) async {
        
        final friendUids = subcollectionSnapshot.docs.map((doc) => doc.id).toList();

        if (friendUids.isEmpty) {
          return [];
        }
        final usersDataSnapshot = await _firestore
            .collection(_userCollection)
            .where(FieldPath.documentId, whereIn: friendUids)
            .get();
        return usersDataSnapshot.docs.map((doc) {
          return UserModel.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
}

Future<void> handleFriendRequest(String senderId, String action) async {
  if (_auth.currentUser == null) {
      throw Exception('Użytkownik nie jest zalogowany. Brak tokena uwierzytelniającego.');
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable('handleFriendRequest');
    
      await callable.call({
        'senderId': senderId, 
        'action': action,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error: (${action}): ${e.message}'); 
    } catch (e) {
      throw Exception('Unknown Error: $e');
    }
  }

Future<void> acceptRequest(String senderId) async {
    await handleFriendRequest(senderId, 'accept');
  }

Future<void> denyRequest(String senderId) async {
    await handleFriendRequest(senderId, 'reject');
  }

Future<void> removeFriend(String friendId) async {
  if (_auth.currentUser == null) {
      throw Exception('User not authenticated.');
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable('removeFriend');
    
      await callable.call({
        'friendId': friendId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error: ${e.message}'); 
    } catch (e) {
      throw Exception('Unknown Error: $e');
    }
  } 
}


