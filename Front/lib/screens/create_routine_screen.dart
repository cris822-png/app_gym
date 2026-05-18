import 'package:flutter/material.dart';

class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routineNameController = TextEditingController();
  final _goalController = TextEditingController();
  int _daysPerWeek = 4;
  bool _isSaving = false;

  @override
  void dispose() {
    _routineNameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rutina guardada correctamente')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Rutina')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text('Configura tu rutina', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Define el nombre, el objetivo y la frecuencia semanal para que la IA te sugiera el plan ideal.', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _routineNameController,
                  decoration: const InputDecoration(labelText: 'Nombre de la rutina', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa un nombre para la rutina';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goalController,
                  decoration: const InputDecoration(labelText: 'Objetivo', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Describe tu objetivo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Días por semana', style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 8),
                Slider(
                  value: _daysPerWeek.toDouble(),
                  min: 2,
                  max: 7,
                  divisions: 5,
                  label: '$_daysPerWeek días',
                  onChanged: (value) => setState(() => _daysPerWeek = value.toInt()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Fuerza', 'Hipertrofia', 'Resistencia', 'Full body'].map((tag) {
                    return InputChip(label: Text(tag), onPressed: () {});
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveRoutine,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar rutina'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
