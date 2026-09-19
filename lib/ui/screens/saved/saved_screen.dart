import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../state/auth_provider.dart';
import '../../../state/scheme_list_provider.dart';
import '../../widgets/claim_account_banner.dart';
import '../auth/auth_modal.dart';
import '../editor/scheme_editor_screen.dart';
import '../generate/generate_wizard_screen.dart';
import '../preview/scheme_preview_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  void _claimAllGuestSchemes(BuildContext context, SchemeListProvider listProvider) async {
    final guestList = List.from(listProvider.guestSchemes);
    int claimed = 0;
    for (final g in guestList) {
      final res = await listProvider.claimScheme(g);
      if (res != null) claimed++;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully claimed $claimed schemes to your account!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listProvider = context.watch<SchemeListProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final guestSchemes = listProvider.guestSchemes;
    final cloudSchemes = listProvider.cloudSchemes;
    final allSchemes = listProvider.allSchemes;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          title: const Text('My Generated Schemes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => listProvider.loadSchemes(),
            ),
          ],
        ),
        body: listProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : RefreshIndicator(
                onRefresh: () => listProvider.loadSchemes(),
                child: allSchemes.isEmpty
                    ? _buildEmptyState(context)
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: [
                          // Claim Account Banner if Guest Schemes Exist
                          if (guestSchemes.isNotEmpty)
                            ClaimAccountBanner(
                              title: isAuthenticated
                                  ? 'Claim ${guestSchemes.length} Local Schemes'
                                  : 'Save your schemes permanently',
                              message: isAuthenticated
                                  ? 'You have ${guestSchemes.length} schemes stored locally on this phone. Tap below to sync them to your cloud account.'
                                  : 'You are currently in Guest Mode. Sign in or create an account to back up and sync your schemes across devices.',
                              onClaimPressed: () {
                                if (isAuthenticated) {
                                  _claimAllGuestSchemes(context, listProvider);
                                } else {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => const AuthModal(),
                                  ).then((_) {
                                    if (!context.mounted) return;
                                    if (context.read<AuthProvider>().isAuthenticated) {
                                      _claimAllGuestSchemes(context, listProvider);
                                    }
                                  });
                                }
                              },
                            ),

                          // Cloud Schemes Section
                          if (cloudSchemes.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.cloud_done_rounded, size: 16, color: AppTheme.primaryGreen),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cloud Schemes (${cloudSchemes.length})',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textDark),
                                  ),
                                ],
                              ),
                            ),
                            ...cloudSchemes.map((s) => _buildSchemeCard(context, s, listProvider, isGuest: false)),
                          ],

                          // Guest Schemes Section
                          if (guestSchemes.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_android_rounded, size: 16, color: AppTheme.accentGold),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Local Guest Schemes (${guestSchemes.length})',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textDark),
                                  ),
                                ],
                              ),
                            ),
                            ...guestSchemes.map((g) => _buildSchemeCard(context, g.toScheme(), listProvider, isGuest: true, guestScheme: g)),
                          ],
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildSchemeCard(
    BuildContext context,
    Scheme scheme,
    SchemeListProvider listProvider, {
    required bool isGuest,
    dynamic guestScheme,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isGuest ? const Color(0xFFFEF3C7) : AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.menu_book_rounded,
                  color: isGuest ? AppTheme.accentGold : AppTheme.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scheme.gradeName ?? "Grade"} ${scheme.subjectName ?? "Subject"}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${scheme.termName} – ${scheme.year}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isGuest ? AppTheme.accentGold : AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: scheme.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            scheme.isPaid ? 'PAID / UNLOCKED' : (isGuest ? 'ON DEVICE' : 'CLOUD'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: scheme.isPaid ? const Color(0xFF166534) : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                onPressed: () => listProvider.deleteScheme(scheme.id, isGuest: isGuest),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${scheme.rows.length} Lessons  •  ${(scheme.rows.length / 5).ceil()} Weeks  •  KICD 10-Column Format',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => SchemePreviewScreen(scheme: scheme)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Preview & Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => SchemeEditorScreen(scheme: scheme)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Edit Scheme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          alignment: Alignment.center,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 16),
              const Text('No Generated Schemes Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              const Text(
                'Generate your first CBC scheme of work on the Generator tab to edit, download, and share it anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const GenerateWizardScreen()),
                ),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate New Scheme'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
