/// Application configuration and environment constants
class AppConfig {
  static const String appName = 'CBC Schemes of Work';
  static const String appVersion = '1.0.0';
  static const String adminEmail = 'ruttohkip4@gmail.com';

  // Supabase Configuration
  // Fallbacks provided for compilation; overridden via --dart-define or Supabase init
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  // Storage Keys
  static const String guestSchemesKey = 'cbc_guest_schemes';
  static const String userThemeKey = 'cbc_theme_mode';
  static const String teacherProfileKey = 'cbc_teacher_profile';

  // OAuth Redirect Scheme
  static const String authRedirectUri = 'app.cbcschemes://login-callback';
}
