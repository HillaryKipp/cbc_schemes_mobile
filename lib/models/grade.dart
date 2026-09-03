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

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as String?,
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
