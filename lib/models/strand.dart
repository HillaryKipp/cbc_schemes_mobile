class Strand {
  final String id;
  final String subjectId;
  final String name; // e.g. "Numbers", "Listening and Speaking"
  final int orderIndex;
  final List<SubStrand> subStrands;

  Strand({
    required this.id,
    required this.subjectId,
    required this.name,
    this.orderIndex = 0,
    this.subStrands = const [],
  });

  factory Strand.fromJson(Map<String, dynamic> json, {List<SubStrand> subStrands = const []}) {
    return Strand(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      name: json['name'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      subStrands: subStrands,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'name': name,
      'order_index': orderIndex,
    };
  }
}

class SubStrand {
  final String id;
  final String strandId;
  final String name; // e.g. "Number concept", "Whole numbers"
  final int suggestedLessons; // Number of slots this sub-strand occupies
  final int orderIndex;

  SubStrand({
    required this.id,
    required this.strandId,
    required this.name,
    this.suggestedLessons = 3,
    this.orderIndex = 0,
  });

  factory SubStrand.fromJson(Map<String, dynamic> json) {
    return SubStrand(
      id: json['id'] as String,
      strandId: json['strand_id'] as String,
      name: json['name'] as String,
      suggestedLessons: json['suggested_lessons'] as int? ?? 3,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'strand_id': strandId,
      'name': name,
      'suggested_lessons': suggestedLessons,
      'order_index': orderIndex,
    };
  }
}
