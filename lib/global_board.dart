import 'package:flutter/material.dart';

class GlobalBoard extends StatefulWidget{
  const GlobalBoard({super.key});
  
  @override
  State<GlobalBoard> createState() => _GlobalBoardState();
}

class _GlobalBoardState extends State<GlobalBoard> {
  @override
    Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Global Goard',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    ); 
}
}