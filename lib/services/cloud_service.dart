import 'package:cloud_firestore/cloud_firestore.dart';

class CloudService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<bool> isUsernameAvailable(String username) async {
    final sanitizedUsername = username.toLowerCase().trim();
    final snapshot = await firestore
        .collection('usernames')
        .doc(sanitizedUsername)
        .get();
    return !snapshot.exists;
  }
  
  Future<void> saveUserData(
    String uid, 
    String username, 
    String email,
  ) async {
    
    await firestore.runTransaction((transaction) async {
      final usernameRef = firestore.collection('usernames').doc(username);
      final userDocRef = firestore.collection('users').doc(uid);

      final usernameSnapshot = await transaction.get(usernameRef);
      if (usernameSnapshot.exists) {
          throw FirebaseException(
            plugin: 'firestore',
            code: 'username-taken-in-transaction',
            message: 'Username was claimed during the registration process.',
          );
      }

      transaction.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userDocRef, {
        'uid': uid,
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}