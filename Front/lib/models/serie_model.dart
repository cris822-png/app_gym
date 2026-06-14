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

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'peso': peso,
        'reps': reps,
        'completada': completada,
        'tipoSerie': tipoSerie,
        'idSerie': idSerie,
        'pesoAnterior': pesoAnterior,
        'repsAnterior': repsAnterior,
        'dropSets': dropSets.map((d) => d.toJson()).toList(),
      };

  factory SerieModel.fromJson(Map<String, dynamic> json) {
    return SerieModel(
      numero: json['numero'] as int,
      peso: (json['peso'] as num).toDouble(),
      reps: json['reps'] as int,
      completada: json['completada'] as bool? ?? false,
      tipoSerie: json['tipoSerie'] as String? ?? 'normal',
      idSerie: json['idSerie'] as int?,
      pesoAnterior: (json['pesoAnterior'] as num?)?.toDouble(),
      repsAnterior: json['repsAnterior'] as int?,
      dropSets: (json['dropSets'] as List<dynamic>?)
              ?.map((d) => SerieModel.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
