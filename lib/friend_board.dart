import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [ZMIANA] Import Firestore
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/repositories/QuizRepository.dart';
import 'package:flutter_quizarena/lobby_screen.dart';

import 'package:rxdart/rxdart.dart';
import 'package:flutter_quizarena/repositories/FriendRepository.dart';
import 'package:flutter_quizarena/repositories/UserRepository.dart';

class FriendBoard extends StatefulWidget {
  const FriendBoard({super.key});

  @override
  State<FriendBoard> createState() => _FriendBoardState();
}

class _FriendBoardState extends State<FriendBoard>
    with AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QuizRepository _quizRepository = QuizRepository();

  // [NOWE] Repozytoria do pobierania listy znajomych
  final FriendRepository _friendRepository = FriendRepository();
  final UserRepository _userRepository =
      UserRepository(); // Załóżmy, że jest potrzebne

  // [NOWE] Strumień, który połączy oba źródła danych
  late final Stream<Map<String, dynamic>> _combinedStream;

  @override
  void initState() {
    super.initState();

    // [NOWE] Strumień 1: Lista ID znajomych (z FriendRepository)
    // Zakładam, że Twój UserModel ma pole 'uid'
    final friendIdsStream = _friendRepository
        .streamFriendList(_auth.currentUser!.uid)
        .map((list) => list.map((user) => user.uid).toSet()); // Użyj Set dla szybszego sprawdzania

    // [NOWE] Strumień 2: Pokoje (z Firestore)
    final roomsStream = _firestore
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .snapshots();

    _combinedStream = Rx.combineLatest2(
      friendIdsStream,
      roomsStream,
      (Set<String> friendIds, QuerySnapshot roomsSnapshot) {
        return {
          'friendIds': friendIds,
          'roomsSnapshot': roomsSnapshot,
        };
      },
    );
  }

  void _showCreateRoomDialog(BuildContext context) async {
    final String? newRoomId = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _CreateRoomDialog(
          quizRepository: _quizRepository,
          onCreateRoom: (roomName, playerLimit, selectedQuiz) async {
            final createdRoomId =
                await _createRoom(roomName, playerLimit, selectedQuiz);
            return createdRoomId;
          },
        );
      },
    );

    if (newRoomId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
              roomID: newRoomId, currentUserId: _auth.currentUser!.uid),
        ),
      );
    } else if (newRoomId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create room.')),
      );
    }
  }

  Future<String?> _createRoom(
      String roomName, int playerLimit, QuizMetadata selectedQuiz) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final CollectionReference roomsRef = _firestore.collection('rooms');

    final roomData = {
      'host': user.uid,
      'roomName': roomName,
      'status': 'waiting',
      'playerLimit': playerLimit,
      'playerCount': 1,
      'quiz': {'id': selectedQuiz.id, 'title': selectedQuiz.name},
      'players': {
        user.uid: {'displayName': user.displayName ?? 'Host'}
      },
      'createdAt': FieldValue.serverTimestamp(), 
    };

    try {
      final DocumentReference newRoomRef = await roomsRef.add(roomData);

      return newRoomRef.id;
    } catch (e) {
      return null;
    }
  }

  Future<void> _joinRoom(String roomID) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final DocumentReference roomRef = _firestore.collection('rooms').doc(roomID);

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot roomSnapshot = await transaction.get(roomRef);

        if (!roomSnapshot.exists) {
          throw Exception("Room does not exist.");
        }

        final Map<String, dynamic> room =
            roomSnapshot.data() as Map<String, dynamic>;

        final bool isWaiting = room['status'] == 'waiting';
        final bool hasSpace =
            (room['playerCount'] as int) < (room['playerLimit'] as int);
        final bool alreadyJoined =
            (room['players'] as Map).containsKey(user.uid);

        if (isWaiting && hasSpace && !alreadyJoined) {
          transaction.update(roomRef, {
            'playerCount': FieldValue.increment(1),
            'players.${user.uid}': {
              'displayName': user.displayName ?? 'Player'
            }
          });
        } else if (isWaiting && alreadyJoined) {
          return;
        } else {
          throw Exception(
              "Failed to join room (full, in game, or does not exist).");
        }
      });

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              roomID: roomID,
              currentUserId: _auth.currentUser!.uid,
            ),
          ),
        );
      }
    } catch (e) {
      // Transakcja nie powiodła się
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining room: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends Rooms'), // [ZMIANA] Lepszy tytuł
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoomDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Room'),
      ),
      // [NOWE] StreamBuilder słucha połączonego strumienia
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading rooms: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Loading data...'));
          }

          // [NOWE] Rozpakuj połączone dane
          final Set<String> friendIds = snapshot.data!['friendIds'];
          final QuerySnapshot roomsSnapshot = snapshot.data!['roomsSnapshot'];

          // [ZMIANA] Mapowanie QuerySnapshot na listę
          final roomsList = roomsSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            };
          }).toList();

          // [NOWE] Kluczowa optymalizacja: Filtrowanie listy pokoi
          // Pokaż tylko pokoje, gdzie host jest na liście znajomych
          final filteredRooms = roomsList.where((room) {
            final hostId = room['host'];
            return friendIds.contains(hostId);
          }).toList();

          // [ZMIANA] Użyj `filteredRooms` do wyświetlania
          if (filteredRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No available rooms from friends.\nCreate one!', // [ZMIANA]
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showCreateRoomDialog(context),
                    child: const Text('Create Room'),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredRooms.length, // [ZMIANA]
            itemBuilder: (context, index) {
              final room = filteredRooms[index]; // [ZMIANA]
              return RoomListItem(
                room: room,
                onJoin: (roomID) async {
                  await _joinRoom(roomID);
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ===================================================================
// Reszta Twojego kodu (Dialog i RoomListItem)
// Nie wymagały żadnych zmian, ponieważ pobierają dane z `_quizRepository`
// lub są prostymi widokami.
// ===================================================================

class _CreateRoomDialog extends StatefulWidget {
  final QuizRepository quizRepository;
  final Future<String?> Function(
          String roomName, int playerLimit, QuizMetadata selectedQuiz)
      onCreateRoom;

  const _CreateRoomDialog({
    required this.quizRepository,
    required this.onCreateRoom,
  });

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();

  QuizMetadata? _selectedQuiz;
  late final Stream<List<QuizMetadata>> _quizzesStream;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // [BEZ ZMIAN] Ta linia automatycznie pobierze nową, złączoną listę quizów!
    // (Publiczne + Własne + Znajomych)
    _quizzesStream = widget.quizRepository.getAvailableQuizzesStream();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Room'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _roomNameController,
                decoration: const InputDecoration(labelText: 'Room Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limitController,
                decoration:
                    const InputDecoration(labelText: 'Player Limit (2-16)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a limit';
                  }
                  final int? limit = int.tryParse(value);
                  if (limit == null || limit < 2 || limit > 16) {
                    return 'Limit must be between 2 and 16';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<QuizMetadata>>(
                stream: _quizzesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('Error loading quizzes: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('No available quizzes found.'),
                    );
                  }

                  final quizzes = snapshot.data!;

                  // Logika do obsługi domyślnego wyboru
                  if (_selectedQuiz != null &&
                      !quizzes.any((q) => q.id == _selectedQuiz!.id)) {
                    _selectedQuiz = null;
                  }
                  if (_selectedQuiz == null && quizzes.isNotEmpty) {
                    _selectedQuiz = quizzes.first;
                  }

                  return DropdownButtonFormField<QuizMetadata>(
                    value: _selectedQuiz,
                    hint: const Text('Select a Quiz'),
                    isExpanded: true,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    items: quizzes.map((quiz) {
                      return DropdownMenuItem<QuizMetadata>(
                        value: quiz,
                        child: Text(
                          quiz.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (QuizMetadata? newValue) {
                      setState(() {
                        _selectedQuiz = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a quiz';
                      }
                      return null;
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(null),
        ),
        ElevatedButton(
          onPressed: _isCreating
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _isCreating = true;
                    });

                    final createdId = await widget.onCreateRoom(
                      _roomNameController.text.trim(),
                      int.parse(_limitController.text),
                      _selectedQuiz!,
                    );

                    // Użyj `context.mounted` dla bezpieczeństwa
                    if (!context.mounted) return;

                    setState(() {
                      _isCreating = false;
                    });

                    if (createdId != null) {
                      Navigator.of(context).pop(createdId);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Failed to create room. Please try again.')));
                    }
                  }
                },
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}

class RoomListItem extends StatelessWidget {
  final Map<String, dynamic> room;
  final Future<void> Function(String roomID) onJoin;

  const RoomListItem({
    super.key,
    required this.room,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final String roomID = room['id'] ?? 'UNKNOWN_ID';
    final String roomName = room['roomName'] ?? 'Unnamed Room';
    final String quizTitle =
        (room['quiz'] is Map ? room['quiz']['title'] : null) ??
            'No Quiz Selected';
    final int playerCount = room['playerCount'] ?? 0;
    final int playerLimit = room['playerLimit'] ?? 2;

    if (roomID == 'UNKNOWN_ID') return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title:
            Text(roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Text('Quiz: $quizTitle\nPlayers: $playerCount / $playerLimit'),
        trailing: ElevatedButton(
          onPressed: () async {
            await onJoin(roomID);
          },
          child: const Text('Join'),
        ),
        isThreeLine: true,
      ),
    );
  }
}