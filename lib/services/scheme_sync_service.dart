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

  /// Claims a local guest scheme and persists it to the user's Supabase account
  Future<String?> claimGuestScheme(GuestScheme g) async {
    if (!_supabase.isAuthenticated || _supabase.currentUser == null) {
      debugPrint('Cannot claim scheme: user is not authenticated');
      return null;
    }

    try {
      final userId = _supabase.currentUser!.id;

      // Insert scheme header
      final schemeRes = await _supabase.client.from('schemes').insert({
        'user_id': userId,
        'grade_id': g.gradeId,
        'subject_id': g.subjectId,
        'reference_book_id': g.referenceBookId,
        'term_name': g.termName,
        'year': g.year,
        'school_name': g.schoolName,
        'teacher_name': g.teacherName,
        'tsc_number': g.tscNumber,
        'hod_name': g.hodName,
      }).select('id').single();

      final schemeId = schemeRes['id'] as String;

      // Insert scheme rows
      final rowsToInsert = g.rows.map((r) {
        final rowMap = r.toJson();
        rowMap['scheme_id'] = schemeId;
        return rowMap;
      }).toList();

      await _supabase.client.from('scheme_rows').insert(rowsToInsert);

      // Remove guest scheme from local storage
      await _guestStorage.removeGuestScheme(g.id);
      debugPrint('Successfully claimed guest scheme ${g.id} -> $schemeId');
      return schemeId;
    } catch (e) {
      debugPrint('Error claiming guest scheme: $e');
      return null;
    }
  }

  /// Autosave a modified scheme row
  Future<bool> saveRow({
    required String schemeId,
    required SchemeRow row,
    required bool isGuest,
  }) async {
    try {
      if (isGuest || schemeId.startsWith('guest-')) {
        final guestScheme = _guestStorage.getGuestScheme(schemeId);
        if (guestScheme != null) {
          final updatedRows = List<SchemeRow>.from(guestScheme.rows);
          final index = updatedRows.indexWhere((r) => r.id == row.id);
          if (index >= 0) {
            updatedRows[index] = row;
          } else {
            updatedRows.add(row);
          }
          await _guestStorage.saveGuestScheme(
            guestScheme.copyWith(rows: updatedRows, updatedAt: DateTime.now()),
          );
          return true;
        }
      } else if (_supabase.isAuthenticated) {
        await _supabase.client
            .from('scheme_rows')
            .update(row.toJson())
            .eq('id', row.id);
        return true;
      }
    } catch (e) {
      debugPrint('Error autosaving row: $e');
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
