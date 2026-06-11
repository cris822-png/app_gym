import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/crear_rutina.dart';
import '../models/ejercicio.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelos locales de UI
// ─────────────────────────────────────────────────────────────────────────────

/// Ejercicio añadido a un día concreto de la rutina.
class _EjEnDia {
  final Ejercicio ejercicio;
  _EjEnDia(this.ejercicio);
}

/// Un día de la rutina en construcción.
class _DiaEnRutina {
  final TextEditingController nombreCtrl;
  final List<_EjEnDia> ejercicios;

  _DiaEnRutina({String nombre = ''})
      : nombreCtrl = TextEditingController(text: nombre),
        ejercicios = [];

  String get nombre => nombreCtrl.text.trim();

  void dispose() => nombreCtrl.dispose();
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal
// ─────────────────────────────────────────────────────────────────────────────

class CreateRoutineScreen extends StatefulWidget {
  final int userId;
  const CreateRoutineScreen({super.key, required this.userId});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final List<_DiaEnRutina> _dias = [];
  List<Ejercicio> _ejerciciosDisponibles = [];
  bool _loadingEjercicios = true;
  String? _errorEjercicios;
  bool _isSaving = false;

  // Nombres de días predefinidos para el dropdown
  static const _nombresDia = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
    'Día A', 'Día B', 'Día C', 'Día D', 'Push', 'Pull', 'Legs',
  ];

  @override
  void initState() {
    super.initState();
    _cargarEjercicios();
    // Empezar con un día por defecto
    _dias.add(_DiaEnRutina(nombre: 'Lunes'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final d in _dias) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarEjercicios() async {
    try {
      final lista = await ApiService().getEjercicios();
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

  // ── Añadir ejercicio a un día ──────────────────────────────────────────────

  void _abrirSelectorEjercicio(int idxDia) {
    if (_loadingEjercicios) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cargando ejercicios, espera un momento…'),
      ));
      return;
    }
    if (_errorEjercicios != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $_errorEjercicios'),
        backgroundColor: AppColors.accentOrange,
      ));
      return;
    }

    // Excluir ejercicios ya añadidos en este día
    final idsYaEnEsteDia = _dias[idxDia]
        .ejercicios
        .map((e) => e.ejercicio.idEjercicio)
        .toSet();
    final disponibles = _ejerciciosDisponibles
        .where((e) => !idsYaEnEsteDia.contains(e.idEjercicio))
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
          setState(() => _dias[idxDia].ejercicios.add(_EjEnDia(ej)));
        },
      ),
    );
  }

  // ── Guardar rutina ─────────────────────────────────────────────────────────

  Future<void> _guardarRutina() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Añade al menos un día a la rutina.'),
        backgroundColor: AppColors.accentOrange,
      ));
      return;
    }

    // Validar que cada día tiene nombre y al menos un ejercicio
    for (int i = 0; i < _dias.length; i++) {
      final dia = _dias[i];
      if (dia.nombre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('El día ${i + 1} necesita un nombre.'),
          backgroundColor: AppColors.accentOrange,
        ));
        return;
      }
      if (dia.ejercicios.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '"${dia.nombre}" no tiene ejercicios. Añade al menos uno.'),
          backgroundColor: AppColors.accentOrange,
        ));
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final payload = CrearRutinaDto(
        idUsuario: widget.userId,
        nameRutina: _nameController.text.trim(),
        fecha: DateTime.now(),
        dias: _dias.asMap().entries.map((entry) {
          final dia = entry.value;
          return DiaDtoPayload(
            nombreDia: dia.nombre,
            ejercicios: dia.ejercicios.asMap().entries.map((e) {
              return EjercicioDiaDto(
                idEjercicio: e.value.ejercicio.idEjercicio,
                orden: e.key + 1,
              );
            }).toList(),
          );
        }).toList(),
      ).toJson();

      await ApiService().crearRutina(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Rutina guardada correctamente'),
        backgroundColor: AppColors.accentGreen,
      ));
      Navigator.of(context).pop(true);
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accentGreen)),
              ),
            )
          else
            TextButton(
              onPressed: _guardarRutina,
              child: const Text('Guardar',
                  style: TextStyle(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              // ── Nombre de la rutina ────────────────────────────────────────
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

              // ── Bloques de días ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel(label: 'Días de la rutina'),
                  Text(
                    '${_dias.length} día${_dias.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Un bloque por cada día
              ...List.generate(_dias.length, (idxDia) {
                final dia = _dias[idxDia];
                return _DiaBlock(
                  key: ObjectKey(dia),
                  idxDia: idxDia,
                  dia: dia,
                  nombresDia: _nombresDia,
                  loadingEjercicios: _loadingEjercicios,
                  onAnadirEjercicio: () => _abrirSelectorEjercicio(idxDia),
                  onEliminarEjercicio: (idxEj) =>
                      setState(() => dia.ejercicios.removeAt(idxEj)),
                  onEliminarDia: _dias.length > 1
                      ? () => setState(() {
                            dia.dispose();
                            _dias.removeAt(idxDia);
                          })
                      : null,
                  onNombreChanged: () => setState(() {}),
                );
              }),

              const SizedBox(height: 12),

              // Botón añadir día
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _dias.add(_DiaEnRutina()));
                },
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.accentPurple),
                label: const Text(
                  'Añadir otro día',
                  style: TextStyle(color: AppColors.accentPurple),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(
                      color: AppColors.accentPurple, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 32),

              // Botón guardar principal
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarRutina,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar Rutina',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: bloque de un día
// ─────────────────────────────────────────────────────────────────────────────

class _DiaBlock extends StatelessWidget {
  final int idxDia;
  final _DiaEnRutina dia;
  final List<String> nombresDia;
  final bool loadingEjercicios;
  final VoidCallback onAnadirEjercicio;
  final void Function(int idxEj) onEliminarEjercicio;
  final VoidCallback? onEliminarDia;
  final VoidCallback onNombreChanged;

  const _DiaBlock({
    super.key,
    required this.idxDia,
    required this.dia,
    required this.nombresDia,
    required this.loadingEjercicios,
    required this.onAnadirEjercicio,
    required this.onEliminarEjercicio,
    this.onEliminarDia,
    required this.onNombreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header del día ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.bg3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${idxDia + 1}',
                      style: const TextStyle(
                          color: AppColors.accentBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NombreDiaField(
                    controller: dia.nombreCtrl,
                    nombresDia: nombresDia,
                    onChanged: onNombreChanged,
                  ),
                ),
                if (onEliminarDia != null)
                  IconButton(
                    onPressed: onEliminarDia,
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.accentOrange, size: 20),
                    tooltip: 'Eliminar día',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // ── Lista de ejercicios del día ──────────────────────────────────
          if (dia.ejercicios.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Ningún ejercicio añadido',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...dia.ejercicios.asMap().entries.map((entry) {
              final idxEj = entry.key;
              final ej = entry.value.ejercicio;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${idxEj + 1}',
                      style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                title: Text(ej.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  ej.musculosPrincipales,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textMuted, size: 18),
                  onPressed: () => onEliminarEjercicio(idxEj),
                  tooltip: 'Quitar ejercicio',
                ),
              );
            }),

          // ── Botón añadir ejercicio ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(
              onPressed: loadingEjercicios ? null : onAnadirEjercicio,
              icon: loadingEjercicios
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentBlue))
                  : const Icon(Icons.add, color: AppColors.accentBlue, size: 18),
              label: Text(
                loadingEjercicios
                    ? 'Cargando…'
                    : '+ Añadir ejercicio',
                style: const TextStyle(
                    color: AppColors.accentBlue, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                side: const BorderSide(color: AppColors.accentBlue, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: campo editable de nombre de día con sugerencias
// ─────────────────────────────────────────────────────────────────────────────

class _NombreDiaField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> nombresDia;
  final VoidCallback onChanged;

  const _NombreDiaField({
    required this.controller,
    required this.nombresDia,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (value) {
        if (value.text.isEmpty) return nombresDia;
        return nombresDia.where((n) =>
            n.toLowerCase().contains(value.text.toLowerCase()));
      },
      onSelected: (option) {
        controller.text = option;
        onChanged();
      },
      fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Nombre del día',
            hintStyle: TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 200),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(opt,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: selector de ejercicios (BottomSheet con buscador)
// ─────────────────────────────────────────────────────────────────────────────

class _EjercicioPickerSheet extends StatefulWidget {
  final List<Ejercicio> ejercicios;
  final void Function(Ejercicio) onSeleccionado;

  const _EjercicioPickerSheet(
      {required this.ejercicios, required this.onSeleccionado});

  @override
  State<_EjercicioPickerSheet> createState() => _EjercicioPickerSheetState();
}

class _EjercicioPickerSheetState extends State<_EjercicioPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.ejercicios
        .where((e) =>
            e.name.toLowerCase().contains(_query.toLowerCase()) ||
            e.musculosPrincipales
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seleccionar ejercicio',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o músculo…',
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textMuted, size: 20),
                    filled: true,
                    fillColor: AppColors.bg3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Text(
                    _query.isEmpty
                        ? 'No hay ejercicios disponibles'
                        : 'Sin resultados para "$_query"',
                    style: const TextStyle(color: AppColors.textMuted),
                  ))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final ej = filtrados[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        title: Text(ej.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            ej.musculosPrincipales,
                            if (ej.material != null) ej.material!,
                          ].join(' · '),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
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

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

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
