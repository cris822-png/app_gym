import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import 'workout_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _loggedIn = false;
  int _selectedIndex = 0;
  int? _userId;
  String _userName = 'Usuario';

  void _onLoginSuccess(int userId, String userName) {
    setState(() {
      _loggedIn = true;
      _userId = userId;
      _userName = userName;
      _selectedIndex = 0;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onLogout() {
    setState(() {
      _loggedIn = false;
      _userId = null;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn || _userId == null) {
      return LoginScreen(onLogin: _onLoginSuccess);
    }

    final pages = <Widget>[
      DashboardScreen(
        userId: _userId!,
        userName: _userName,
        onStartWorkout: () => _onItemTapped(1),
        onOpenChat: () => _onItemTapped(2),
      ),
      const WorkoutScreen(),
      ChatScreen(userId: _userId!),
      ProgressScreen(userId: _userId!),
      ProfileScreen(userId: _userId!, onLogout: _onLogout),
    ];

    return Scaffold(
      body: SafeArea(child: pages.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Entreno'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat IA'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progreso'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _onItemTapped(1),
              label: const Text('Iniciar Entreno'),
              icon: const Icon(Icons.play_arrow),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
