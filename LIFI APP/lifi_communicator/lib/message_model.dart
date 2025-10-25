class Message {
  final String content;
  final bool isSent;
  final DateTime timestamp;
  final String encryptedContent;

  Message({
    required this.content,
    required this.isSent,
    required this.timestamp,
    required this.encryptedContent,
  });
}
