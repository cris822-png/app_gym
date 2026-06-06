/// Modelo para un registro de la tabla `registro_nutricion`.
class RegistroNutricion {
  final int? idRegistro;
  final int? idUsuario;
  final String comida;
  final double cantidadG;
  final String tipoComida;
  final DateTime fechaConsumo;

  const RegistroNutricion({
    this.idRegistro,
    this.idUsuario,
    required this.comida,
    required this.cantidadG,
    required this.tipoComida,
    required this.fechaConsumo,
  });

  factory RegistroNutricion.fromJson(Map<String, dynamic> json) {
    return RegistroNutricion(
      idRegistro: json['id_registro'] as int?,
      idUsuario: json['id_usuario'] as int?,
      comida: json['comida'] as String,
      cantidadG: (json['cantidad_g'] as num).toDouble(),
      tipoComida: json['tipo_comida'] as String? ?? '',
      fechaConsumo: DateTime.parse(json['fecha_consumo'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'comida': comida,
        'cantidad_g': cantidadG,
        'tipo_comida': tipoComida,
        'fecha_consumo': fechaConsumo.toIso8601String(),
      };

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
