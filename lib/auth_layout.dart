import 'package:flutter/material.dart';
import 'package:flutter_quizarena/app_layout.dart';
import 'package:flutter_quizarena/loading.dart';
import 'package:flutter_quizarena/services/auth_service.dart';
import 'package:flutter_quizarena/welcome.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    this.pageIfNotConnected,
  });

  final  Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: authService, 
      builder: (context, authService, child) {
          return StreamBuilder(stream: authService.authStateChanges, 
          builder: (context, snapshot) {
            Widget widget;
            if (snapshot.connectionState == ConnectionState.waiting) {
              widget = Loading();
            } else if (snapshot.hasData) {
              widget = AppLayout();
            } else {
              widget = pageIfNotConnected ?? const Welcome();
            }
            return widget;
          },
        );
      }
      );
  }

}

