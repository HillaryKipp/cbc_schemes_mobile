import 'dart:math';
import 'package:uuid/uuid.dart';
import '../core/utils/calendar_utils.dart';
import '../core/utils/formatters.dart';
import '../models/grade.dart';
import '../models/subject.dart';
import '../models/strand.dart';
import '../models/reference_book.dart';
import '../models/scheme.dart';
import '../models/scheme_row.dart';
import '../models/guest_scheme.dart';
import '../models/content_bank.dart';
import '../models/term_settings.dart';
import 'curriculum_service.dart';
import 'guest_storage_service.dart';
import 'supabase_service.dart';

typedef SubStrandBank = ({
  List<LearningOutcome> outcomes,
  List<KeyInquiryQuestion> questions,
  List<LearningExperience> experiences,
  List<LearningResource> resources,
  List<AssessmentMethod> assessments,
});

class TermCapacity {
  final int termNumber; // 1, 2, 3
  final int totalLessons;
  TermCapacity({required this.termNumber, required this.totalLessons});
}

class TermSubStrandAssignment {
  final int termNumber;
  final String strandId;
  final String subStrandId;
  int allocatedLessons;
  final int lessonOffset;

  TermSubStrandAssignment({
    required this.termNumber,
    required this.strandId,
    required this.subStrandId,
    required this.allocatedLessons,
    this.lessonOffset = 0,
  });

  TermSubStrandAssignment copyWith({
    int? termNumber,
    String? strandId,
    String? subStrandId,
    int? allocatedLessons,
    int? lessonOffset,
  }) {
    return TermSubStrandAssignment(
      termNumber: termNumber ?? this.termNumber,
      strandId: strandId ?? this.strandId,
      subStrandId: subStrandId ?? this.subStrandId,
      allocatedLessons: allocatedLessons ?? this.allocatedLessons,
      lessonOffset: lessonOffset ?? this.lessonOffset,
    );
  }
}

class SchemeGenerator {
  static const _uuid = Uuid();

  /// Official 2026 Ministry Term Capacities (Term 1: 13 wks, Term 2: 14 wks, Term 3: 9 wks)
  static List<TermCapacity> getOfficial2026Capacities(int lessonsPerWeek) {
    final lpw = lessonsPerWeek > 0 ? lessonsPerWeek : 5;
    return [
      TermCapacity(termNumber: 1, totalLessons: 13 * lpw),
      TermCapacity(termNumber: 2, totalLessons: 14 * lpw),
      TermCapacity(termNumber: 3, totalLessons: 9 * lpw),
    ];
  }

  /// Pacing and progression algorithm matching web src/lib/generate.ts
  static List<String> distributeContentIds(
    List<String> itemIds,
    int lessonIndex,
    int totalLessons,
  ) {
    if (itemIds.isEmpty) return [];
    if (totalLessons <= 1 || itemIds.length == 1) return itemIds;

    // Case A: More (or equal) lessons than items (e.g. 15 lessons, 3 outcomes)
    if (totalLessons >= itemIds.length) {
      final idx = ((lessonIndex / totalLessons) * itemIds.length).floor().clamp(0, itemIds.length - 1);
      return [itemIds[idx]];
    }

    // Case B: More items than lessons (e.g. 5 items, 2 lessons)
    final start = ((lessonIndex / totalLessons) * itemIds.length).floor();
    final end = (((lessonIndex + 1) / totalLessons) * itemIds.length).floor();
    final slice = itemIds.sublist(start, end.clamp(start + 1, itemIds.length));
    return slice.isNotEmpty ? slice : [itemIds[start.clamp(0, itemIds.length - 1)]];
  }

  /// Auto-Distribution across 3 Terms matching Flutter Mobile App Guide Section 5.2
  static Map<int, List<TermSubStrandAssignment>> autoDistributeSubStrandsToTerms({
    required List<Map<String, dynamic>> strands,
    required List<Map<String, dynamic>> subStrands,
    required List<TermCapacity> termCapacities,
  }) {
    final result = <int, List<TermSubStrandAssignment>>{1: [], 2: [], 3: []};

    // Sort strands sequentially by order_index
    final sortedStrands = List<Map<String, dynamic>>.from(strands)
      ..sort((a, b) => ((a['order_index'] as int?) ?? 0).compareTo((b['order_index'] as int?) ?? 0));

    final ordered = <({Map<String, dynamic> strand, Map<String, dynamic> subStrand})>[];
    for (final strand in sortedStrands) {
      final sSubs = subStrands
          .where((s) => s['strand_id'] == strand['id'])
          .toList()
        ..sort((a, b) => ((a['order_index'] as int?) ?? 0).compareTo((b['order_index'] as int?) ?? 0));
      for (final ss in sSubs) {
        ordered.add((strand: strand, subStrand: ss));
      }
    }

    if (ordered.isEmpty) return result;

    final totalCurriculumLessons = ordered.fold<int>(
      0,
      (sum, e) => sum + (int.tryParse(e.subStrand['suggested_lessons']?.toString() ?? '1') ?? 1).clamp(1, 99),
    );

    final capMap = {for (var c in termCapacities) c.termNumber: c.totalLessons};
    final cap1 = capMap[1] ?? 65;
    final cap2 = capMap[2] ?? 70;
    final cap3 = capMap[3] ?? 45;
    final totalCap = cap1 + cap2 + cap3;

    final target1 = (cap1 / totalCap * totalCurriculumLessons).round().clamp(1, 999);
    final target2 = (cap2 / totalCap * totalCurriculumLessons).round().clamp(1, 999);
    final target3 = (totalCurriculumLessons - target1 - target2).clamp(1, 999);

    final termTargets = {1: target1, 2: target2, 3: target3};

    var currentTerm = 1;
    var remainingInTerm = termTargets[1]!;

    for (final entry in ordered) {
      final totalLessons = (int.tryParse(entry.subStrand['suggested_lessons']?.toString() ?? '1') ?? 1).clamp(1, 99);
      var lessonsToPlace = totalLessons;
      var offset = 0;

      while (lessonsToPlace > 0) {
        if (remainingInTerm <= 0) {
          if (currentTerm < 3) {
            currentTerm += 1;
            remainingInTerm = termTargets[currentTerm]!;
          } else {
            result[3]!.add(TermSubStrandAssignment(
              termNumber: 3,
              strandId: entry.strand['id'] as String,
              subStrandId: entry.subStrand['id'] as String,
              allocatedLessons: lessonsToPlace,
              lessonOffset: offset,
            ));
            break;
          }
        }

        final canTake = lessonsToPlace < remainingInTerm ? lessonsToPlace : remainingInTerm;
        result[currentTerm]!.add(TermSubStrandAssignment(
          termNumber: currentTerm,
          strandId: entry.strand['id'] as String,
          subStrandId: entry.subStrand['id'] as String,
          allocatedLessons: canTake,
          lessonOffset: offset,
        ));

        lessonsToPlace -= canTake;
        remainingInTerm -= canTake;
        offset += canTake;
      }
    }

    return result;
  }

  /// Generation Engine matching Flutter Mobile App Guide — CBC Schemes of Work
  static Future<Scheme> generateScheme({
    required Grade grade,
    required Subject subject,
    ReferenceBook? referenceBook,
    required String termName,
    required int year,
    required int weeks,
    required int lessonsPerWeek,
    String pacingMode = 'progressive', // 'progressive' (default) or 'comprehensive'
    int? halfTermWeek, // defaults to week 8 for standard terms, or null if disabled
    List<int>? assessmentWeeks, // defaults to [weeks] (last week of term)
    List<TermSubStrandAssignment>? assignedSubStrands,
    String? bundleId,
    List<BundleTermInfo>? bundleTerms,
    String? schoolName,
    String? teacherName,
    String? tscNumber,
    String? hodName,
  }) async {
    final curriculum = CurriculumService.instance;
    final lpw = lessonsPerWeek > 0 ? lessonsPerWeek : 5;
    final totalSlots = CalendarUtils.calculateTotalSlots(weeks: weeks, lessonsPerWeek: lpw);

    // Default milestone weeks matching Kenyan Academic Calendar
    final resolvedHalfTermWeek = halfTermWeek ?? (weeks >= 10 ? 8 : null);
    final resolvedAssessmentWeeks = assessmentWeeks ?? [weeks];

    // 1. Fetch strands and ordered sub-strands
    final strands = await curriculum.getStrandsWithSubStrands(subject.id);

    // 2. Fetch default global assessments (top 3)
    final allAssessments = (await curriculum.getContentBankForSubStrand(subStrandId: 'any')).assessments;
    final globalAssessments = allAssessments.where((a) => a.isGlobal).take(3).toList();
    final List<String> defaultAssessmentIds = globalAssessments.map((a) => a.id).toList();
    final List<String> defaultAssessmentNames = globalAssessments.map((a) => a.name).toList();

    if (defaultAssessmentNames.isEmpty) {
      defaultAssessmentNames.addAll([
        'Oral Questions & Answers',
        'Written Quizzes & Exercises',
        'Observation & Class Presentation',
      ]);
    }

    // Build slot list
    final slots = CalendarUtils.computeLessonSlots(weeks, lpw);

    // Count regular teaching slots (excluding half-term and assessment weeks)
    final regularSlotsCount = slots.where((s) =>
      s.week != resolvedHalfTermWeek && !resolvedAssessmentWeeks.contains(s.week)
    ).length;

    // Determine sub-strands to include
    final rawPlanEntries = <({Strand strand, SubStrand subStrand, int allocatedLessons, int offset})>[];

    if (assignedSubStrands != null && assignedSubStrands.isNotEmpty) {
      for (final assign in assignedSubStrands) {
        final strand = strands.firstWhere(
          (s) => s.id == assign.strandId,
          orElse: () => Strand(id: assign.strandId, subjectId: subject.id, name: 'Curriculum Strand'),
        );
        final subStrand = strand.subStrands.firstWhere(
          (ss) => ss.id == assign.subStrandId,
          orElse: () => SubStrand(id: assign.subStrandId, strandId: assign.strandId, name: 'Curriculum Topic', suggestedLessons: assign.allocatedLessons),
        );
        rawPlanEntries.add((
          strand: strand,
          subStrand: subStrand,
          allocatedLessons: assign.allocatedLessons,
          offset: assign.lessonOffset,
        ));
      }
    } else {
      // Single term: use all available strands/sub-strands
      for (final strand in strands) {
        for (final subStrand in strand.subStrands) {
          final suggested = max(1, subStrand.suggestedLessons > 0 ? subStrand.suggestedLessons : 3);
          rawPlanEntries.add((
            strand: strand,
            subStrand: subStrand,
            allocatedLessons: suggested,
            offset: 0,
          ));
        }
      }
    }

    // Section 5.3: Zero Blank Slots & Proportional Scaling
    var scaledPlanEntries = rawPlanEntries;
    final initialLessonsSum = rawPlanEntries.fold<int>(0, (s, e) => s + e.allocatedLessons);

    if (initialLessonsSum > 0 && regularSlotsCount > 0) {
      var assignedSum = 0;
      final tempScaled = <({Strand strand, SubStrand subStrand, int allocatedLessons, int offset})>[];

      for (final e in rawPlanEntries) {
        final proportional = ((e.allocatedLessons / initialLessonsSum) * regularSlotsCount).round().clamp(1, 999);
        assignedSum += proportional;
        tempScaled.add((
          strand: e.strand,
          subStrand: e.subStrand,
          allocatedLessons: proportional,
          offset: e.offset,
        ));
      }

      var diff = regularSlotsCount - assignedSum;
      var ptr = 0;
      while (diff != 0 && tempScaled.isNotEmpty) {
        final cur = tempScaled[ptr % tempScaled.length];
        if (diff > 0) {
          tempScaled[ptr % tempScaled.length] = (
            strand: cur.strand,
            subStrand: cur.subStrand,
            allocatedLessons: cur.allocatedLessons + 1,
            offset: cur.offset,
          );
          diff -= 1;
        } else if (cur.allocatedLessons > 1) {
          tempScaled[ptr % tempScaled.length] = (
            strand: cur.strand,
            subStrand: cur.subStrand,
            allocatedLessons: cur.allocatedLessons - 1,
            offset: cur.offset,
          );
          diff += 1;
        }
        ptr += 1;
        if (ptr > 500) break;
      }
      scaledPlanEntries = tempScaled;
    }

    // Pre-fetch content banks for all sub-strands
    final bankMap = <String, SubStrandBank>{};
    for (final entry in scaledPlanEntries) {
      if (!bankMap.containsKey(entry.subStrand.id)) {
        bankMap[entry.subStrand.id] = await curriculum.getContentBankForSubStrand(
          subStrandId: entry.subStrand.id,
          referenceBookId: referenceBook?.id,
        );
      }
    }

    final List<SchemeRow> generatedRows = [];
    var planEntryIndex = 0;
    var lessonInCurrentSubStrand = 0;

    for (int slotIdx = 0; slotIdx < totalSlots; slotIdx++) {
      final slotInfo = CalendarUtils.getWeekAndLesson(slotIdx, lpw);
      final isHalfTerm = slotInfo.week == resolvedHalfTermWeek;
      final isAssessment = resolvedAssessmentWeeks.contains(slotInfo.week);

      // Section 5.4: Ministry Milestone Rows
      if (isHalfTerm) {
        generatedRows.add(
          SchemeRow(
            id: 'guest-${_uuid.v4()}-r$slotIdx',
            weekNumber: slotInfo.week,
            lessonNumber: slotInfo.lesson,
            strandId: null,
            subStrandId: null,
            strandName: 'HALF TERM BREAK',
            subStrandName: 'MID-TERM BREAK',
            learningOutcomeIds: [],
            keyInquiryQuestionIds: [],
            learningExperienceIds: [],
            learningResourceIds: [],
            assessmentMethodIds: [],
            learningOutcomes: ['Mid-Term Break'],
            keyInquiryQuestions: [],
            learningExperiences: [],
            learningResources: [],
            assessmentMethods: [],
            reflections: 'HALF TERM BREAK',
            position: slotIdx,
            milestoneType: MilestoneType.halfTerm,
          ),
        );
        continue;
      }

      if (isAssessment) {
        generatedRows.add(
          SchemeRow(
            id: 'guest-${_uuid.v4()}-r$slotIdx',
            weekNumber: slotInfo.week,
            lessonNumber: slotInfo.lesson,
            strandId: null,
            subStrandId: null,
            strandName: 'ASSESSMENT & REVISION',
            subStrandName: 'END OF TERM EVALUATION',
            learningOutcomeIds: [],
            keyInquiryQuestionIds: [],
            learningExperienceIds: [],
            learningResourceIds: [],
            assessmentMethodIds: defaultAssessmentIds,
            learningOutcomes: formatOutcomes(['Revise, consolidate, and assess key competencies learned throughout the term.']),
            keyInquiryQuestions: formatQuestions(['What learning concepts have been mastered?']),
            learningExperiences: formatBullets(['Learners take end of term assessment tests, review portfolios, and self-evaluate.']),
            learningResources: formatBullets(['Assessment papers, Questionnaires, Rubrics, Learners portfolios']),
            assessmentMethods: formatBullets(defaultAssessmentNames),
            reflections: 'ASSESSMENT / EVALUATION',
            position: slotIdx,
            milestoneType: MilestoneType.assessment,
          ),
        );
        continue;
      }

      // Regular Teaching Slot
      if (scaledPlanEntries.isEmpty) {
        // Fallback when no curriculum data exists
        generatedRows.add(
          SchemeRow(
            id: 'guest-${_uuid.v4()}-r$slotIdx',
            weekNumber: slotInfo.week,
            lessonNumber: slotInfo.lesson,
            strandId: null,
            subStrandId: null,
            strandName: 'General Learning',
            subStrandName: 'Core Competencies',
            learningOutcomeIds: [],
            keyInquiryQuestionIds: [],
            learningExperienceIds: [],
            learningResourceIds: [],
            assessmentMethodIds: defaultAssessmentIds,
            learningOutcomes: formatOutcomes(['Identify and apply core competencies.']),
            keyInquiryQuestions: formatQuestions(['How is this applied?']),
            learningExperiences: formatBullets(['Learners engage in interactive learning activities.']),
            learningResources: formatBullets(['Textbooks, Charts, Realia']),
            assessmentMethods: formatBullets(defaultAssessmentNames),
            reflections: '',
            position: slotIdx,
          ),
        );
        continue;
      }

      // Advance to next entry if needed
      while (planEntryIndex < scaledPlanEntries.length &&
          lessonInCurrentSubStrand >= scaledPlanEntries[planEntryIndex].allocatedLessons) {
        planEntryIndex++;
        lessonInCurrentSubStrand = 0;
      }

      // If we reached the end of entries, loop or stay on last
      final currentEntry = planEntryIndex < scaledPlanEntries.length
          ? scaledPlanEntries[planEntryIndex]
          : scaledPlanEntries.last;

      final strand = currentEntry.strand;
      final subStrand = currentEntry.subStrand;
      final totalLessonsForSub = currentEntry.allocatedLessons;
      final effectiveLessonIdx = currentEntry.offset + lessonInCurrentSubStrand;

      final bank = bankMap[subStrand.id] ?? (
        outcomes: <LearningOutcome>[],
        questions: <KeyInquiryQuestion>[],
        experiences: <LearningExperience>[],
        resources: <LearningResource>[],
        assessments: <AssessmentMethod>[],
      );

      var outcomes = bank.outcomes;
      if (referenceBook != null && referenceBook.id.isNotEmpty) {
        final specific = outcomes.where((o) => o.referenceBookId == referenceBook.id).toList();
        if (specific.isNotEmpty) outcomes = specific;
      }

      var questions = bank.questions;
      if (referenceBook != null && referenceBook.id.isNotEmpty) {
        final specific = questions.where((q) => q.referenceBookId == referenceBook.id).toList();
        if (specific.isNotEmpty) questions = specific;
      }

      var experiences = bank.experiences;
      if (referenceBook != null && referenceBook.id.isNotEmpty) {
        final specific = experiences.where((e) => e.referenceBookId == referenceBook.id).toList();
        if (specific.isNotEmpty) experiences = specific;
      }

      var resources = bank.resources;
      if (referenceBook != null && referenceBook.id.isNotEmpty) {
        final specific = resources.where((r) => r.referenceBookId == referenceBook.id).toList();
        if (specific.isNotEmpty) resources = specific;
      }

      final resourceIds = resources.map((r) => r.id).toList();
      final resourceTexts = formatBullets(resources.map((r) => r.title).toList());

      List<String> rowOutcomeIds;
      List<String> rawOutcomeTexts;
      List<String> rowQuestionIds;
      List<String> rawQuestionTexts;
      List<String> rowExperienceIds;
      List<String> rawExperienceTexts;

      if (pacingMode == 'progressive') {
        final outcomeIdxs = distributeContentIds(
          List.generate(outcomes.length, (i) => i.toString()),
          effectiveLessonIdx,
          max(1, totalLessonsForSub),
        );
        final pickedOutcomes = outcomeIdxs.map((s) => outcomes[int.parse(s)]).toList();
        rowOutcomeIds = pickedOutcomes.map((o) => o.id).toList();
        rawOutcomeTexts = pickedOutcomes.map((o) => o.content).toList();

        final questionIdxs = distributeContentIds(
          List.generate(questions.length, (i) => i.toString()),
          effectiveLessonIdx,
          max(1, totalLessonsForSub),
        );
        final pickedQuestions = questionIdxs.map((s) => questions[int.parse(s)]).toList();
        rowQuestionIds = pickedQuestions.map((q) => q.id).toList();
        rawQuestionTexts = pickedQuestions.map((q) => q.question).toList();

        final expIdxs = distributeContentIds(
          List.generate(experiences.length, (i) => i.toString()),
          effectiveLessonIdx,
          max(1, totalLessonsForSub),
        );
        final pickedExp = expIdxs.map((s) => experiences[int.parse(s)]).toList();
        rowExperienceIds = pickedExp.map((e) => e.id).toList();
        rawExperienceTexts = pickedExp.map((e) => e.description).toList();
      } else {
        rowOutcomeIds = outcomes.map((o) => o.id).toList();
        rawOutcomeTexts = outcomes.map((o) => o.content).toList();

        rowQuestionIds = questions.map((q) => q.id).toList();
        rawQuestionTexts = questions.map((q) => q.question).toList();

        rowExperienceIds = experiences.map((e) => e.id).toList();
        rawExperienceTexts = experiences.map((e) => e.description).toList();
      }

      final row = SchemeRow(
        id: 'guest-${_uuid.v4()}-r$slotIdx',
        weekNumber: slotInfo.week,
        lessonNumber: slotInfo.lesson,
        strandId: strand.id,
        subStrandId: subStrand.id,
        strandName: strand.name,
        subStrandName: subStrand.name,
        learningOutcomeIds: rowOutcomeIds,
        keyInquiryQuestionIds: rowQuestionIds,
        learningExperienceIds: rowExperienceIds,
        learningResourceIds: resourceIds,
        assessmentMethodIds: defaultAssessmentIds,
        learningOutcomes: formatOutcomes(rawOutcomeTexts),
        keyInquiryQuestions: formatQuestions(rawQuestionTexts),
        learningExperiences: formatBullets(rawExperienceTexts),
        learningResources: resourceTexts,
        assessmentMethods: formatBullets(defaultAssessmentNames),
        reflections: '',
        position: slotIdx,
      );

      generatedRows.add(row);
      lessonInCurrentSubStrand++;
    }

    // Cache teacher profile
    await GuestStorageService.instance.saveTeacherProfile(
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
    );

    final supabase = SupabaseService.instance;

    // 5. Authenticated flow: Insert directly to Postgres
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
          'is_paid': false,
          if (bundleId != null) 'bundle_id': bundleId,
        }).select().single();

        final createdSchemeId = schemeRes['id'] as String;
        final rowsToInsert = generatedRows.map((r) => r.toPostgresPayload(createdSchemeId)).toList();

        if (rowsToInsert.isNotEmpty) {
          await supabase.client.from('scheme_rows').insert(rowsToInsert);
        }

        return Scheme.fromJson(schemeRes, rows: generatedRows).copyWith(
          bundleId: bundleId,
          bundleTerms: bundleTerms,
        );
      } catch (e) {
        // Fallback to guest storage if cloud insert fails
      }
    }

    // Guest Flow: Store in local GuestStorageService
    final guestId = 'guest-${_uuid.v4()}';
    final guestScheme = GuestScheme(
      id: guestId,
      createdAt: DateTime.now().toIso8601String(),
      gradeId: grade.id,
      subjectId: subject.id,
      referenceBookId: referenceBook?.id,
      termName: termName,
      year: year,
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
      isPaid: false,
      bundleId: bundleId,
      bundleTerms: bundleTerms,
      gradeName: grade.name,
      subjectName: subject.name,
      referenceBookTitle: referenceBook?.title,
      rows: generatedRows.map(GuestRow.fromSchemeRow).toList(),
    );

    await GuestStorageService.instance.saveGuestScheme(guestScheme);
    return guestScheme.toScheme();
  }

  /// Multi-Term Academic Bundle Generation (generateMultiTermBundle) Section 5.5
  /// Generates Term 1, Term 2, and Term 3 in a single batch linked by a shared bundleId
  static Future<List<Scheme>> generateMultiTermBundle({
    required Grade grade,
    required Subject subject,
    ReferenceBook? referenceBook,
    required int year,
    required int lessonsPerWeek,
    String pacingMode = 'progressive',
    Map<int, List<TermSubStrandAssignment>>? customAssignments,
    Map<int, TermSettings>? customTermSettings,
    String? schoolName,
    String? teacherName,
    String? tscNumber,
    String? hodName,
  }) async {
    final curriculum = CurriculumService.instance;
    final lpw = lessonsPerWeek > 0 ? lessonsPerWeek : 5;
    final sharedBundleId = 'bundle-${_uuid.v4()}';

    // 1. Resolve sub-strand distribution
    Map<int, List<TermSubStrandAssignment>> distribution;
    if (customAssignments != null && customAssignments.isNotEmpty) {
      distribution = customAssignments;
    } else {
      final strands = await curriculum.getStrandsWithSubStrands(subject.id);
      final strandsMap = strands.map((s) => s.toJson()).toList();
      final subStrandsMap = <Map<String, dynamic>>[];
      for (final s in strands) {
        for (final ss in s.subStrands) {
          subStrandsMap.add(ss.toJson());
        }
      }
      final capacities = getOfficial2026Capacities(lpw);
      distribution = autoDistributeSubStrandsToTerms(
        strands: strandsMap,
        subStrands: subStrandsMap,
        termCapacities: capacities,
      );
    }

    final t1Settings = customTermSettings?[1];
    final t2Settings = customTermSettings?[2];
    final t3Settings = customTermSettings?[3];

    // Placeholder bundle terms info
    final bundleTerms = [
      BundleTermInfo(termNumber: 1, schemeId: '', termName: 'Term 1'),
      BundleTermInfo(termNumber: 2, schemeId: '', termName: 'Term 2'),
      BundleTermInfo(termNumber: 3, schemeId: '', termName: 'Term 3'),
    ];

    // 4. Generate Term 1
    final t1Weeks = t1Settings?.weeks ?? 13;
    final t1Lpw = t1Settings?.lessonsPerWeek ?? lpw;
    final term1Scheme = await generateScheme(
      grade: grade,
      subject: subject,
      referenceBook: referenceBook,
      termName: 'Term 1',
      year: year,
      weeks: t1Weeks,
      lessonsPerWeek: t1Lpw,
      pacingMode: pacingMode,
      halfTermWeek: t1Settings != null ? (t1Settings.includeHalfTerm ? t1Settings.halfTermWeek : null) : 8,
      assessmentWeeks: t1Settings?.assessmentWeeks ?? [t1Weeks],
      assignedSubStrands: distribution[1] ?? [],
      bundleId: sharedBundleId,
      bundleTerms: bundleTerms,
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
    );

    // 5. Generate Term 2
    final t2Weeks = t2Settings?.weeks ?? 14;
    final t2Lpw = t2Settings?.lessonsPerWeek ?? lpw;
    final term2Scheme = await generateScheme(
      grade: grade,
      subject: subject,
      referenceBook: referenceBook,
      termName: 'Term 2',
      year: year,
      weeks: t2Weeks,
      lessonsPerWeek: t2Lpw,
      pacingMode: pacingMode,
      halfTermWeek: t2Settings != null ? (t2Settings.includeHalfTerm ? t2Settings.halfTermWeek : null) : 8,
      assessmentWeeks: t2Settings?.assessmentWeeks ?? [t2Weeks],
      assignedSubStrands: distribution[2] ?? [],
      bundleId: sharedBundleId,
      bundleTerms: bundleTerms,
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
    );

    // 6. Generate Term 3
    final t3Weeks = t3Settings?.weeks ?? 9;
    final t3Lpw = t3Settings?.lessonsPerWeek ?? lpw;
    final term3Scheme = await generateScheme(
      grade: grade,
      subject: subject,
      referenceBook: referenceBook,
      termName: 'Term 3',
      year: year,
      weeks: t3Weeks,
      lessonsPerWeek: t3Lpw,
      pacingMode: pacingMode,
      halfTermWeek: t3Settings != null ? (t3Settings.includeHalfTerm ? t3Settings.halfTermWeek : null) : 6,
      assessmentWeeks: t3Settings?.assessmentWeeks ?? [t3Weeks],
      assignedSubStrands: distribution[3] ?? [],
      bundleId: sharedBundleId,
      bundleTerms: bundleTerms,
      schoolName: schoolName,
      teacherName: teacherName,
      tscNumber: tscNumber,
      hodName: hodName,
    );

    // 7. Update companion scheme IDs in bundleTerms
    final completedBundleTerms = [
      BundleTermInfo(termNumber: 1, schemeId: term1Scheme.id, termName: 'Term 1'),
      BundleTermInfo(termNumber: 2, schemeId: term2Scheme.id, termName: 'Term 2'),
      BundleTermInfo(termNumber: 3, schemeId: term3Scheme.id, termName: 'Term 3'),
    ];

    final updated1 = term1Scheme.copyWith(bundleTerms: completedBundleTerms);
    final updated2 = term2Scheme.copyWith(bundleTerms: completedBundleTerms);
    final updated3 = term3Scheme.copyWith(bundleTerms: completedBundleTerms);

    // Save updated bundleTerms in local storage
    if (term1Scheme.id.startsWith('guest-')) {
      await GuestStorageService.instance.saveGuestScheme(updated1.toGuestScheme());
    }
    if (term2Scheme.id.startsWith('guest-')) {
      await GuestStorageService.instance.saveGuestScheme(updated2.toGuestScheme());
    }
    if (term3Scheme.id.startsWith('guest-')) {
      await GuestStorageService.instance.saveGuestScheme(updated3.toGuestScheme());
    }

    return [updated1, updated2, updated3];
  }
}
