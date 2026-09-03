import 'scheme_row.dart';

class Scheme {
  final String id;
  final String? userId;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/Display helpers
  final String? gradeName;
  final String? subjectName;
  final String? referenceBookTitle;
  final List<SchemeRow> rows;

  Scheme({
    required this.id,
    this.userId,
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
    this.createdAt,
    this.updatedAt,
    this.gradeName,
    this.subjectName,
    this.referenceBookTitle,
    this.rows = const [],
  });

  factory Scheme.fromJson(Map<String, dynamic> json, {List<SchemeRow>? rows}) {
    return Scheme(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      referenceBookId: json['reference_book_id'] as String?,
      termName: json['term_name'] as String? ?? 'Term 1',
      year: json['year'] as int? ?? DateTime.now().year,
      schoolName: json['school_name'] as String?,
      teacherName: json['teacher_name'] as String?,
      tscNumber: json['tsc_number'] as String?,
      hodName: json['hod_name'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      gradeName: json['grades'] != null ? json['grades']['name'] as String? : json['grade_name'] as String?,
      subjectName: json['subjects'] != null ? json['subjects']['name'] as String? : json['subject_name'] as String?,
      referenceBookTitle: json['reference_books'] != null ? json['reference_books']['title'] as String? : json['reference_book_title'] as String?,
      rows: rows ?? (json['scheme_rows'] as List<dynamic>?)?.map((r) => SchemeRow.fromJson(r as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
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
    };
  }

  Scheme copyWith({
    String? id,
    String? userId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    String? gradeName,
    String? subjectName,
    String? referenceBookTitle,
    List<SchemeRow>? rows,
  }) {
    return Scheme(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gradeName: gradeName ?? this.gradeName,
      subjectName: subjectName ?? this.subjectName,
      referenceBookTitle: referenceBookTitle ?? this.referenceBookTitle,
      rows: rows ?? this.rows,
    );
  }
}
