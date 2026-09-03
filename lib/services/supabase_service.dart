import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';

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

  /// Sign In with Google OAuth
  Future<bool> signInWithGoogle() async {
    if (!_isInitialized) return false;
    try {
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.authRedirectUri,
      );
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return false;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    if (!_isInitialized) return;
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Check if current user is an Admin via user_roles table
  Future<bool> checkIsAdmin() async {
    if (!_isInitialized || currentUser == null) return false;
    try {
      // Special check for hardcoded admin email or database role
      if (currentUser?.email?.toLowerCase() == AppConfig.adminEmail.toLowerCase()) {
        return true;
      }
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
      return currentUser?.email?.toLowerCase() == AppConfig.adminEmail.toLowerCase();
    }
  }
}
