import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/app_settings.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/supabase_service.dart';
import '../../../state/auth_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _curriculum = CurriculumService.instance;
  final _supabase = SupabaseService.instance;

  bool _isLoading = true;
  AppSettings _appSettings = AppSettings();
  List<Grade> _grades = [];
  List<Subject> _subjects = [];

  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    _appSettings = await _curriculum.getAppSettings();
    _grades = await _curriculum.getGrades();
    if (_grades.isNotEmpty) {
      _subjects = await _curriculum.getSubjects(_grades.first.id);
    }
    _priceController.text = _appSettings.pricePerScheme.toStringAsFixed(0);
    _phoneController.text = _appSettings.supportPhone ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_supabase.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin requires authenticated Supabase session')),
      );
      return;
    }

    try {
      final updated = AppSettings(
        paymentsEnabled: _appSettings.paymentsEnabled,
        adsEnabled: _appSettings.adsEnabled,
        pricePerScheme: double.tryParse(_priceController.text) ?? 100.0,
        currency: 'KES',
        supportPhone: _phoneController.text.trim(),
        supportEmail: _appSettings.supportEmail,
      );

      await _supabase.client.from('app_settings').upsert(updated.toJson());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Settings saved to database!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating settings: $e')),
      );
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Portal')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('Restricted Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'This section requires admin privileges (${authProvider.user?.email ?? "Signed out"}).',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Curriculum & Admin Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Settings',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryEmerald))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // App Flags & Monetization
                const Text('App Configuration & Monetization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Payment Gate on Download', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('When disabled, all teachers export for free without gates'),
                        value: _appSettings.paymentsEnabled,
                        activeColor: AppTheme.primaryEmerald,
                        onChanged: (val) => setState(() => _appSettings = AppSettings(
                          paymentsEnabled: val,
                          adsEnabled: _appSettings.adsEnabled,
                          pricePerScheme: _appSettings.pricePerScheme,
                          supportPhone: _appSettings.supportPhone,
                          supportEmail: _appSettings.supportEmail,
                        )),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Enable Ads', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Toggle promotional sponsor banners'),
                        value: _appSettings.adsEnabled,
                        activeColor: AppTheme.primaryEmerald,
                        onChanged: (val) => setState(() => _appSettings = AppSettings(
                          paymentsEnabled: _appSettings.paymentsEnabled,
                          adsEnabled: val,
                          pricePerScheme: _appSettings.pricePerScheme,
                          supportPhone: _appSettings.supportPhone,
                          supportEmail: _appSettings.supportEmail,
                        )),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Price per Scheme (KES)',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Support Phone / M-Pesa',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Curriculum Bank Summary
                const Text('Curriculum Bank Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total CBC Grades Available:'),
                            Text('${_grades.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Grade Sample Subjects:'),
                            Text('${_subjects.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Curriculum content bank is synced directly with Postgres RLS anon/admin tables.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Save App Settings to Database'),
                ),
              ],
            ),
    );
  }
}
