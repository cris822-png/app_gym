import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
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
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');

    if (token != null) {
      try {
        final apiService = ApiService();
        final result = await apiService.verificarSesion(token);
        final userId = result['id_usuario'] as int?;
        final userName = result['name'] as String?;
        final expiresAt = result['expires_at'] as String?;

        if (userId != null && userName != null) {
          if (expiresAt != null) {
            final expiryMillis = DateTime.tryParse(expiresAt)?.millisecondsSinceEpoch;
            if (expiryMillis != null) {
              await prefs.setInt('session_expiry', expiryMillis);
            }
          }
          await prefs.setInt('user_id', userId);
          await prefs.setString('user_name', userName);

          if (mounted) {
            setState(() {
              _loggedIn = true;
              _userId = userId;
              _userName = userName;
              _checkingSession = false;
            });
          }
          return;
        }
      } catch (e) {
        // Sesión inválida o error al verificar, se limpia el almacenamiento local
      }

      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('session_token');
      await prefs.remove('session_expiry');
    }

    if (mounted) {
      setState(() {
        _checkingSession = false;
      });
    }
  }

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

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    
    if (token != null) {
      try {
        final apiService = ApiService();
        await apiService.logout(token);
      } catch (e) {
        // Error al eliminar sesión en el servidor, continuamos con logout local
      }
    }
    
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('session_token');
    await prefs.remove('session_expiry');
    
    setState(() {
      _loggedIn = false;
      _userId = null;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
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
