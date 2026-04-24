class Nutricion {
  final int? idNutricion;
  final int? idUsuario;
  final String comida;
  final DateTime time;

  Nutricion({
    this.idNutricion,
    this.idUsuario,
    required this.comida,
    required this.time,
  });

  factory Nutricion.fromJson(Map<String, dynamic> json) {
    return Nutricion(
      idNutricion: json['id_nutricion'] as int?,
      idUsuario: json['id_usuario'] as int?,
      comida: json['comida'] as String,
      time: DateTime.parse(json['time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comida': comida,
      'time': time.toIso8601String(),
    };
  }
}
