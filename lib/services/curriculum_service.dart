import 'package:flutter/foundation.dart';
import '../models/grade.dart';
import '../models/subject.dart';
import '../models/strand.dart';
import '../models/reference_book.dart';
import '../models/content_bank.dart';
import '../models/term_template.dart';
import '../models/app_settings.dart';
import 'supabase_service.dart';
import 'seed_data.dart';

class CurriculumService {
  static CurriculumService? _instance;
  static CurriculumService get instance => _instance ??= CurriculumService._();

  CurriculumService._();

  final _supabase = SupabaseService.instance;
  List<Grade> _cachedGrades = [];

  bool _isUuid(String id) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  }

  /// Fetch all grades
  Future<List<Grade>> getGrades() async {
    if (_supabase.isInitialized) {
      try {
        final res = await _supabase.client
            .from('grades')
            .select()
            .order('order_index', ascending: true);
        if (res.isNotEmpty) {
          _cachedGrades = (res as List).map((e) => Grade.fromJson(e as Map<String, dynamic>)).toList();
          return _cachedGrades;
        }
      } catch (e) {
        debugPrint('Error loading grades from Supabase: $e');
      }
    }
    _cachedGrades = SeedData.defaultGrades;
    return _cachedGrades;
  }

  /// Fetch subjects for a specific grade
  Future<List<Subject>> getSubjects(String gradeId, {Grade? grade}) async {
    if (_supabase.isInitialized) {
      if (_isUuid(gradeId)) {
        try {
          final res = await _supabase.client
              .from('subjects')
              .select()
              .eq('grade_id', gradeId)
              .order('order_index', ascending: true);
          return (res as List).map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
        } catch (e) {
          debugPrint('Error loading subjects from Supabase: $e');
          return [];
        }
      }
      return [];
    }

    // Resolve grade from argument, cache, or seed data to ensure grade-level accuracy (Offline/Mock only)
    Grade? resolvedGrade = grade;
    if (resolvedGrade == null) {
      for (final g in _cachedGrades) {
        if (g.id == gradeId) {
          resolvedGrade = g;
          break;
        }
      }
    }
    if (resolvedGrade == null) {
      for (final g in SeedData.defaultGrades) {
        if (g.id == gradeId) {
          resolvedGrade = g;
          break;
        }
      }
    }

    return SeedData.getSubjectsForGrade(gradeId: gradeId, grade: resolvedGrade);
  }

  /// Fetch reference books for a subject
  Future<List<ReferenceBook>> getReferenceBooks(String subjectId) async {
    if (_supabase.isInitialized && _isUuid(subjectId)) {
      try {
        final res = await _supabase.client
            .from('reference_books')
            .select()
            .eq('subject_id', subjectId);
        if (res.isNotEmpty) {
          return (res as List).map((e) => ReferenceBook.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Error loading reference books: $e');
      }
    }
    final filtered = SeedData.defaultReferenceBooks.where((b) => b.subjectId == subjectId).toList();
    if (filtered.isNotEmpty) return filtered;
    return [
      ReferenceBook(
        id: 'book-$subjectId-klb',
        subjectId: subjectId,
        title: 'KLB Top Mark Curriculum Course Book',
        publisher: 'Kenya Literature Bureau (KLB)',
        edition: 'KICD Approved',
      ),
      ReferenceBook(
        id: 'book-$subjectId-oxford',
        subjectId: subjectId,
        title: 'Oxford Headstart Series',
        publisher: 'Oxford University Press',
        edition: 'KICD Approved',
      ),
      ReferenceBook(
        id: 'book-$subjectId-longhorn',
        subjectId: subjectId,
        title: 'Longhorn Active Learning Series',
        publisher: 'Longhorn Publishers',
        edition: 'KICD Approved',
      ),
    ];
  }

  /// Fetch strands and sub-strands ordered by order_index
  Future<List<Strand>> getStrandsWithSubStrands(String subjectId) async {
    if (_supabase.isInitialized && _isUuid(subjectId)) {
      try {
        final strandsRes = await _supabase.client
            .from('strands')
            .select('*, sub_strands(*)')
            .eq('subject_id', subjectId)
            .order('order_index', ascending: true);

        if (strandsRes.isNotEmpty) {
          return (strandsRes as List).map((strandJson) {
            final subStrandsRaw = strandJson['sub_strands'] as List<dynamic>? ?? [];
            final subStrands = subStrandsRaw
                .map((s) => SubStrand.fromJson(s as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            return Strand.fromJson(strandJson as Map<String, dynamic>, subStrands: subStrands);
          }).toList();
        }
      } catch (e) {
        debugPrint('Error loading strands with sub-strands: $e');
      }
    }
    final filtered = SeedData.defaultStrands.where((s) => s.subjectId == subjectId).toList();
    if (filtered.isNotEmpty) return filtered;
    return SeedData.defaultStrands;
  }

  /// Fetch Content Banks for a given SubStrand
  Future<({
    List<LearningOutcome> outcomes,
    List<KeyInquiryQuestion> questions,
    List<LearningExperience> experiences,
    List<LearningResource> resources,
    List<AssessmentMethod> assessments,
  })> getContentBankForSubStrand({
    required String subStrandId,
    String? referenceBookId,
  }) async {
    if (_supabase.isInitialized && _isUuid(subStrandId)) {
      try {
        final outcomesFuture = _supabase.client.from('learning_outcomes').select().eq('sub_strand_id', subStrandId);
        final questionsFuture = _supabase.client.from('key_inquiry_questions').select().eq('sub_strand_id', subStrandId);
        final expFuture = _supabase.client.from('learning_experiences').select().eq('sub_strand_id', subStrandId);
        final resFuture = _supabase.client.from('learning_resources').select().eq('sub_strand_id', subStrandId);
        final asmFuture = _supabase.client.from('assessment_methods').select();

        final results = await Future.wait([
          outcomesFuture,
          questionsFuture,
          expFuture,
          resFuture,
          asmFuture,
        ]);

        return (
          outcomes: (results[0] as List).map((e) => LearningOutcome.fromJson(e as Map<String, dynamic>)).toList(),
          questions: (results[1] as List).map((e) => KeyInquiryQuestion.fromJson(e as Map<String, dynamic>)).toList(),
          experiences: (results[2] as List).map((e) => LearningExperience.fromJson(e as Map<String, dynamic>)).toList(),
          resources: (results[3] as List).map((e) => LearningResource.fromJson(e as Map<String, dynamic>)).toList(),
          assessments: (results[4] as List).map((e) => AssessmentMethod.fromJson(e as Map<String, dynamic>)).toList(),
        );
      } catch (e) {
        debugPrint('Error loading sub-strand content bank from Supabase: $e');
      }
    }

    // Offline / Seed Fallback
    final outcomes = SeedData.defaultOutcomes.where((o) => o.subStrandId == subStrandId).toList();
    final questions = SeedData.defaultQuestions.where((q) => q.subStrandId == subStrandId).toList();
    final experiences = SeedData.defaultExperiences.where((e) => e.subStrandId == subStrandId).toList();
    final resources = SeedData.defaultResources.where((r) => r.subStrandId == subStrandId).toList();
    final assessments = SeedData.defaultAssessments;

    return (
      outcomes: outcomes.isNotEmpty ? outcomes : [
        LearningOutcome(
          id: 'out-gen-$subStrandId',
          subStrandId: subStrandId,
          content: 'By the end of the lesson, the learner should be able to: demonstrate core concepts, solve practical problems, and appreciate CBC values.',
        ),
      ],
      questions: questions.isNotEmpty ? questions : [
        KeyInquiryQuestion(
          id: 'kiq-gen-$subStrandId',
          subStrandId: subStrandId,
          question: 'How does this concept apply in real-life Kenyan situations?',
        ),
      ],
      experiences: experiences.isNotEmpty ? experiences : [
        LearningExperience(
          id: 'exp-gen-$subStrandId',
          subStrandId: subStrandId,
          description: 'Learners work in collaborative groups using charts, concrete objects, and digital resources to explore key ideas.',
        ),
      ],
      resources: resources.isNotEmpty ? resources : [
        LearningResource(
          id: 'res-gen-$subStrandId',
          subStrandId: subStrandId,
          title: 'KICD Curriculum Designs, Approved Course Books, Charts, Realia',
        ),
      ],
      assessments: assessments,
    );
  }

  /// Fetch Term Templates
  Future<List<TermTemplate>> getTermTemplates() async {
    if (_supabase.isInitialized) {
      try {
        final res = await _supabase.client
            .from('term_templates')
            .select()
            .order('year', ascending: false);
        if (res.isNotEmpty) {
          return (res as List).map((e) => TermTemplate.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Error loading term templates: $e');
      }
    }
    return SeedData.defaultTermTemplates;
  }

  /// Fetch App Settings (payments, ads, pricing)
  Future<AppSettings> getAppSettings() async {
    if (_supabase.isInitialized) {
      try {
        final res = await _supabase.client
            .from('app_settings')
            .select()
            .limit(1)
            .maybeSingle();
        if (res != null) {
          return AppSettings.fromJson(res);
        }
      } catch (e) {
        debugPrint('Error loading app settings: $e');
      }
    }
    return SeedData.defaultAppSettings;
  }

  // -------------------------------------------------------------
  // ADMIN CRUD OPERATIONS (Authenticated Supabase / Local Fallback)
  // -------------------------------------------------------------

  /// Create or Update Grade
  Future<bool> saveGrade(Grade grade) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('grades').upsert(grade.toJson());
        return true;
      } catch (e) {
        debugPrint('Error saving grade: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Delete Grade
  Future<bool> deleteGrade(String gradeId) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('grades').delete().eq('id', gradeId);
        return true;
      } catch (e) {
        debugPrint('Error deleting grade: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Create or Update Subject
  Future<bool> saveSubject(Subject subject) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('subjects').upsert(subject.toJson());
        return true;
      } catch (e) {
        debugPrint('Error saving subject: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Delete Subject
  Future<bool> deleteSubject(String subjectId) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('subjects').delete().eq('id', subjectId);
        return true;
      } catch (e) {
        debugPrint('Error deleting subject: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Create or Update Strand
  Future<bool> saveStrand(Strand strand) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('strands').upsert(strand.toJson());
        return true;
      } catch (e) {
        debugPrint('Error saving strand: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Delete Strand
  Future<bool> deleteStrand(String strandId) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('strands').delete().eq('id', strandId);
        return true;
      } catch (e) {
        debugPrint('Error deleting strand: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Create or Update SubStrand
  Future<bool> saveSubStrand(SubStrand subStrand) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('sub_strands').upsert(subStrand.toJson());
        return true;
      } catch (e) {
        debugPrint('Error saving sub_strand: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Delete SubStrand
  Future<bool> deleteSubStrand(String subStrandId) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('sub_strands').delete().eq('id', subStrandId);
        return true;
      } catch (e) {
        debugPrint('Error deleting sub_strand: $e');
        rethrow;
      }
    }
    return false;
  }

  /// Save App Settings
  Future<bool> saveAppSettings(AppSettings settings) async {
    if (_supabase.isInitialized && _supabase.isAuthenticated) {
      try {
        await _supabase.client.from('app_settings').upsert(settings.toJson());
        return true;
      } catch (e) {
        debugPrint('Error saving app settings: $e');
        rethrow;
      }
    }
    return false;
  }
}
