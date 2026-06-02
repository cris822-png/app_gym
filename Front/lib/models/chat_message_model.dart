/// Mensaje en la interfaz de chat con el coach IA.
class ChatMessageModel {
  final String rol;    // 'user' | 'assistant'
  final String texto;
  final DateTime timestamp;

  ChatMessageModel({
    required this.rol,
    required this.texto,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get esUsuario => rol == 'user';
}
