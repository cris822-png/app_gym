// ── Modelos de respuesta de rutina (3 niveles) ────────────────────────────────

/// Un ejercicio dentro de un día de la rutina.
class RutinaEjercicio {
  final int idRutinaEjercicio;
  final int orden;
  final int idEjercicio;
  final String name;
  final String? musculosPrincipales;
  final String? musculosSecundarios;
  final String? material;
  final String? grupoSuperset;

  const RutinaEjercicio({
    required this.idRutinaEjercicio,
    required this.orden,
    required this.idEjercicio,
    required this.name,
    this.musculosPrincipales,
    this.musculosSecundarios,
    this.material,
    this.grupoSuperset,
  });

  factory RutinaEjercicio.fromJson(Map<String, dynamic> json) {
    return RutinaEjercicio(
      idRutinaEjercicio: json['id_rutina_ejercicio'] as int,
      orden: json['orden'] as int? ?? 0,
      idEjercicio: json['id_ejercicio'] as int,
      name: json['name'] as String? ?? '',
      musculosPrincipales: json['musculos_principales'] as String?,
      musculosSecundarios: json['musculos_secundarios'] as String?,
      material: json['material'] as String?,
      grupoSuperset: json['grupo_superset'] as String?,
    );
  }

  /// Para pasarlo al WorkoutProvider como Map.
  Map<String, dynamic> toWorkoutMap() => {
        'id_ejercicio': idEjercicio,
        'name': name,
        'musculos_principales': musculosPrincipales,
        'material': material,
        'grupo_superset': grupoSuperset,
      };
}

/// Un día de la rutina con sus ejercicios.
class RutinaDia {
  final int idRutinaDia;
  final String nombreDia;
  final List<RutinaEjercicio> ejercicios;

  const RutinaDia({
    required this.idRutinaDia,
    required this.nombreDia,
    required this.ejercicios,
  });

  factory RutinaDia.fromJson(Map<String, dynamic> json) {
    final ejList = (json['ejercicios'] as List<dynamic>? ?? [])
        .map((e) => RutinaEjercicio.fromJson(e as Map<String, dynamic>))
        .toList();
    return RutinaDia(
      idRutinaDia: json['id_rutina_dia'] as int,
      nombreDia: json['nombre_dia'] as String? ?? '',
      ejercicios: ejList,
    );
  }
}

/// Rutina completa con días y ejercicios anidados.
class Rutina {
  final int idRutina;
  final int idUsuario;
  final String nameRutina;
  final String fecha;
  final List<RutinaDia> dias;

  const Rutina({
    required this.idRutina,
    required this.idUsuario,
    required this.nameRutina,
    required this.fecha,
    required this.dias,
  });

  factory Rutina.fromJson(Map<String, dynamic> json) {
    final diasList = (json['dias'] as List<dynamic>? ?? [])
        .map((d) => RutinaDia.fromJson(d as Map<String, dynamic>))
        .toList();
    return Rutina(
      idRutina: json['id_rutina'] as int,
      idUsuario: json['id_usuario'] as int,
      nameRutina: json['name_rutina'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      dias: diasList,
    );
  }

  /// Número total de ejercicios en todos los días.
  int get totalEjercicios =>
      dias.fold(0, (sum, d) => sum + d.ejercicios.length);
}
