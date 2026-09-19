import 'scheme.dart';
import 'scheme_row.dart';

class BundleTermInfo {
  final int termNumber; // 1, 2, or 3
  final String schemeId;
  final String termName;

  BundleTermInfo({
    required this.termNumber,
    required this.schemeId,
    required this.termName,
  });

  Map<String, dynamic> toMap() => {
    'termNumber': termNumber,
    'schemeId': schemeId,
    'termName': termName,
  };

  factory BundleTermInfo.fromMap(Map<String, dynamic> map) => BundleTermInfo(
    termNumber: (map['termNumber'] ?? map['term_number'] ?? 1) as int,
    schemeId: (map['schemeId'] ?? map['scheme_id'] ?? '') as String,
    termName: (map['termName'] ?? map['term_name'] ?? 'Term 1') as String,
  );

  Map<String, dynamic> toJson() => toMap();
  factory BundleTermInfo.fromJson(Map<String, dynamic> json) => BundleTermInfo.fromMap(json);
}

class GuestRow {
  final String id; // e.g. "guest-<uuid>-r0"
  final int weekNumber;
  final int lessonNumber;
  final String? strandId;
  final String? subStrandId;
  final String? customStrand;
  final String? customSubStrand;
  final List<String>? customOutcomes;
  final List<String>? customQuestions;
  final List<String>? customExperiences;
  final List<String>? customResources;
  final List<String>? customAssessments;
  final List<String> learningOutcomeIds;
  final List<String> keyInquiryQuestionIds;
  final List<String> learningExperienceIds;
  final List<String> learningResourceIds;
  final List<String> assessmentMethodIds;
  final String reflections;
  final int position;
  final MilestoneType? milestoneType;

  // Cached display strings for seamless offline rendering
  final String strandName;
  final String subStrandName;
  final List<String> learningOutcomes;
  final List<String> keyInquiryQuestions;
  final List<String> learningExperiences;
  final List<String> learningResources;
  final List<String> assessmentMethods;

  GuestRow({
    required this.id,
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
    this.learningOutcomeIds = const [],
    this.keyInquiryQuestionIds = const [],
    this.learningExperienceIds = const [],
    this.learningResourceIds = const [],
    this.assessmentMethodIds = const [],
    this.reflections = '',
    required this.position,
    this.milestoneType,
    this.strandName = '',
    this.subStrandName = '',
    this.learningOutcomes = const [],
    this.keyInquiryQuestions = const [],
    this.learningExperiences = const [],
    this.learningResources = const [],
    this.assessmentMethods = const [],
  });

  bool get isMilestone => milestoneType != null;

  Map<String, dynamic> toMap() => {
    'id': id,
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
    'strand_name': strandName,
    'sub_strand_name': subStrandName,
    'learning_outcomes': learningOutcomes,
    'key_inquiry_questions': keyInquiryQuestions,
    'learning_experiences': learningExperiences,
    'learning_resources': learningResources,
    'assessment_methods': assessmentMethods,
  };

  factory GuestRow.fromMap(Map<String, dynamic> map) {
    MilestoneType? mType;
    final rawM = map['milestone_type']?.toString();
    if (rawM == 'half_term' || rawM == 'halfTerm') {
      mType = MilestoneType.halfTerm;
    } else if (rawM == 'assessment') {
      mType = MilestoneType.assessment;
    }

    return GuestRow(
      id: map['id'] as String,
      weekNumber: map['week_number'] as int? ?? 1,
      lessonNumber: map['lesson_number'] as int? ?? 1,
      strandId: map['strand_id'] as String?,
      subStrandId: map['sub_strand_id'] as String?,
      customStrand: map['custom_strand'] as String?,
      customSubStrand: map['custom_sub_strand'] as String?,
      customOutcomes: (map['custom_outcomes'] as List<dynamic>?)?.cast<String>(),
      customQuestions: (map['custom_questions'] as List<dynamic>?)?.cast<String>(),
      customExperiences: (map['custom_experiences'] as List<dynamic>?)?.cast<String>(),
      customResources: (map['custom_resources'] as List<dynamic>?)?.cast<String>(),
      customAssessments: (map['custom_assessments'] as List<dynamic>?)?.cast<String>(),
      learningOutcomeIds: List<String>.from(map['learning_outcome_ids'] ?? []),
      keyInquiryQuestionIds: List<String>.from(map['key_inquiry_question_ids'] ?? []),
      learningExperienceIds: List<String>.from(map['learning_experience_ids'] ?? []),
      learningResourceIds: List<String>.from(map['learning_resource_ids'] ?? []),
      assessmentMethodIds: List<String>.from(map['assessment_method_ids'] ?? []),
      reflections: map['reflections'] as String? ?? '',
      position: map['position'] as int? ?? 0,
      milestoneType: mType,
      strandName: map['strand_name'] as String? ?? '',
      subStrandName: map['sub_strand_name'] as String? ?? '',
      learningOutcomes: List<String>.from(map['learning_outcomes'] ?? []),
      keyInquiryQuestions: List<String>.from(map['key_inquiry_questions'] ?? []),
      learningExperiences: List<String>.from(map['learning_experiences'] ?? []),
      learningResources: List<String>.from(map['learning_resources'] ?? []),
      assessmentMethods: List<String>.from(map['assessment_methods'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory GuestRow.fromJson(Map<String, dynamic> json) => GuestRow.fromMap(json);

  /// Convert to a SchemeRow
  SchemeRow toSchemeRow([String? schemeId]) {
    return SchemeRow(
      id: id,
      schemeId: schemeId,
      weekNumber: weekNumber,
      lessonNumber: lessonNumber,
      strandId: strandId,
      subStrandId: subStrandId,
      customStrand: customStrand,
      customSubStrand: customSubStrand,
      customOutcomes: customOutcomes,
      customQuestions: customQuestions,
      customExperiences: customExperiences,
      customResources: customResources,
      customAssessments: customAssessments,
      strandName: strandName,
      subStrandName: subStrandName,
      learningOutcomeIds: learningOutcomeIds,
      keyInquiryQuestionIds: keyInquiryQuestionIds,
      learningExperienceIds: learningExperienceIds,
      learningResourceIds: learningResourceIds,
      assessmentMethodIds: assessmentMethodIds,
      learningOutcomes: learningOutcomes,
      keyInquiryQuestions: keyInquiryQuestions,
      learningExperiences: learningExperiences,
      learningResources: learningResources,
      assessmentMethods: assessmentMethods,
      reflections: reflections,
      position: position,
      milestoneType: milestoneType,
    );
  }

  /// Create a GuestRow from a SchemeRow
  factory GuestRow.fromSchemeRow(SchemeRow r) {
    return GuestRow(
      id: r.id,
      weekNumber: r.weekNumber,
      lessonNumber: r.lessonNumber,
      strandId: r.strandId,
      subStrandId: r.subStrandId,
      customStrand: r.customStrand,
      customSubStrand: r.customSubStrand,
      customOutcomes: r.customOutcomes,
      customQuestions: r.customQuestions,
      customExperiences: r.customExperiences,
      customResources: r.customResources,
      customAssessments: r.customAssessments,
      learningOutcomeIds: r.learningOutcomeIds,
      keyInquiryQuestionIds: r.keyInquiryQuestionIds,
      learningExperienceIds: r.learningExperienceIds,
      learningResourceIds: r.learningResourceIds,
      assessmentMethodIds: r.assessmentMethodIds,
      reflections: r.reflections,
      position: r.position,
      milestoneType: r.milestoneType,
      strandName: r.strandName,
      subStrandName: r.subStrandName,
      learningOutcomes: r.learningOutcomes,
      keyInquiryQuestions: r.keyInquiryQuestions,
      learningExperiences: r.learningExperiences,
      learningResources: r.learningResources,
      assessmentMethods: r.assessmentMethods,
    );
  }
}

class GuestScheme {
  final String id; // "guest-<uuid>"
  final String createdAt;
  final String gradeId;
  final String subjectId;
  final String? referenceBookId;
  final String termName;
  final int year;
  final String? schoolName;
  final String? teacherName;
  final String? tscNumber;
  final String? hodName;
  final bool isPaid;
  final String? bundleId; // UUID grouping Term 1, 2, 3 together
  final List<BundleTermInfo>? bundleTerms;
  final List<GuestRow> rows;

  // Display helpers (for offline viewing)
  final String? gradeName;
  final String? subjectName;
  final String? referenceBookTitle;
  final String? updatedAt;

  GuestScheme({
    required this.id,
    required this.createdAt,
    required this.gradeId,
    required this.subjectId,
    this.referenceBookId,
    required this.termName,
    required this.year,
    this.schoolName,
    this.teacherName,
    this.tscNumber,
    this.hodName,
    this.isPaid = false,
    this.bundleId,
    this.bundleTerms,
    required this.rows,
    this.gradeName,
    this.subjectName,
    this.referenceBookTitle,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'created_at': createdAt,
    'grade_id': gradeId,
    'subject_id': subjectId,
    'reference_book_id': referenceBookId,
    'term_name': termName,
    'year': year,
    'school_name': schoolName,
    'teacher_name': teacherName,
    'tsc_number': tscNumber,
    'hod_name': hodName,
    'is_paid': isPaid,
    if (bundleId != null) 'bundle_id': bundleId,
    if (bundleTerms != null) 'bundle_terms': bundleTerms!.map((t) => t.toMap()).toList(),
    'rows': rows.map((r) => r.toMap()).toList(),
    if (gradeName != null) 'grade_name': gradeName,
    if (subjectName != null) 'subject_name': subjectName,
    if (referenceBookTitle != null) 'reference_book_title': referenceBookTitle,
    if (updatedAt != null) 'updated_at': updatedAt,
  };

  factory GuestScheme.fromMap(Map<String, dynamic> map) => GuestScheme(
    id: map['id'] as String,
    createdAt: (map['created_at'] ?? DateTime.now().toIso8601String()) as String,
    gradeId: map['grade_id'] as String,
    subjectId: map['subject_id'] as String,
    referenceBookId: map['reference_book_id'] as String?,
    termName: map['term_name'] as String? ?? 'Term 1',
    year: map['year'] as int? ?? DateTime.now().year,
    schoolName: map['school_name'] as String?,
    teacherName: map['teacher_name'] as String?,
    tscNumber: map['tsc_number'] as String?,
    hodName: map['hod_name'] as String?,
    isPaid: map['is_paid'] as bool? ?? false,
    bundleId: map['bundle_id'] as String?,
    bundleTerms: (map['bundle_terms'] as List<dynamic>?)
        ?.map((t) => BundleTermInfo.fromMap(t as Map<String, dynamic>))
        .toList(),
    rows: (map['rows'] as List<dynamic>? ?? [])
        .map((r) => GuestRow.fromMap(r as Map<String, dynamic>))
        .toList(),
    gradeName: map['grade_name'] as String?,
    subjectName: map['subject_name'] as String?,
    referenceBookTitle: map['reference_book_title'] as String?,
    updatedAt: map['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => toMap();
  factory GuestScheme.fromJson(Map<String, dynamic> json) => GuestScheme.fromMap(json);

  /// Converts this guest scheme to a standard Scheme model
  Scheme toScheme() {
    return Scheme(
      id: id,
      userId: null,
      gradeId: gradeId,
      subjectId: subjectId,
      referenceBookId: referenceBookId,
      termName: termName,
      year: year,
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
      isPaid: isPaid,
      bundleId: bundleId,
      bundleTerms: bundleTerms,
      createdAt: DateTime.tryParse(createdAt),
      updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
      gradeName: gradeName,
      subjectName: subjectName,
      referenceBookTitle: referenceBookTitle,
      rows: rows.map((r) => r.toSchemeRow(id)).toList(),
    );
  }

  GuestScheme copyWith({
    String? id,
    String? createdAt,
    String? gradeId,
    String? subjectId,
    String? referenceBookId,
    String? termName,
    int? year,
    String? schoolName,
    String? teacherName,
    String? tscNumber,
    String? hodName,
    bool? isPaid,
    String? bundleId,
    List<BundleTermInfo>? bundleTerms,
    List<GuestRow>? rows,
    String? gradeName,
    String? subjectName,
    String? referenceBookTitle,
    String? updatedAt,
  }) {
    return GuestScheme(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      gradeId: gradeId ?? this.gradeId,
      subjectId: subjectId ?? this.subjectId,
      referenceBookId: referenceBookId ?? this.referenceBookId,
      termName: termName ?? this.termName,
      year: year ?? this.year,
      schoolName: schoolName ?? this.schoolName,
      teacherName: teacherName ?? this.teacherName,
      tscNumber: tscNumber ?? this.tscNumber,
      hodName: hodName ?? this.hodName,
      isPaid: isPaid ?? this.isPaid,
      bundleId: bundleId ?? this.bundleId,
      bundleTerms: bundleTerms ?? this.bundleTerms,
      rows: rows ?? this.rows,
      gradeName: gradeName ?? this.gradeName,
      subjectName: subjectName ?? this.subjectName,
      referenceBookTitle: referenceBookTitle ?? this.referenceBookTitle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
