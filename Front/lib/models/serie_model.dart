/// Modelo de una serie dentro de un ejercicio en curso.
/// Contiene tanto el valor actual (que escribe el usuario) como el anterior
/// (extraído de la DB y mostrado como placeholder gris).
class SerieModel {
  final int numero;
  double peso;
  int reps;
  bool completada;

  /// Dato de la última sesión, para el placeholder gris
  final double? pesoAnterior;
  final int? repsAnterior;

  SerieModel({
    required this.numero,
    this.peso = 0,
    this.reps = 0,
    this.completada = false,
    this.pesoAnterior,
    this.repsAnterior,
  });

  /// Texto del placeholder gris (columna "ANTERIOR")
  String get placeholderText {
    if (pesoAnterior != null && repsAnterior != null) {
      final pesoStr = pesoAnterior! % 1 == 0
          ? pesoAnterior!.toInt().toString()
          : pesoAnterior!.toString();
      return '${pesoStr}kg × $repsAnterior';
    }
    return '— × —';
  }
}
