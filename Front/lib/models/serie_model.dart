/// Modelo de una serie dentro de un ejercicio en curso.
/// Contiene tanto el valor actual (que escribe el usuario) como el anterior
/// (extraído de la DB y mostrado como placeholder gris).
class SerieModel {
  final int numero;
  double peso;
  int reps;
  bool completada;
  String tipoSerie; // 'normal', 'calentamiento', 'drop_set'

  /// id_serie devuelto por la DB después de persistir (null hasta completar).
  int? idSerie;

  /// Drop Sets anidadas bajo esta serie (solo en series normales).
  final List<SerieModel> dropSets;

  /// Dato de la última sesión, para el placeholder gris
  final double? pesoAnterior;
  final int? repsAnterior;

  SerieModel({
    required this.numero,
    this.peso = 0,
    this.reps = 0,
    this.completada = false,
    this.tipoSerie = 'normal',
    this.idSerie,
    List<SerieModel>? dropSets,
    this.pesoAnterior,
    this.repsAnterior,
  }) : dropSets = dropSets ?? [];

  bool get esCalentamiento => tipoSerie == 'calentamiento';
  bool get esDropSet => tipoSerie == 'drop_set';

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
