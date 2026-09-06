import 'package:cloud_firestore/cloud_firestore.dart';

/// One message in the AI assistant conversation.
///
/// Stored at: users/{uid}/chatHistory/{messageId}
class ChatMessageModel {
  const ChatMessageModel({
    required this.messageId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions = const [],
  });

  final String messageId;

  /// "user" or "assistant"
  final String role;

  final String content;
  final DateTime timestamp;

  /// Optional follow-up question chips attached to assistant messages.
  final List<String> suggestedActions;

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      messageId: map['messageId'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      content: map['content'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      suggestedActions:
          List<String>.from(map['suggestedActions'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'role': role,
        'content': content,
        'timestamp': Timestamp.fromDate(timestamp),
        'suggestedActions': suggestedActions,
      };
}
