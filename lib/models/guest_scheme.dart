import 'scheme.dart';
import 'scheme_row.dart';

class GuestScheme {
  final String id; // "guest-<uuid>"
  final String gradeId;
  final String subjectId;
  final String termName;
  final String? referenceBookId;
  final String? schoolName;
  final String? teacherName;
  final String? tscNumber;
  final String? hodName;
  final int year;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? gradeName;
  final String? subjectName;
  final String? referenceBookTitle;
  final List<SchemeRow> rows;

  GuestScheme({
    required this.id,
    required this.gradeId,
    required this.subjectId,
    required this.termName,
    this.referenceBookId,
    this.schoolName,
    this.teacherName,
    this.tscNumber,
    this.hodName,
    required this.year,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.gradeName,
    this.subjectName,
    this.referenceBookTitle,
    this.rows = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory GuestScheme.fromJson(Map<String, dynamic> json) {
    return GuestScheme(
      id: json['id'] as String,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      termName: json['term_name'] as String? ?? 'Term 1',
      referenceBookId: json['reference_book_id'] as String?,
      schoolName: json['school_name'] as String?,
      teacherName: json['teacher_name'] as String?,
      tscNumber: json['tsc_number'] as String?,
      hodName: json['hod_name'] as String?,
      year: json['year'] as int? ?? DateTime.now().year,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      gradeName: json['grade_name'] as String?,
      subjectName: json['subject_name'] as String?,
      referenceBookTitle: json['reference_book_title'] as String?,
      rows: (json['rows'] as List<dynamic>?)
              ?.map((r) => SchemeRow.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'term_name': termName,
      'reference_book_id': referenceBookId,
      'school_name': schoolName,
      'teacher_name': teacherName,
      'tsc_number': tscNumber,
      'hod_name': hodName,
      'year': year,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'grade_name': gradeName,
      'subject_name': subjectName,
      'reference_book_title': referenceBookTitle,
      'rows': rows.map((r) => r.toJson()).toList(),
    };
  }

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
      isPaid: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      gradeName: gradeName,
      subjectName: subjectName,
      referenceBookTitle: referenceBookTitle,
      rows: rows,
    );
  }

  GuestScheme copyWith({
    String? id,
    String? gradeId,
    String? subjectId,
    String? termName,
    String? referenceBookId,
    String? schoolName,
    String? teacherName,
    String? tscNumber,
    String? hodName,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? gradeName,
    String? subjectName,
    String? referenceBookTitle,
    List<SchemeRow>? rows,
  }) {
    return GuestScheme(
      id: id ?? this.id,
      gradeId: gradeId ?? this.gradeId,
      subjectId: subjectId ?? this.subjectId,
      termName: termName ?? this.termName,
      referenceBookId: referenceBookId ?? this.referenceBookId,
      schoolName: schoolName ?? this.schoolName,
      teacherName: teacherName ?? this.teacherName,
      tscNumber: tscNumber ?? this.tscNumber,
      hodName: hodName ?? this.hodName,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gradeName: gradeName ?? this.gradeName,
      subjectName: subjectName ?? this.subjectName,
      referenceBookTitle: referenceBookTitle ?? this.referenceBookTitle,
      rows: rows ?? this.rows,
    );
  }
}
