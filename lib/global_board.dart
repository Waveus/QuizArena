import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quizarena/models/QuizMetadata';
import 'package:flutter_quizarena/repositories/QuizRepository.dart';
import 'package:flutter_quizarena/lobby_screen.dart';


class GlobalBoard extends StatefulWidget {
  const GlobalBoard({super.key});

  @override
  State<GlobalBoard> createState() => _GlobalBoardState();
}

class _GlobalBoardState extends State<GlobalBoard>
    with AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final QuizRepository _quizRepository = QuizRepository();

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

    final DatabaseReference roomsRef = _db.ref('rooms');
    final DatabaseReference newRoomRef = roomsRef.push();

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
      'createdAt': ServerValue.timestamp,
      'visibility': 'public',
      'status_visibility': 'waiting_public',
    };

    try {
      await newRoomRef.set(roomData);
      await newRoomRef.onDisconnect().remove();
      return newRoomRef.key;
    } catch (e) {
      return null;
    }
  }

  Future<void> _joinRoom(String roomID) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final DatabaseReference roomRef = _db.ref('rooms/$roomID');

    try {
      final TransactionResult result = await roomRef.runTransaction(
        (Object? roomData) {
          if (roomData == null) {
            return Transaction.abort();
          }

          Map<String, dynamic> room;
          if (roomData is Map) {
            room = Map<String, dynamic>.from(roomData.cast<String, dynamic>());
          } else {
            return Transaction.abort();
          }
          
          if (room['players'] != null && room['players'] is Map) {
             room['players'] = Map<String, dynamic>.from(room['players'].cast<String, dynamic>());
          } else {
             room['players'] = <String, dynamic>{};
          }

          final bool isWaiting = room['status'] == 'waiting';
          final bool hasSpace = (room['playerCount'] as int) < (room['playerLimit'] as int);
          final bool alreadyJoined = (room['players'] as Map).containsKey(user.uid);

          if (isWaiting && hasSpace && !alreadyJoined) {
            room['playerCount'] = (room['playerCount'] as int) + 1;
            (room['players'] as Map)[user.uid] = {
              'displayName': user.displayName ?? 'Player'
            };
            return Transaction.success(room);
          } else if (isWaiting && alreadyJoined) {
            return Transaction.success(roomData); 
          } else {
            return Transaction.abort();
          }
        },
      );

      if (result.committed) {
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Failed to join room (full, in game, or does not exist).')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining room: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Query roomsQuery = _db
        .ref('rooms')
        .orderByChild('status_visibility') 
        .equalTo('waiting_public');       
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rooms'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoomDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Room'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: roomsQuery.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading rooms: ${snapshot.error}'));
          }

          final data = snapshot.data?.snapshot.value;
          final roomsList = <Map<String, dynamic>>[];

          if (data != null && data is Map) {
            data.forEach((key, value) {
              if (value is Map) {
                roomsList.add({'id': key, ...Map<String, dynamic>.from(value.cast<String, dynamic>())});
              }
            });
          }

          if (roomsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No available rooms.\nCreate one!',
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
            itemCount: roomsList.length,
            itemBuilder: (context, index) {
              final room = roomsList[index];
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
                  
                  if (_selectedQuiz != null &&
                      !quizzes.any((q) => q.id == _selectedQuiz!.id)) {
                    _selectedQuiz = null;
                  }
                  if (_selectedQuiz == null && quizzes.isNotEmpty) {
                    _selectedQuiz = quizzes.first;
                  }

                  return DropdownButtonFormField<QuizMetadata>(
                    initialValue: _selectedQuiz,
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
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
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
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Form validation failed!')));
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