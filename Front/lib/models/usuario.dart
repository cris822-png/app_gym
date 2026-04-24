class Usuario {
  final int idUsuario;
  final String name;
  final String surname;
  final String email;
  final double peso;
  final double altura;
  final String fechaCreacion;

  Usuario({
    required this.idUsuario,
    required this.name,
    required this.surname,
    required this.email,
    required this.peso,
    required this.altura,
    required this.fechaCreacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idUsuario: json['id_usuario'] as int,
      name: json['name'] as String,
      surname: json['surname'] as String,
      email: json['email'] as String,
      peso: (json['peso'] as num).toDouble(),
      altura: (json['altura'] as num).toDouble(),
      fechaCreacion: json['fecha_creacion'] as String,
    );
  }
}
