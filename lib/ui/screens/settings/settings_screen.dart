import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/theme.dart';
import '../../../services/guest_storage_service.dart';
import '../../../state/auth_provider.dart';
import '../auth/auth_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _guestStorage = GuestStorageService.instance;

  final _schoolController = TextEditingController();
  final _teacherController = TextEditingController();
  final _tscController = TextEditingController();
  final _hodController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final cached = _guestStorage.getTeacherProfile();
    _schoolController.text = cached['school_name'] ?? '';
    _teacherController.text = cached['teacher_name'] ?? '';
    _tscController.text = cached['tsc_number'] ?? '';
    _hodController.text = cached['hod_name'] ?? '';
  }

  Future<void> _saveProfile() async {
    await _guestStorage.saveTeacherProfile(
      schoolName: _schoolController.text.trim(),
      teacherName: _teacherController.text.trim(),
      tscNumber: _tscController.text.trim(),
      hodName: _hodController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teacher Profile saved! Will auto-fill upcoming schemes.')),
    );
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _teacherController.dispose();
    _tscController.dispose();
    _hodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: authProvider.isGuest
                            ? const Color(0xFFFEF3C7)
                            : AppTheme.primaryEmerald.withOpacity(0.12),
                        child: Icon(
                          authProvider.isGuest ? Icons.person_outline : Icons.verified_user_rounded,
                          color: authProvider.isGuest ? AppTheme.accentGold : AppTheme.primaryEmerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authProvider.isGuest ? 'Guest Mode (Offline)' : 'Signed In',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                            Text(
                              authProvider.isGuest
                                  ? 'Schemes saved locally on device'
                                  : authProvider.userEmail,
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: authProvider.isGuest
                        ? OutlinedButton.icon(
                            onPressed: () => AuthModal.show(context),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Sign In / Create Account'),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => authProvider.signOut(),
                            icon: const Icon(Icons.logout, size: 18, color: AppTheme.errorRed),
                            label: const Text('Sign Out', style: TextStyle(color: AppTheme.errorRed)),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Default Teacher Profile Prefills
          const Text('Default Scheme Cover Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('These details will automatically prefill every new scheme you generate.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _schoolController,
                    decoration: const InputDecoration(
                      labelText: 'Default School Name',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _teacherController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tscController,
                          decoration: const InputDecoration(
                            labelText: 'TSC Number',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _hodController,
                          decoration: const InputDecoration(
                            labelText: 'H.O.D Name',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Cover Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // About App Info
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primaryEmerald),
                  title: const Text('About CBC Schemes of Work'),
                  subtitle: const Text('Version ${AppConfig.appVersion} • Kenyan CBC Standard'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined, color: AppTheme.primaryEmerald),
                  title: const Text('Support Email'),
                  subtitle: const Text(AppConfig.adminEmail),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
