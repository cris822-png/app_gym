import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/coach_recommendation.dart';
import '../models/entrenamiento.dart';
import '../models/registro_nutricion.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'nutricion_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final VoidCallback onStartWorkout;
  final VoidCallback onOpenChat;
  final VoidCallback onCreateRoutine;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.onStartWorkout,
    required this.onOpenChat,
    required this.onCreateRoutine,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  Usuario? _usuario;
  CoachRecommendation? _recommendation;
  List<RegistroNutricion> _registrosNutricion = [];
  List<Entrenamiento> _entrenamientos = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final usuario = await _apiService.getUsuario(widget.userId);
      final recommendation = await _apiService.getCoachRecommendation(widget.userId);
      final registros = await _apiService.getRegistrosNutricion(widget.userId);
      final entrenamientos = await _apiService.getEntrenamientos(widget.userId);

      setState(() {
        _usuario = usuario;
        _recommendation = recommendation;
        _registrosNutricion = registros;
        _entrenamientos = entrenamientos;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          Text('Hola, ${widget.userName}',
                              style: Theme.of(context).textTheme.headlineLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Este es tu resumen diario. Revisa recomendaciones, progreso y rutinas sugeridas.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          _buildSummaryRow(),
                          _buildSummaryInfo(_registrosNutricion.length),
                          const SizedBox(height: 20),
                          _buildRecommendationCard(),
                          const SizedBox(height: 20),
                          _buildWorkoutCard(),
                          const SizedBox(height: 20),
                          _buildQuickActionsRow(),
                          const SizedBox(height: 20),
                          _buildRecentSection(),
                          // Espacio para que el FAB central no tape el último item
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),

          // ── FAB esquina inferior izquierda: Nutrición ──
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'fab_nutricion',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NutricionScreen(userId: widget.userId),
                ),
              ),
              backgroundColor: const Color(0xFF10B981),
              tooltip: 'Mi Nutrición',
              child: const Icon(Icons.restaurant_menu,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      // ── FAB central: Iniciar Entreno ──
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_entreno',
        onPressed: widget.onStartWorkout,
        backgroundColor: AppColors.accentGreen,
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        label: const Text('Iniciar Entreno',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSummaryRow() {
    final weight = _usuario?.peso.toStringAsFixed(1) ?? '—';
    final height = _usuario?.altura.toStringAsFixed(0) ?? '—';
    final sessions = _entrenamientos.length;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Peso', '$weight kg', 'Última medición')),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Altura', '$height cm', 'Objetivo 12% grasa')),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Sesiones', '$sessions', 'Esta semana')),
      ],
    );
  }

  Widget _buildSummaryInfo(int meals) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Text('$meals comidas recientes registradas',
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recomendación directa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_recommendation?.mensaje ?? 'No hay recomendaciones disponibles.', style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: widget.onOpenChat, child: const Text('Abrir Chat IA')),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard() {
    final nextWorkout = _entrenamientos.isNotEmpty ? 'Revisa tu última rutina' : 'Crea tu primera rutina';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rutina sugerida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(nextWorkout, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: widget.onStartWorkout, child: const Text('Comenzar sesión')),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            icon: Icons.add_box,
            label: 'Crear rutina',
            onTap: widget.onCreateRoutine,  // ✅ Agente 1 fix: navega a CreateRoutine
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            icon: Icons.chat_bubble_outline,
            label: 'Abrir coach',
            onTap: widget.onOpenChat,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bg3),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentGreen),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Entrenamientos recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._entrenamientos.take(2).map((entrenamiento) => _buildTrainingTile(entrenamiento)).toList(),
      ],
    );
  }

  Widget _buildTrainingTile(Entrenamiento entrenamiento) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('Sesión ${entrenamiento.idEntrenamiento ?? '-'}'),
        subtitle: Text('Fecha: ${entrenamiento.fecha.toLocal().toIso8601String().split('T').first}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
