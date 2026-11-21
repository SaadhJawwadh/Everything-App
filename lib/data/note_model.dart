

class Note {
  final String id;
  String title;
  String content;
  DateTime dateCreated;
  DateTime dateModified;
  int color;
  bool isPinned;
  bool isArchived;
  String? imagePath;
  String category;
  List<String> tags; // New field
  String? previewText;
  DateTime? deletedAt;
  DateTime? reminderAt;
  bool isLocked;
  String? searchText;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.dateCreated,
    required this.dateModified,
    this.color = 0xFF252529,
    this.isPinned = false,
    this.isArchived = false,
    this.imagePath,
    this.category = 'All Notes',
    this.tags = const [], // Default empty list
    this.previewText,
    this.deletedAt,
    this.reminderAt,
    this.isLocked = false,
    this.searchText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'dateCreated': dateCreated.toIso8601String(),
      'dateModified': dateModified.toIso8601String(),
      'color': color,
      'isPinned': isPinned ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'imagePath': imagePath,
      'category': category,
      'previewText': previewText,
      'deletedAt': deletedAt?.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'isLocked': isLocked ? 1 : 0,
      'searchText': searchText,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      dateCreated: map['dateCreated'] != null ? DateTime.tryParse(map['dateCreated'].toString()) ?? DateTime.now() : DateTime.now(),
      dateModified: map['dateModified'] != null ? DateTime.tryParse(map['dateModified'].toString()) ?? DateTime.now() : DateTime.now(),
      color: map['color'] ?? 0xFF252529,
      isPinned: map['isPinned'] == 1 || map['isPinned'] == true,
      isArchived: map['isArchived'] == 1 || map['isArchived'] == true,
      imagePath: map['imagePath'],
      category: map['category'] ?? 'All Notes',
      tags: [], // Tags will be populated by DatabaseHelper
      previewText: map['previewText'],
      deletedAt:
          map['deletedAt'] != null ? DateTime.tryParse(map['deletedAt'].toString()) : null,
      reminderAt:
          map['reminderAt'] != null ? DateTime.tryParse(map['reminderAt'].toString()) : null,
      isLocked: map['isLocked'] == 1 || map['isLocked'] == true,
      searchText: map['searchText'],
    );
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? dateModified,
    int? color,
    bool? isPinned,
    bool? isArchived,
    String? imagePath,
    String? category,
    List<String>? tags,
    String? previewText,
    DateTime? deletedAt,
    DateTime? reminderAt,
    bool? isLocked,
    String? searchText,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      dateCreated: dateCreated,
      dateModified: dateModified ?? this.dateModified,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      previewText: previewText ?? this.previewText,
      deletedAt: deletedAt ?? this.deletedAt,
      reminderAt: reminderAt ?? this.reminderAt,
      isLocked: isLocked ?? this.isLocked,
      searchText: searchText ?? this.searchText,
    );
  }
}
