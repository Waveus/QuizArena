import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quizarena/models/QuizMetadata';

// === IMPORTY, KTÓRYCH MOGŁO BRAKOWAĆ ===
// (Upewnij się, że ścieżki pasują do struktury Twojego projektu)

// 3. Import Ekranu Lobby (KLUCZOWY DO NAWIGACJI)
import 'package:flutter_quizarena/lobby_screen.dart';
import 'package:flutter_quizarena/repositories/QuizRepository.dart'; 

// ===========================================

class GlobalBoard extends StatefulWidget {
  const GlobalBoard({super.key});

  @override
  State<GlobalBoard> createState() => _GlobalBoardState();
}

class _GlobalBoardState extends State<GlobalBoard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  
  // Utwórz instancję repozytorium
  final QuizRepository _quizRepository = QuizRepository();

  // Ta funkcja JEDYNIE OTWIERA nowe okno dialogowe
  void _showCreateRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      // Używamy naszego nowego widgetu, przekazując mu potrzebne zależności
      builder: (BuildContext dialogContext) {
        return _CreateRoomDialog(
          quizRepository: _quizRepository,
          onCreateRoom: (roomName, playerLimit, selectedQuiz) async {
            // Ta funkcja zostanie wywołana przez okno dialogowe
            // Zmieniliśmy ją na async, aby poczekać na stworzenie pokoju
            String? newRoomId = await _createRoom(roomName, playerLimit, selectedQuiz);
            
            if (newRoomId != null && mounted) {
              // --- NAWIGACJA PO STWORZENIU POKOJU ---
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LobbyScreen(roomID: newRoomId),
                ),
              );
            }
          },
        );
      },
    );
  }

  // Zwraca ID pokoju lub null, jeśli się nie udało
  Future<String?> _createRoom(
    String roomName,
    int playerLimit,
    QuizMetadata selectedQuiz, 
  ) async {
    final User? user = _auth.currentUser;
    if (user == null) return null; 

    final DatabaseReference roomsRef = _db.ref('rooms');
    final DatabaseReference newRoomRef = roomsRef.push(); 

    final roomData = {
      'host': user.uid,
      'roomName': roomName, 
      'status': 'waiting',
      'playerLimit': playerLimit,
      'playerCount': 1,
      'quiz': {
        'id': selectedQuiz.id,
        'title': selectedQuiz.name,
      },
      'players': {
        user.uid: {
          'displayName': user.displayName ?? 'Host', 
        }
      }
    };

    try {
      await newRoomRef.set(roomData);
      await newRoomRef.onDisconnect().remove();
      return newRoomRef.key; // Zwróć ID nowego pokoju
    } catch (e) {
      print("Error creating room: $e");
      return null;
    }
  }

  // Funkcja dołączania do pokoju (używa transakcji)
  Future<void> _joinRoom(String roomID) async {
    final User? user = _auth.currentUser;
    if (user == null) return; 

    final DatabaseReference roomRef = _db.ref('rooms/$roomID');

    try {
      final TransactionResult result = await roomRef.runTransaction((Object? roomData) {
        if (roomData == null) {
          return Transaction.abort(); 
        }

        Map<String, dynamic> room = Map<String, dynamic>.from(roomData as Map);
        
        final bool isWaiting = room['status'] == 'waiting';
        final bool hasSpace = (room['playerCount'] as int) < (room['playerLimit'] as int);

        if (isWaiting && hasSpace) {
          room['playerCount'] = (room['playerCount'] as int) + 1;
          
          if (room['players'] == null) {
             room['players'] = {};
          }
          (room['players'] as Map)[user.uid] = {
            'displayName': user.displayName ?? 'Player'
          };
          
          return Transaction.success(room);
        } else {
          return Transaction.abort();
        }
      });

      if (result.committed) {
        print("Successfully joined room!");
        
        // --- NAWIGACJA PO DOŁĄCZENIU DO POKOJU ---
        if (mounted) {
           Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LobbyScreen(roomID: roomID),
            ),
          );
        }
      } else {
        print("Failed to join room (full, in game, or deleted).");
        // TODO: Pokaż błąd (pokój pełny)
      }
    } catch (e) {
      print("Error joining room: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Query roomsQuery = _db.ref('rooms')
                                .orderByChild('status')
                                .equalTo('waiting');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rooms'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoomDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Room'),
      ),
      
      body: StreamBuilder(
        stream: roomsQuery.onValue, 
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: Text('Error loading rooms.'));
          }

          final data = snapshot.data?.snapshot.value;
          if (data == null) {
            return const Center(
              child: Text(
                'No available rooms.\nCreate one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          
          final Map<String, dynamic> roomsMap = Map<String, dynamic>.from(data as Map);

          final List<Map<String, dynamic>> roomsList = roomsMap.entries.map((entry) {
            return {
              'id': entry.key,
              ...Map<String, dynamic>.from(entry.value as Map)
            };
          }).toList();

          return ListView.builder(
            itemCount: roomsList.length,
            itemBuilder: (context, index) {
              final room = roomsList[index];
              return RoomListItem( 
                room: room,
                onJoin: (roomID) async {
                  // --- CZEKAMY (AWAIT) NA DOŁĄCZENIE ---
                  await _joinRoom(roomID);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// =======================================================================
// WIDGET: OKNO DIALOGOWE TWORZENIA POKOJU
// =======================================================================

class _CreateRoomDialog extends StatefulWidget {
  final QuizRepository quizRepository;
  // Funkcja zwrotna (teraz asynchroniczna)
  final Future<void> Function(String roomName, int playerLimit, QuizMetadata selectedQuiz) onCreateRoom;

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

  @override
  void initState() {
    super.initState();
    _quizzesStream = widget.quizRepository.getAvailableQuizzesStream();
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
              // --- Pole Nazwy Pokoju ---
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
              
              // --- Pole Limitu Graczy ---
              TextFormField(
                controller: _limitController,
                decoration: const InputDecoration(labelText: 'Player Limit (e.g., 8)'),
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

              // --- Dropdown z Quizami ---
              StreamBuilder<List<QuizMetadata>>(
                stream: _quizzesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.hasError) {
                    return Text('Error loading quizzes: ${snapshot.error}');
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Text('No available quizzes found.');
                  }

                  final quizzes = snapshot.data!;

                  return DropdownButtonFormField<QuizMetadata>(
                    value: _selectedQuiz,
                    hint: const Text('Select a Quiz'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Create'),
          onPressed: () async { // <-- 1. Dodaj 'async'
            // Sprawdź, czy formularz jest poprawny
            if (_formKey.currentState!.validate()) {
              
              // 2. Zaczekaj (await), aż funkcja tworzenia pokoju się wykona
              await widget.onCreateRoom(
                _roomNameController.text.trim(),
                int.parse(_limitController.text),
                _selectedQuiz!,
              );
              
              // 3. Dopiero teraz zamknij okno dialogowe
              if (mounted) {
                 Navigator.of(context).pop(); 
              }
            }
          },
        ),
      ],
    );
  }
}


// =======================================================================
// WIDGET: ELEMENT LISTY POKOI
// =======================================================================

class RoomListItem extends StatelessWidget {
  final Map<String, dynamic> room;
  final Future<void> Function(String roomID) onJoin; // Funkcja (teraz asynchroniczna)

  const RoomListItem({
    super.key,
    required this.room,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final String roomID = room['id'] ?? '...';
    final String roomName = room['roomName'] ?? 'Unnamed Room';
    final String quizTitle = room['quiz']?['title'] ?? 'No Quiz Selected'; 
    final int playerCount = room['playerCount'] ?? 0;
    final int playerLimit = room['playerLimit'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Quiz: $quizTitle\nPlayers: $playerCount / $playerLimit'),
        trailing: ElevatedButton(
          onPressed: () async { // <-- 1. Dodaj 'async'
            await onJoin(roomID); // <-- 2. Dodaj 'await'
          },
          child: const Text('Join'),
        ),
        isThreeLine: true, 
      ),
    );
  }
}