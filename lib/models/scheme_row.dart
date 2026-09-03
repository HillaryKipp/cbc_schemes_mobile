import 'dart:convert';

class SchemeRow {
  final String id;
  final String? schemeId;
  int weekNumber;
  int lessonNumber;
  String strandName;
  String subStrandName;
  List<String> learningOutcomes;
  List<String> keyInquiryQuestions;
  List<String> learningExperiences;
  List<String> learningResources;
  List<String> assessmentMethods;
  String reflections;
  int position;
  Map<String, dynamic> customOverrides;

  SchemeRow({
    required this.id,
    this.schemeId,
    required this.weekNumber,
    required this.lessonNumber,
    required this.strandName,
    required this.subStrandName,
    required this.learningOutcomes,
    required this.keyInquiryQuestions,
    required this.learningExperiences,
    required this.learningResources,
    required this.assessmentMethods,
    this.reflections = '',
    required this.position,
    this.customOverrides = const {},
  });

  factory SchemeRow.fromJson(Map<String, dynamic> json) {
    return SchemeRow(
      id: json['id'] as String,
      schemeId: json['scheme_id'] as String?,
      weekNumber: json['week_number'] as int? ?? 1,
      lessonNumber: json['lesson_number'] as int? ?? 1,
      strandName: (json['strand_name'] ?? json['strand']) as String? ?? '',
      subStrandName: (json['sub_strand_name'] ?? json['sub_strand']) as String? ?? '',
      learningOutcomes: _parseList(json['learning_outcomes'] ?? json['specific_learning_outcomes']),
      keyInquiryQuestions: _parseList(json['key_inquiry_questions']),
      learningExperiences: _parseList(json['learning_experiences']),
      learningResources: _parseList(json['learning_resources']),
      assessmentMethods: _parseList(json['assessment_methods']),
      reflections: json['reflections'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      customOverrides: _parseMap(json['custom_overrides']),
    );
  }

  static List<String> _parseList(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) {
      if (val.trim().isEmpty) return [];
      try {
        final decoded = jsonDecode(val);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [val];
      }
      return [val];
    }
    return [];
  }

  static Map<String, dynamic> _parseMap(dynamic val) {
    if (val == null) return {};
    if (val is Map<String, dynamic>) return val;
    if (val is String && val.isNotEmpty) {
      try {
        return jsonDecode(val) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (schemeId != null) 'scheme_id': schemeId,
      'week_number': weekNumber,
      'lesson_number': lessonNumber,
      'strand_name': strandName,
      'sub_strand_name': subStrandName,
      'learning_outcomes': learningOutcomes,
      'key_inquiry_questions': keyInquiryQuestions,
      'learning_experiences': learningExperiences,
      'learning_resources': learningResources,
      'assessment_methods': assessmentMethods,
      'reflections': reflections,
      'position': position,
      'custom_overrides': customOverrides,
    };
  }

  SchemeRow copyWith({
    String? id,
    String? schemeId,
    int? weekNumber,
    int? lessonNumber,
    String? strandName,
    String? subStrandName,
    List<String>? learningOutcomes,
    List<String>? keyInquiryQuestions,
    List<String>? learningExperiences,
    List<String>? learningResources,
    List<String>? assessmentMethods,
    String? reflections,
    int? position,
    Map<String, dynamic>? customOverrides,
  }) {
    return SchemeRow(
      id: id ?? this.id,
      schemeId: schemeId ?? this.schemeId,
      weekNumber: weekNumber ?? this.weekNumber,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      strandName: strandName ?? this.strandName,
      subStrandName: subStrandName ?? this.subStrandName,
      learningOutcomes: learningOutcomes ?? List.from(this.learningOutcomes),
      keyInquiryQuestions: keyInquiryQuestions ?? List.from(this.keyInquiryQuestions),
      learningExperiences: learningExperiences ?? List.from(this.learningExperiences),
      learningResources: learningResources ?? List.from(this.learningResources),
      assessmentMethods: assessmentMethods ?? List.from(this.assessmentMethods),
      reflections: reflections ?? this.reflections,
      position: position ?? this.position,
      customOverrides: customOverrides ?? Map.from(this.customOverrides),
    );
  }
}
