import 'package:uuid/uuid.dart';
import '../core/utils/calendar_utils.dart';
import '../models/grade.dart';
import '../models/subject.dart';
import '../models/reference_book.dart';
import '../models/strand.dart';
import '../models/scheme.dart';
import '../models/scheme_row.dart';
import '../models/guest_scheme.dart';
import 'curriculum_service.dart';
import 'guest_storage_service.dart';
import 'supabase_service.dart';

class SchemeGenerator {
  static final _uuid = const Uuid();

  /// Generation Engine (Direct port of CBC generation algorithm)
  static Future<Scheme> generateScheme({
    required Grade grade,
    required Subject subject,
    ReferenceBook? referenceBook,
    required String termName,
    required int year,
    required int weeks,
    required int lessonsPerWeek,
    String? schoolName,
    String? teacherName,
    String? tscNumber,
    String? hodName,
  }) async {
    final curriculum = CurriculumService.instance;
    final totalSlots = CalendarUtils.calculateTotalSlots(
      weeks: weeks,
      lessonsPerWeek: lessonsPerWeek,
    );

    // 1. Fetch strands and ordered sub-strands
    final strands = await curriculum.getStrandsWithSubStrands(subject.id);

    // 2. Fetch default global assessments (top 3)
    final allAssessments = (await curriculum.getContentBankForSubStrand(subStrandId: 'any')).assessments;
    final defaultAssessments = allAssessments.where((a) => a.isGlobal).take(3).map((a) => a.name).toList();
    if (defaultAssessments.isEmpty) {
      defaultAssessments.addAll([
        'Oral Questions & Answers',
        'Written Quizzes & Exercises',
        'Observation & Class Presentation',
      ]);
    }

    final List<SchemeRow> generatedRows = [];
    int currentSlotIndex = 0;

    // 3. Walk strands in order, then sub-strands in order
    for (final strand in strands) {
      if (currentSlotIndex >= totalSlots) break;

      for (final subStrand in strand.subStrands) {
        if (currentSlotIndex >= totalSlots) break;

        // Fetch content bank items for this sub-strand
        final bank = await curriculum.getContentBankForSubStrand(
          subStrandId: subStrand.id,
          referenceBookId: referenceBook?.id,
        );

        // Filter outcomes by reference book (book-specific first, fallback to generic)
        List<String> outcomes = [];
        if (referenceBook != null) {
          final bookSpecific = bank.outcomes
              .where((o) => o.referenceBookId == referenceBook.id)
              .map((o) => o.content)
              .toList();
          if (bookSpecific.isNotEmpty) {
            outcomes = bookSpecific;
          }
        }
        if (outcomes.isEmpty) {
          outcomes = bank.outcomes
              .where((o) => o.referenceBookId == null || o.referenceBookId!.isEmpty)
              .map((o) => o.content)
              .toList();
        }
        if (outcomes.isEmpty && bank.outcomes.isNotEmpty) {
          outcomes = bank.outcomes.map((o) => o.content).toList();
        }

        // Filter inquiry questions
        List<String> questions = [];
        if (referenceBook != null) {
          final bookSpecific = bank.questions
              .where((q) => q.referenceBookId == referenceBook.id)
              .map((q) => q.question)
              .toList();
          if (bookSpecific.isNotEmpty) {
            questions = bookSpecific;
          }
        }
        if (questions.isEmpty) {
          questions = bank.questions
              .where((q) => q.referenceBookId == null || q.referenceBookId!.isEmpty)
              .map((q) => q.question)
              .toList();
        }
        if (questions.isEmpty && bank.questions.isNotEmpty) {
          questions = bank.questions.map((q) => q.question).toList();
        }

        // Filter learning experiences
        List<String> experiences = [];
        if (referenceBook != null) {
          final bookSpecific = bank.experiences
              .where((e) => e.referenceBookId == referenceBook.id)
              .map((e) => e.description)
              .toList();
          if (bookSpecific.isNotEmpty) {
            experiences = bookSpecific;
          }
        }
        if (experiences.isEmpty) {
          experiences = bank.experiences
              .where((e) => e.referenceBookId == null || e.referenceBookId!.isEmpty)
              .map((e) => e.description)
              .toList();
        }
        if (experiences.isEmpty && bank.experiences.isNotEmpty) {
          experiences = bank.experiences.map((e) => e.description).toList();
        }

        // Filter learning resources
        List<String> resources = [];
        if (referenceBook != null) {
          final bookSpecific = bank.resources
              .where((r) => r.referenceBookId == referenceBook.id)
              .map((r) => r.title)
              .toList();
          if (bookSpecific.isNotEmpty) {
            resources = bookSpecific;
          }
        }
        if (resources.isEmpty) {
          resources = bank.resources
              .where((r) => r.referenceBookId == null || r.referenceBookId!.isEmpty)
              .map((r) => r.title)
              .toList();
        }
        if (resources.isEmpty && bank.resources.isNotEmpty) {
          resources = bank.resources.map((r) => r.title).toList();
        }

        // Fill suggested_lessons consecutive slots
        final slotsForThisSubStrand = subStrand.suggestedLessons > 0 ? subStrand.suggestedLessons : 3;

        for (int i = 0; i < slotsForThisSubStrand; i++) {
          if (currentSlotIndex >= totalSlots) break;

          final slotInfo = CalendarUtils.getWeekAndLesson(currentSlotIndex, lessonsPerWeek);

          final row = SchemeRow(
            id: _uuid.v4(),
            weekNumber: slotInfo.week,
            lessonNumber: slotInfo.lesson,
            strandName: strand.name,
            subStrandName: subStrand.name,
            learningOutcomes: List.from(outcomes),
            keyInquiryQuestions: List.from(questions),
            learningExperiences: List.from(experiences),
            learningResources: List.from(resources),
            assessmentMethods: List.from(defaultAssessments),
            reflections: '', // Reflections always starts empty
            position: currentSlotIndex,
          );

          generatedRows.add(row);
          currentSlotIndex++;
        }
      }
    }

    // 4. Fill any remaining lesson slots with blank planning rows
    while (currentSlotIndex < totalSlots) {
      final slotInfo = CalendarUtils.getWeekAndLesson(currentSlotIndex, lessonsPerWeek);
      generatedRows.add(
        SchemeRow(
          id: _uuid.v4(),
          weekNumber: slotInfo.week,
          lessonNumber: slotInfo.lesson,
          strandName: 'Revision & Remediation / Assessment',
          subStrandName: 'End of Term Assessment and Project Consolidation',
          learningOutcomes: ['Revise and assess key concepts covered during the term.'],
          keyInquiryQuestions: ['What areas require further practice and mastery?'],
          learningExperiences: ['Learners solve revision tasks, review past projects, and self-assess.'],
          learningResources: ['Assessment papers, Portfolios, Rubrics, Exercise books'],
          assessmentMethods: List.from(defaultAssessments),
          reflections: '',
          position: currentSlotIndex,
        ),
      );
      currentSlotIndex++;
    }

    // Cache teacher profile for future prefilling
    await GuestStorageService.instance.saveTeacherProfile(
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
    );

    final supabase = SupabaseService.instance;

    // 5. Persistence: Signed in -> Supabase Postgres; Signed out -> GuestScheme (SharedPreferences)
    if (supabase.isAuthenticated && supabase.currentUser != null) {
      try {
        final userId = supabase.currentUser!.id;
        final schemeRes = await supabase.client.from('schemes').insert({
          'user_id': userId,
          'grade_id': grade.id,
          'subject_id': subject.id,
          'reference_book_id': referenceBook?.id,
          'term_name': termName,
          'year': year,
          'school_name': schoolName,
          'teacher_name': teacherName,
          'tsc_number': tscNumber,
          'hod_name': hodName,
        }).select().single();

        final createdSchemeId = schemeRes['id'] as String;

        // Insert scheme rows
        final rowsToInsert = generatedRows.map((r) {
          final rowMap = r.toJson();
          rowMap['scheme_id'] = createdSchemeId;
          return rowMap;
        }).toList();

        await supabase.client.from('scheme_rows').insert(rowsToInsert);

        return Scheme.fromJson(schemeRes, rows: generatedRows);
      } catch (e) {
        // Fallback to local guest scheme if network/db error
      }
    }

    // Guest Flow: Store in local GuestStorageService
    final guestId = 'guest-${_uuid.v4()}';
    final guestScheme = GuestScheme(
      id: guestId,
      gradeId: grade.id,
      subjectId: subject.id,
      termName: termName,
      referenceBookId: referenceBook?.id,
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
      year: year,
      gradeName: grade.name,
      subjectName: subject.name,
      referenceBookTitle: referenceBook?.title,
      rows: generatedRows,
    );

    await GuestStorageService.instance.saveGuestScheme(guestScheme);
    return guestScheme.toScheme();
  }
}
