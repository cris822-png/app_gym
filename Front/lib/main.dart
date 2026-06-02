import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación en vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Estilo de la barra de estado transparente sobre fondo oscuro
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg2,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const AppGym());
}

class AppGym extends StatelessWidget {
  const AppGym({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Gym',
      debugShowCheckedModeBanner: false,
      // ── Dark mode con design system propio ──────────────────────────────
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // ── WorkoutProvider a nivel raíz para compartir estado entre
      //    WorkoutScreen y ChatScreen / IaChatOverlay ─────────────────────
      home: _AppRoot(),
    );
  }
}

/// Wrapper que inyecta WorkoutProvider.
/// Se hace aquí (no en MaterialApp) para poder acceder al userId
/// una vez que el usuario haya hecho login.
class _AppRoot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MainApp();
  }
}
