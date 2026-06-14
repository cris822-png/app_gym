import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/rutina.dart';
import '../providers/workout_provider.dart';
import '../services/api_service.dart';
import '../widgets/ejercicio_card.dart';
import '../widgets/ia_chat_overlay.dart';

/// Pantalla de entrenamiento activo — registro en tiempo real.
///
/// Flujo:
/// 1. Carga las rutinas del usuario y permite seleccionar una.
/// 2. Para cada ejercicio de la rutina, carga el último registro (placeholders).
/// 3. El usuario completa series → se guardan en DB al presionar ✓.
/// 4. FAB morado abre el chat IA sin salir del entreno.
class WorkoutScreen extends StatefulWidget {
  final int userId;

  const WorkoutScreen({super.key, required this.userId});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final ApiService _api = ApiService();
  bool _loadingRutinas = true;
  List<Rutina> _rutinas = [];
  List<Map<String, dynamic>> _ejerciciosDisponibles = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutProvider>().restaurarDeCache();
    });
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _loadingRutinas = true;
      _error = null;
    });
    try {
      final rutinas = await _api.getRutinas(widget.userId);
      final ejercicios = await _api.getEjercicios();
      setState(() {
        _rutinas = rutinas;
        _ejerciciosDisponibles = ejercicios.map((e) => {
          'id_ejercicio': e.idEjercicio,
          'name': e.name,
          'musculos_principales': e.musculosPrincipales,
          'material': e.material,
        }).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingRutinas = false);
    }
  }

  void _openIaChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.93,
        builder: (ctx, scrollCtrl) => IaChatOverlay(
          userId: widget.userId,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        // Mostrar SnackBar si el provider registra un error (ej. fallo al guardar serie)
        if (provider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.error!),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            provider.clearError();
          });
        }
        return Scaffold(
          backgroundColor: AppColors.bg1,
          // ── AppBar con timer ─────────────────────────────────────────────
          appBar: AppBar(
            backgroundColor: AppColors.bg1,
            surfaceTintColor: Colors.transparent,
            title: provider.activo
                ? Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 8, color: AppColors.accentGreen),
                      const SizedBox(width: 6),
                      Text(
                        'Entreno activo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          provider.duracionFormateada,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentGreen,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  )
                : Text('Entreno',
                    style: Theme.of(context).textTheme.titleLarge),
            actions: [
                TextButton(
                  onPressed: () async {
                    final provider = context.read<WorkoutProvider>();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.bg2,
                        title: const Text('Finalizar Entreno', style: TextStyle(color: AppColors.textPrimary)),
                        content: const Text('¿Guardar y finalizar el entrenamiento actual?', style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Finalizar', style: TextStyle(color: AppColors.accentOrange)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final success = await provider.finalizarEntrenamientoLote();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Entrenamiento guardado con éxito'), backgroundColor: AppColors.accentGreen),
                        );
                        // Redirect or just let the view change back to selector
                      }
                    }
                  },
                  child: provider.loading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOrange))
                    : const Text('Finalizar',
                      style: TextStyle(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),

          body: _loadingRutinas
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accentBlue))
              : _error != null
                  ? _ErrorView(
                      error: _error!, onRetry: _cargarDatos)
                  : provider.activo
                      ? _EntrenoActivoView(
                          provider: provider,
                          userId: widget.userId,
                          ejerciciosDisponibles: _ejerciciosDisponibles,
                        )
                      : _SelectorRutinaView(
                          rutinas: _rutinas,
                          ejercicios: _ejerciciosDisponibles,
                          apiService: _api,
                          onRutinaSeleccionada: (ejerciciosDia) async {
                            provider.iniciarEntreno();
                            await provider.cargarEjerciciosDeRutina(
                                ejerciciosDia);
                          },
                          onEntrenoLibre: () {
                            provider.iniciarEntreno();
                          },
                          onRutinaEliminada: _cargarDatos,
                        ),

          // ── FAB: coach IA (solo durante entreno) ────────────────────────
          floatingActionButton: provider.activo
              ? FloatingActionButton(
                  onPressed: () => _openIaChat(context),
                  backgroundColor: AppColors.accentPurple.withValues(alpha: 0.9),
                  elevation: 6,
                  tooltip: 'Coach IA',
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 22),
                )
              : null,
          
          bottomNavigationBar: provider.isResting
              ? _RestTimerBottomBar(provider: provider)
              : null,
        );
      },
    );
  }
}

// ── Widget: Barra Inferior de Descanso ────────────────────────────────────

class _RestTimerBottomBar extends StatelessWidget {
  final WorkoutProvider provider;

  const _RestTimerBottomBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final m = provider.restSecondsRemaining ~/ 60;
    final s = provider.restSecondsRemaining % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descanso',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (provider.currentRestEjercicioId == null) return;
                    
                    final textCtrl = TextEditingController();
                    final secs = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.bg2,
                        title: const Text('Editar Descanso Base', style: TextStyle(color: AppColors.textPrimary)),
                        content: TextField(
                          controller: textCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Segundos (ej. 90)',
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
                      )
                    );
                    
                    if (secs != null) {
                      provider.cambiarTiempoDescansoBase(provider.currentRestEjercicioId!, secs);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Descanso base actualizado'), backgroundColor: AppColors.accentGreen)
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _TimerBtn(
                  icon: Icons.remove,
                  label: '-30s',
                  onTap: () => provider.modifyRestTimer(-30),
                ),
                const SizedBox(width: 8),
                _TimerBtn(
                  icon: Icons.add,
                  label: '+30s',
                  onTap: () => provider.modifyRestTimer(30),
                ),
                const SizedBox(width: 8),
                _TimerBtn(
                  icon: Icons.skip_next,
                  label: 'Saltar',
                  onTap: () => provider.skipRestTimer(),
                  isPrimary: true,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _TimerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _TimerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.accentOrange.withValues(alpha: 0.2) : AppColors.bg2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? AppColors.accentOrange : AppColors.textPrimary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? AppColors.accentOrange : AppColors.textSecondary,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista: Selector de Rutina / Entreno libre ───────────────────────────────

class _SelectorRutinaView extends StatefulWidget {
  final List<Rutina> rutinas;
  final List<Map<String, dynamic>> ejercicios;
  final ApiService apiService;
  final Function(List<Map<String, dynamic>>) onRutinaSeleccionada;
  final VoidCallback onEntrenoLibre;
  final VoidCallback onRutinaEliminada;

  const _SelectorRutinaView({
    required this.rutinas,
    required this.ejercicios,
    required this.apiService,
    required this.onRutinaSeleccionada,
    required this.onEntrenoLibre,
    required this.onRutinaEliminada,
  });

  @override
  State<_SelectorRutinaView> createState() => _SelectorRutinaViewState();
}

class _SelectorRutinaViewState extends State<_SelectorRutinaView> {
  bool _cargandoRutina = false;

  /// Al seleccionar una rutina con múltiples días, pregunta al usuario
  /// cuál día quiere entrenar hoy (Opción A: selector de día previo).
  Future<void> _seleccionarRutina(Rutina rutina) async {
    if (rutina.dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta rutina no tiene días configurados.'),
          backgroundColor: AppColors.accentOrange,
        ),
      );
      return;
    }

    RutinaDia? diaSeleccionado;

    if (rutina.dias.length == 1) {
      // Una sola opción — no hace falta preguntar
      diaSeleccionado = rutina.dias.first;
    } else {
      // Mostrar dialog de selección de día
      diaSeleccionado = await showDialog<RutinaDia>(
        context: context,
        builder: (ctx) => _DialogSeleccionDia(rutina: rutina),
      );
    }

    if (diaSeleccionado == null || !mounted) return;

    setState(() => _cargandoRutina = true);
    try {
      final ejerciciosDia = diaSeleccionado.ejercicios
          .map((e) => e.toWorkoutMap())
          .toList();
      await widget.onRutinaSeleccionada(ejerciciosDia);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar la rutina: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoRutina = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoRutina) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accentBlue),
            SizedBox(height: 16),
            Text('Cargando rutina...', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué entrenas hoy?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Selecciona una rutina o empieza libremente.',
              style: Theme.of(context).textTheme.bodyMedium),

          const SizedBox(height: 24),

          // Tarjeta entreno libre
          _QuickStartCard(
            icon: Icons.bolt,
            color: AppColors.accentOrange,
            titulo: 'Entreno libre',
            subtitulo: 'Añade ejercicios sobre la marcha',
            onTap: widget.onEntrenoLibre,
          ),

          if (widget.rutinas.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Mis rutinas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...widget.rutinas.map((r) => _RutinaItem(
                  rutina: r,
                  apiService: widget.apiService,
                  onTap: () => _seleccionarRutina(r),
                  onDeleted: widget.onRutinaEliminada,
                )),
          ],
        ],
      ),
    );
  }
}

// ── Dialog: selección de día ──────────────────────────────────────────────────

class _DialogSeleccionDia extends StatelessWidget {
  final Rutina rutina;
  const _DialogSeleccionDia({required this.rutina});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué día entrenas?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              rutina.nameRutina,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...rutina.dias.map((dia) => _DiaOpcion(
                  dia: dia,
                  onTap: () => Navigator.of(context).pop(dia),
                )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaOpcion extends StatelessWidget {
  final RutinaDia dia;
  final VoidCallback onTap;
  const _DiaOpcion({required this.dia, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today,
                  color: AppColors.accentBlue, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dia.nombreDia,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  Text(
                    '${dia.ejercicios.length} ejercicio${dia.ejercicios.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow,
                color: AppColors.accentGreen, size: 22),
          ],
        ),
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _QuickStartCard({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _RutinaItem extends StatelessWidget {
  final Rutina rutina;
  final ApiService apiService;
  final VoidCallback onTap;
  final VoidCallback onDeleted;

  const _RutinaItem({
    required this.rutina, 
    required this.apiService, 
    required this.onTap, 
    required this.onDeleted
  });

  Future<void> _confirmarBorrado(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('Eliminar rutina', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('¿Estás seguro de que quieres borrar "${rutina.nameRutina}"? Esta acción no se puede deshacer.', 
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await apiService.deleteRutina(rutina.idRutina);
        onDeleted();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al borrar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diasCount = rutina.dias.length;
    final ejCount = rutina.totalEjercicios;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bg3),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center,
                  color: AppColors.accentBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rutina.nameRutina,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$diasCount día${diasCount != 1 ? 's' : ''} · $ejCount ejercicio${ejCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 22),
              onPressed: () => _confirmarBorrado(context),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Vista: Entreno activo ────────────────────────────────────────────────────

class _EntrenoActivoView extends StatelessWidget {
  final WorkoutProvider provider;
  final int userId;
  final List<Map<String, dynamic>> ejerciciosDisponibles;

  const _EntrenoActivoView({
    required this.provider,
    required this.userId,
    required this.ejerciciosDisponibles,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accentBlue),
            SizedBox(height: 16),
            Text('Cargando ejercicios...',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (provider.ejercicios.isEmpty) {
      return _AgregarPrimerEjercicio(
        ejerciciosDisponibles: ejerciciosDisponibles,
        onAgregar: (ej) => provider.agregarEjercicio(ej),
      );
    }

    // Construir grupos de widgets respetando supersets
    final widgets = _buildEjercicioWidgets(context, provider);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: widgets.length + 1,
      itemBuilder: (ctx, i) {
        if (i == widgets.length) {
          return _BotonAgregarEjercicio(
            ejerciciosDisponibles: ejerciciosDisponibles,
            onAgregar: (ej) => provider.agregarEjercicio(ej),
          );
        }
        return widgets[i];
      },
    );
  }

  List<Widget> _buildEjercicioWidgets(
      BuildContext context, WorkoutProvider provider) {
    final ejercicios = provider.ejercicios;
    final List<Widget> result = [];
    final Set<int> procesados = {};

    for (int i = 0; i < ejercicios.length; i++) {
      if (procesados.contains(i)) continue;
      final ej = ejercicios[i];

      if (ej.grupoSuperset != null) {
        // Recoger todos los índices del mismo grupo
        final grupo = ej.grupoSuperset!;
        final indicesGrupo = <int>[];
        for (int j = i; j < ejercicios.length; j++) {
          if (ejercicios[j].grupoSuperset == grupo) {
            indicesGrupo.add(j);
            procesados.add(j);
          }
        }

        result.add(_SupersetCard(
          grupo: grupo,
          children: indicesGrupo
              .map((idx) => _buildEjercicioCard(context, provider, idx))
              .toList(),
        ));
      } else {
        procesados.add(i);
        result.add(_buildEjercicioCard(context, provider, i));
      }
    }
    return result;
  }

  Widget _buildEjercicioCard(
      BuildContext context, WorkoutProvider provider, int i) {
    final ej = provider.ejercicios[i];
    return EjercicioCard(
      key: ValueKey(ej.idEjercicio),
      ejercicio: ej,
      index: i,
      onAgregarSerie: () => provider.agregarSerie(i),
      onSerieCompletada: (idxSerie, peso, reps) =>
          provider.completarSerie(i, idxSerie, peso, reps),
      onAgregarDropSet: (idxSerie) =>
          provider.agregarDropSet(i, idxSerie),
      onDropSetCompletado: (idxSerie, idxDrop, peso, reps) =>
          provider.completarDropSet(i, idxSerie, idxDrop, peso, reps),
      onCambiarTipoSerie: (idxSerie, tipo) =>
          provider.cambiarTipoSerie(i, idxSerie, tipo),
    );
  }
}

// ── Tarjeta visual de Súper Serie ─────────────────────────────────────────────

class _SupersetCard extends StatelessWidget {
  final String grupo;
  final List<Widget> children;

  const _SupersetCard({required this.grupo, required this.children});

  // Colores cíclicos por grupo: A=azul, B=verde, C=naranja, D=morado…
  static const _colores = [
    AppColors.accentBlue,
    AppColors.accentGreen,
    AppColors.accentOrange,
    AppColors.accentPurple,
  ];

  Color get _color {
    final idx = grupo.codeUnitAt(0) % _colores.length;
    return _colores[idx];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral de color
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 4, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge SUPERSET
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'SUPERSET $grupo',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ),
                    // Tarjetas individuales sin margen extra
                    ...children.map((child) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: child,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AgregarPrimerEjercicio extends StatelessWidget {
  final List<Map<String, dynamic>> ejerciciosDisponibles;
  final Function(Map<String, dynamic>) onAgregar;

  const _AgregarPrimerEjercicio({
    required this.ejerciciosDisponibles,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline,
              color: AppColors.textMuted, size: 60),
          const SizedBox(height: 16),
          const Text('Entreno libre iniciado',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Añade tu primer ejercicio para empezar',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _mostrarSelectorEjercicio(
                context, ejerciciosDisponibles, onAgregar),
            icon: const Icon(Icons.add),
            label: const Text('Añadir ejercicio'),
          ),
        ],
      ),
    );
  }
}

class _BotonAgregarEjercicio extends StatelessWidget {
  final List<Map<String, dynamic>> ejerciciosDisponibles;
  final Function(Map<String, dynamic>) onAgregar;

  const _BotonAgregarEjercicio({
    required this.ejerciciosDisponibles,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () => _mostrarSelectorEjercicio(
            context, ejerciciosDisponibles, onAgregar),
        icon: const Icon(Icons.add, color: AppColors.accentBlue),
        label: const Text('Añadir ejercicio',
            style: TextStyle(color: AppColors.accentBlue)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppColors.accentBlue, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

void _mostrarSelectorEjercicio(
  BuildContext context,
  List<Map<String, dynamic>> ejercicios,
  Function(Map<String, dynamic>) onSeleccionado,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bg1,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _EjercicioSelectorSheet(
      ejercicios: ejercicios,
      onSeleccionado: onSeleccionado,
    ),
  );
}

class _EjercicioSelectorSheet extends StatefulWidget {
  final List<Map<String, dynamic>> ejercicios;
  final Function(Map<String, dynamic>) onSeleccionado;

  const _EjercicioSelectorSheet({
    required this.ejercicios,
    required this.onSeleccionado,
  });

  @override
  State<_EjercicioSelectorSheet> createState() =>
      _EjercicioSelectorSheetState();
}

class _EjercicioSelectorSheetState extends State<_EjercicioSelectorSheet> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.ejercicios.where((e) {
      final nombre = (e['name'] as String? ?? '').toLowerCase();
      return nombre.contains(_busqueda.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.bg3, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Buscar ejercicio...',
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtrados.length,
            itemBuilder: (_, i) {
              final ej = filtrados[i];
              return ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: AppColors.accentBlue, size: 18),
                ),
                title: Text(ej['name'] as String? ?? '',
                    style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  ej['musculos_principales'] as String? ?? '',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSeleccionado(ej);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Vista de error ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off,
                color: AppColors.accentOrange, size: 48),
            const SizedBox(height: 12),
            const Text('No se pudo cargar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(error,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
