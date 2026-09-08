import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../models/guest_scheme.dart';
import '../../../state/auth_provider.dart';
import '../../../state/scheme_list_provider.dart';
import '../../widgets/claim_account_banner.dart';
import '../../widgets/stat_badge.dart';
import '../auth/auth_modal.dart';
import '../editor/scheme_editor_screen.dart';
import '../generate/generate_wizard_screen.dart';
import '../preview/scheme_preview_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final listProvider = context.watch<SchemeListProvider>();
    final authProvider = context.watch<AuthProvider>();

    final guestSchemes = listProvider.guestSchemes;
    final cloudSchemes = listProvider.cloudSchemes;
    final isGuest = authProvider.isGuest;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Saved Schemes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (isGuest && guestSchemes.isNotEmpty)
                    ClaimAccountBanner(
                      onClaimPressed: () => AuthModal.show(context),
                    ),

                  if (!isGuest && guestSchemes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Guest Schemes on this Device',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentOrange),
                          ),
                          TextButton(
                            onPressed: () async {
                              for (final g in List<GuestScheme>.from(guestSchemes)) {
                                await listProvider.claimScheme(g);
                              }
                            },
                            child: const Text('Claim All to Cloud'),
                          ),
                        ],
                      ),
                    ),
                    ...guestSchemes.map((g) => _buildGuestSchemeCard(context, g, listProvider)),
                    const Divider(height: 24),
                  ],

                  if (!isGuest) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'Cloud Saved Schemes (${cloudSchemes.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                      ),
                    ),
                    if (cloudSchemes.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...cloudSchemes.map((s) => _buildSchemeCard(context, s, listProvider, isGuest: false)),
                  ],

                  if (isGuest) ...[
                    if (guestSchemes.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...guestSchemes.map((g) => _buildGuestSchemeCard(context, g, listProvider)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSchemeCard(
    BuildContext context,
    Scheme scheme,
    SchemeListProvider listProvider, {
    required bool isGuest,
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
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scheme.gradeName ?? "Grade 6"} ${scheme.subjectName ?? "Mathematics"}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scheme.termName} – ${scheme.year}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
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
            '${scheme.rows.length} Lessons  •  ${(scheme.rows.length / 5).ceil()} Weeks',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
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
                  child: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

  Widget _buildGuestSchemeCard(
    BuildContext context,
    GuestScheme guestScheme,
    SchemeListProvider listProvider,
  ) {
    final scheme = guestScheme.toScheme();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
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
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${scheme.gradeName ?? "Grade 6"} ${scheme.subjectName ?? "Mathematics"}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                        ),
                        const SizedBox(width: 6),
                        const StatBadge(label: 'On Device', color: Color(0xFFFEF3C7), textColor: Color(0xFF92400E)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scheme.termName} – ${scheme.year}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                onPressed: () => listProvider.deleteScheme(guestScheme.id, isGuest: true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${scheme.rows.length} Lessons  •  ${(scheme.rows.length / 5).ceil()} Weeks',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
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
                  child: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bookmark_border_rounded, size: 48, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 16),
          const Text('No Saved Schemes Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          const Text(
            'Generate a scheme from the Home or Schemes tab to view and edit it here anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const GenerateWizardScreen()),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Generate New Scheme'),
          ),
        ],
      ),
    );
  }
}
