import 'package:flutter/material.dart';

class FriendBoard extends StatefulWidget{
  const FriendBoard({super.key});
  
  @override
  State<FriendBoard> createState() => _FriendBoardState();
}

class _FriendBoardState extends State<FriendBoard> {
  @override
    Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Friend Goard',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    ); 
}
}