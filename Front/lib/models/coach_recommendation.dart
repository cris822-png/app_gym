class CoachRecommendation {
  final int idUsuario;
  final String objetivoGrasa;
  final String mensaje;
  final List<String> observaciones;
  final List<String> acciones;
  final String? fuente;
  final String? advertenciaIa;

  CoachRecommendation({
    required this.idUsuario,
    required this.objetivoGrasa,
    required this.mensaje,
    required this.observaciones,
    required this.acciones,
    this.fuente,
    this.advertenciaIa,
  });

  factory CoachRecommendation.fromJson(Map<String, dynamic> json) {
    return CoachRecommendation(
      idUsuario: json['id_usuario'] as int,
      objetivoGrasa: json['objetivo_grasa'] as String,
      mensaje: json['mensaje'] as String,
      observaciones: List<String>.from(json['observaciones'] as List<dynamic>),
      acciones: List<String>.from(json['acciones'] as List<dynamic>),
      fuente: json['fuente'] as String?,
      advertenciaIa: json['advertencia_ia'] as String?,
    );
  }
}
