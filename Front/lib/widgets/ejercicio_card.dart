import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/ejercicio_entreno_model.dart';
import '../providers/workout_provider.dart';
import 'serie_row.dart';

/// Tarjeta de ejercicio en la pantalla de entreno activo.
/// Soporta series normales, calentamientos y drop sets.
class EjercicioCard extends StatelessWidget {
  final EjercicioEntrenoModel ejercicio;
  final int index;
  final VoidCallback onAgregarSerie;
  final Function(int idxSerie, double peso, int reps) onSerieCompletada;
  final Function(int idxSerie, double peso, int reps)? onValorCambiado;
  final Function(int idxSerie, int idxDrop, double peso, int reps)?
      onDropSetCompletado;
  final Function(int idxSerie, int idxDrop, double peso, int reps)?
      onDropSetValorCambiado;
  final Function(int idxSerie)? onAgregarDropSet;
  final Function(int idxSerie, String tipo)? onCambiarTipoSerie;

  const EjercicioCard({
    super.key,
    required this.ejercicio,
    required this.index,
    required this.onAgregarSerie,
    required this.onSerieCompletada,
    this.onValorCambiado,
    this.onDropSetCompletado,
    this.onDropSetValorCambiado,
    this.onAgregarDropSet,
    this.onCambiarTipoSerie,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ejercicio.todasCompletadas
              ? AppColors.accentGreen.withValues(alpha: 0.4)
              : AppColors.bg3,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icono + nombre + músculos + badge ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bg3, width: 1),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: AppColors.accentBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ejercicio.nombre,
                          style: tt.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (ejercicio.musculosPrincipales != null) ...[
                        const SizedBox(height: 2),
                        Text(ejercicio.musculosPrincipales!,
                            style: tt.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                // ── Indicador de descanso base ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final currentSecs = ejercicio.tiempoDescanso ?? 90;
                        final textCtrl = TextEditingController(text: currentSecs.toString());
                        final secs = await showDialog<int>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.bg2,
                            title: const Text('Descanso Base', style: TextStyle(color: AppColors.textPrimary)),
                            content: TextField(
                              controller: textCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Segundos',
                                hintStyle: TextStyle(color: AppColors.textMuted),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
                              ),
                              TextButton(
                                onPressed: () {
                                  final val = int.tryParse(textCtrl.text);
                                  if (val != null && val >= 0) {
                                    Navigator.pop(ctx, val);
                                  }
                                },
                                child: const Text('Guardar', style: TextStyle(color: AppColors.accentBlue)),
                              ),
                            ],
                          ),
                        );

                        if (secs != null && context.mounted) {
                          // Solo lo guarda en base de datos si tiene idRutinaEjercicio válido (rutinas nuevas),
                          // pero lo actualiza localmente en la sesión igual.
                          if (ejercicio.idRutinaEjercicio != null) {
                            context.read<WorkoutProvider>().cambiarTiempoDescansoBase(ejercicio.idRutinaEjercicio!, secs);
                          } else {
                            ejercicio.tiempoDescanso = secs;
                            // Forzamos un rebuild manual o podríamos requerir un método genérico.
                            // Para el caso de rutinas "viejas" sin idRutinaEjercicio, actualizarlo visualmente.
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${ejercicio.tiempoDescanso ?? 90}s',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Badge progreso series
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ejercicio.todasCompletadas
                        ? AppColors.serieCompletada
                        : AppColors.bg3,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ejercicio.seriesCompletadas}/${ejercicio.series.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ejercicio.todasCompletadas
                          ? AppColors.accentGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Cabecera de columnas ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: const [
                  SizedBox(
                    width: 36,
                    child: Text('N°',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Text('ANTERIOR',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 82,
                    child: Text('PESO',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 82,
                    child: Text('REPS',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 6),
                  SizedBox(width: 36),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Filas de series con drop sets anidados ──────────────────────
            ...ejercicio.series.asMap().entries.expand((entry) {
              final idxSerie = entry.key;
              final serie = entry.value;
              return [
                SerieRow(
                  key: ValueKey('${ejercicio.idEjercicio}_serie_$idxSerie'),
                  serie: serie,
                  onCompleted: (peso, reps) =>
                      onSerieCompletada(idxSerie, peso, reps),
                  onValueChanged: (peso, reps) =>
                      onValorCambiado?.call(idxSerie, peso, reps),
                  onAgregarDropSet: onAgregarDropSet != null
                      ? () => onAgregarDropSet!(idxSerie)
                      : null,
                  onCambiarTipo: onCambiarTipoSerie != null
                      ? (tipo) => onCambiarTipoSerie!(idxSerie, tipo)
                      : null,
                ),
                // Drop sets anidados
                ...serie.dropSets.asMap().entries.map((dropEntry) {
                  final idxDrop = dropEntry.key;
                  final drop = dropEntry.value;
                  return SerieRow(
                    key: ValueKey(
                        '${ejercicio.idEjercicio}_serie_${idxSerie}_drop_$idxDrop'),
                    serie: drop,
                    onCompleted: (peso, reps) => onDropSetCompletado?.call(
                        idxSerie, idxDrop, peso, reps),
                    onValueChanged: (peso, reps) => onDropSetValorCambiado?.call(
                        idxSerie, idxDrop, peso, reps),
                  );
                }),
              ];
            }),


            const SizedBox(height: 8),

            // ── Botón Añadir serie ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onAgregarSerie,
                icon: const Icon(Icons.add, size: 16, color: AppColors.accentBlue),
                label: const Text('Añadir serie',
                    style: TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor:
                      AppColors.accentBlue.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
