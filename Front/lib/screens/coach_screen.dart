import 'package:flutter/material.dart';

import '../models/coach_recommendation.dart';
import '../models/entrenamiento.dart';
import '../models/nutricion.dart';
import '../services/api_service.dart';

class CoachScreen extends StatefulWidget {
  final int idUsuario;

  const CoachScreen({super.key, required this.idUsuario});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
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
      final recommendation = await _apiService.getCoachRecommendation(widget.idUsuario);
      final nutricion = await _apiService.getNutricion(widget.idUsuario);
      final entrenamientos = await _apiService.getEntrenamientos(widget.idUsuario);

      setState(() {
        _recommendation = recommendation;
        _nutricion = nutricion;
        _entrenamientos = entrenamientos;
      });
    } catch (exception) {
      setState(() {
        _error = exception.toString();
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
        title: const Text('Coach Gym IA'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_recommendation == null) {
      return const Center(child: Text('No hay recomendaciones disponibles'));
    }

    return ListView(
      children: [
        _buildSectionTitle('Recomendación directa'),
        Text(_recommendation!.mensaje, style: const TextStyle(fontSize: 16.0, height: 1.4)),
        const SizedBox(height: 16),
        _buildSectionTitle('Observaciones'),
        ..._recommendation!.observaciones.map((obs) => _buildBullet(obs)),
        const SizedBox(height: 16),
        _buildSectionTitle('Acciones inmediatas'),
        ..._recommendation!.acciones.map((action) => _buildBullet(action)),
        if (_recommendation!.advertenciaIa != null) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('Advertencia IA'),
          Text(_recommendation!.advertenciaIa!, style: const TextStyle(color: Colors.red)),
        ],
        if (_nutricion.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('Últimos alimentos registrados'),
          ..._nutricion.take(5).map((item) => _buildBullet('${item.time.toLocal()}: ${item.comida}')),
        ],
        if (_entrenamientos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('Entrenamientos recientes'),
          ..._entrenamientos.map(_buildEntrenamientoCard),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 18)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildEntrenamientoCard(Entrenamiento entrenamiento) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entrenamiento ${entrenamiento.idEntrenamiento ?? '-'} - ${entrenamiento.fecha.toLocal().toIso8601String().split('T').first}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...entrenamiento.ejercicios.map(
              (ejercicio) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ejercicio.nombreEjercicio ?? 'Ejercicio ${ejercicio.idEjercicio}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ...ejercicio.series.map(
                      (serie) => Text('• ${serie.peso} kg x ${serie.reps} reps'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
