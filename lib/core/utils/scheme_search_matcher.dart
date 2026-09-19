import '../../models/grade.dart';
import '../../models/subject.dart';

class SchemeSearchMatch {
  final Map<String, dynamic> grade;
  final Map<String, dynamic> subject;
  final String? term;

  SchemeSearchMatch({required this.grade, required this.subject, this.term});

  String get gradeName => grade['name'] as String? ?? '';
  String get subjectName => subject['name'] as String? ?? '';
  String get gradeId => grade['id'] as String? ?? '';
  String get subjectId => subject['id'] as String? ?? '';
}

class SchemeSearchModelMatch {
  final Grade grade;
  final Subject subject;
  final String? term;

  SchemeSearchModelMatch({
    required this.grade,
    required this.subject,
    this.term,
  });
}

const Map<String, List<String>> subjectAliases = {
  'mathematics': ['math', 'maths', 'mathematics', 'mathematical', 'hesabu', 'numeracy'],
  'english': ['english', 'eng', 'literacy', 'reading', 'language'],
  'kiswahili': ['kiswahili', 'swahili', 'kusoma', 'lugha'],
  'science': ['science', 'integrated science', 'sci', 'sayansi'],
  'social studies': ['social studies', 'social', 'sst'],
  'agriculture': ['agri', 'agriculture', 'kilimo', 'nutrition'],
  'cre': ['cre', 'christian religious education', 'christian religious', 'din'],
  'creative arts': ['creative arts', 'art', 'music', 'craft'],
  'pre-technical': ['pre-tech', 'pre-technical', 'pre technical', 'technical'],
};

List<SchemeSearchMatch> parseSchemeSearch(
  String rawQuery,
  List<Map<String, dynamic>> grades,
  List<Map<String, dynamic>> subjects,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return [];

  String? detectedTerm;
  if (RegExp(r'term\s*1|\bt1\b').hasMatch(q)) {
    detectedTerm = "Term 1";
  } else if (RegExp(r'term\s*2|\bt2\b').hasMatch(q)) {
    detectedTerm = "Term 2";
  } else if (RegExp(r'term\s*3|\bt3\b').hasMatch(q)) {
    detectedTerm = "Term 3";
  }

  final clean = q
      .replaceAll(RegExp(r'\b(schemes?|of|work|cbc|download|pdf|docx|free|notes|lesson|plans?)\b'), ' ')
      .replaceAll(RegExp(r'term\s*[123]|\bt[123]\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final scored = <({SchemeSearchMatch match, int score})>[];

  for (final subject in subjects) {
    final matchingGrades = grades.where((g) => g['id'] == subject['grade_id']);
    if (matchingGrades.isEmpty) continue;
    final grade = matchingGrades.first;

    final gName = (grade['name'] as String? ?? '').toLowerCase();
    final sName = (subject['name'] as String? ?? '').toLowerCase();

    int score = 0;
    final gradeMentioned = q.contains(gName) ||
        (gName.contains('grade') && q.contains('g${gName.replaceAll(RegExp(r'\D'), '')}')) ||
        (gName.contains('pp') && q.contains(gName.replaceAll(' ', '')));

    bool subjectMentioned = sName.contains(clean) || (clean.length > 2 && clean.contains(sName));
    if (!subjectMentioned) {
      for (final entry in subjectAliases.entries) {
        if (sName.contains(entry.key) && entry.value.any((a) => q.contains(a))) {
          subjectMentioned = true;
          break;
        }
      }
    }

    if (gradeMentioned && subjectMentioned) {
      score += 10;
    } else if (subjectMentioned && !gradeMentioned && clean.length > 2) {
      score += 6;
    } else if (gradeMentioned && clean.length <= 2) {
      score += 4;
    }

    if (score > 0) {
      scored.add((
        match: SchemeSearchMatch(grade: grade, subject: subject, term: detectedTerm),
        score: score,
      ));
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(6).map((e) => e.match).toList();
}

List<SchemeSearchModelMatch> parseSchemeSearchModels(
  String rawQuery,
  List<Grade> grades,
  List<Subject> subjects,
) {
  final gradesJson = grades.map((g) => g.toJson()).toList();
  final subjectsJson = subjects.map((s) => s.toJson()).toList();

  final matches = parseSchemeSearch(rawQuery, gradesJson, subjectsJson);

  return matches.map((m) {
    final g = grades.firstWhere((g) => g.id == m.gradeId, orElse: () => grades.first);
    final s = subjects.firstWhere((s) => s.id == m.subjectId, orElse: () => subjects.first);
    return SchemeSearchModelMatch(
      grade: g,
      subject: s,
      term: m.term,
    );
  }).toList();
}
