import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = SupabaseService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? get user => _supabase.currentUser;
  bool get isAuthenticated => _supabase.isAuthenticated;
  bool get isGuest => !isAuthenticated;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    if (!_supabase.isInitialized) return;
    _supabase.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) {
        await checkAdminStatus();
      } else if (event == AuthChangeEvent.signedOut) {
        _isAdmin = false;
      }
      notifyListeners();
    });
    checkAdminStatus();
  }

  Future<void> checkAdminStatus() async {
    _isAdmin = await _supabase.checkIsAdmin();
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _supabase.signInWithGoogle();
      await checkAdminStatus();
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.signOut();
      _isAdmin = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
