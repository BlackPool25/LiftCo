// lib/models/chat_message.dart
class ChatMessage {
  final String id;
  final String sessionId;
  final String? userId;
  final String content;
  final String type;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String?,
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
