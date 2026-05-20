import 'package:flutter/material.dart';

import '../models/progreso.dart';
import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  final int userId;

  const ProgressScreen({super.key, required this.userId});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _formError;
  List<ProgressEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _apiService.getProgreso(widget.userId);
      setState(() {
        _entries = entries;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _submitProgress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _formError = null;
    });

    final peso = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));

    if (peso == null || peso <= 0) {
      setState(() {
        _formError = 'Ingresa un peso válido mayor a 0';
        _saving = false;
      });
      return;
    }

    try {
      await _apiService.registrarProgreso(widget.userId, peso);
      _weightController.clear();
      await _loadProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progreso registrado correctamente')));
      }
    } catch (e) {
      setState(() {
        _formError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Registrar nuevo peso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              if (_formError != null) ...[
                                Text(_formError!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                              ],
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _weightController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Peso (kg)',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu peso';
                                        }
                                        final parsed = double.tryParse(value.replaceAll(',', '.'));
                                        if (parsed == null || parsed <= 0) {
                                          return 'Ingresa un peso válido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _saving ? null : _submitProgress,
                                      child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar peso'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Peso (kg)', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              SizedBox(height: 120, child: Center(child: Text('Gráfico de línea (placeholder)'))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return Card(
                              child: ListTile(
                                title: Text('${entry.peso.toStringAsFixed(1)} kg'),
                                subtitle: Text(entry.date),
                              ),
                            );
                          },
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _loadProgress,
                        child: const Text('Actualizar progreso'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
