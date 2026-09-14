import 'package:flutter_test/flutter_test.dart';
import 'package:cbc_schemes_mobile/main.dart';
import 'package:cbc_schemes_mobile/models/grade.dart';
import 'package:cbc_schemes_mobile/models/subject.dart';
import 'package:cbc_schemes_mobile/services/guest_storage_service.dart';
import 'package:cbc_schemes_mobile/services/scheme_generator.dart';
import 'package:cbc_schemes_mobile/services/curriculum_service.dart';
import 'package:cbc_schemes_mobile/core/utils/calendar_utils.dart';
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
}
