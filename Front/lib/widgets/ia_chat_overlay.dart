import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/chat_message_model.dart';
import '../providers/workout_provider.dart';
import '../services/api_service.dart';

/// Panel inferior de chat con el coach IA.
/// Se abre como DraggableScrollableSheet sin abandonar la pantalla de entreno.
/// Recibe el contexto del entreno en tiempo real desde WorkoutProvider.
class IaChatOverlay extends StatefulWidget {
  final int userId;
  final ScrollController scrollController;

  const IaChatOverlay({
    super.key,
    required this.userId,
    required this.scrollController,
  });

  @override
  State<IaChatOverlay> createState() => _IaChatOverlayState();
}

class _IaChatOverlayState extends State<IaChatOverlay> {
  final ApiService _api = ApiService();
  final List<ChatMessageModel> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _listCtrl = ScrollController();
  bool _isLoading = false;

  // Chips de sugerencias rápidas
  static const _sugerencias = [
    '¿Cómo sustituyo este ejercicio?',
    '¿Subo el peso hoy?',
    '¿Cuánto descanso me queda?',
    'Corrige mi técnica',
    '¿Qué músculo trabaja esto?',
  ];

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;

    final contexto =
        context.read<WorkoutProvider>().buildContextoParaChat();

    setState(() {
      _messages.add(ChatMessageModel(rol: 'user', texto: msg));
      _isLoading = true;
      _inputCtrl.clear();
    });

    _scrollToBottom();

    try {
      final respuesta = await _api.chatIa(
        userId: widget.userId,
        mensaje: msg,
        contextoEntreno: contexto,
      );
      setState(() {
        _messages.add(ChatMessageModel(rol: 'assistant', texto: respuesta));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessageModel(
          rol: 'assistant',
          texto: 'Error al conectar con el coach. Revisa tu conexión.',
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listCtrl.hasClients) {
        _listCtrl.animateTo(
          _listCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.bg3, width: 1)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: AppColors.accentPurple, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Coach IA',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    // Estado del entreno en tiempo real
                    Consumer<WorkoutProvider>(
                      builder: (_, p, __) => Text(
                        p.activo
                            ? '⏱ ${p.duracionFormateada} — ${p.ejercicios.length} ejercicios'
                            : 'Sin entreno activo',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Badge "En vivo"
                Consumer<WorkoutProvider>(
                  builder: (_, p, __) => AnimatedOpacity(
                    opacity: p.activo ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 6, color: AppColors.accentGreen),
                          SizedBox(width: 4),
                          Text('En vivo',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.bg3),

          // ── Lista de mensajes ────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(onSugerencia: _sendMessage)
                : ListView.builder(
                    controller: _listCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _ChatBubble(message: _messages[i]);
                    },
                  ),
          ),

          // ── Chips de sugerencias (solo cuando hay mensajes) ──────────────
          if (_messages.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _sugerencias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _sendMessage(_sugerencias[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentPurple.withValues(alpha: 0.25)),
                    ),
                    child: Text(_sugerencias[i],
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ),

          // ── Barra de input (zona del pulgar) ─────────────────────────────
          SafeArea(
            top: false,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(color: AppColors.bg2),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: const InputDecoration(
                        hintText: 'Pregunta al coach...',
                        filled: true,
                        fillColor: AppColors.bg3,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide(
                              color: AppColors.accentPurple, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(_inputCtrl.text),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isLoading
                              ? [AppColors.bg3, AppColors.bg3]
                              : [
                                  AppColors.accentPurple,
                                  AppColors.accentBlue
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío con chips de sugerencias ────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Function(String) onSugerencia;
  const _EmptyState({required this.onSugerencia});

  static const _sugerencias = [
    '¿Cómo sustituyo este ejercicio?',
    '¿Subo el peso hoy?',
    '¿Cuánto descanso me queda?',
    'Corrige mi técnica',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome,
              color: AppColors.accentPurple, size: 40),
          const SizedBox(height: 12),
          const Text('¿En qué te puedo ayudar?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
              'El coach conoce tu entreno en tiempo real.\nPregúntale lo que necesites.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _sugerencias
                .map((s) => GestureDetector(
                      onTap: () => onSugerencia(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.accentPurple.withValues(alpha: 0.3)),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final esUsuario = message.esUsuario;

    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: esUsuario
              ? const LinearGradient(
                  colors: [AppColors.accentBlue, Color(0xFF2D7AEF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: esUsuario ? null : AppColors.bg3,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(esUsuario ? 18 : 4),
            bottomRight: Radius.circular(esUsuario ? 4 : 18),
          ),
        ),
        child: Text(
          message.texto,
          style: TextStyle(
            color: esUsuario ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms)
        .slideX(
            begin: esUsuario ? 0.15 : -0.15,
            end: 0,
            duration: 220.ms,
            curve: Curves.easeOutCubic);
  }
}

// ── Indicador de "escribiendo…" ───────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                color: AppColors.textMuted, shape: BoxShape.circle),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleY(
                    begin: 0.4,
                    end: 1.0,
                    duration: 500.ms,
                    delay: Duration(milliseconds: i * 150),
                    curve: Curves.easeInOut)
                .then()
                .scaleY(begin: 1.0, end: 0.4, duration: 500.ms),
          ),
        ),
      ),
    );
  }
}
