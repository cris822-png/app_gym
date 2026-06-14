import 'serie_model.dart';

/// Representa un ejercicio dentro del entreno activo.
/// Contiene sus series y el id_entrenamiento devuelto por la API
/// (se crea cuando el usuario "inicia" el ejercicio).
class EjercicioEntrenoModel {
  final int idEjercicio;
  final String nombre;
  final String? musculosPrincipales;
  final String? material;
  final String? grupoSuperset;

  /// id devuelto por POST /api/usuarios/{id}/entrenamientos/iniciar
  /// Null hasta que se haya creado el registro en la DB.
  int? idEntrenamiento;

  final List<SerieModel> series;

  EjercicioEntrenoModel({
    required this.idEjercicio,
    required this.nombre,
    this.musculosPrincipales,
    this.material,
    this.grupoSuperset,
    this.idEntrenamiento,
    List<SerieModel>? series,
  }) : series = series ?? _defaultSeries();

  /// Crea 3 series vacías por defecto, con el placeholder anterior si hay datos
  static List<SerieModel> _defaultSeries({
    List<Map<String, dynamic>> anteriores = const [],
  }) {
    return List.generate(3, (i) {
      final anterior = i < anteriores.length ? anteriores[i] : null;
      return SerieModel(
        numero: i + 1,
        pesoAnterior: anterior != null
            ? (anterior['peso'] as num?)?.toDouble()
            : null,
        repsAnterior: anterior != null
            ? anterior['reps'] as int?
            : null,
      );
    });
  }

  /// Crea el ejercicio con las series anteriores como placeholders
  factory EjercicioEntrenoModel.conAnteriores({
    required int idEjercicio,
    required String nombre,
    String? musculosPrincipales,
    String? material,
    String? grupoSuperset,
    required List<Map<String, dynamic>> seriesAnteriores,
  }) {
    final numSeries = seriesAnteriores.isNotEmpty ? seriesAnteriores.length : 3;
    return EjercicioEntrenoModel(
      idEjercicio: idEjercicio,
      nombre: nombre,
      musculosPrincipales: musculosPrincipales,
      material: material,
      grupoSuperset: grupoSuperset,
      series: List.generate(numSeries, (i) {
        final ant = i < seriesAnteriores.length ? seriesAnteriores[i] : null;
        return SerieModel(
          numero: i + 1,
          pesoAnterior: ant != null ? (ant['peso'] as num?)?.toDouble() : null,
          repsAnterior: ant != null ? ant['reps'] as int? : null,
        );
      }),
    );
  }

  int get seriesCompletadas => series.where((s) => s.completada).length;
  bool get todasCompletadas => series.isNotEmpty && seriesCompletadas == series.length;
  double get progresoFraccion => series.isEmpty ? 0 : seriesCompletadas / series.length;
}
