import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quizarena/models/User';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'user_data';

  Future<void> createUser(String uid, String username) async {
    final newUser = UserModel(uid: uid, username: username);
    try {
      await _firestore.collection(_usersCollection).doc(uid).set(
        newUser.toFirestore(),
        SetOptions(merge: true), 
      );
    } catch (e) {
      print('Error creating user data for $uid: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final docSnapshot = await _firestore.collection(_usersCollection).doc(uid).get();
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      print('Error fetching user data for $uid: $e');
      return null;
    }
  }

  Stream<UserModel?> streamUserData(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((docSnapshot) {
          if (docSnapshot.exists) {
            return UserModel.fromFirestore(docSnapshot.data() as Map<String, dynamic>, uid);
          }
          return null;
        });
  }
  
  Future<void> updateUsername(String uid, String newUsername) async {
    try {
      String usernameNormalized = newUsername.trim().toLowerCase();
      bool isUnique = await isUsernameUnique(usernameNormalized);
      print('Unique  ${isUnique}');
      if(isUnique) {
        await _firestore.collection(_usersCollection).doc(uid).update({
          'username': usernameNormalized,
        });
      } else {
        throw 'Error username is already taken';
      }
    } catch (e) {
        print('Error updating username for $uid: $e');
      rethrow;
    }
  }
  
  Future<bool> isUsernameUnique(String username) async {
    try {
      final normalizedUsername = username.trim().toLowerCase();
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();
      return querySnapshot.docs.isEmpty;

    } catch (e) {
        print('Error checking username uniqueness: $e');
      return false; 
    }
  }
}