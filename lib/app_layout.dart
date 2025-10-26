import 'package:flutter/material.dart';
import 'package:flutter_quizarena/friend_board.dart';
import 'package:flutter_quizarena/global_board.dart';
import 'package:flutter_quizarena/me.dart';
import 'package:flutter_quizarena/quizes.dart';

class AppLayout extends StatefulWidget{
  const AppLayout({super.key});
  
  @override
  State<AppLayout> createState() =>_AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int _selectedIndex = 0; 
  
  late PageController _pageController;

  final List<Widget> _screens = [
    const GlobalBoard(),
    const FriendBoard(),
    const Me(),
    const Quizes()
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("QuizArena"),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Global Board',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Friend Board',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Me',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Quizes'
          )
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}