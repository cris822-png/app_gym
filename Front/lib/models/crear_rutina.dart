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

  RutinaEjercicioDto({required this.idEjercicio, this.orden, required this.series});

  Map<String, dynamic> toJson() => {
        'id_ejercicio': idEjercicio,
        if (orden != null) 'orden': orden,
        'series': series.map((s) => s.toJson()).toList(),
      };
}

class CrearRutinaDto {
  int idUsuario;
  String nameRutina;
  DateTime fecha;
  List<RutinaEjercicioDto> ejercicios;

  CrearRutinaDto({required this.idUsuario, required this.nameRutina, required this.fecha, required this.ejercicios});

  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'name_rutina': nameRutina,
        'fecha': fecha.toIso8601String().split('T').first,
        'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
      };
}
