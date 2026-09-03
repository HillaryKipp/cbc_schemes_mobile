import 'package:flutter_test/flutter_test.dart';
import 'package:cbc_schemes_mobile/main.dart';
import 'package:cbc_schemes_mobile/models/grade.dart';
import 'package:cbc_schemes_mobile/models/subject.dart';
import 'package:cbc_schemes_mobile/services/guest_storage_service.dart';
import 'package:cbc_schemes_mobile/services/scheme_generator.dart';
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
      schoolName: 'Nairobi Junior School',
      teacherName: 'Tr. Hillary',
      tscNumber: '123456',
      hodName: 'Tr. Kip',
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

    expect(find.text('CBC SCHEMES'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Schemes'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
  });
}
