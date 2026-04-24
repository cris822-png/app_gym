class Rutina {
  final int idRutina;
  final int idUsuario;
  final String nameRutina;
  final String fecha;

  Rutina({
    required this.idRutina,
    required this.idUsuario,
    required this.nameRutina,
    required this.fecha,
  });

  factory Rutina.fromJson(Map<String, dynamic> json) {
    return Rutina(
      idRutina: json['id_rutina'] as int,
      idUsuario: json['id_usuario'] as int,
      nameRutina: json['name_rutina'] as String,
      fecha: json['fecha'] as String,
    );
  }
}
