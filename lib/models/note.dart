class Note {
  final int id;
  final String note;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.note,
    required this.createdAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['note_id'] as int,
      note: map['note'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
