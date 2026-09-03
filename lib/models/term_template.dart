class TermTemplate {
  final String id;
  final String termName; // "Term 1", "Term 2", "Term 3"
  final int year;
  final int defaultWeeks;
  final int defaultLessonsPerWeek;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? halfTermStart;
  final DateTime? halfTermEnd;

  TermTemplate({
    required this.id,
    required this.termName,
    required this.year,
    this.defaultWeeks = 12,
    this.defaultLessonsPerWeek = 5,
    this.startDate,
    this.endDate,
    this.halfTermStart,
    this.halfTermEnd,
  });

  factory TermTemplate.fromJson(Map<String, dynamic> json) {
    return TermTemplate(
      id: json['id'] as String,
      termName: json['term_name'] as String,
      year: json['year'] as int? ?? DateTime.now().year,
      defaultWeeks: json['default_weeks'] as int? ?? 12,
      defaultLessonsPerWeek: json['default_lessons_per_week'] as int? ?? 5,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      halfTermStart: json['half_term_start'] != null ? DateTime.tryParse(json['half_term_start']) : null,
      halfTermEnd: json['half_term_end'] != null ? DateTime.tryParse(json['half_term_end']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'term_name': termName,
      'year': year,
      'default_weeks': defaultWeeks,
      'default_lessons_per_week': defaultLessonsPerWeek,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'half_term_start': halfTermStart?.toIso8601String(),
      'half_term_end': halfTermEnd?.toIso8601String(),
    };
  }
}
