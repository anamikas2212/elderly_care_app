class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? sentiment;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sentiment,
  });

  // Add these helper methods for database storage
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'sentiment': sentiment,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: DateTime.parse(map['timestamp']),
      sentiment: map['sentiment'],
    );
  }
}
