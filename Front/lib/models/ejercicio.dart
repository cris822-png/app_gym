class Ejercicio {
  final int idEjercicio;
  final String name;
  final String musculosPrincipales;
  final String? musculosSecundarios;
  final String? material;
  final String? tiempoDescanso;

  Ejercicio({
    required this.idEjercicio,
    required this.name,
    required this.musculosPrincipales,
    this.musculosSecundarios,
    this.material,
    this.tiempoDescanso,
  });

  factory Ejercicio.fromJson(Map<String, dynamic> json) {
    return Ejercicio(
      idEjercicio: json['id_ejercicio'] as int,
      name: json['name'] as String,
      musculosPrincipales: json['musculos_principales'] as String,
      musculosSecundarios: json['musculos_secundarios'] as String?,
      material: json['material'] as String?,
      tiempoDescanso: json['tiempo_descanso'] as String?,
    );
  }
}
