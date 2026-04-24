import 'package:flutter/material.dart';
import 'screens/coach_screen.dart';

void main() {
  runApp(const AppGym());
}

class AppGym extends StatelessWidget {
  const AppGym({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Gym',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade700),
        useMaterial3: true,
      ),
      home: const CoachScreen(
        idUsuario: 1,
      ),
    );
  }
}
