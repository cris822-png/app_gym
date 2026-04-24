class Serie {
  final double peso;
  final int reps;

  Serie({required this.peso, required this.reps});

  factory Serie.fromJson(Map<String, dynamic> json) {
    return Serie(
      peso: (json['peso'] as num).toDouble(),
      reps: json['reps'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'peso': peso,
      'reps': reps,
    };
  }
}

class EntrenamientoEjercicio {
  final int idEjercicio;
  final String? nombreEjercicio;
  final List<Serie> series;

  EntrenamientoEjercicio({
    required this.idEjercicio,
    this.nombreEjercicio,
    required this.series,
  });

  factory EntrenamientoEjercicio.fromJson(Map<String, dynamic> json) {
    final seriesJson = json['series'] as List<dynamic>;
    return EntrenamientoEjercicio(
      idEjercicio: json['id_ejercicio'] as int,
      nombreEjercicio: json['nombre_ejercicio'] as String?,
      series: seriesJson.map((item) => Serie.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_ejercicio': idEjercicio,
      'series': series.map((serie) => serie.toJson()).toList(),
    };
  }
}

class Entrenamiento {
  final int? idRutina;
  final int? idEntrenamiento;
  final DateTime fecha;
  final List<EntrenamientoEjercicio> ejercicios;

  Entrenamiento({
    this.idRutina,
    this.idEntrenamiento,
    required this.fecha,
    required this.ejercicios,
  });

  factory Entrenamiento.fromJson(Map<String, dynamic> json) {
    final seriesJson = json['series'] as List<dynamic>;
    return Entrenamiento(
      idEntrenamiento: json['id_entrenamiento'] as int?,
      fecha: DateTime.parse(json['fecha'] as String),
      ejercicios: [
        EntrenamientoEjercicio(
          idEjercicio: json['id_ejercicio'] as int,
          nombreEjercicio: json['nombre_ejercicio'] as String?,
          series: seriesJson.map((item) => Serie.fromJson(item as Map<String, dynamic>)).toList(),
        ),
      ],
    );
  }

  Map<String, dynamic> toPostJson() {
    if (idRutina == null) {
      throw StateError('idRutina es requerido para enviar un entrenamiento');
    }
    return {
      'id_rutina': idRutina,
      'fecha': fecha.toIso8601String().split('T').first,
      'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
    };
  }
}
