import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';


class LobbyScreen extends StatefulWidget {
  final String roomID;
  const LobbyScreen({super.key, required this.roomID});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  late DatabaseReference _roomRef;
  User? _user;
  bool _isHost = false;

  Stream<DatabaseEvent>? _roomStream; // Nullable

  @override
  void initState() {
    super.initState();
    print(">>> LobbyScreen zainicjalizowany z roomID: ${widget.roomID} <<<");
    _user = _auth.currentUser;
    if (_user == null) {
      print("BŁĄD: Użytkownik jest null w LobbyScreen initState!");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _roomRef = _db.ref('rooms/${widget.roomID}');

    _checkIfHostAndSetupPresence().then((_) {
      if (mounted) {
        print("Przypisanie strumienia _roomStream po _checkIfHostAndSetupPresence.");
        setState(() {
          _roomStream = _roomRef.onValue;
        });
      }
    });
  }

  Future<void> _checkIfHostAndSetupPresence() async {
     print("_checkIfHost: Sprawdzanie istnienia pokoju...");
    final roomSnapshot = await _roomRef.get();
    if (!mounted) return;

    if (!roomSnapshot.exists) {
      print("BŁĄD KRYTYCZNY: Pokój ${widget.roomID} nie istnieje w _checkIfHost!");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    print("_checkIfHost: Pokój istnieje. Sprawdzanie hosta...");

    final hostData = roomSnapshot.child('host').value;
    _isHost = (hostData is String && hostData == _user!.uid);
    print("Użytkownik ${_user!.uid} jest hostem: $_isHost");

     if (mounted) {
      setState(() {});
    }

    if (_isHost) {
       await _roomRef.onDisconnect().remove().catchError((e) {
         print("Błąd ustawiania onDisconnect dla hosta: $e");
       });
       print("Reguły onDisconnect dla hosta ustawione (usuwanie pokoju).");
    } else {
      final playerRef = _roomRef.child('players/${_user!.uid}');
      try {
        await playerRef.onDisconnect().remove();
        print("Reguły onDisconnect dla gracza ${_user!.uid} (tylko usunięcie z listy) ustawione.");
      } catch (e) {
         print("Błąd podczas ustawiania onDisconnect dla gracza: $e");
      }
    }
     print("_checkIfHostAndSetupPresence zakończone.");
  }

  Future<void> _startGame() async {
    if (_isHost) {
       print("Host starting game...");
       try {
          await _roomRef.child('status').set('in_game');
          print("Room status set to in_game.");
       } catch(e) {
          print("Error setting room status to in_game: $e");
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error starting game: $e')),
             );
          }
       }
    }
  }

  Future<void> _cancelOnDisconnectRules() async {
     if (_user == null) return;
     print("Anulowanie reguł onDisconnect...");
     try {
       await _roomRef.onDisconnect().cancel().catchError((e) {
         print("roomRef.onDisconnect.cancel() error (ignored): $e");
       });

       if (!_isHost) {
         final playerRef = _roomRef.child('players/${_user!.uid}');
         await playerRef.onDisconnect().cancel().catchError((e) {
           print("playerRef.onDisconnect.cancel() error (ignored): $e");
         });
       }
       print("Anulowano onDisconnect (safely).");
     } catch (e) {
       print("Błąd podczas anulowania onDisconnect: $e");
     }
  }

   Future<void> _performLeaveAction() async {
     if (_user == null) return;
     print("Wykonywanie akcji wyjścia...");
      try {
        if (_isHost) {
          print("Host ręcznie usuwa pokój...");
          await _roomRef.remove();
          print("Pokój usunięty przez hosta.");
        } else {
           print("Gracz ręcznie opuszcza pokój (usuwanie i transakcja licznika)...");
           await _roomRef.child('players/${_user!.uid}').remove();
           await _roomRef.child('playerCount').runTransaction((currentData) {
             if (currentData == null) {
               print("Transakcja playerCount: Brak danych, ustawiam 0.");
               return Transaction.success(0);
             }
             if (currentData is int) {
               final newVal = (currentData - 1).clamp(0, 9999);
               print("Transakcja playerCount: Old=$currentData, New=$newVal");
               return Transaction.success(newVal);
             }
              print("Transakcja playerCount: Nieprawidłowy typ danych ($currentData). Przerywam.");
             return Transaction.abort();
           });
           print("Gracz usunięty, licznik zaktualizowany przez transakcję.");
        }
      } catch (e) {
         print("Błąd podczas ręcznego opuszczania pokoju: $e");
      }
   }

  @override
  Widget build(BuildContext context) {
    print("LobbyScreen build method called. _roomStream is null: ${_roomStream == null}");

    if (_roomStream == null) {
       return Scaffold(
          appBar: AppBar(title: const Text('Lobby')),
          body: const Center(child: Text('Initializing lobby...')),
       );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            print("Prosty przycisk Wstecz naciśnięty (jawny klucz)...");
            try {
              await _cancelOnDisconnectRules();
              await _performLeaveAction();
            } catch (e) {
               print("Błąd podczas wychodzenia (przycisk wstecz): $e");
            } finally {
               if (mounted) {
                 Navigator.pop(context,true);
                 print("Wywołano pop() na friendBoardNavigatorKey po ręcznym wyjściu.");
               }
            }
          },
        ),
      ),
      body: StreamBuilder(
        stream: _roomStream!,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState != ConnectionState.active && !snapshot.hasData) {
            print("StreamBuilder: State = Waiting for initial data...");
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("StreamBuilder: Stream has error: ${snapshot.error}");
            return Center(child: Text('Error listening to room: ${snapshot.error}'));
          }

          final roomDataRaw = snapshot.data?.snapshot.value;
          if (snapshot.connectionState == ConnectionState.active && roomDataRaw == null) {
              print("StreamBuilder: Data received as null (Room likely deleted by host)");
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  print("StreamBuilder: Popping LobbyScreen because room data became null.");
                  Navigator.pop(context,true);
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                     const SnackBar(content: Text('Room closed by host.')),
                   );
                }
              });
              return const Center(child: Text('Room closed by host...'));
          }

           if (roomDataRaw == null) {
              print("StreamBuilder: Data is still null, but connection active. Waiting...");
              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)));
           }

          print("StreamBuilder: Data received and is not null.");

          Map<String, dynamic> roomData;
          if (roomDataRaw is Map) {
             roomData = Map<String, dynamic>.from(roomDataRaw);
          } else {
             print("StreamBuilder: Incorrect room data format received.");
             return const Center(child: Text('Incorrect room data format.'));
          }

          final String roomName = roomData['roomName'] ?? 'Unnamed Room';
          final String quizTitle = (roomData['quiz'] is Map ? roomData['quiz']['title'] : null) ?? 'No Quiz Selected';
          final int playerCount = roomData['playerCount'] ?? 0;
          final int playerLimit = roomData['playerLimit'] ?? 2;
          final String status = roomData['status'] ?? 'waiting';

          if (status == 'in_game') {
            print("StreamBuilder: Game status 'in_game'. Navigating...");
            // TODO: Nawigacja do GameScreen
            return const Center(child: Text('Game starting...'));
          }

          final Map<String, dynamic> playersMap = roomData['players'] is Map
              ? Map<String, dynamic>.from(roomData['players'] as Map)
              : {};
          final List<String> playerNames = playersMap.values
              .map((playerData) {
                 if (playerData is Map && playerData['displayName'] is String) {
                    return playerData['displayName'] as String;
                 }
                 return 'Invalid Player Data';
               })
              .toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quiz: $quizTitle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Players: $playerCount / $playerLimit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: playerLimit,
                    itemBuilder: (context, index) {
                      if (index < playerNames.length) {
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(
                            playerNames[index],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: playersMap.keys.elementAt(index) == roomData['host']
                             ? const Chip(label: Text('Host'), padding: EdgeInsets.zero)
                             : null,
                        );
                      } else {
                        return const ListTile(
                          leading: Icon(Icons.person_outline, color: Colors.grey),
                          title: Text(
                            'Waiting for player...',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (_isHost)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: playerCount > 1 ? _startGame : null,
                      child: Text(
                        playerCount > 1 ? 'Start Game' : 'Waiting for more players...',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

   @override
   void dispose() {
     print("LobbyScreen dispose method called.");
     _cancelOnDisconnectRules();
     super.dispose();
   }
}