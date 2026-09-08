import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import 'guest_storage_service.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => _isInitialized ? client.auth.currentUser : null;
  bool get isAuthenticated => currentUser != null;

  /// Initialize Supabase
  Future<void> initialize() async {
    if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
      debugPrint('Supabase not configured. Operating in local account & curriculum mode.');
      _isInitialized = false;
      return;
    }
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialization error (will use offline mode): $e');
      _isInitialized = false;
    }
  }

  /// Sign Up with Email and Password
  Future<AuthResponse?> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
    String? schoolName,
    String? tscNumber,
  }) async {
    if (!_isInitialized) {
      // Local fallback account storage
      final localAccount = {
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'email': email.trim().toLowerCase(),
        'full_name': fullName ?? 'Teacher',
        'school_name': schoolName ?? '',
        'tsc_number': tscNumber ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
      await GuestStorageService.instance.saveUserAccount(localAccount);
      if (schoolName != null || fullName != null || tscNumber != null) {
        await GuestStorageService.instance.saveTeacherProfile(
          schoolName: schoolName,
          teacherName: fullName,
          tscNumber: tscNumber,
        );
      }
      return null;
    }

    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName,
          'school_name': schoolName,
          'tsc_number': tscNumber,
        },
      );
      return res;
    } catch (e) {
      debugPrint('Error signing up with email: $e');
      rethrow;
    }
  }

  /// Sign In with Email and Password
  Future<AuthResponse?> signInWithEmail(String email, String password) async {
    if (!_isInitialized) {
      final local = GuestStorageService.instance.getUserAccount();
      if (local != null && local['email'] == email.trim().toLowerCase()) {
        return null;
      }
      // Create/sign into local account
      final localAccount = {
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'email': email.trim().toLowerCase(),
        'full_name': 'Teacher',
        'created_at': DateTime.now().toIso8601String(),
      };
      await GuestStorageService.instance.saveUserAccount(localAccount);
      return null;
    }

    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return res;
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    await GuestStorageService.instance.clearUserAccount();
    if (!_isInitialized) return;
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Check if current user is an Admin via user_roles table or admin email
  Future<bool> checkIsAdmin() async {
    final email = currentUser?.email ?? GuestStorageService.instance.getUserAccount()?['email'];
    if (email?.toLowerCase() == AppConfig.adminEmail.toLowerCase()) {
      return true;
    }
    if (!_isInitialized || currentUser == null) return false;
    try {
      final response = await client
          .from('user_roles')
          .select('role')
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (response != null && response['role'] == 'admin') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking admin role: $e');
      return false;
    }
  }
}
