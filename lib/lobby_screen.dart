// Plik: lobby_screen.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quizarena/quiz_screen.dart'; // Import ekranu quizu

class LobbyScreen extends StatefulWidget {
  final String roomID;
  final String currentUserId;

  const LobbyScreen({
    super.key,
    required this.roomID,
    required this.currentUserId,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final DatabaseReference _roomRef;
  StreamSubscription? _roomSubscription;

  Map<String, dynamic>? _roomData;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _roomRef = _db.ref('rooms/${widget.roomID}');

    _listenToRoom();
  }

  void _listenToRoom() {
    _roomSubscription?.cancel(); 
    
    _roomSubscription = _roomRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      
      if (data == null) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pokój został rozwiązany przez hosta.')),
          );
        }
        return;
      }

      final roomData = Map<String, dynamic>.from(
        (data as Map).cast<String, dynamic>()
      );

     if (roomData['status'] == 'in_game' || roomData['status'] == 'playing') {
        
        final quizId = roomData['quiz']?['id'];
        if (quizId != null) {
          _roomSubscription?.cancel(); 
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => QuizScreen(
                quizId: quizId,
                roomId: widget.roomID,
               isHost: roomData['host'] == widget.currentUserId,
              ),
            ),
          ).then((_) {
            if (mounted) {
              _listenToRoom();
            }
          });
        }
      } 
      else if (roomData['status'] == 'waiting') {
         setState(() {
          _roomData = roomData;
          _isHost = roomData['host'] == widget.currentUserId;
        });
      }
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    if (!_isHost) return; 

    if (_roomData?['playerCount'] < 1) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Potrzebujesz co najmniej 1 gracza.')),
      );
      return;
    }

    try {
      await _roomRef.update({'status': 'in_game'});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się rozpocząć gry: $e')),
      );
    }
  }
  
  Future<void> _leaveRoom() async {
    if (_isHost) return; 
    try {
      await _roomRef.runTransaction((Object? roomData) {
         if (roomData == null) {
           return Transaction.abort();
         }
         
         Map<String, dynamic> room = Map<String, dynamic>.from(
           (roomData as Map).cast<String, dynamic>()
         );
         
         if (room['players'] != null && room['players'] is Map) {
            room['players'] = Map<String, dynamic>.from(
              room['players'].cast<String, dynamic>()
            );
         } else {
            room['players'] = <String, dynamic>{};
         }
         
         (room['players'] as Map).remove(widget.currentUserId);
         room['playerCount'] = (room['playerCount'] as int) - 1;

         return Transaction.success(room);
      });
      
      if (mounted) Navigator.of(context).pop(); 
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Błąd podczas opuszczania pokoju: $e')),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_roomData?['roomName'] ?? 'Ładowanie lobby...'),
        leading: !_isHost ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leaveRoom,
        ) : null,
      ),
      body: _roomData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quiz: ${_roomData?['quiz']?['title'] ?? '...'}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  Text('Gracze (${_roomData?['playerCount'] ?? 0} / ${_roomData?['playerLimit'] ?? 0}):', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: _buildPlayerList(),
                  ),
                  const SizedBox(height: 20),
                  
                  if (_isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                        child: const Text('Rozpocznij Grę', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  
                  if (!_isHost)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Oczekiwanie na rozpoczęcie gry przez hosta...', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlayerList() {
    final players = _roomData?['players'];
    if (players == null || players is! Map) {
      return const Center(child: Text('Brak graczy...'));
    }
    
    final playerMap = Map<String, dynamic>.from(players.cast<String, dynamic>());
    final playerEntries = playerMap.entries.toList();

    return ListView.builder(
      itemCount: playerEntries.length,
      itemBuilder: (context, index) {
        final playerId = playerEntries[index].key;
        
        final playerData = Map<String, dynamic>.from(
          (playerEntries[index].value as Map).cast<String, dynamic>()
        );
        
        final displayName = playerData['displayName'] ?? 'Gracz bez nazwy';
        final isPlayerHost = playerId == _roomData?['host'];

        return Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: isPlayerHost 
                ? const Chip(label: Text('Host'), backgroundColor: Colors.amber) 
                : null,
          ),
        );
      },
    );
  }
}