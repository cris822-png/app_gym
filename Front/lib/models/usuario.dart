class Usuario {
  final int idUsuario;
  final String name;
  final String surname;
  final String email;
  final double peso;
  final double altura;
  final String? objetivoPorcentage;
  final String? objetivoPeso;
  final String fechaCreacion;

  Usuario({
    required this.idUsuario,
    required this.name,
    required this.surname,
    required this.email,
    required this.peso,
    required this.altura,
    this.objetivoPorcentage,
    this.objetivoPeso,
    required this.fechaCreacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final pesoValue = json['peso'];
    final alturaValue = json['altura'];

    return Usuario(
      idUsuario: json['id_usuario'] as int,
      name: json['name'] as String,
      surname: json['surname'] as String,
      email: json['email'] as String,
      peso: pesoValue != null ? (pesoValue as num).toDouble() : 0.0,
      altura: alturaValue != null ? (alturaValue as num).toDouble() : 0.0,
      objetivoPorcentage: json['objetivo_porcentage'] as String?,
      objetivoPeso: json['objetivo_peso'] as String?,
      fechaCreacion: json['fecha_creacion'] as String,
    );
  }
}
