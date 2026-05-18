import 'package:flutter/material.dart';

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
  bool _loading = true;
  String? _error;
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
    });

    try {
      final usuario = await _apiService.getUsuario(1);
      setState(() => _usuario = usuario);
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 20),
                      _buildInfoCard('Email', _usuario?.email ?? '-'),
                      const SizedBox(height: 12),
                      _buildInfoCard('Peso', '${_usuario?.peso.toStringAsFixed(1)} kg'),
                      const SizedBox(height: 12),
                      _buildInfoCard('Altura', '${_usuario?.altura.toStringAsFixed(0)} cm'),
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
          backgroundColor: Colors.green.shade700,
          child: Text(firstName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_usuario?.name ?? ''} ${_usuario?.surname ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Miembro desde $memberSince', style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ],
    );
  }

  Widget _buildRoutineSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green.shade700,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
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
            Text(title, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap ?? () {},
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Colors.grey.shade100,
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  void _openCreateRoutine() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateRoutineScreen()));
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
