class Journal {
  final String id;
  final String userId;
  final String title;
  final String content;
  final List<String> tags;
  final String mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  Journal({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.tags,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Journal.fromMap(String id, Map<String, dynamic> map) {
    return Journal(
      id: id,
      userId: map['userId'],
      title: map['title'],
      content: map['content'],
      tags: List<String>.from(map['tags'] ?? []),
      mood: map['mood'],
      createdAt: map['createdAt'].toDate(),
      updatedAt: map['updatedAt'].toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'tags': tags,
      'mood': mood,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
