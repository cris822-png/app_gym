import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/chat_message_model.dart';
import '../providers/workout_provider.dart';
import '../services/api_service.dart';

/// Pantalla completa del chat IA (tab de la BottomNavigationBar).
/// Diferente del overlay: aquí el usuario puede chatear sin un entreno activo,
/// con historial completo y sugerencias generales.
class ChatScreen extends StatefulWidget {
  final int userId;

  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final List<ChatMessageModel> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _listCtrl = ScrollController();
  bool _isLoading = false;

  static const _sugerencias = [
    '¿Cuántas calorías he comido hoy?',
    '¿Qué debo entrenar hoy?',
    'Estima mis macros de hoy',
    '¿Cómo progreso más rápido?',
    '¿Coído suficiente proteína?',
    'Analiza mi progreso',
  ];

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;

    // Si hay un entreno activo, incluir su contexto
    Map<String, dynamic> contexto = {};
    try {
      final provider = context.read<WorkoutProvider>();
      if (provider.activo) {
        contexto = provider.buildContextoParaChat();
      }
    } catch (_) {}

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
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.accentPurple, size: 18),
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
                Consumer<WorkoutProvider>(
                  builder: (_, p, __) => Text(
                    p.activo
                        ? '⏱ Entreno activo — ${p.duracionFormateada}'
                        : 'Tu entrenador personal',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Badge "En vivo" si hay entreno activo
          Consumer<WorkoutProvider>(
            builder: (_, p, __) => p.activo
                ? Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 7, color: AppColors.accentGreen),
                        SizedBox(width: 4),
                        Text('En vivo',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),

      body: Column(
        children: [
          const Divider(height: 1, color: AppColors.bg3),

          // ── Mensajes ────────────────────────────────────────────────────
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

          // ── Chips rápidos ─────────────────────────────────────────────
          if (_messages.isNotEmpty)
            SizedBox(
              height: 46,
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

          // ── Input bar (zona del pulgar) ─────────────────────────────
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
                                  AppColors.accentBlue,
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

// ── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Function(String) onSugerencia;
  const _EmptyState({required this.onSugerencia});

  static const _sugerencias = [
    '¿Cuántas calorías he comido hoy?',
    'Estima mis macros de hoy',
    '¿Qué debo entrenar hoy?',
    '¿Coído suficiente proteína?',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentPurple, AppColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Tu Coach IA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
                'Pregúntame sobre entrenamiento, nutrición\no técnica. Conozco tu historial completo.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textMuted, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
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
                                color:
                                    AppColors.accentPurple.withValues(alpha: 0.3)),
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
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
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
    );
  }
}

// ── Indicador "escribiendo…" ──────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 150),
            SizedBox(width: 4),
            _Dot(delay: 300),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
