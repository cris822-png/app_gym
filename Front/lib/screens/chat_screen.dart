import 'package:flutter/material.dart';

import '../models/coach_recommendation.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int userId;

  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  String? _error;
  CoachRecommendation? _recommendation;
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendation();
  }

  Future<void> _loadRecommendation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recommendation = await _apiService.getCoachRecommendation(widget.userId);
      setState(() {
        _recommendation = recommendation;
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

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _messages.add({'sender': 'ai', 'text': _recommendation?.mensaje ?? 'Cargando recomendación...'});
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenador IA'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_recommendation != null) _CoachRecommendationCard(recommendation: _recommendation!),
                          const SizedBox(height: 12),
                          ..._messages.map((message) {
                            if (message['sender'] == 'user') {
                              return _UserBubble(text: message['text']!);
                            }
                            return _AiBubble(text: message['text']!);
                          }).toList(),
                        ],
                      ),
          ),
          _Composer(controller: _controller, onSend: _sendMessage),
        ],
      ),
    );
  }
}

class _CoachRecommendationCard extends StatelessWidget {
  final CoachRecommendation recommendation;

  const _CoachRecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recomendación directa', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(recommendation.mensaje),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Aplicar')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () {}, child: const Text('Guardar')),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
        child: Text(text),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final String text;

  const _AiBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: Text(text),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(onPressed: onSend, mini: true, child: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}
