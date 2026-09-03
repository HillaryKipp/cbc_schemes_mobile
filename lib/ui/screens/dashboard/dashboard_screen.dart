import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../core/utils/formatters.dart';
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final listProvider = context.watch<SchemeListProvider>();
    final authProvider = context.watch<AuthProvider>();

    final guestSchemes = listProvider.guestSchemes;
    final cloudSchemes = listProvider.cloudSchemes;
    final isGuest = authProvider.isGuest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schemes of Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => listProvider.loadSchemes(),
          ),
        ],
      ),
      body: listProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryEmerald))
          : RefreshIndicator(
              onRefresh: () => listProvider.loadSchemes(),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // Guest Notice Banner
                  if (isGuest && guestSchemes.isNotEmpty)
                    ClaimAccountBanner(
                      onClaimPressed: () => AuthModal.show(context),
                    ),

                  // Guest Schemes Section (if signed in and guest schemes exist on this device)
                  if (!isGuest && guestSchemes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Guest Schemes on this Device',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentGold),
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

                  // Cloud Schemes Section
                  if (!isGuest) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'Cloud Saved Schemes (${cloudSchemes.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                      ),
                    ),
                    if (cloudSchemes.isEmpty)
                      _buildEmptyState(context, isGuest: false)
                    else
                      ...cloudSchemes.map((s) => _buildSchemeCard(context, s, listProvider, isGuest: false)),
                  ],

                  // Guest Only View
                  if (isGuest) ...[
                    if (guestSchemes.isEmpty)
                      _buildEmptyState(context, isGuest: true)
                    else
                      ...guestSchemes.map((g) => _buildGuestSchemeCard(context, g, listProvider)),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const GenerateWizardScreen()),
        ),
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Generate New Scheme'),
      ),
    );
  }

  Widget _buildSchemeCard(
    BuildContext context,
    Scheme scheme,
    SchemeListProvider listProvider, {
    required bool isGuest,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => SchemeEditorScreen(scheme: scheme),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scheme.subjectName ?? 'Learning Area',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${scheme.gradeName ?? "Grade"} • ${scheme.termName} ${scheme.year}',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                    onSelected: (val) {
                      if (val == 'preview') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => SchemePreviewScreen(scheme: scheme)),
                        );
                      } else if (val == 'delete') {
                        listProvider.deleteScheme(scheme.id, isGuest: isGuest);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Preview & Export'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                            SizedBox(width: 8),
                            Text('Delete Scheme', style: TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatBadge(
                    label: '${scheme.rows.length} Lessons',
                    icon: Icons.list_alt,
                    color: AppTheme.primaryEmerald.withOpacity(0.08),
                  ),
                  const SizedBox(width: 8),
                  if (scheme.referenceBookTitle != null)
                    Expanded(
                      child: Text(
                        scheme.referenceBookTitle!,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestSchemeCard(
    BuildContext context,
    GuestScheme guestScheme,
    SchemeListProvider listProvider,
  ) {
    final scheme = guestScheme.toScheme();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => SchemeEditorScreen(scheme: scheme),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              scheme.subjectName ?? 'Learning Area',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                            const SizedBox(width: 6),
                            const StatBadge(
                              label: 'On Device',
                              color: Color(0xFFFEF3C7),
                              textColor: Color(0xFF92400E),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${scheme.gradeName ?? "Grade"} • ${scheme.termName} ${scheme.year}',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                    onSelected: (val) async {
                      if (val == 'claim') {
                        final auth = context.read<AuthProvider>();
                        if (auth.isGuest) {
                          AuthModal.show(context);
                        } else {
                          await listProvider.claimScheme(guestScheme);
                        }
                      } else if (val == 'preview') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => SchemePreviewScreen(scheme: scheme)),
                        );
                      } else if (val == 'delete') {
                        listProvider.deleteScheme(guestScheme.id, isGuest: true);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'claim',
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 18, color: AppTheme.accentGold),
                            SizedBox(width: 8),
                            Text('Claim to Account'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Preview & Export'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                            SizedBox(width: 8),
                            Text('Delete Scheme', style: TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatBadge(
                    label: '${scheme.rows.length} Lessons',
                    icon: Icons.list_alt,
                  ),
                  Text(
                    'Updated ${Formatters.formatDate(guestScheme.updatedAt)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isGuest}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.post_add_outlined,
              size: 48,
              color: AppTheme.primaryEmerald,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Schemes Yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick your grade and learning area to generate a complete, ready-to-teach scheme of work in seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const GenerateWizardScreen()),
            ),
            icon: const Icon(Icons.flash_on_rounded, size: 18),
            label: const Text('Generate Free Scheme'),
          ),
        ],
      ),
    );
  }
}
