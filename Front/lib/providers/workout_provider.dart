import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ejercicio_entreno_model.dart';
import '../models/serie_model.dart';
import '../services/api_service.dart';

/// Estado global del entrenamiento activo.
/// Compartido entre WorkoutScreen y IaChatOverlay para que el chat
/// siempre tenga acceso al contexto en tiempo real del entreno.
class WorkoutProvider extends ChangeNotifier {
  final ApiService _api;
  final int userId;

  WorkoutProvider({required this.userId, ApiService? apiService})
      : _api = apiService ?? ApiService();

  // ── Estado del entreno ───────────────────────────────────────────────────
  bool _activo = false;
  bool get activo => _activo;

  DateTime? _inicio;
  Timer? _timer;
  int _segundosTranscurridos = 0;
  int get segundosTranscurridos => _segundosTranscurridos;
  int get minutosTranscurridos => _segundosTranscurridos ~/ 60;

  /// Timestamp de inicio del entreno (útil para logging y debug)
  DateTime? get inicio => _inicio;

  String get duracionFormateada {
    final m = _segundosTranscurridos ~/ 60;
    final s = _segundosTranscurridos % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  final List<EjercicioEntrenoModel> _ejercicios = [];
  List<EjercicioEntrenoModel> get ejercicios => List.unmodifiable(_ejercicios);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Iniciar/Detener entreno ──────────────────────────────────────────────

  void iniciarEntreno() {
    _activo = true;
    _inicio = DateTime.now();
    _segundosTranscurridos = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _segundosTranscurridos++;
      notifyListeners();
    });
    notifyListeners();
  }

  void detenerEntreno() {
    _activo = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resetEntreno() {
    _activo = false;
    _timer?.cancel();
    _timer = null;
    _segundosTranscurridos = 0;
    _ejercicios.clear();
    notifyListeners();
  }

  // ── Cargar ejercicios de una rutina con placeholders ─────────────────────

  /// Carga todos los ejercicios de la rutina y pide en paralelo
  /// el último registro de cada uno para poblar los placeholders grises.
  Future<void> cargarEjerciciosDeRutina(
      List<Map<String, dynamic>> ejerciciosRutina) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Peticiones en paralelo — Future.wait evita N+1 secuencial
      final futures = ejerciciosRutina.map((ej) async {
        final idEjercicio = ej['id_ejercicio'] as int;
        List<Map<String, dynamic>> anteriores = [];
        try {
          anteriores = await _api.getUltimoRegistro(userId, idEjercicio);
        } catch (_) {
          // Sin historial previo — muestra '— × —' como placeholder
        }
        return EjercicioEntrenoModel.conAnteriores(
          idEjercicio: idEjercicio,
          nombre: ej['name'] as String? ?? 'Ejercicio',
          musculosPrincipales: ej['musculos_principales'] as String?,
          material: ej['material'] as String?,
          seriesAnteriores: anteriores,
        );
      });

      final resultados = await Future.wait(futures);
      _ejercicios
        ..clear()
        ..addAll(resultados);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Añadir ejercicio suelto ──────────────────────────────────────────────

  Future<void> agregarEjercicio(Map<String, dynamic> ejData) async {
    final idEjercicio = ejData['id_ejercicio'] as int;
    List<Map<String, dynamic>> anteriores = [];
    try {
      anteriores = await _api.getUltimoRegistro(userId, idEjercicio);
    } catch (_) {}

    _ejercicios.add(EjercicioEntrenoModel.conAnteriores(
      idEjercicio: idEjercicio,
      nombre: ejData['name'] as String? ?? 'Ejercicio',
      musculosPrincipales: ejData['musculos_principales'] as String?,
      material: ejData['material'] as String?,
      seriesAnteriores: anteriores,
    ));
    notifyListeners();
  }

  // ── Gestión de series ────────────────────────────────────────────────────

  void agregarSerie(int idxEjercicio) {
    final ej = _ejercicios[idxEjercicio];
    final numNueva = ej.series.length + 1;
    // El placeholder de la serie nueva usa el registro previo si existe
    final ant = numNueva <= (ej.series
            .where((s) => s.pesoAnterior != null)
            .length)
        ? ej.series[numNueva - 1]
        : null;
    ej.series.add(SerieModel(
      numero: numNueva,
      pesoAnterior: ant?.pesoAnterior,
      repsAnterior: ant?.repsAnterior,
    ));
    notifyListeners();
  }

  void actualizarSerie(int idxEjercicio, int idxSerie, double peso, int reps) {
    _ejercicios[idxEjercicio].series[idxSerie]
      ..peso = peso
      ..reps = reps;
    // No notificamos aquí para evitar rebuilds por cada tecla
  }

  /// Marca la serie como completada y la persiste en la DB.
  Future<void> completarSerie(
      int idxEjercicio, int idxSerie, double peso, int reps) async {
    final ej = _ejercicios[idxEjercicio];
    final serie = ej.series[idxSerie];

    // Actualizar valores locales
    serie.peso = peso;
    serie.reps = reps;

    // Si el ejercicio aún no tiene id_entrenamiento, crearlo primero
    if (ej.idEntrenamiento == null) {
      try {
        ej.idEntrenamiento = await _api.iniciarEntrenamiento(
          userId: userId,
          idEjercicio: ej.idEjercicio,
        );
      } catch (e) {
        _error = 'Error al iniciar ejercicio: $e';
        notifyListeners();
        return;
      }
    }

    // Persistir la serie en la DB
    try {
      await _api.registrarSerie(
        idEntrenamiento: ej.idEntrenamiento!,
        peso: peso,
        reps: reps,
      );
      serie.completada = true;
    } catch (e) {
      _error = 'Error al guardar serie: $e';
    }

    notifyListeners();
  }

  // ── Contexto para el chat IA ─────────────────────────────────────────────

  /// Construye el dict de contexto que se envía al endpoint de chat.
  Map<String, dynamic> buildContextoParaChat() {
    return {
      'ejercicios': _ejercicios.map((e) => {
        'nombre': e.nombre,
        'series_completadas': e.series
            .where((s) => s.completada)
            .map((s) => {'peso': s.peso, 'reps': s.reps})
            .toList(),
      }).toList(),
      'duracion_minutos': minutosTranscurridos,
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
