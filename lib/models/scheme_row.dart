import 'dart:convert';

enum MilestoneType { halfTerm, assessment }

class SchemeRow {
  final String id;
  final String? schemeId;
  int weekNumber;
  int lessonNumber;
  String? strandId;
  String? subStrandId;
  String? customStrand;
  String? customSubStrand;
  List<String>? customOutcomes;
  List<String>? customQuestions;
  List<String>? customExperiences;
  List<String>? customResources;
  List<String>? customAssessments;

  String strandName;
  String subStrandName;

  List<String> learningOutcomeIds;
  List<String> keyInquiryQuestionIds;
  List<String> learningExperienceIds;
  List<String> learningResourceIds;
  List<String> assessmentMethodIds;

  List<String> learningOutcomes;
  List<String> keyInquiryQuestions;
  List<String> learningExperiences;
  List<String> learningResources;
  List<String> assessmentMethods;

  String reflections;
  int position;
  MilestoneType? milestoneType;
  Map<String, dynamic> customOverrides;

  SchemeRow({
    required this.id,
    this.schemeId,
    required this.weekNumber,
    required this.lessonNumber,
    this.strandId,
    this.subStrandId,
    this.customStrand,
    this.customSubStrand,
    this.customOutcomes,
    this.customQuestions,
    this.customExperiences,
    this.customResources,
    this.customAssessments,
    this.strandName = '',
    this.subStrandName = '',
    this.learningOutcomeIds = const [],
    this.keyInquiryQuestionIds = const [],
    this.learningExperienceIds = const [],
    this.learningResourceIds = const [],
    this.assessmentMethodIds = const [],
    this.learningOutcomes = const [],
    this.keyInquiryQuestions = const [],
    this.learningExperiences = const [],
    this.learningResources = const [],
    this.assessmentMethods = const [],
    this.reflections = '',
    required this.position,
    this.milestoneType,
    this.customOverrides = const {},
  });

  bool get isMilestone => milestoneType != null;

  String get milestoneBannerText {
    if (milestoneType == MilestoneType.halfTerm) {
      return 'HALF TERM BREAK — WEEK $weekNumber';
    } else if (milestoneType == MilestoneType.assessment) {
      return 'END OF TERM ASSESSMENT & REVISION — WEEK $weekNumber';
    }
    return '';
  }

  factory SchemeRow.fromJson(Map<String, dynamic> json) {
    MilestoneType? mType;
    final rawMType = json['milestone_type']?.toString();
    if (rawMType == 'half_term' || rawMType == 'halfTerm') {
      mType = MilestoneType.halfTerm;
    } else if (rawMType == 'assessment') {
      mType = MilestoneType.assessment;
    }

    return SchemeRow(
      id: json['id'] as String,
      schemeId: json['scheme_id'] as String?,
      weekNumber: json['week_number'] as int? ?? 1,
      lessonNumber: json['lesson_number'] as int? ?? 1,
      strandId: json['strand_id'] as String?,
      subStrandId: json['sub_strand_id'] as String?,
      customStrand: json['custom_strand'] as String?,
      customSubStrand: json['custom_sub_strand'] as String?,
      customOutcomes: _parseNullableList(json['custom_outcomes']),
      customQuestions: _parseNullableList(json['custom_questions']),
      customExperiences: _parseNullableList(json['custom_experiences']),
      customResources: _parseNullableList(json['custom_resources']),
      customAssessments: _parseNullableList(json['custom_assessments']),
      strandName: (json['strand_name'] ?? json['strand'] ?? json['custom_strand']) as String? ?? '',
      subStrandName: (json['sub_strand_name'] ?? json['sub_strand'] ?? json['custom_sub_strand']) as String? ?? '',
      learningOutcomeIds: _parseList(json['learning_outcome_ids']),
      keyInquiryQuestionIds: _parseList(json['key_inquiry_question_ids']),
      learningExperienceIds: _parseList(json['learning_experience_ids']),
      learningResourceIds: _parseList(json['learning_resource_ids']),
      assessmentMethodIds: _parseList(json['assessment_method_ids']),
      learningOutcomes: _parseList(json['learning_outcomes'] ?? json['specific_learning_outcomes'] ?? json['custom_outcomes']),
      keyInquiryQuestions: _parseList(json['key_inquiry_questions'] ?? json['custom_questions']),
      learningExperiences: _parseList(json['learning_experiences'] ?? json['custom_experiences']),
      learningResources: _parseList(json['learning_resources'] ?? json['custom_resources']),
      assessmentMethods: _parseList(json['assessment_methods'] ?? json['custom_assessments']),
      reflections: json['reflections'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      milestoneType: mType,
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

  static List<String>? _parseNullableList(dynamic val) {
    if (val == null) return null;
    final list = _parseList(val);
    return list.isNotEmpty ? list : null;
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
      'strand_id': strandId,
      'sub_strand_id': subStrandId,
      if (customStrand != null) 'custom_strand': customStrand,
      if (customSubStrand != null) 'custom_sub_strand': customSubStrand,
      if (customOutcomes != null) 'custom_outcomes': customOutcomes,
      if (customQuestions != null) 'custom_questions': customQuestions,
      if (customExperiences != null) 'custom_experiences': customExperiences,
      if (customResources != null) 'custom_resources': customResources,
      if (customAssessments != null) 'custom_assessments': customAssessments,
      'strand_name': strandName,
      'sub_strand_name': subStrandName,
      'learning_outcome_ids': learningOutcomeIds,
      'key_inquiry_question_ids': keyInquiryQuestionIds,
      'learning_experience_ids': learningExperienceIds,
      'learning_resource_ids': learningResourceIds,
      'assessment_method_ids': assessmentMethodIds,
      'learning_outcomes': learningOutcomes,
      'key_inquiry_questions': keyInquiryQuestions,
      'learning_experiences': learningExperiences,
      'learning_resources': learningResources,
      'assessment_methods': assessmentMethods,
      'reflections': reflections,
      'position': position,
      'milestone_type': milestoneType == MilestoneType.halfTerm
          ? 'half_term'
          : milestoneType == MilestoneType.assessment
              ? 'assessment'
              : null,
      'custom_overrides': customOverrides,
    };
  }

  /// Exact payload format for Postgres scheme_rows table
  Map<String, dynamic> toPostgresPayload(String parentSchemeId) {
    return {
      'id': id,
      'scheme_id': parentSchemeId,
      'week_number': weekNumber,
      'lesson_number': lessonNumber,
      'strand_id': strandId,
      'sub_strand_id': subStrandId,
      'custom_strand': customStrand,
      'custom_sub_strand': customSubStrand,
      'custom_outcomes': customOutcomes,
      'custom_questions': customQuestions,
      'custom_experiences': customExperiences,
      'custom_resources': customResources,
      'custom_assessments': customAssessments,
      'learning_outcome_ids': learningOutcomeIds,
      'key_inquiry_question_ids': keyInquiryQuestionIds,
      'learning_experience_ids': learningExperienceIds,
      'learning_resource_ids': learningResourceIds,
      'assessment_method_ids': assessmentMethodIds,
      'reflections': reflections,
      'position': position,
      'milestone_type': milestoneType == MilestoneType.halfTerm
          ? 'half_term'
          : milestoneType == MilestoneType.assessment
              ? 'assessment'
              : null,
    };
  }

  SchemeRow copyWith({
    String? id,
    String? schemeId,
    int? weekNumber,
    int? lessonNumber,
    String? strandId,
    String? subStrandId,
    String? customStrand,
    String? customSubStrand,
    List<String>? customOutcomes,
    List<String>? customQuestions,
    List<String>? customExperiences,
    List<String>? customResources,
    List<String>? customAssessments,
    String? strandName,
    String? subStrandName,
    List<String>? learningOutcomeIds,
    List<String>? keyInquiryQuestionIds,
    List<String>? learningExperienceIds,
    List<String>? learningResourceIds,
    List<String>? assessmentMethodIds,
    List<String>? learningOutcomes,
    List<String>? keyInquiryQuestions,
    List<String>? learningExperiences,
    List<String>? learningResources,
    List<String>? assessmentMethods,
    String? reflections,
    int? position,
    MilestoneType? milestoneType,
    Map<String, dynamic>? customOverrides,
  }) {
    return SchemeRow(
      id: id ?? this.id,
      schemeId: schemeId ?? this.schemeId,
      weekNumber: weekNumber ?? this.weekNumber,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      strandId: strandId ?? this.strandId,
      subStrandId: subStrandId ?? this.subStrandId,
      customStrand: customStrand ?? this.customStrand,
      customSubStrand: customSubStrand ?? this.customSubStrand,
      customOutcomes: customOutcomes ?? this.customOutcomes,
      customQuestions: customQuestions ?? this.customQuestions,
      customExperiences: customExperiences ?? this.customExperiences,
      customResources: customResources ?? this.customResources,
      customAssessments: customAssessments ?? this.customAssessments,
      strandName: strandName ?? this.strandName,
      subStrandName: subStrandName ?? this.subStrandName,
      learningOutcomeIds: learningOutcomeIds ?? List.from(this.learningOutcomeIds),
      keyInquiryQuestionIds: keyInquiryQuestionIds ?? List.from(this.keyInquiryQuestionIds),
      learningExperienceIds: learningExperienceIds ?? List.from(this.learningExperienceIds),
      learningResourceIds: learningResourceIds ?? List.from(this.learningResourceIds),
      assessmentMethodIds: assessmentMethodIds ?? List.from(this.assessmentMethodIds),
      learningOutcomes: learningOutcomes ?? List.from(this.learningOutcomes),
      keyInquiryQuestions: keyInquiryQuestions ?? List.from(this.keyInquiryQuestions),
      learningExperiences: learningExperiences ?? List.from(this.learningExperiences),
      learningResources: learningResources ?? List.from(this.learningResources),
      assessmentMethods: assessmentMethods ?? List.from(this.assessmentMethods),
      reflections: reflections ?? this.reflections,
      position: position ?? this.position,
      milestoneType: milestoneType ?? this.milestoneType,
      customOverrides: customOverrides ?? Map.from(this.customOverrides),
    );
  }
}
