class Grade {
  final String id;
  final String name; // e.g. "Grade 1", "Grade 7", "PP1"
  final String? level; // e.g. "Pre-Primary", "Lower Primary", "Upper Primary", "Junior School"
  final int orderIndex;

  Grade({
    required this.id,
    required this.name,
    this.level,
    this.orderIndex = 0,
  });

  String get displayLevel {
    if (level != null && level!.isNotEmpty) return level!;
    return inferLevelFromName(name);
  }

  static String inferLevelFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pp') || lower.contains('pre')) return 'Pre-Primary';
    if (lower.contains('grade 1') || lower.contains('grade 2') || lower.contains('grade 3')) {
      return 'Lower Primary';
    }
    if (lower.contains('grade 4') || lower.contains('grade 5') || lower.contains('grade 6')) {
      return 'Upper Primary';
    }
    if (lower.contains('grade 7') || lower.contains('grade 8') || lower.contains('grade 9')) {
      return 'Junior School';
    }
    return 'Primary School';
  }

  factory Grade.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final rawLevel = json['level'] as String?;
    final level = (rawLevel != null && rawLevel.isNotEmpty)
        ? rawLevel
        : inferLevelFromName(name);
    return Grade(
      id: json['id'] as String,
      name: name,
      level: level,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'order_index': orderIndex,
    };
  }
}
