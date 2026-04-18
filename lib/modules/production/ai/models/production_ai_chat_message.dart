/// Jedna poruka u razgovoru s Operativnim asistentom (pregled + puni ekran dijele istu povijest).
class ProductionAiChatMessage {
  const ProductionAiChatMessage._({
    required this.text,
    required this.isUser,
    required this.isError,
  });

  const ProductionAiChatMessage.user(String text)
      : this._(text: text, isUser: true, isError: false);

  const ProductionAiChatMessage.assistant(String text)
      : this._(text: text, isUser: false, isError: false);

  const ProductionAiChatMessage.error(String text)
      : this._(text: text, isUser: false, isError: true);

  final String text;
  final bool isUser;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'role': isUser
            ? 'user'
            : (isError ? 'error' : 'assistant'),
        'text': text,
      };

  factory ProductionAiChatMessage.fromJson(Map<String, dynamic> m) {
    final role = (m['role'] ?? '').toString();
    final text = (m['text'] ?? '').toString();
    switch (role) {
      case 'user':
        return ProductionAiChatMessage.user(text);
      case 'error':
        return ProductionAiChatMessage.error(text);
      default:
        return ProductionAiChatMessage.assistant(text);
    }
  }
}
