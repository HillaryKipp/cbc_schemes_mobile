/// Application configuration and environment constants
class AppConfig {
  static const String appName = 'CBC Schemes of Work';
  static const String appVersion = '1.0.0';
  static const String adminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'admin@cbcschemes.app',
  );
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@cbcschemes.app',
  );

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://woaibqmgrqlvcduvmtpc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_gTNgTe0IjvAF-0tX697z-Q_Un_HXcdm',
  );

  // Storage Keys
  static const String guestSchemesKey = 'cbc_guest_schemes';
  static const String userThemeKey = 'cbc_theme_mode';
  static const String teacherProfileKey = 'cbc_teacher_profile';
  static const String userAccountKey = 'cbc_user_account';
  static const String userCloudSchemesKey = 'cbc_user_cloud_schemes';

  // Auth Redirect Scheme
  static const String authRedirectUri = 'app.cbcschemes://login-callback';
}
