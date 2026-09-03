import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/theme.dart';
import '../../../services/guest_storage_service.dart';
import '../../../state/auth_provider.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_modal.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
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
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Menu & Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: authProvider.isGuest ? const Color(0xFFFEF3C7) : AppTheme.primaryGreenLight,
                      child: Icon(
                        authProvider.isGuest ? Icons.person_outline : Icons.verified_user_rounded,
                        color: authProvider.isGuest ? AppTheme.accentOrange : AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authProvider.isGuest ? 'Guest Mode (No Login Required)' : 'Signed In',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                          ),
                          Text(
                            authProvider.isGuest ? 'Schemes saved locally on device' : (authProvider.user?.email ?? 'Connected with Google'),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
                          label: const Text('Connect Google Account'),
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

          const SizedBox(height: 20),

          // Admin Portal Tile (if admin)
          if (authProvider.isAdmin) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryGreenLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primaryGreen),
                ),
                title: const Text('Admin & Curriculum Portal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Manage payment gates, pricing, and curriculum'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const AdminScreen()),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Default Scheme Cover Details
          const Text('Default Scheme Cover Details', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 4),
          const Text('These details will automatically prefill every new scheme you generate.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _schoolController,
                  decoration: const InputDecoration(labelText: 'Default School Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _teacherController,
                  decoration: const InputDecoration(labelText: 'Teacher Name'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tscController,
                        decoration: const InputDecoration(labelText: 'TSC Number'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _hodController,
                        decoration: const InputDecoration(labelText: 'H.O.D Name'),
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

          const SizedBox(height: 20),

          // About App
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                  title: const Text('About CBC Schemes of Work', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Version ${AppConfig.appVersion} • Kenyan CBC Standard'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
                  title: const Text('Support Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
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
