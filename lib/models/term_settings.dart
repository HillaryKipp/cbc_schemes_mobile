class TermSettings {
  final int termNumber; // 1, 2, 3
  final String termName; // 'Term 1', 'Term 2', 'Term 3'
  final String startDate;
  final String endDate;
  int weeks;
  int lessonsPerWeek;
  bool includeHalfTerm;
  int halfTermWeek;
  String midTermStartDate;
  String midTermEndDate;
  List<int> assessmentWeeks;

  TermSettings({
    required this.termNumber,
    required this.termName,
    required this.startDate,
    required this.endDate,
    required this.weeks,
    this.lessonsPerWeek = 5,
    this.includeHalfTerm = true,
    required this.halfTermWeek,
    this.midTermStartDate = '',
    this.midTermEndDate = '',
    List<int>? assessmentWeeks,
  }) : assessmentWeeks = assessmentWeeks ?? [weeks];

  int get totalLessonSlots => weeks * lessonsPerWeek;

  /// Number of active teaching slots excluding half-term breaks and assessment weeks
  int get availableTeachingSlots {
    final lpw = lessonsPerWeek > 0 ? lessonsPerWeek : 5;
    final wks = weeks > 0 ? weeks : 13;
    var nonTeachingWeeks = 0;
    if (includeHalfTerm && halfTermWeek > 0 && halfTermWeek <= wks) {
      nonTeachingWeeks += 1;
    }
    for (final aw in assessmentWeeks) {
      if (aw > 0 && aw <= wks && (!includeHalfTerm || aw != halfTermWeek)) {
        nonTeachingWeeks += 1;
      }
    }
    final teachingWeeks = (wks - nonTeachingWeeks).clamp(1, wks);
    return teachingWeeks * lpw;
  }

  TermSettings copyWith({
    int? termNumber,
    String? termName,
    String? startDate,
    String? endDate,
    int? weeks,
    int? lessonsPerWeek,
    bool? includeHalfTerm,
    int? halfTermWeek,
    String? midTermStartDate,
    String? midTermEndDate,
    List<int>? assessmentWeeks,
  }) {
    return TermSettings(
      termNumber: termNumber ?? this.termNumber,
      termName: termName ?? this.termName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weeks: weeks ?? this.weeks,
      lessonsPerWeek: lessonsPerWeek ?? this.lessonsPerWeek,
      includeHalfTerm: includeHalfTerm ?? this.includeHalfTerm,
      halfTermWeek: halfTermWeek ?? this.halfTermWeek,
      midTermStartDate: midTermStartDate ?? this.midTermStartDate,
      midTermEndDate: midTermEndDate ?? this.midTermEndDate,
      assessmentWeeks: assessmentWeeks ?? List<int>.from(this.assessmentWeeks),
    );
  }

  /// Official 2026 Kenyan Academic Calendar Defaults
  static Map<int, TermSettings> getOfficial2026Defaults({int defaultLessonsPerWeek = 5}) {
    return {
      1: TermSettings(
        termNumber: 1,
        termName: 'Term 1',
        startDate: '2026-01-05',
        endDate: '2026-04-03',
        weeks: 13,
        lessonsPerWeek: defaultLessonsPerWeek,
        includeHalfTerm: true,
        halfTermWeek: 8,
        midTermStartDate: '2026-02-25',
        midTermEndDate: '2026-03-01',
        assessmentWeeks: [13],
      ),
      2: TermSettings(
        termNumber: 2,
        termName: 'Term 2',
        startDate: '2026-04-27',
        endDate: '2026-07-31',
        weeks: 14,
        lessonsPerWeek: defaultLessonsPerWeek,
        includeHalfTerm: true,
        halfTermWeek: 8,
        midTermStartDate: '2026-06-24',
        midTermEndDate: '2026-06-28',
        assessmentWeeks: [14],
      ),
      3: TermSettings(
        termNumber: 3,
        termName: 'Term 3',
        startDate: '2026-08-24',
        endDate: '2026-10-23',
        weeks: 9,
        lessonsPerWeek: defaultLessonsPerWeek,
        includeHalfTerm: true,
        halfTermWeek: 6,
        midTermStartDate: '2026-10-01',
        midTermEndDate: '2026-10-04',
        assessmentWeeks: [9],
      ),
    };
  }
}
