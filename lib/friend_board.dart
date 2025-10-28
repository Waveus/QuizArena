import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quizarena/models/QuizMetadata';

// === IMPORTY ===
import 'package:flutter_quizarena/repositories/QuizRepository.dart'; // Twoje repozytorium
import 'package:flutter_quizarena/lobby_screen.dart'; // Ekran lobby
// ===============

class FriendBoard extends StatefulWidget {
  final VoidCallback? onPopFromNestedRoute;
  
  const FriendBoard({super.key, this.onPopFromNestedRoute});

  @override
  State<FriendBoard> createState() => _FriendBoardState();
}

class _FriendBoardState extends State<FriendBoard> 
  with AutomaticKeepAliveClientMixin{
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Utwórz instancję repozytorium
  final QuizRepository _quizRepository = QuizRepository();

  // --- Otwiera okno dialogowe ---
  void _showCreateRoomDialog(BuildContext context) async {
    // showDialog zwraca ID pokoju (lub null), gdy dialog jest zamykany przez pop()
    final String? newRoomId = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _CreateRoomDialog(
          quizRepository: _quizRepository,
          onCreateRoom: (roomName, playerLimit, selectedQuiz) async {
            String? createdRoomId = await _createRoom(roomName, playerLimit, selectedQuiz);
            Navigator.of(dialogContext).pop(createdRoomId);
          },
        );
      },
    ); // Koniec showDialog

    // --- Diagnostyka ---
    print("--- Dialog został zamknięty ---");
    print("Otrzymano ID pokoju: $newRoomId");
    print("Widget _FriendBoardState jest zamontowany (mounted): $mounted");
    // ------------------

    // --- Nawigacja dzieje się TUTAJ, PO zamknięciu dialogu ---
    if (newRoomId != null && mounted) {
      print(">>> Próba nawigacji do LobbyScreen z ID: $newRoomId (w zagnieżdżonym) <<<");
      // --- KROK 2: Dodaj .then() po push ---
      await Navigator.of(context).push( // Dodaj await
        MaterialPageRoute(
          builder: (context) => LobbyScreen(roomID: newRoomId),
        ),
      ).then((_) {
         // Ten kod wykona się PO powrocie z LobbyScreen
         print("Returned from LobbyScreen (Create). Calling onPop callback.");
         widget.onPopFromNestedRoute?.call(); // Wywołaj callback przekazany z AppLayout
      });
      // ------------------------------------
    } else if (newRoomId == null && mounted) {
      print("Tworzenie pokoju anulowane lub nieudane.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create room.')),
      );
    }
  }

  // --- Tworzy pokój w Firebase ---
  // Zwraca ID pokoju lub null, jeśli się nie udało
  Future<String?> _createRoom(
    String roomName,
    int playerLimit,
    QuizMetadata selectedQuiz,
  ) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print("Błąd: Użytkownik niezalogowany podczas próby stworzenia pokoju.");
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
      'quiz': {
        'id': selectedQuiz.id,
        // Upewnij się, że QuizMetadata ma pole `title` LUB zmień na `name`
        'title': selectedQuiz.name, // <<-- UWAGA: Sprawdź czy pole to 'name' czy 'title' w QuizMetadata
        // 'category': selectedQuiz.category,
      },
      'players': {
        user.uid: {
          'displayName': user.displayName ?? 'Host',
        }
      }
    };

    try {
      await newRoomRef.set(roomData);
      // Ustaw onDisconnect DOPIERO po pomyślnym zapisie
      await newRoomRef.onDisconnect().remove();
      print('Pokój ${newRoomRef.key} utworzony PRAWIDŁOWO w Firebase.');
      return newRoomRef.key; // Zwróć ID nowego pokoju
    } catch (e) {
      print("Błąd podczas tworzenia pokoju w Firebase: $e");
      return null;
    }
  }

  // --- Dołącza do pokoju (używa transakcji) ---
  Future<void> _joinRoom(String roomID) async {
    final User? user = _auth.currentUser;
    if (user == null) {
       print("Błąd: Użytkownik niezalogowany podczas próby dołączenia.");
       return;
    }

    print("Próba dołączenia do pokoju: $roomID przez użytkownika ${user.uid}");
    final DatabaseReference roomRef = _db.ref('rooms/$roomID');

    try {
      final TransactionResult result = await roomRef.runTransaction((Object? roomData) {
        if (roomData == null) {
           print("Transakcja przerwana: Pokój $roomID nie istnieje.");
          return Transaction.abort();
        }

        Map<String, dynamic> room;
         if (roomData is Map) {
            room = Map<String, dynamic>.from(roomData);
         } else {
            print("Transakcja przerwana: Nieprawidłowy format danych pokoju.");
            return Transaction.abort();
         }

        final bool isWaiting = room['status'] == 'waiting';
        final bool hasSpace = (room['playerCount'] is int && room['playerLimit'] is int)
            ? (room['playerCount'] as int) < (room['playerLimit'] as int)
            : false;
        final bool alreadyJoined = (room['players'] as Map?)?.containsKey(user.uid) ?? false;

        print("Warunki dołączenia: isWaiting=$isWaiting, hasSpace=$hasSpace, alreadyJoined=$alreadyJoined");

        if (isWaiting && hasSpace && !alreadyJoined) {
          print("Warunki spełnione. Aktualizowanie danych pokoju...");
          room['playerCount'] = (room['playerCount'] as int) + 1;

          if (room['players'] is! Map) {
             room['players'] = <String, dynamic>{};
          }

          (room['players'] as Map)[user.uid] = {
            'displayName': user.displayName ?? 'Player'
          };
          print("Dane pokoju zaktualizowane. Zwracanie sukcesu transakcji.");
          return Transaction.success(room);
        } else {
          print("Warunki dołączenia niespełnione. Przerywanie transakcji.");
          return Transaction.abort();
        }
      });

      if (result.committed) {
        print("Transakcja dołączenia zakończona sukcesem!");
        if (mounted) {
          // --- KROK 2 (ponownie): Dodaj .then() po push ---
          await Navigator.of(context).push( // Dodaj await
            MaterialPageRoute(
              builder: (context) => LobbyScreen(roomID: roomID),
            ),
          ).then((_) {
             // Ten kod wykona się PO powrocie z LobbyScreen
             print("Returned from LobbyScreen (Join). Calling onPop callback.");
             widget.onPopFromNestedRoute?.call(); // Wywołaj callback
          });
        }
      } else {
        print("Transakcja dołączenia nieudana (pokój pełny, w grze, już dołączono lub usunięto).");
        if(mounted){
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Failed to join room (full, in game, or already joined).')),
           );
        }
      }
    } catch (e) {
      print("Błąd podczas transakcji dołączania: $e");
       if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error joining room: $e')),
          );
       }
    }
  }

  // --- Buduje główny ekran ---
  @override
  Widget build(BuildContext context) {
    // --- Print diagnostyczny ---
    print("--- FriendBoard build method called ---");
    // ----------------------
    super.build(context);
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
          // --- Printy diagnostyczne StreamBuilder ---
          print("--- FriendBoard StreamBuilder updated ---");
          print("Connection State: ${snapshot.connectionState}");
          print("Has Data: ${snapshot.hasData}");
          print("Has Error: ${snapshot.hasError}");
          if(snapshot.hasError) {
            print("StreamBuilder Error Details: ${snapshot.error}");
          }
          if(snapshot.hasData) {
            print("StreamBuilder Data Value: ${snapshot.data?.snapshot.value}");
          }
          // -------------------------------------

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading rooms: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(
              child: Text(
                'No available rooms.\nCreate one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          // Bezpieczne rzutowanie i przetwarzanie danych
          try {
            final data = snapshot.data!.snapshot.value;
            if (data is! Map) {
              print('StreamBuilder: Data is not a Map. Actual: ${data.runtimeType}');
              return const Center(child: Text('Incorrect data format received.'));
            }
            final roomsMap = Map<String, dynamic>.from(data);

            final roomsList = roomsMap.entries.map((entry) {
              final value = entry.value;
              if (value is Map) {
                return {
                  'id': entry.key,
                  ...Map<String, dynamic>.from(value)
                };
              } else {
                print('Warning: Invalid room data format for key ${entry.key}');
                return <String, dynamic>{'id': entry.key};
              }
            }).where((room) => room.isNotEmpty && room['id'] != null).toList(); // Upewnij się, że ID istnieje

            if (roomsList.isEmpty && roomsMap.isNotEmpty) {
              return const Center(child: Text('Error processing room data.'));
            }

            return ListView.builder(
              itemCount: roomsList.length,
              itemBuilder: (context, index) {
                final room = roomsList[index];
                // Dodatkowe zabezpieczenie
                if (room['id'] == null) return const SizedBox.shrink();

                return RoomListItem(
                  room: room,
                  onJoin: (roomID) async {
                    await _joinRoom(roomID);
                  },
                );
              },
            );
          } catch (e, st) {
            print('Exception parsing rooms in FriendBoard StreamBuilder: $e\n$st');
            return Center(child: Text('Error parsing rooms: $e'));
          }
        },
      ),
    );
  }
  
  @override
  bool get wantKeepAlive => true;
}

// =======================================================================
// WIDGET: OKNO DIALOGOWE TWORZENIA POKOJU (StatefulWidget)
// =======================================================================

class _CreateRoomDialog extends StatefulWidget {
  final QuizRepository quizRepository;
  // Funkcja zwrotna (teraz asynchroniczna)
  final Function(String roomName, int playerLimit, QuizMetadata selectedQuiz) onCreateRoom;

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
    print("_CreateRoomDialog build method called");
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
                decoration: const InputDecoration(labelText: 'Player Limit (2-16)'),
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
                    print('Dropdown Error: ${snapshot.error}');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('Error loading quizzes: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                     return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('No available quizzes found.'),
                    );
                  }

                  final quizzes = snapshot.data!;

                  // Reset _selectedQuiz if it's no longer in the list (edge case)
                  if (_selectedQuiz != null && !quizzes.any((q) => q.id == _selectedQuiz!.id)) {
                      _selectedQuiz = null;
                       // Wywołaj setState, aby odświeżyć UI po zresetowaniu
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                         if (mounted) setState(() {});
                       });
                  }

                  return DropdownButtonFormField<QuizMetadata>(
                    value: _selectedQuiz,
                    hint: const Text('Select a Quiz'),
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: quizzes.map((quiz) {
                      return DropdownMenuItem<QuizMetadata>(
                        value: quiz,
                        child: Text(
                          // Użyj 'title' lub 'name' - zależnie od modelu
                          quiz.name, // <<-- UWAGA: Sprawdź czy pole to 'name' czy 'title'
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
          // Zamyka dialog zwracając null
          onPressed: () => Navigator.of(context).pop(null),
        ),
        ElevatedButton(
          child: const Text('Create'),
          onPressed: () async {
            print("Create button pressed!");
            if (_formKey.currentState!.validate()) {
              print("Form validation passed!");
              print("Calling widget.onCreateRoom...");
              try { // <-- Dodaj try
                // Wywołaj funkcję zwrotną (ona tworzy pokój i ZAMYKA dialog z ID)
                await widget.onCreateRoom(
                  _roomNameController.text.trim(),
                  int.parse(_limitController.text),
                  _selectedQuiz!,
                );
                print("widget.onCreateRoom finished successfully."); // <-- Zmieniono print
              } catch (e) { // <-- Dodaj catch
                print("!!! Error during widget.onCreateRoom execution: $e");
                // Jeśli wystąpi błąd, zamknij dialog bez zwracania ID,
                // aby główna funkcja wiedziała, że coś poszło nie tak.
                if(mounted) {
                  Navigator.of(context).pop(null); // Zwróć null w razie błędu
                }
              }
              // Już NIE zamykamy okna tutaj ręcznie, robi to callback onCreateRoom
            } else {
              print("Form validation failed!");
            }
          },
        ),
      ],
    );
  }
}

// =======================================================================
// WIDGET: ELEMENT LISTY POKOI (Zaktualizowany)
// =======================================================================

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
    // Bezpieczne pobieranie danych
    final String roomID = room['id'] ?? 'UNKNOWN_ID';
    final String roomName = room['roomName'] ?? 'Unnamed Room';
    final String quizTitle = (room['quiz'] is Map ? room['quiz']['title'] : null) ?? 'No Quiz Selected';
    final int playerCount = room['playerCount'] ?? 0;
    final int playerLimit = room['playerLimit'] ?? 2;

    if (roomID == 'UNKNOWN_ID') {
       print("Warning: Rendering RoomListItem with UNKNOWN_ID.");
       return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Quiz: $quizTitle\nPlayers: $playerCount / $playerLimit'),
        trailing: ElevatedButton(
          onPressed: () async {
            print("Join button pressed for room: $roomID");
            await onJoin(roomID);
             print("onJoin function finished for room: $roomID");
          },
          child: const Text('Join'),
        ),
        isThreeLine: true,
      ),
    );
  }
}