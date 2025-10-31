import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/models/FriendRequestModel';
import 'package:rxdart/rxdart.dart';

class FriendRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userCollection = 'user_data';
  final String _friendCollection = 'friends';
  final String _friendRequestCollection = 'friend_request';

  Future<void> sendRequest(String senderId, String receiverId) async {
    String uniqueId = senderId + receiverId;
    await _firestore.collection(_friendRequestCollection).doc(uniqueId).set({
      'sender': senderId,
      'receiver': receiverId,
    }, SetOptions(merge: true));
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
        .where('reciever', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
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

  Future<void> acceptRequest(String requestId) async {
   try {
      await _firestore.collection(_friendRequestCollection).doc(requestId).update({'status': 'accepted'});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> denyRequest(String requestId) async {
    try {
      await _firestore
          .collection(_friendRequestCollection)
          .doc(requestId)
          .update({
            'status': 'accepted',
          });
    } catch (e) {
      rethrow;
    }
  }
}