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
  bool _loading = true;
  String? _error;
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
                                title: Text('${entry.peso} kg'),
                                subtitle: Text('${entry.date} • Objetivo: ${entry.objetivo}'),
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
