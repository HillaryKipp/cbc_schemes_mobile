import 'package:flutter/foundation.dart';
import '../models/scheme.dart';
import '../models/guest_scheme.dart';
import '../services/guest_storage_service.dart';
import '../services/scheme_sync_service.dart';
import '../services/supabase_service.dart';

class SchemeListProvider extends ChangeNotifier {
  final _guestStorage = GuestStorageService.instance;
  final _syncService = SchemeSyncService.instance;
  final _supabase = SupabaseService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<GuestScheme> _guestSchemes = [];
  List<GuestScheme> get guestSchemes => _guestSchemes;

  List<Scheme> _cloudSchemes = [];
  List<Scheme> get cloudSchemes => _cloudSchemes;

  /// All schemes combined (cloud first, then local guest schemes converted to Scheme)
  List<Scheme> get allSchemes {
    final list = <Scheme>[..._cloudSchemes];
    for (final g in _guestSchemes) {
      list.add(g.toScheme());
    }
    return list;
  }

  SchemeListProvider() {
    loadSchemes();
  }

  Future<void> loadSchemes() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load local guest schemes
      _guestSchemes = _guestStorage.getGuestSchemes();

      // 2. Load cloud schemes if user is signed in
      if (_supabase.isAuthenticated) {
        _cloudSchemes = await _syncService.fetchUserSchemes();
      } else {
        _cloudSchemes = [];
      }
    } catch (e) {
      debugPrint('Error loading schemes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Claim a guest scheme and migrate it to user's Supabase account
  Future<String?> claimScheme(GuestScheme guestScheme) async {
    if (!_supabase.isAuthenticated) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final newSchemeId = await _syncService.claimGuestScheme(guestScheme);
      await loadSchemes();
      return newSchemeId;
    } catch (e) {
      debugPrint('Error claiming scheme: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a scheme
  Future<void> deleteScheme(String schemeId, {required bool isGuest}) async {
    await _syncService.deleteScheme(schemeId, isGuest);
    await loadSchemes();
  }
}
