class Subject {
  final String id;
  final String gradeId;
  final String name; // e.g. "Mathematics", "English Language", "Integrated Science"
  final String? code;
  final int orderIndex;

  Subject({
    required this.id,
    required this.gradeId,
    required this.name,
    this.code,
    this.orderIndex = 0,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      gradeId: json['grade_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade_id': gradeId,
      'name': name,
      'code': code,
      'order_index': orderIndex,
    };
  }
}
