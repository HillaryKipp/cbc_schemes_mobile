import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/theme.dart';
import '../../../services/guest_storage_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/scheme_list_provider.dart';
import '../admin/admin_screen.dart';
import '../saved/saved_screen.dart';

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
      const SnackBar(
        content: Text('Default scheme cover details saved!'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  void _showAdminLoginDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Text('Admin Login', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign in as administrator to manage grades, subjects, strands, sub-strands, and app payment settings.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final pass = passCtrl.text.trim();
                        if (email.isEmpty || pass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter admin credentials')),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);
                        final auth = context.read<AuthProvider>();
                        final ok = await auth.signInWithEmail(email, pass);
                        setModalState(() => isSubmitting = false);

                        if (ok && context.mounted) {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => const AdminScreen()),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(auth.errorMessage ?? 'Admin authentication failed')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In to Portal'),
              ),
            ],
          );
        },
      ),
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
    final schemeList = context.watch<SchemeListProvider>();
    final totalSchemes = schemeList.allSchemes.length;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          title: const Text('Settings & Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Teacher Profile & Cover Preferences
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.badge_outlined, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default Scheme Cover Details',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                            Text(
                              'Auto-filled on generated documents',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _schoolController,
                    decoration: const InputDecoration(
                      labelText: 'Default School Name',
                      prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _teacherController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher Name',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tscController,
                          decoration: const InputDecoration(
                            labelText: 'TSC / ID Number',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _hodController,
                          decoration: const InputDecoration(
                            labelText: 'H.O.D Name',
                            prefixIcon: Icon(Icons.supervisor_account_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Save Cover Preferences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Saved Schemes Quick Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Generated Schemes',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                        ),
                        Text(
                          '$totalSchemes Scheme${totalSchemes == 1 ? "" : "s"} stored on this device',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const SavedScreen()),
                    ),
                    child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Admin Management Portal Tile
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: authProvider.isAdmin ? AppTheme.primaryGreenLight : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: authProvider.isAdmin ? AppTheme.primaryGreen : AppTheme.textMuted,
                  ),
                ),
                title: const Text('Administrator Portal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  authProvider.isAdmin ? 'Signed in as Admin (${authProvider.user?.email})' : 'Sign in to edit curriculum, grades & strands',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                onTap: () {
                  if (authProvider.isAdmin) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const AdminScreen()),
                    );
                  } else {
                    _showAdminLoginDialog();
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // App Information & Support
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                    title: const Text('CBC Schemes of Work Generator', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text('Version ${AppConfig.appVersion} • Kenyan KICD Standard'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
                    title: const Text('Support Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text(AppConfig.supportEmail),
                    onTap: () async {
                      final url = Uri.parse('mailto:${AppConfig.supportEmail}');
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
