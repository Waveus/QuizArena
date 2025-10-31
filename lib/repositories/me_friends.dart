import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quizarena/models/User';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:flutter_quizarena/repositories/UserRepository.dart';

class MeFriends extends StatefulWidget {
  const MeFriends({super.key});
  @override
  State<MeFriends> createState() => _MeFriendsState(); 
}

class _MeFriendsState extends State<MeFriends> {
  final FriendRepository friendRepository = FriendRepository();
  final UserRepository userRepository = UserRepository();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
     if (currentUserId == null) {
      return const Center(child: Text("Error: Current user not signed in."));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Friends')),
      body: StreamBuilder<List<dynamic>>(
  stream: friendRepository.streamCombinedFriendData(currentUserId!), 
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }

    final combinedList = snapshot.data ?? []; 
    
    if (combinedList.isEmpty) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: combinedList.length,
      itemBuilder: (context, index) {
        final item = combinedList[index];

        if (item is UserModel) {
          final isSenderSection = combinedList.sublist(0, index).contains('HEADER_SENDERS') && 
                                  !combinedList.sublist(0, index).contains('HEADER_FRIENDS');
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(
                item.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              
              trailing: isSenderSection
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () { /* TODO: Accept */ },
                      ),
                      const SizedBox(width: 10),

                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () { /* TODO: Deny */ },
                      ),
                    ],
                  )
                : null, // Null for friends
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  },
)
      );
  }
}