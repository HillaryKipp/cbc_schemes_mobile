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
  static const String whatsappSupportNumber = '254734232994';
  static const String supportPhone = '0734232994';

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://woaibqmgrqlvcduvmtpc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_gTNgTe0IjvAF-0tX697z-Q_Un_HXcdm',
  );

  // Backend API URL (for Daraja M-Pesa STK push & payment query functions)
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://cbcschemes.co.ke',
  );

  // Storage Keys (matches web localStorage key cbc:guest-schemes)
  static const String guestSchemesKey = 'cbc:guest-schemes';
  static const String legacyGuestSchemesKey = 'cbc_guest_schemes';
  static const String userThemeKey = 'cbc_theme_mode';
  static const String teacherProfileKey = 'cbc_teacher_profile';
  static const String userAccountKey = 'cbc_user_account';
  static const String userCloudSchemesKey = 'cbc_user_cloud_schemes';

  // Auth Redirect Scheme
  static const String authRedirectUri = 'app.cbcschemes://login-callback';
}
