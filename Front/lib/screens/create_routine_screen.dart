import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/crear_rutina.dart';
import '../models/ejercicio.dart';
import '../services/api_service.dart';

// ── Modelo local de ejercicio añadido a la rutina ──────────────────────────

class _EjercicioEnRutina {
  final Ejercicio ejercicio;
  int series;
  int reps;

  _EjercicioEnRutina.withDefaults({required this.ejercicio})
      : series = 3,
        reps = 10;

  _EjercicioEnRutina({
    required this.ejercicio,
    required this.series,
    required this.reps,
  });
}

// ── Pantalla principal ─────────────────────────────────────────────────────

class CreateRoutineScreen extends StatefulWidget {
  final int userId;

  const CreateRoutineScreen({super.key, required this.userId});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Días de la semana seleccionados (0=Lun … 6=Dom)
  final Set<int> _diasSeleccionados = {};

  // Lista de ejercicios añadidos a la rutina
  final List<_EjercicioEnRutina> _ejerciciosEnRutina = [];

  // Ejercicios disponibles cargados desde la API
  List<Ejercicio> _ejerciciosDisponibles = [];
  bool _loadingEjercicios = true;
  String? _errorEjercicios;

  bool _isSaving = false;

  static const _diasSemana = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];

  @override
  void initState() {
    super.initState();
    _cargarEjercicios();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _cargarEjercicios() async {
    try {
      final api = ApiService();
      final lista = await api.getEjercicios();
      if (mounted) {
        setState(() {
          _ejerciciosDisponibles = lista;
          _loadingEjercicios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorEjercicios = e.toString();
          _loadingEjercicios = false;
        });
      }
    }
  }

  // ── Modal de búsqueda y selección de ejercicios ────────────────────────

  void _abrirSelectorEjercicio() {
    if (_loadingEjercicios) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cargando ejercicios, espera un momento…'),
      ));
      return;
    }
    if (_errorEjercicios != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cargar ejercicios: $_errorEjercicios'),
        backgroundColor: AppColors.accentOrange,
      ));
      return;
    }

    // Ejercicios ya añadidos, los excluimos del selector
    final idsYaAgregados =
        _ejerciciosEnRutina.map((e) => e.ejercicio.idEjercicio).toSet();
    final disponibles = _ejerciciosDisponibles
        .where((e) => !idsYaAgregados.contains(e.idEjercicio))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EjercicioPickerSheet(
        ejercicios: disponibles,
        onSeleccionado: (ej) {
          setState(() {
            _ejerciciosEnRutina.add(_EjercicioEnRutina.withDefaults(ejercicio: ej));
          });
        },
      ),
    );
  }

  // ── Guardar rutina: POST real al backend ─────────────────────────────────

  Future<void> _guardarRutina() async {
    if (!_formKey.currentState!.validate()) return;

    if (_diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona al menos un día de entrenamiento.'),
        backgroundColor: AppColors.accentOrange,
      ));
      return;
    }

    if (_ejerciciosEnRutina.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Añade al menos un ejercicio a la rutina.'),
        backgroundColor: AppColors.accentOrange,
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ApiService();
      // Usamos hoy como fecha inicial de la rutina
      final payload = CrearRutinaDto(
        idUsuario: widget.userId,
        nameRutina: _nameController.text.trim(),
        fecha: DateTime.now(),
        ejercicios: _ejerciciosEnRutina.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return RutinaEjercicioDto(
            idEjercicio: item.ejercicio.idEjercicio,
            orden: idx + 1,
            series: List.generate(
              item.series,
              (_) => SerieDto(reps: item.reps),
            ),
          );
        }).toList(),
      ).toJson();

      await api.crearRutina(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Rutina guardada correctamente'),
        backgroundColor: AppColors.accentGreen,
      ));
      Navigator.of(context).pop(true); // devuelve true para refrescar
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'),
        backgroundColor: AppColors.accentOrange,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: const Text('Crear Rutina'),
        backgroundColor: AppColors.bg1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              // ── Nombre de la rutina ──────────────────────────────────
              _SectionLabel(label: 'Nombre de la rutina'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ej. Push & Pull, Tren superior…',
                  prefixIcon: Icon(Icons.fitness_center,
                      color: AppColors.textMuted, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              ),

              const SizedBox(height: 28),

              // ── Días de la semana ────────────────────────────────────
              _SectionLabel(label: 'Días de entrenamiento'),
              const SizedBox(height: 4),
              Text(
                'Selecciona los días en que harás esta rutina',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_diasSemana.length, (i) {
                  final seleccionado = _diasSeleccionados.contains(i);
                  return FilterChip(
                    label: Text(_diasSemana[i]),
                    selected: seleccionado,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _diasSeleccionados.add(i);
                        } else {
                          _diasSeleccionados.remove(i);
                        }
                      });
                    },
                    selectedColor: AppColors.accentBlue.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.accentBlue,
                    labelStyle: TextStyle(
                      color: seleccionado
                          ? AppColors.accentBlue
                          : AppColors.textSecondary,
                      fontWeight: seleccionado
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    backgroundColor: AppColors.bg3,
                    side: BorderSide(
                      color: seleccionado
                          ? AppColors.accentBlue
                          : AppColors.bg3,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // ── Ejercicios añadidos ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel(label: 'Ejercicios'),
                  if (_ejerciciosEnRutina.isNotEmpty)
                    Text(
                      '${_ejerciciosEnRutina.length} añadidos',
                      style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista de ejercicios añadidos
              if (_ejerciciosEnRutina.isEmpty)
                _EmptyEjerciciosPlaceholder(
                  loading: _loadingEjercicios,
                  error: _errorEjercicios,
                  onRetry: _cargarEjercicios,
                )
              else
                ...List.generate(_ejerciciosEnRutina.length, (i) {
                  final item = _ejerciciosEnRutina[i];
                  return _EjercicioEnRutinaCard(
                    key: ValueKey(item.ejercicio.idEjercicio),
                    item: item,
                    onRemove: () =>
                        setState(() => _ejerciciosEnRutina.removeAt(i)),
                    onChanged: () => setState(() {}),
                  );
                }),

              const SizedBox(height: 12),

              // Botón añadir ejercicio
              OutlinedButton.icon(
                onPressed:
                    _loadingEjercicios ? null : _abrirSelectorEjercicio,
                icon: _loadingEjercicios
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentBlue),
                      )
                    : const Icon(Icons.add, color: AppColors.accentBlue),
                label: Text(
                  _loadingEjercicios
                      ? 'Cargando ejercicios…'
                      : 'Añadir ejercicio',
                  style: TextStyle(
                    color: _loadingEjercicios
                        ? AppColors.textMuted
                        : AppColors.accentBlue,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: BorderSide(
                    color: _loadingEjercicios
                        ? AppColors.bg3
                        : AppColors.accentBlue,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Botón flotante Guardar ─────────────────────────────────────────
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _guardarRutina,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            disabledBackgroundColor: AppColors.bg3,
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text(
                  'Guardar rutina',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyEjerciciosPlaceholder extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const _EmptyEjerciciosPlaceholder({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.accentBlue),
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.wifi_off, color: AppColors.accentOrange, size: 32),
            const SizedBox(height: 8),
            const Text('No se pudieron cargar los ejercicios',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Reintentar',
                  style: TextStyle(color: AppColors.accentBlue)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.2),
            style: BorderStyle.solid),
      ),
      child: const Column(
        children: [
          Icon(Icons.add_circle_outline,
              color: AppColors.textMuted, size: 40),
          SizedBox(height: 10),
          Text(
            'Sin ejercicios todavía',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Pulsa "Añadir ejercicio" para incluirlos en tu rutina',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de ejercicio en la rutina con control de series/reps ───────────

class _EjercicioEnRutinaCard extends StatelessWidget {
  final _EjercicioEnRutina item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _EjercicioEnRutinaCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center,
                    color: AppColors.accentBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.ejercicio.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item.ejercicio.musculosPrincipales,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 18),
                onPressed: onRemove,
                tooltip: 'Quitar ejercicio',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SpinnerField(
                label: 'Series',
                value: item.series,
                min: 1,
                max: 10,
                onDecrement: () {
                  if (item.series > 1) {
                    item.series--;
                    onChanged();
                  }
                },
                onIncrement: () {
                  if (item.series < 10) {
                    item.series++;
                    onChanged();
                  }
                },
              ),
              const SizedBox(width: 16),
              _SpinnerField(
                label: 'Reps',
                value: item.reps,
                min: 1,
                max: 50,
                onDecrement: () {
                  if (item.reps > 1) {
                    item.reps--;
                    onChanged();
                  }
                },
                onIncrement: () {
                  if (item.reps < 50) {
                    item.reps++;
                    onChanged();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpinnerField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SpinnerField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            _SpinButton(
              icon: Icons.remove,
              onPressed: value > min ? onDecrement : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SpinButton(
              icon: Icons.add,
              onPressed: value < max ? onIncrement : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _SpinButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SpinButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onPressed != null ? AppColors.bg3 : AppColors.bg2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onPressed != null
                ? AppColors.accentBlue
                : AppColors.textMuted),
      ),
    );
  }
}

// ── Modal bottom sheet: selector de ejercicios con búsqueda ───────────────

class _EjercicioPickerSheet extends StatefulWidget {
  final List<Ejercicio> ejercicios;
  final Function(Ejercicio) onSeleccionado;

  const _EjercicioPickerSheet({
    required this.ejercicios,
    required this.onSeleccionado,
  });

  @override
  State<_EjercicioPickerSheet> createState() => _EjercicioPickerSheetState();
}

class _EjercicioPickerSheetState extends State<_EjercicioPickerSheet> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.ejercicios.where((e) {
      final nombre = e.name.toLowerCase();
      final musculo = e.musculosPrincipales.toLowerCase();
      final q = _busqueda.toLowerCase();
      return nombre.contains(q) || musculo.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const Text(
                  'Selecciona un ejercicio',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtrados.length} disponibles',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o músculo…',
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textMuted, size: 20),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final ej = filtrados[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.fitness_center,
                              color: AppColors.accentBlue, size: 18),
                        ),
                        title: Text(ej.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ej.musculosPrincipales,
                                style: const TextStyle(
                                    color: AppColors.accentGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (ej.material != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '· ${ej.material}',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.add_circle,
                            color: AppColors.accentBlue, size: 22),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSeleccionado(ej);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
