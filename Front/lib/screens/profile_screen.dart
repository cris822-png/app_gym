import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'create_routine_screen.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.userId, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _objetivoPercentageController = TextEditingController();
  final TextEditingController _objetivoPesoController = TextEditingController();
  bool _loading = true;
  bool _savingObjectives = false;
  String? _error;
  String? _formError;
  Usuario? _usuario;

  @override
  void initState() {
    super.initState();
    _loadUsuario();
  }

  Future<void> _loadUsuario() async {
    setState(() {
      _loading = true;
      _error = null;
      _formError = null;
    });

    try {
      final usuario = await _apiService.getUsuario(widget.userId);
      setState(() {
        _usuario = usuario;
        _objetivoPercentageController.text = usuario.objetivoPorcentage ?? '';
        _objetivoPesoController.text = usuario.objetivoPeso ?? '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileHeader(),
                              const SizedBox(height: 20),
                              _buildInfoCard('Email', _usuario?.email ?? '-'),
                              const SizedBox(height: 12),
                              _buildInfoCard('Objetivo grasa', _usuario?.objetivoPorcentage ?? 'Sin objetivo registrado'),
                              const SizedBox(height: 12),
                              _buildInfoCard('Objetivo peso', _usuario?.objetivoPeso ?? 'Sin objetivo registrado'),
                              const SizedBox(height: 12),
                              _buildInfoCard('Peso', '${_usuario?.peso.toStringAsFixed(1)} kg'),
                              const SizedBox(height: 12),
                              _buildInfoCard('Altura', '${_usuario?.altura.toStringAsFixed(0)} cm'),
                              const SizedBox(height: 20),
                              _buildObjectiveForm(),
                              const SizedBox(height: 20),
                              _buildRoutineSummaryCard(),
                              const SizedBox(height: 20),
                              const Text('Configuración rápida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _buildActionTile(Icons.add_circle_outline, 'Crear rutina', 'Diseña tu plan ideal', onTap: _openCreateRoutine),
                              const SizedBox(height: 8),
                              _buildActionTile(Icons.bolt, 'Metas y objetivos', 'Ajusta tu plan de entrenamiento'),
                              const SizedBox(height: 8),
                              _buildActionTile(Icons.shield_outlined, 'Privacidad', 'Controla tus datos'),
                              const SizedBox(height: 8),
                              _buildActionTile(Icons.logout, 'Cerrar sesión', 'Volver a iniciar sesión', onTap: () => _showLogoutDialog(context)),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final firstName = _usuario?.name.split(' ').first ?? 'Usuario';
    final memberSince = _usuario?.fechaCreacion.isNotEmpty == true ? _usuario!.fechaCreacion.substring(0, 4) : '2026';
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.accentBlue,
          child: Text(
            firstName.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_usuario?.name ?? ''} ${_usuario?.surname ?? ''}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Miembro desde $memberSince',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildObjectiveForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Objetivos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_formError != null) ...[
              Text(_formError!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _objetivoPercentageController,
              decoration: const InputDecoration(
                labelText: 'Objetivo de grasa (%)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _objetivoPesoController,
              decoration: const InputDecoration(
                labelText: 'Objetivo de peso',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _savingObjectives ? null : _saveObjectives,
              child: _savingObjectives ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar objetivos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green.shade700,
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rutina actual', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('Full Body Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Text('4 días / semana · Fuerza y definición', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap ?? () {},
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: AppColors.bg2,
      leading: Icon(icon, color: AppColors.accentBlue),
      title: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
      ),
    );
  }

  Future<void> _saveObjectives() async {
    setState(() {
      _savingObjectives = true;
      _formError = null;
    });

    try {
      final usuario = await _apiService.actualizarUsuarioObjetivos(
        widget.userId,
        _objetivoPercentageController.text.trim(),
        _objetivoPesoController.text.trim(),
      );
      setState(() {
        _usuario = usuario;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Objetivos guardados correctamente')));
      }
    } catch (e) {
      setState(() {
        _formError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingObjectives = false;
        });
      }
    }
  }

  void _openCreateRoutine() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateRoutineScreen(userId: widget.userId),
      ),
    );
  }

  @override
  void dispose() {
    _objetivoPercentageController.dispose();
    _objetivoPesoController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () {
            Navigator.of(context).pop();
            widget.onLogout();
          }, child: const Text('Salir')),
        ],
      ),
    );
  }
}
