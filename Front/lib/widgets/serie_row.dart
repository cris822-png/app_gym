import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_theme.dart';
import '../models/serie_model.dart';

/// Fila horizontal de una serie: Nº | Anterior | Peso | Reps | ✓
///
/// Soporta tres tipos de serie:
///   - normal      → fondo bg3, número de serie
///   - calentamiento → borde azul, badge de llama
///   - drop_set    → sangría izquierda, fondo morado translúcido (rendered by EjercicioCard)
///
/// Long-press abre un menú con opciones de tipo de serie.
class SerieRow extends StatefulWidget {
  final SerieModel serie;
  final Function(double peso, int reps) onCompleted;
  final Function(double peso, int reps)? onValueChanged;
  final VoidCallback? onAgregarDropSet;
  final Function(String tipo)? onCambiarTipo;

  const SerieRow({
    super.key,
    required this.serie,
    required this.onCompleted,
    this.onValueChanged,
    this.onAgregarDropSet,
    this.onCambiarTipo,
  });

  @override
  State<SerieRow> createState() => _SerieRowState();
}

class _SerieRowState extends State<SerieRow> {
  late final TextEditingController _pesoCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _pesoCtrl = TextEditingController(
      text: widget.serie.peso > 0 ? _formatPeso(widget.serie.peso) : '',
    );
    _repsCtrl = TextEditingController(
      text: widget.serie.reps > 0 ? '${widget.serie.reps}' : '',
    );
    _pesoCtrl.addListener(_notifyValueChange);
    _repsCtrl.addListener(_notifyValueChange);
  }

  void _notifyValueChange() {
    final peso = double.tryParse(_pesoCtrl.text) ?? 0;
    final reps = int.tryParse(_repsCtrl.text) ?? 0;
    widget.onValueChanged?.call(peso, reps);
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  String _formatPeso(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();

  void _onCheck() {
    final peso = double.tryParse(_pesoCtrl.text) ?? 0;
    final reps = int.tryParse(_repsCtrl.text) ?? 0;
    if (!widget.serie.completada && (peso <= 0 || reps <= 0)) {
      HapticFeedback.heavyImpact();
      return;
    }
    widget.onCompleted(peso, reps);
  }

  void _mostrarMenu(BuildContext context) {
    if (widget.serie.completada) return;
    final esCalentamiento = widget.serie.esCalentamiento;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                esCalentamiento ? Icons.fitness_center : Icons.local_fire_department,
                color: esCalentamiento ? AppColors.accentBlue : AppColors.accentOrange,
              ),
              title: Text(
                esCalentamiento
                    ? 'Convertir en serie normal'
                    : 'Marcar como calentamiento',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onCambiarTipo?.call(
                    esCalentamiento ? 'normal' : 'calentamiento');
              },
            ),
            if (!widget.serie.esDropSet)
              ListTile(
                leading: const Icon(Icons.arrow_downward,
                    color: AppColors.accentPurple),
                title: const Text('Añadir Drop Set',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAgregarDropSet?.call();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completada = widget.serie.completada;
    final esCalentamiento = widget.serie.esCalentamiento;
    final esDropSet = widget.serie.esDropSet;

    Color bgColor;
    Color borderColor;
    if (completada) {
      bgColor = AppColors.serieCompletada;
      borderColor = AppColors.serieCompletadaBorder;
    } else if (esCalentamiento) {
      bgColor = AppColors.accentBlue.withValues(alpha: 0.08);
      borderColor = AppColors.accentBlue.withValues(alpha: 0.4);
    } else if (esDropSet) {
      bgColor = AppColors.accentPurple.withValues(alpha: 0.08);
      borderColor = AppColors.accentPurple.withValues(alpha: 0.3);
    } else {
      bgColor = AppColors.bg3;
      borderColor = Colors.transparent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        top: 3,
        bottom: 3,
        left: esDropSet ? 18 : 0, // sangría para drop sets
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
            // ── Badge Nº / tipo ───────────────────────────────────────────────
            SizedBox(
              width: 36,
              child: InkWell(
                onTap: completada ? null : () => _mostrarMenu(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      esCalentamiento
                          ? const Icon(Icons.local_fire_department,
                              color: AppColors.accentOrange, size: 14)
                          : esDropSet
                              ? const Icon(Icons.arrow_downward,
                                  color: AppColors.accentPurple, size: 12)
                              : Text(
                                  '${widget.serie.numero}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: completada
                                        ? AppColors.accentGreen
                                        : AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                      if (!completada && !esDropSet)
                        const Icon(Icons.arrow_drop_down,
                            size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // ── Placeholder anterior ──────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                esDropSet ? 'Drop Set' : widget.serie.placeholderText,
                style: TextStyle(
                  fontSize: 11,
                  color: esDropSet
                      ? AppColors.accentPurple.withValues(alpha: 0.8)
                      : AppColors.placeholder,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 6),

            // ── Input Peso ────────────────────────────────────────────────────
            _NumericInput(
              controller: _pesoCtrl,
              label: 'kg',
              step: 2.5,
              enabled: true,
            ),

            const SizedBox(width: 6),

            // ── Input Reps ────────────────────────────────────────────────────
            _NumericInput(
              controller: _repsCtrl,
              label: 'reps',
              step: 1,
              enabled: true,
              isInt: true,
            ),

            const SizedBox(width: 6),

            // ── Check Button ──────────────────────────────────────────────────
            _CheckButton(
              completada: completada,
              onTap: _onCheck,
            ),
          ],
        ),
    );
  }
}

// ── Input numérico con botones +/- ──────────────────────────────────────────

class _NumericInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final double step;
  final bool enabled;
  final bool isInt;

  const _NumericInput({
    required this.controller,
    required this.label,
    required this.step,
    required this.enabled,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: enabled ? () => _increment(-step) : null,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        isInt ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        enabled ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              _StepBtn(
                icon: Icons.add,
                onTap: enabled ? () => _increment(step) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _increment(double delta) {
    final current = double.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0.0, 999.0);
    if (isInt) {
      controller.text = next.toInt().toString();
    } else {
      controller.text = next % 1 == 0
          ? next.toInt().toString()
          : next.toStringAsFixed(1);
    }
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 13,
            color:
                onTap != null ? AppColors.textSecondary : AppColors.textMuted),
      ),
    );
  }
}

// ── Botón Check con animación de escala ────────────────────────────────────

class _CheckButton extends StatelessWidget {
  final bool completada;
  final VoidCallback? onTap;
  const _CheckButton({required this.completada, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: completada ? AppColors.accentGreen : AppColors.bg2,
          shape: BoxShape.circle,
          border: Border.all(
            color: completada
                ? AppColors.accentGreen
                : AppColors.textMuted.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Icon(
          completada ? Icons.check : Icons.check,
          size: 18,
          color: completada ? AppColors.bg1 : AppColors.textMuted,
        ),
      )
          .animate(target: completada ? 1 : 0)
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.25, 1.25),
              duration: 150.ms,
              curve: Curves.easeOut)
          .then()
          .scale(
              begin: const Offset(1.25, 1.25),
              end: const Offset(1, 1),
              duration: 100.ms),
    );
  }
}
