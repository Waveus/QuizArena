import 'package:flutter_quizarena/player.dart';

class Lobby {
  final String id;
  final String name;
  final Player host;

  const Lobby({required this.id, required this.name, required this.host});
}