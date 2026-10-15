class JournalMessage {
  final String id;
  final String journalId;
  final String role; // 'user' or 'ai'
  final String content;
  final DateTime createdAt;

  JournalMessage({
    required this.id,
    required this.journalId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory JournalMessage.fromMap(String id, Map<String, dynamic> map) {
    return JournalMessage(
      id: id,
      journalId: map['journalId'],
      role: map['role'],
      content: map['content'],
      createdAt: map['createdAt'].toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'journalId': journalId,
      'role': role,
      'content': content,
      'createdAt': createdAt,
    };
  }
}
