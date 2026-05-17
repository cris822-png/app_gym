import 'package:flutter/material.dart';

import '../models/coach_recommendation.dart';
import '../models/entrenamiento.dart';
import '../models/nutricion.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onStartWorkout;
  final VoidCallback onOpenChat;

  const DashboardScreen({super.key, required this.userName, required this.onStartWorkout, required this.onOpenChat});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  Usuario? _usuario;
  CoachRecommendation? _recommendation;
  List<Nutricion> _nutricion = [];
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
      final usuario = await _apiService.getUsuario(1);
      final recommendation = await _apiService.getCoachRecommendation(1);
      final nutricion = await _apiService.getNutricion(1);
      final entrenamientos = await _apiService.getEntrenamientos(1);

      setState(() {
        _usuario = usuario;
        _recommendation = recommendation;
        _nutricion = nutricion;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Text('Hola, ${widget.userName}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Este es tu resumen diario. Revisa recomendaciones, progreso y rutinas sugeridas.', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 24),
                      _buildSummaryRow(),
                      _buildSummaryInfo(_nutricion.length),
                      const SizedBox(height: 20),
                      _buildRecommendationCard(),
                      const SizedBox(height: 20),
                      _buildWorkoutCard(),
                      const SizedBox(height: 20),
                      _buildQuickActionsRow(),
                      const SizedBox(height: 20),
                      _buildRecentSection(),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onStartWorkout,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar Entreno'),
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
      child: Text('$meals comidas recientes registradas', style: const TextStyle(color: Colors.black54)),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
        Expanded(child: _buildActionTile(Icons.add_box, 'Crear rutina')),
        const SizedBox(width: 12),
        Expanded(child: _buildActionTile(Icons.chat_bubble_outline, 'Abrir coach')),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String label) {
    return InkWell(
      onTap: widget.onOpenChat,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Colors.green.shade700),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
