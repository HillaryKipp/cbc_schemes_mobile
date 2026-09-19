import 'package:flutter_test/flutter_test.dart';
import 'package:cbc_schemes_mobile/main.dart';
import 'package:cbc_schemes_mobile/models/grade.dart';
import 'package:cbc_schemes_mobile/models/subject.dart';
import 'package:cbc_schemes_mobile/services/guest_storage_service.dart';
import 'package:cbc_schemes_mobile/services/scheme_generator.dart';
import 'package:cbc_schemes_mobile/services/curriculum_service.dart';
import 'package:cbc_schemes_mobile/core/utils/calendar_utils.dart';
import 'package:cbc_schemes_mobile/core/utils/formatters.dart';
import 'package:cbc_schemes_mobile/core/utils/scheme_search_matcher.dart';
import 'package:cbc_schemes_mobile/core/config/app_config.dart';
import 'package:cbc_schemes_mobile/models/scheme_row.dart';
import 'package:cbc_schemes_mobile/models/term_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GuestStorageService.instance.init();
  });

  test('CalendarUtils calculates slots correctly', () {
    final totalSlots = CalendarUtils.calculateTotalSlots(weeks: 12, lessonsPerWeek: 5);
    expect(totalSlots, 60);

    final slot1 = CalendarUtils.getWeekAndLesson(0, 5);
    expect(slot1.week, 1);
    expect(slot1.lesson, 1);

    final slot6 = CalendarUtils.getWeekAndLesson(5, 5);
    expect(slot6.week, 2);
    expect(slot6.lesson, 1);
  });

  test('SchemeGenerator produces exact 10-column scheme rows for guest user', () async {
    final grade = Grade(id: 'grade-7', name: 'Grade 7', level: 'Junior School');
    final subject = Subject(id: 'subj-g7-math', gradeId: 'grade-7', name: 'Mathematics');

    final scheme = await SchemeGenerator.generateScheme(
      grade: grade,
      subject: subject,
      termName: 'Term 1',
      year: 2026,
      weeks: 10,
      lessonsPerWeek: 5,
      schoolName: 'CBC Model Junior School',
      teacherName: 'Teacher Jane Doe',
      tscNumber: 'TSC123456',
      hodName: 'HOD Science & Math',
    );

    expect(scheme.id.startsWith('guest-'), isTrue);
    expect(scheme.rows.length, 50); // 10 weeks * 5 lessons
    expect(scheme.rows.first.learningOutcomes.isNotEmpty, isTrue);
    expect(scheme.rows.first.keyInquiryQuestions.isNotEmpty, isTrue);
    expect(scheme.rows.first.learningExperiences.isNotEmpty, isTrue);
    expect(scheme.rows.first.learningResources.isNotEmpty, isTrue);
    expect(scheme.rows.first.assessmentMethods.isNotEmpty, isTrue);
    expect(scheme.rows.first.reflections, ''); // reflections always starts empty
  });

  testWidgets('App renders MainNavigationScreen correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const CbcSchemesApp());
    await tester.pumpAndSettle();

    expect(find.text('CBC SCHEMES OF WORK'), findsOneWidget);
    expect(find.text('Generator'), findsOneWidget);
    expect(find.text('Schemes'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  test('Grade level subjects are strictly isolated by curriculum stage', () async {
    final curriculum = CurriculumService.instance;

    // PP1 Grade (Pre-Primary)
    final pp1Grade = Grade(id: 'uuid-pp1', name: 'PP1');
    final pp1Subjects = await curriculum.getSubjects(pp1Grade.id, grade: pp1Grade);
    final pp1Names = pp1Subjects.map((s) => s.name).toList();

    expect(pp1Names.contains('Language Activities'), isTrue);
    expect(pp1Names.contains('Mathematical Activities'), isTrue);
    expect(pp1Names.contains('Integrated Science'), isFalse);
    expect(pp1Names.contains('Agriculture & Nutrition'), isFalse);
    expect(pp1Names.contains('Pre-Technical Studies'), isFalse);

    // Grade 2 (Lower Primary)
    final g2Grade = Grade(id: 'uuid-g2', name: 'Grade 2');
    final g2Subjects = await curriculum.getSubjects(g2Grade.id, grade: g2Grade);
    final g2Names = g2Subjects.map((s) => s.name).toList();

    expect(g2Names.contains('Mathematics Activities'), isTrue);
    expect(g2Names.contains('English Language Activities'), isTrue);
    expect(g2Names.contains('Integrated Science'), isFalse);
    expect(g2Names.contains('Agriculture & Nutrition'), isFalse);

    // Grade 4 (Upper Primary)
    final g4Grade = Grade(id: 'uuid-g4', name: 'Grade 4');
    final g4Subjects = await curriculum.getSubjects(g4Grade.id, grade: g4Grade);
    final g4Names = g4Subjects.map((s) => s.name).toList();

    expect(g4Names.contains('Science and Technology'), isTrue);
    expect(g4Names.contains('Agriculture and Nutrition'), isTrue);
    expect(g4Names.contains('Integrated Science'), isFalse);

    // Grade 7 (Junior School)
    final g7Grade = Grade(id: 'uuid-g7', name: 'Grade 7');
    final g7Subjects = await curriculum.getSubjects(g7Grade.id, grade: g7Grade);
    final g7Names = g7Subjects.map((s) => s.name).toList();

    expect(g7Names.contains('Integrated Science'), isTrue);
    expect(g7Names.contains('Pre-Technical Studies'), isTrue);
    expect(g7Names.contains('Creative Arts & Sports'), isTrue);
  });

  test('CBC sanitization and formatting rules match guide', () {
    expect(cleanItemText('• Identify rational numbers'), 'Identify rational numbers');
    expect(cleanItemText('1. Identify rational numbers'), 'Identify rational numbers');
    expect(cleanItemText('a) Identify rational numbers'), 'Identify rational numbers');
    expect(cleanItemText('- Identify rational numbers'), 'Identify rational numbers');

    final outcomes = formatOutcomes(['Identify fractions', 'Order decimals']);
    expect(outcomes.first, 'By the end of the sub strand, the learner should be able to;');
    expect(outcomes[1], 'a) Identify fractions');
    expect(outcomes[2], 'b) Order decimals');

    final questions = formatQuestions(['How do we add fractions?', 'Why do we simplify?']);
    expect(questions[0], '1. How do we add fractions?');
    expect(questions[1], '2. Why do we simplify?');

    final bullets = formatBullets(['Charts', 'Worksheets']);
    expect(bullets[0], '- Charts');
    expect(bullets[1], '- Worksheets');
  });

  test('Pacing & Progression distributeContentIds behaves correctly', () {
    final outcomes = ['Outcome A', 'Outcome B', 'Outcome C'];
    // 6 lessons, 3 outcomes -> distributed 2 lessons each
    final l0 = SchemeGenerator.distributeContentIds(outcomes, 0, 6);
    final l1 = SchemeGenerator.distributeContentIds(outcomes, 1, 6);
    final l2 = SchemeGenerator.distributeContentIds(outcomes, 2, 6);
    final l3 = SchemeGenerator.distributeContentIds(outcomes, 3, 6);
    final l4 = SchemeGenerator.distributeContentIds(outcomes, 4, 6);
    final l5 = SchemeGenerator.distributeContentIds(outcomes, 5, 6);

    expect(l0, ['Outcome A']);
    expect(l1, ['Outcome A']);
    expect(l2, ['Outcome B']);
    expect(l3, ['Outcome B']);
    expect(l4, ['Outcome C']);
    expect(l5, ['Outcome C']);
  });

  test('CalendarUtils computeWeeks and computeLessonSlots match web logic', () {
    final weeks = CalendarUtils.computeWeeks('2026-01-05', '2026-04-03', [
      {'start': '2026-02-25', 'end': '2026-03-01'}
    ]);
    expect(weeks, 12);

    final slots = CalendarUtils.computeLessonSlots(2, 3);
    expect(slots.length, 6);
    expect(slots.first, (week: 1, lesson: 1));
    expect(slots.last, (week: 2, lesson: 3));
  });

  test('Natural Language search parses queries like "grade 4 math term 1"', () {
    final grades = [
      {'id': 'grade-4', 'name': 'Grade 4'},
      {'id': 'grade-7', 'name': 'Grade 7'},
    ];
    final subjects = [
      {'id': 'g4-math', 'grade_id': 'grade-4', 'name': 'Mathematics'},
      {'id': 'g7-sci', 'grade_id': 'grade-7', 'name': 'Integrated Science'},
    ];

    final matches = parseSchemeSearch('grade 4 math term 1', grades, subjects);
    expect(matches.isNotEmpty, isTrue);
    expect(matches.first.grade['name'], 'Grade 4');
    expect(matches.first.subject['name'], 'Mathematics');
    expect(matches.first.term, 'Term 1');
  });

  test('AppConfig maintains official WhatsApp support phone routing', () {
    expect(AppConfig.whatsappSupportNumber, '254734232994');
    expect(AppConfig.supportPhone, '0734232994');
  });

  test('SchemeRow supports MilestoneType and banner text serialization', () {
    final halfTermRow = SchemeRow(
      id: 'row-half-term',
      schemeId: 'scheme-1',
      position: 0,
      weekNumber: 8,
      lessonNumber: 1,
      strandName: 'HALF TERM ASSESSMENT & BREAK',
      subStrandName: '',
      learningOutcomes: [],
      keyInquiryQuestions: [],
      learningExperiences: [],
      learningResources: [],
      assessmentMethods: [],
      milestoneType: MilestoneType.halfTerm,
    );

    expect(halfTermRow.isMilestone, isTrue);
    expect(halfTermRow.milestoneBannerText, 'HALF TERM BREAK — WEEK 8');

    final json = halfTermRow.toJson();
    expect(json['milestone_type'], 'half_term');

    final revived = SchemeRow.fromJson(json);
    expect(revived.isMilestone, isTrue);
    expect(revived.milestoneType, MilestoneType.halfTerm);
  });

  test('SchemeGenerator returns accurate official 2026 academic term capacities', () {
    final capacities = SchemeGenerator.getOfficial2026Capacities(5);
    expect(capacities.length, 3);
    expect(capacities[0].termNumber, 1);
    expect(capacities[0].totalLessons, 65);

    expect(capacities[1].termNumber, 2);
    expect(capacities[1].totalLessons, 70);

    expect(capacities[2].termNumber, 3);
    expect(capacities[2].totalLessons, 45);
  });

  test('SchemeGenerator autoDistributeSubStrandsToTerms balances across 3 terms without dropping items', () {
    final strandList = [
      {'id': 'st-1', 'order_index': 0},
      {'id': 'st-2', 'order_index': 1},
    ];
    final subStrandList = [
      {'id': 'ss-1', 'strand_id': 'st-1', 'suggested_lessons': 20, 'order_index': 0},
      {'id': 'ss-2', 'strand_id': 'st-1', 'suggested_lessons': 25, 'order_index': 1},
      {'id': 'ss-3', 'strand_id': 'st-1', 'suggested_lessons': 20, 'order_index': 2},
      {'id': 'ss-4', 'strand_id': 'st-2', 'suggested_lessons': 30, 'order_index': 0},
      {'id': 'ss-5', 'strand_id': 'st-2', 'suggested_lessons': 25, 'order_index': 1},
      {'id': 'ss-6', 'strand_id': 'st-2', 'suggested_lessons': 20, 'order_index': 2},
    ];
    final capacities = SchemeGenerator.getOfficial2026Capacities(5);

    final distribution = SchemeGenerator.autoDistributeSubStrandsToTerms(
      strands: strandList,
      subStrands: subStrandList,
      termCapacities: capacities,
    );
    expect(distribution.containsKey(1), isTrue);
    expect(distribution.containsKey(2), isTrue);
    expect(distribution.containsKey(3), isTrue);

    final allDistributedIds = <String>[];
    for (final termList in distribution.values) {
      for (final item in termList) {
        allDistributedIds.add(item.subStrandId);
      }
    }

    expect(allDistributedIds.length, greaterThanOrEqualTo(6));
    expect(allDistributedIds.toSet().length, 6);
  });

  test('SchemeGenerator generateMultiTermBundle creates 3 linked schemes with companion metadata', () async {
    final grade = Grade(id: 'grade-7', name: 'Grade 7', level: 'Junior School');
    final subject = Subject(id: 'subj-g7-math', gradeId: 'grade-7', name: 'Mathematics');

    final bundle = await SchemeGenerator.generateMultiTermBundle(
      grade: grade,
      subject: subject,
      year: 2026,
      lessonsPerWeek: 5,
      schoolName: 'Bundle Model Academy',
      teacherName: 'Teacher Test',
    );

    expect(bundle.length, 3);
    final term1 = bundle.firstWhere((s) => s.termName == 'Term 1');
    final term2 = bundle.firstWhere((s) => s.termName == 'Term 2');
    final term3 = bundle.firstWhere((s) => s.termName == 'Term 3');

    expect(term1.bundleId, isNotNull);
    expect(term1.bundleId, term2.bundleId);
    expect(term2.bundleId, term3.bundleId);

    expect(term1.bundleTerms?.length, 3);
    expect(term1.bundleTerms!.any((t) => t.termName == 'Term 2'), isTrue);

    // Verify milestones exist
    expect(term1.rows.any((r) => r.isMilestone), isTrue);
    expect(term1.rows.any((r) => r.milestoneType == MilestoneType.halfTerm), isTrue);
    expect(term1.rows.any((r) => r.milestoneType == MilestoneType.assessment), isTrue);
  });

  test('TermSettings provides accurate 2026 Kenyan Ministry calendar defaults', () {
    final settings = TermSettings.getOfficial2026Defaults(defaultLessonsPerWeek: 5);
    expect(settings[1]?.weeks, 13);
    expect(settings[1]?.halfTermWeek, 8);
    expect(settings[1]?.assessmentWeeks, [13]);

    expect(settings[2]?.weeks, 14);
    expect(settings[2]?.halfTermWeek, 8);
    expect(settings[2]?.assessmentWeeks, [14]);

    expect(settings[3]?.weeks, 9);
    expect(settings[3]?.halfTermWeek, 6);
    expect(settings[3]?.assessmentWeeks, [9]);
  });
}

