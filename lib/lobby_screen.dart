import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

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
  late DatabaseReference _roomRef;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _roomRef = _db.ref('rooms/${widget.roomID}');
  }

  Future<bool> _onWillPop() async {
    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isHost ? 'Delete Room?' : 'Leave Room?'),
        content: Text(_isHost
            ? 'As the host, leaving will delete the room for everyone.'
            : 'Are you sure you want to leave the lobby?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isHost ? Colors.red : null,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_isHost ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      if (_isHost) {
        await _deleteRoom();
      } else {
        await _leaveRoom();
      }
      return true;
    }
    return false;
  }

  Future<void> _leaveRoom() async {
    try {
      final TransactionResult result = await _roomRef.runTransaction(
        (Object? roomData) {
          if (roomData == null) {
            return Transaction.abort();
          }

          Map<String, dynamic> room;
          if (roomData is Map) {
            room = Map<String, dynamic>.from(roomData);
          } else {
            return Transaction.abort();
          }

          if (room['players'] is Map &&
              (room['players'] as Map).containsKey(widget.currentUserId)) {
            (room['players'] as Map).remove(widget.currentUserId);
            room['playerCount'] = (room['playerCount'] as int? ?? 1) - 1;

            return Transaction.success(room);
          } else {
            return Transaction.abort();
          }
        },
      );

      if (result.committed && mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving room: $e')),
        );
      }
    }
  }

  Future<void> _deleteRoom() async {
    try {
      await _roomRef.remove();
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting room: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lobby'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onWillPop,
          ),
        ),
        body: StreamBuilder<DatabaseEvent>(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              });
              return const Center(child: Text('Room deleted.'));
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final roomData = Map<String, dynamic>.from(
                snapshot.data!.snapshot.value as Map);
            final String roomName = roomData['roomName'] ?? 'Unnamed Room';
            final String quizTitle =
                (roomData['quiz'] is Map ? roomData['quiz']['title'] : null) ??
                    'No Quiz';
            final int playerCount = roomData['playerCount'] ?? 0;
            final int playerLimit = roomData['playerLimit'] ?? 2;
            final Map<String, dynamic> players =
                (roomData['players'] is Map)
                    ? Map<String, dynamic>.from(roomData['players'])
                    : {};
            
            _isHost = roomData['host'] == widget.currentUserId;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomName,
                    style: Theme.of(context).textTheme.headlineMedium,
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
                  const SizedBox(height: 16),
                  const Text(
                    'Player List:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final playerId = players.keys.elementAt(index);
                        final player = players[playerId] as Map;
                        final String displayName =
                            player['displayName'] ?? 'Player';
                        final bool isPlayerHost = playerId == roomData['host'];

                        return Card(
                          child: ListTile(
                            title: Text(displayName),
                            trailing: isPlayerHost
                                ? const Icon(Icons.star, color: Colors.amber)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          // TODO: add game logic
                          print("Start Game! (Not implemented)");
                        },
                        child: const Text('Start Game', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isHost ? Colors.red : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _onWillPop,
                      child: Text(
                        _isHost ? 'Delete Room' : 'Leave Room',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
