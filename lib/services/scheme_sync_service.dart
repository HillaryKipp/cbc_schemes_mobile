import 'package:flutter/foundation.dart';
import '../models/scheme.dart';
import '../models/scheme_row.dart';
import '../models/guest_scheme.dart';
import 'supabase_service.dart';
import 'guest_storage_service.dart';

class SchemeSyncService {
  static SchemeSyncService? _instance;
  static SchemeSyncService get instance => _instance ??= SchemeSyncService._();

  SchemeSyncService._();

  final _supabase = SupabaseService.instance;
  final _guestStorage = GuestStorageService.instance;

  /// Claims a local guest scheme and uploads it to Postgres matching Section 3
  Future<String> claimGuestScheme(GuestScheme g) async {
    final user = _supabase.currentUser;
    if (user == null) {
      throw Exception("User must be signed in to save schemes.");
    }

    try {
      final schemeData = await _supabase.client.from('schemes').insert({
        'user_id': user.id,
        'grade_id': g.gradeId,
        'subject_id': g.subjectId,
        'reference_book_id': g.referenceBookId,
        'term_name': g.termName,
        'year': g.year,
        'school_name': g.schoolName,
        'teacher_name': g.teacherName,
        'tsc_number': g.tscNumber,
        'hod_name': g.hodName,
        'is_paid': g.isPaid,
        if (g.bundleId != null) 'bundle_id': g.bundleId,
      }).select('id').single();

      final schemeId = schemeData['id'] as String;

      final rowsPayload = g.rows.map((r) => {
        'scheme_id': schemeId,
        'week_number': r.weekNumber,
        'lesson_number': r.lessonNumber,
        'strand_id': r.strandId,
        'sub_strand_id': r.subStrandId,
        'custom_strand': r.customStrand,
        'custom_sub_strand': r.customSubStrand,
        'custom_outcomes': r.customOutcomes,
        'custom_questions': r.customQuestions,
        'custom_experiences': r.customExperiences,
        'custom_resources': r.customResources,
        'custom_assessments': r.customAssessments,
        'learning_outcome_ids': r.learningOutcomeIds,
        'key_inquiry_question_ids': r.keyInquiryQuestionIds,
        'learning_experience_ids': r.learningExperienceIds,
        'learning_resource_ids': r.learningResourceIds,
        'assessment_method_ids': r.assessmentMethodIds,
        'reflections': r.reflections,
        'position': r.position,
        'milestone_type': r.milestoneType == MilestoneType.halfTerm
            ? 'half_term'
            : r.milestoneType == MilestoneType.assessment
                ? 'assessment'
                : null,
      }).toList();

      if (rowsPayload.isNotEmpty) {
        await _supabase.client.from('scheme_rows').insert(rowsPayload);
      }

      // If a payment was made for this guest scheme, link it to the newly signed-in user
      try {
        await _supabase.client.from('payments').update({
          'user_id': user.id,
          'scheme_id': schemeId,
        }).eq('scheme_id', g.id);
      } catch (e) {
        debugPrint('Note: No payments linked or error linking payment: $e');
      }

      // Remove from local guest storage
      await _guestStorage.removeGuestScheme(g.id);
      debugPrint('Successfully claimed guest scheme ${g.id} -> $schemeId');
      return schemeId;
    } catch (e) {
      debugPrint('Error claiming guest scheme: $e');
      rethrow;
    }
  }

  /// Autosave a modified scheme row (Debounced 600ms caller)
  Future<bool> saveRow({
    required String schemeId,
    required SchemeRow row,
    required bool isGuest,
  }) async {
    try {
      if (isGuest || schemeId.startsWith('guest-')) {
        final guestScheme = _guestStorage.getGuestScheme(schemeId);
        if (guestScheme != null) {
          final guestRow = GuestRow.fromSchemeRow(row);
          final updatedRows = List<GuestRow>.from(guestScheme.rows);
          final index = updatedRows.indexWhere((r) => r.id == row.id);
          if (index >= 0) {
            updatedRows[index] = guestRow;
          } else {
            updatedRows.add(guestRow);
          }
          await _guestStorage.saveGuestScheme(
            guestScheme.copyWith(
              rows: updatedRows,
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          return true;
        }
      } else if (_supabase.isAuthenticated) {
        await _supabase.client
            .from('scheme_rows')
            .update(row.toPostgresPayload(schemeId))
            .eq('id', row.id);
        return true;
      }
    } catch (e) {
      debugPrint('Error autosaving row: $e');
    }
    return false;
  }

  /// Update scheme cover details (School, Teacher, TSC, HOD)
  Future<bool> updateCoverDetails({
    required String schemeId,
    required String? schoolName,
    required String? teacherName,
    required String? tscNumber,
    required String? hodName,
    required bool isGuest,
  }) async {
    try {
      if (isGuest || schemeId.startsWith('guest-')) {
        final guestScheme = _guestStorage.getGuestScheme(schemeId);
        if (guestScheme != null) {
          await _guestStorage.saveGuestScheme(
            guestScheme.copyWith(
              schoolName: schoolName,
              teacherName: teacherName,
              tscNumber: tscNumber,
              hodName: hodName,
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          return true;
        }
      } else if (_supabase.isAuthenticated) {
        await _supabase.client.from('schemes').update({
          'school_name': schoolName,
          'teacher_name': teacherName,
          'tsc_number': tscNumber,
          'hod_name': hodName,
        }).eq('id', schemeId);
        return true;
      }
    } catch (e) {
      debugPrint('Error updating cover details: $e');
    }
    return false;
  }

  /// Delete a scheme
  Future<bool> deleteScheme(String schemeId, bool isGuest) async {
    try {
      if (isGuest || schemeId.startsWith('guest-')) {
        await _guestStorage.removeGuestScheme(schemeId);
        return true;
      } else if (_supabase.isAuthenticated) {
        await _supabase.client.from('schemes').delete().eq('id', schemeId);
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting scheme: $e');
    }
    return false;
  }

  /// Fetch user's saved schemes from Supabase
  Future<List<Scheme>> fetchUserSchemes() async {
    if (!_supabase.isAuthenticated || _supabase.currentUser == null) return [];
    try {
      final res = await _supabase.client
          .from('schemes')
          .select('*, grades(name), subjects(name), reference_books(title), scheme_rows(*)')
          .order('created_at', ascending: false);

      return (res as List).map((json) => Scheme.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching user schemes: $e');
      return [];
    }
  }

  /// Fetch full scheme by id
  Future<Scheme?> fetchSchemeById(String schemeId) async {
    if (schemeId.startsWith('guest-')) {
      final guest = _guestStorage.getGuestScheme(schemeId);
      return guest?.toScheme();
    }

    if (_supabase.isAuthenticated) {
      try {
        final res = await _supabase.client
            .from('schemes')
            .select('*, grades(name), subjects(name), reference_books(title), scheme_rows(*)')
            .eq('id', schemeId)
            .maybeSingle();

        if (res != null) {
          final rowsRaw = res['scheme_rows'] as List<dynamic>? ?? [];
          final rows = rowsRaw
              .map((r) => SchemeRow.fromJson(r as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));
          return Scheme.fromJson(res, rows: rows);
        }
      } catch (e) {
        debugPrint('Error fetching scheme by id: $e');
      }
    }
    return null;
  }
}
