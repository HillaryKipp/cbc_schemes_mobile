/// Application configuration and environment constants
class AppConfig {
  static const String appName = 'CBC Schemes of Work';
  static const String appVersion = '1.0.0';
  static const String adminEmail = 'ruttohkip4@gmail.com';

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
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
