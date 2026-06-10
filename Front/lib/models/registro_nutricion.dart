/// Modelo para un registro de la tabla `registro_nutricion`.
class RegistroNutricion {
  final int? idRegistro;
  final int? idUsuario;
  final String comida;
  final double cantidadG;
  final String tipoComida;
  final String? detalles;
  final DateTime fechaConsumo;

  const RegistroNutricion({
    this.idRegistro,
    this.idUsuario,
    required this.comida,
    required this.cantidadG,
    required this.tipoComida,
    this.detalles,
    required this.fechaConsumo,
  });

  factory RegistroNutricion.fromJson(Map<String, dynamic> json) {
    return RegistroNutricion(
      idRegistro: json['id_registro'] as int?,
      idUsuario: json['id_usuario'] as int?,
      comida: json['comida'] as String,
      cantidadG: (json['cantidad_g'] as num).toDouble(),
      tipoComida: json['tipo_comida'] as String? ?? '',
      detalles: json['detalles'] as String?,
      fechaConsumo: DateTime.parse(json['fecha_consumo'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'comida': comida,
      'cantidad_g': cantidadG,
      'tipo_comida': tipoComida,
      'fecha_consumo': fechaConsumo.toIso8601String(),
    };
    // Solo incluir detalles si tiene contenido
    if (detalles != null && detalles!.trim().isNotEmpty) {
      map['detalles'] = detalles!.trim();
    }
    return map;
  }

  String get tipoLabel {
    const labels = {
      'desayuno': 'Desayuno',
      'almuerzo': 'Almuerzo',
      'cena': 'Cena',
      'snack': 'Snack',
      'postre': 'Postre',
    };
    return labels[tipoComida.toLowerCase()] ?? tipoComida;
  }
}
