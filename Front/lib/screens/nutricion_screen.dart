import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/registro_nutricion.dart';
import '../services/api_service.dart';

// ── Tipos de comida disponibles ──────────────────────────────────────────────
const _tiposComida = ['desayuno', 'almuerzo', 'cena', 'snack', 'postre'];
const _tiposLabel = {
  'desayuno': '🌅 Desayuno',
  'almuerzo': '☀️ Almuerzo',
  'cena': '🌙 Cena',
  'snack': '🍎 Snack',
  'postre': '🍮 Postre',
};

// ── Colores por tipo de comida ───────────────────────────────────────────────
const _tiposColor = {
  'desayuno': Color(0xFFF59E0B),
  'almuerzo': Color(0xFF10B981),
  'cena': Color(0xFF6366F1),
  'snack': Color(0xFFEC4899),
  'postre': Color(0xFFF97316),
};

/// Pantalla principal de Registro Nutricional.
/// Muestra el historial del usuario y permite añadir nuevas comidas via BottomSheet.
class NutricionScreen extends StatefulWidget {
  final int userId;

  const NutricionScreen({super.key, required this.userId});

  @override
  State<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends State<NutricionScreen> {
  final ApiService _api = ApiService();
  List<RegistroNutricion> _registros = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final registros = await _api.getRegistrosNutricion(widget.userId);
      setState(() => _registros = registros);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _abrirFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutricionFormSheet(
        userId: widget.userId,
        onGuardado: () {
          _cargarRegistros();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mi Nutrición',
                    style: tt.titleLarge),
                Text('Registro de comidas',
                    style: tt.labelSmall),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _cargarRegistros,
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _cargarRegistros)
              : _registros.isEmpty
                  ? _EmptyView(onAnadir: _abrirFormulario)
                  : _ListaRegistros(
                      registros: _registros,
                      onRefresh: _cargarRegistros,
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Añadir comida',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Lista de registros ───────────────────────────────────────────────────────

class _ListaRegistros extends StatelessWidget {
  final List<RegistroNutricion> registros;
  final Future<void> Function() onRefresh;

  const _ListaRegistros(
      {required this.registros, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // Agrupar por día
    final Map<String, List<RegistroNutricion>> porDia = {};
    for (final r in registros) {
      final dia = '${r.fechaConsumo.year}-${r.fechaConsumo.month.toString().padLeft(2, '0')}-${r.fechaConsumo.day.toString().padLeft(2, '0')}';
      porDia.putIfAbsent(dia, () => []).add(r);
    }
    final dias = porDia.keys.toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: dias.length,
        itemBuilder: (ctx, i) {
          final dia = dias[i];
          final items = porDia[dia]!;
          final fecha = DateTime.parse(dia);
          final esHoy = dia ==
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
          final label = esHoy
              ? 'Hoy'
              : '${fecha.day}/${fecha.month}/${fecha.year}';

          // Total gramos del día
          final totalG = items.fold<double>(
              0, (sum, r) => sum + r.cantidadG);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: esHoy
                                ? const Color(0xFF10B981)
                                : AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    Text('${totalG.toStringAsFixed(0)}g total',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              ...items.map((r) => _RegistroTile(registro: r)),
            ],
          );
        },
      ),
    );
  }
}

// ── Tile individual ──────────────────────────────────────────────────────────

class _RegistroTile extends StatelessWidget {
  final RegistroNutricion registro;
  const _RegistroTile({required this.registro});

  @override
  Widget build(BuildContext context) {
    final color =
        _tiposColor[registro.tipoComida] ?? AppColors.accentBlue;
    final hora =
        '${registro.fechaConsumo.hour.toString().padLeft(2, '0')}:${registro.fechaConsumo.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bg3),
      ),
      child: Row(
        children: [
          // Icono tipo comida
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _tiposLabel[registro.tipoComida]?.substring(0, 2) ?? '🍽',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nombre y tipo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(registro.comida,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                    '${registro.tipoLabel} · $hora',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          // Cantidad
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${registro.cantidadG.toStringAsFixed(0)}g',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAnadir;
  const _EmptyView({required this.onAnadir});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: Color(0xFF10B981), size: 38),
            ),
            const SizedBox(height: 20),
            const Text('Sin registros aún',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
                'Empieza a registrar tus comidas\npara que el Coach IA pueda\nestimar tus calorías y macros.',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAnadir,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Añadir primera comida',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

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
            const Icon(Icons.wifi_off, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text('Error al cargar datos',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
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

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — Formulario de registro
// ─────────────────────────────────────────────────────────────────────────────

class _NutricionFormSheet extends StatefulWidget {
  final int userId;
  final VoidCallback onGuardado;

  const _NutricionFormSheet(
      {required this.userId, required this.onGuardado});

  @override
  State<_NutricionFormSheet> createState() => _NutricionFormSheetState();
}

class _NutricionFormSheetState extends State<_NutricionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _comidaCtrl = TextEditingController();
  final _gramosCtrl = TextEditingController();

  String _tipoSeleccionado = 'almuerzo';
  DateTime _fechaConsumo = DateTime.now();
  bool _guardando = false;

  @override
  void dispose() {
    _comidaCtrl.dispose();
    _gramosCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaHora() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaConsumo,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF10B981),
            surface: AppColors.bg2,
          ),
        ),
        child: child!,
      ),
    );
    if (fecha == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaConsumo),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF10B981),
            surface: AppColors.bg2,
          ),
        ),
        child: child!,
      ),
    );
    if (hora == null || !mounted) return;

    setState(() {
      _fechaConsumo = DateTime(
          fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final registro = RegistroNutricion(
        comida: _comidaCtrl.text.trim(),
        cantidadG: double.parse(_gramosCtrl.text),
        tipoComida: _tipoSeleccionado,
        fechaConsumo: _fechaConsumo,
      );

      await ApiService().guardarRegistroNutricion(widget.userId, registro);

      HapticFeedback.lightImpact();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onGuardado();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                    '¡${_comidaCtrl.text.trim()} registrado!',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final hora =
        '${_fechaConsumo.hour.toString().padLeft(2, '0')}:${_fechaConsumo.minute.toString().padLeft(2, '0')}';
    final fechaStr =
        '${_fechaConsumo.day}/${_fechaConsumo.month}/${_fechaConsumo.year} $hora';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle + título
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_menu,
                      color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Text('Registrar comida',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),

            const SizedBox(height: 24),

            // ── Nombre de la comida ────────────────────────────────────────
            _Label('Nombre de la comida'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _comidaCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: _inputDeco('Ej: Pollo a la plancha, Ensalada...'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),

            const SizedBox(height: 16),

            // ── Cantidad en gramos ─────────────────────────────────────────
            _Label('Cantidad (gramos)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _gramosCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: _inputDeco('Ej: 200'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Introduce un valor válido';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Tipo de comida ─────────────────────────────────────────────
            _Label('Tipo de comida'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tipoSeleccionado,
                  isExpanded: true,
                  dropdownColor: AppColors.bg3,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  items: _tiposComida
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                                _tiposLabel[t] ?? t,
                                style: const TextStyle(
                                    color: AppColors.textPrimary)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _tipoSeleccionado = v!),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Fecha y hora ───────────────────────────────────────────────
            _Label('Fecha y hora'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _seleccionarFechaHora,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Text(fechaStr,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Botón guardar ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Guardar comida',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers de UI ─────────────────────────────────────────────────────────────

Widget _Label(String text) => Text(
      text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.4),
    );

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.placeholder, fontSize: 13),
      filled: true,
      fillColor: AppColors.bg3,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
