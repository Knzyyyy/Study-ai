class ChatSession {
  final String id;
  final String title;
  final DateTime? date;

  ChatSession({required this.id, required this.title, this.date});

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String,
    date: DateTime.tryParse(json['last_message_at'] ?? ''),
  );
}

class ChatMessage {
  final String role; // 'user' atau 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
    );
  }

  // Helper untuk mempermudah update pesan streaming
  ChatMessage copyWith({String? content}) {
    return ChatMessage(role: role, content: content ?? this.content);
  }
}
