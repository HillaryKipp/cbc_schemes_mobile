import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/guest_storage_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = SupabaseService.instance;
  final _storage = GuestStorageService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  User? get user => _supabase.currentUser;
  
  Map<String, dynamic>? get localAccount => _storage.getUserAccount();

  bool get isAuthenticated => _supabase.isAuthenticated || localAccount != null;
  bool get isGuest => !isAuthenticated;

  String get userEmail {
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user!.email!;
    }
    if (localAccount != null && localAccount!['email'] != null) {
      return localAccount!['email'] as String;
    }
    return 'Guest Teacher';
  }

  String get userDisplayName {
    if (user?.userMetadata?['full_name'] != null) {
      return user!.userMetadata!['full_name'] as String;
    }
    if (localAccount != null && localAccount!['full_name'] != null) {
      return localAccount!['full_name'] as String;
    }
    final profile = _storage.getTeacherProfile();
    if (profile['teacher_name'] != null && profile['teacher_name']!.isNotEmpty) {
      return profile['teacher_name']!;
    }
    return 'Teacher Account';
  }

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    if (_supabase.isInitialized) {
      _supabase.client.auth.onAuthStateChange.listen((data) async {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) {
          await checkAdminStatus();
        } else if (event == AuthChangeEvent.signedOut) {
          _isAdmin = false;
        }
        notifyListeners();
      });
    }
    checkAdminStatus();
  }

  Future<void> checkAdminStatus() async {
    _isAdmin = await _supabase.checkIsAdmin();
    notifyListeners();
  }

  /// Sign In with Email and Password
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _supabase.signInWithEmail(email, password);
      await checkAdminStatus();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign Up with Email and Password
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
    String? schoolName,
    String? tscNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _supabase.signUpWithEmail(
        email,
        password,
        fullName: fullName,
        schoolName: schoolName,
        tscNumber: tscNumber,
      );
      await checkAdminStatus();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
      debugPrint('Sign up error: $e');
      return false;
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
