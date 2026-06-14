// ── DTOs para crear una rutina (Payload → Backend) ───────────────────────────

/// Un ejercicio dentro de un día (payload de creación).
class EjercicioDiaDto {
  final int idEjercicio;
  final int? orden;
  final String? grupoSuperset;

  const EjercicioDiaDto({required this.idEjercicio, this.orden, this.grupoSuperset});

  Map<String, dynamic> toJson() => {
        'id_ejercicio': idEjercicio,
        if (orden != null) 'orden': orden,
        if (grupoSuperset != null) 'grupo_superset': grupoSuperset,
      };
}

/// Un día de la rutina con sus ejercicios (payload de creación).
class DiaDtoPayload {
  final String nombreDia;
  final List<EjercicioDiaDto> ejercicios;

  DiaDtoPayload({required this.nombreDia, required this.ejercicios});

  Map<String, dynamic> toJson() => {
        'nombre_dia': nombreDia,
        'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
      };
}

/// Payload completo para crear una rutina con 3 niveles.
class CrearRutinaDto {
  final int idUsuario;
  final String nameRutina;
  final DateTime fecha;
  final List<DiaDtoPayload> dias;

  CrearRutinaDto({
    required this.idUsuario,
    required this.nameRutina,
    required this.fecha,
    required this.dias,
  });

  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'name_rutina': nameRutina,
        'fecha': fecha.toIso8601String().split('T').first,
        'dias': dias.map((d) => d.toJson()).toList(),
      };
}

// ── Clases legacy mantenidas por compatibilidad ───────────────────────────────
// (no se usan en los nuevos flujos, pero evitan romper imports transitivos)

class SerieDto {
  int reps;
  double? peso;
  String? tiempoDescanso;
  SerieDto({required this.reps, this.peso, this.tiempoDescanso});
  Map<String, dynamic> toJson() => {
        'reps': reps,
        'peso': peso,
        'tiempo_descanso': tiempoDescanso,
      };
}

class RutinaEjercicioDto {
  int idEjercicio;
  int? orden;
  List<SerieDto> series;
  RutinaEjercicioDto(
      {required this.idEjercicio, this.orden, required this.series});
  Map<String, dynamic> toJson() => {
        'id_ejercicio': idEjercicio,
        if (orden != null) 'orden': orden,
        'series': series.map((s) => s.toJson()).toList(),
      };
}
