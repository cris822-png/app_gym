import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ejercicio_entreno_model.dart';
import '../models/serie_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

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

  // ── Estado del Temporizador de Descanso ──────────────────────────────────
  DateTime? _restTargetEndTime;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  int? _currentRestEjercicioId;
  
  bool get isResting => _restTargetEndTime != null && _restSecondsRemaining > 0;
  int get restSecondsRemaining => _restSecondsRemaining;
  int? get currentRestEjercicioId => _currentRestEjercicioId;

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

  // ── Caché Local ──────────────────────────────────────────────────────────

  static const String _cacheKeyPrefix = 'workout_cache_user_';

  Future<void> _guardarEnCache() async {
    if (!_activo) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'inicio': _inicio?.toIso8601String(),
        'segundosTranscurridos': _segundosTranscurridos,
        'ejercicios': _ejercicios.map((e) => e.toJson()).toList(),
      };
      await prefs.setString('$_cacheKeyPrefix$userId', jsonEncode(data));
    } catch (e) {
      debugPrint('Error guardando caché: $e');
    }
  }

  Future<bool> restaurarDeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_cacheKeyPrefix$userId');
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        
        _ejercicios.clear();
        final ejsList = data['ejercicios'] as List<dynamic>? ?? [];
        for (final e in ejsList) {
          _ejercicios.add(EjercicioEntrenoModel.fromJson(e as Map<String, dynamic>));
        }
        
        final inicioStr = data['inicio'] as String?;
        if (inicioStr != null) {
          _inicio = DateTime.tryParse(inicioStr);
        }
        _segundosTranscurridos = data['segundosTranscurridos'] as int? ?? 0;
        
        _activo = true;
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          _segundosTranscurridos++;
          notifyListeners();
        });
        
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error restaurando caché: $e');
    }
    return false;
  }

  // ── Iniciar/Detener entreno ──────────────────────────────────────────────

  void iniciarEntreno() {
    _activo = true;
    _inicio = DateTime.now();
    _segundosTranscurridos = 0;
    _ejercicios.clear();
    _guardarEnCache();
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

  Future<void> resetEntreno() async {
    _activo = false;
    _timer?.cancel();
    _timer = null;
    _segundosTranscurridos = 0;
    _ejercicios.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cacheKeyPrefix$userId');
    
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
          grupoSuperset: ej['grupo_superset'] as String?,
          idRutinaEjercicio: ej['id_rutina_ejercicio'] as int?,
          tiempoDescanso: ej['tiempo_descanso'] as int?,
          seriesAnteriores: anteriores,
        );
      });

      final resultados = await Future.wait(futures);
      _ejercicios
        ..clear()
        ..addAll(resultados);
      _guardarEnCache();
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
      grupoSuperset: ejData['grupo_superset'] as String?,
      idRutinaEjercicio: ejData['id_rutina_ejercicio'] as int?,
      tiempoDescanso: ejData['tiempo_descanso'] as int?,
      seriesAnteriores: anteriores,
    ));
    _guardarEnCache();
    notifyListeners();
  }

  // ── Gestión de series ────────────────────────────────────────────────────

  void agregarSerie(int idxEjercicio, {String tipoSerie = 'normal'}) {
    final ej = _ejercicios[idxEjercicio];
    // Contar solo series no-drop_set para el número de serie
    final numNormales = ej.series.where((s) => !s.esDropSet).length;
    final ant = numNormales < ej.series.where((s) => s.pesoAnterior != null && !s.esDropSet).length
        ? ej.series.where((s) => !s.esDropSet).elementAt(numNormales)
        : null;
    ej.series.add(SerieModel(
      numero: numNormales + 1,
      tipoSerie: tipoSerie,
      pesoAnterior: ant?.pesoAnterior,
      repsAnterior: ant?.repsAnterior,
    ));
    _guardarEnCache();
    notifyListeners();
  }

  /// Añade un Drop Set justo después de la serie padre (idxSerie).
  void agregarDropSet(int idxEjercicio, int idxSerie) {
    final ej = _ejercicios[idxEjercicio];
    final seriePadre = ej.series[idxSerie];
    seriePadre.dropSets.add(SerieModel(
      numero: seriePadre.dropSets.length + 1,
      tipoSerie: 'drop_set',
    ));
    _guardarEnCache();
    notifyListeners();
  }

  /// Cambia el tipo de una serie (normal ↔ calentamiento).
  void cambiarTipoSerie(int idxEjercicio, int idxSerie, String nuevoTipo) {
    _ejercicios[idxEjercicio].series[idxSerie].tipoSerie = nuevoTipo;
    _guardarEnCache();
    notifyListeners();
  }

  /// Marca o desmarca la serie como completada en caché local.
  void completarSerie(
      int idxEjercicio, int idxSerie, double peso, int reps,
      {bool esDropSet = false, int? idSeriePadre}) {
    final ej = _ejercicios[idxEjercicio];
    final serie = ej.series[idxSerie];
    serie.peso = peso;
    serie.reps = reps;
    serie.completada = !serie.completada;
    
    if (serie.completada) {
      startRestTimer(ej.tiempoDescanso ?? 90, ej.idRutinaEjercicio);
    }
    
    _guardarEnCache();
    notifyListeners();
  }

  /// Marca o desmarca un drop set como completado en caché local.
  void completarDropSet(
      int idxEjercicio, int idxSerie, int idxDrop, double peso, int reps) {
    final ej = _ejercicios[idxEjercicio];
    final seriePadre = ej.series[idxSerie];
    final drop = seriePadre.dropSets[idxDrop];
    drop.peso = peso;
    drop.reps = reps;
    drop.completada = !drop.completada;
    
    if (drop.completada) {
      startRestTimer(ej.tiempoDescanso ?? 90, ej.idRutinaEjercicio);
    }
    
    _guardarEnCache();
    notifyListeners();
  }

  /// Actualiza los valores sin marcar check
  void actualizarValoresSerie(int idxEjercicio, int idxSerie, double peso, int reps) {
    final serie = _ejercicios[idxEjercicio].series[idxSerie];
    serie.peso = peso;
    serie.reps = reps;
    _guardarEnCache();
  }

  /// Actualiza los valores sin marcar check
  void actualizarValoresDropSet(int idxEjercicio, int idxSerie, int idxDrop, double peso, int reps) {
    final seriePadre = _ejercicios[idxEjercicio].series[idxSerie];
    final drop = seriePadre.dropSets[idxDrop];
    drop.peso = peso;
    drop.reps = reps;
    _guardarEnCache();
  }

  // ── Sincronización Lote ──────────────────────────────────────────────────

  Future<bool> finalizarEntrenamientoLote() async {
    if (_ejercicios.isEmpty) {
      await resetEntreno();
      return true;
    }
    
    _loading = true;
    notifyListeners();
    
    try {
      final payload = {
        'fecha': (_inicio ?? DateTime.now()).toIso8601String(),
        'ejercicios': _ejercicios.map((e) {
          return {
            'id_ejercicio': e.idEjercicio,
            'series': e.series.where((s) => s.completada).map((s) {
              return {
                'peso': s.peso,
                'reps': s.reps,
                'tipo_serie': s.tipoSerie,
                'drop_sets': s.dropSets.where((d) => d.completada).map((d) {
                  return {
                    'peso': d.peso,
                    'reps': d.reps,
                    'tipo_serie': d.tipoSerie
                  };
                }).toList(),
              };
            }).toList()
          };
        }).where((e) => (e['series'] as List).isNotEmpty).toList()
      };
      
      if ((payload['ejercicios'] as List).isEmpty) {
         // No hay nada que guardar
         await resetEntreno();
         return true;
      }
      
      await _api.finalizarEntrenamientoLote(userId, payload);
      
      await resetEntreno();
      return true;
    } catch (e) {
      _error = 'Error al finalizar: $e';
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
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

  // ── Temporizador de Descanso ─────────────────────────────────────────────

  void startRestTimer(int segundos, int? idRutinaEjercicio) {
    if (segundos <= 0) return;
    _currentRestEjercicioId = idRutinaEjercicio;
    _restTargetEndTime = DateTime.now().add(Duration(seconds: segundos));
    _actualizarRestTimer();
    
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _actualizarRestTimer();
    });

    NotificationService().scheduleRestNotification(_restTargetEndTime!);
  }

  void _actualizarRestTimer() {
    if (_restTargetEndTime == null) return;
    final diff = _restTargetEndTime!.difference(DateTime.now()).inSeconds;
    if (diff <= 0) {
      _restSecondsRemaining = 0;
      _restTargetEndTime = null;
      _restTimer?.cancel();
    } else {
      _restSecondsRemaining = diff;
    }
    notifyListeners();
  }

  void modifyRestTimer(int deltaSeconds) {
    if (_restTargetEndTime == null) return;
    final nuevoTarget = _restTargetEndTime!.add(Duration(seconds: deltaSeconds));
    if (nuevoTarget.isBefore(DateTime.now())) {
      skipRestTimer();
      return;
    }
    _restTargetEndTime = nuevoTarget;
    _actualizarRestTimer();
    
    NotificationService().cancelNotification();
    NotificationService().scheduleRestNotification(_restTargetEndTime!);
  }

  void skipRestTimer() {
    _restTargetEndTime = null;
    _restSecondsRemaining = 0;
    _restTimer?.cancel();
    NotificationService().cancelNotification();
    notifyListeners();
  }

  Future<void> cambiarTiempoDescansoBase(int idRutinaEjercicio, int nuevosSegundos) async {
    for (var ej in _ejercicios) {
      if (ej.idRutinaEjercicio == idRutinaEjercicio) {
        ej.tiempoDescanso = nuevosSegundos;
        _api.actualizarTiempoDescanso(idRutinaEjercicio, nuevosSegundos).catchError((e) {
          debugPrint("Error guardando tiempo descanso: $e");
        });
        break;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}
