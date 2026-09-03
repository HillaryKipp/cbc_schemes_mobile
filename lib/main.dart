import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/config/theme.dart';
import 'services/guest_storage_service.dart';
import 'services/supabase_service.dart';
import 'state/auth_provider.dart';
import 'state/scheme_editor_provider.dart';
import 'state/scheme_list_provider.dart';
import 'ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize Local Guest Storage
  await GuestStorageService.instance.init();

  // Initialize Supabase Backend
  await SupabaseService.instance.initialize();

  runApp(const CbcSchemesApp());
}

class CbcSchemesApp extends StatelessWidget {
  const CbcSchemesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SchemeListProvider()),
        ChangeNotifierProvider(create: (_) => SchemeEditorProvider()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
