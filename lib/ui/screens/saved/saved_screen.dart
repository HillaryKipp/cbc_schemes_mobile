import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../state/scheme_list_provider.dart';
import '../generate/generate_wizard_screen.dart';
import '../preview/scheme_preview_screen.dart';

class SavedScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const SavedScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final listProvider = context.watch<SchemeListProvider>();
    final allSchemes = listProvider.allSchemes;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Saved Schemes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              if (allSchemes.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${allSchemes.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => listProvider.loadSchemes(),
            ),
          ],
        ),
        body: listProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
            : RefreshIndicator(
                onRefresh: () => listProvider.loadSchemes(),
                child: allSchemes.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: allSchemes.length,
                        itemBuilder: (ctx, idx) {
                          final scheme = allSchemes[idx];
                          return _buildSchemeCard(context, scheme, listProvider);
                        },
                      ),
              ),
      ),
    );
  }

  Widget _buildSchemeCard(
    BuildContext context,
    Scheme scheme,
    SchemeListProvider listProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => SchemePreviewScreen(scheme: scheme)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        color: AppTheme.primaryBlueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppTheme.primaryBlue,
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
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: scheme.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  scheme.isPaid ? 'PAID / UNLOCKED' : 'READY',
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
                      onPressed: () => _confirmDelete(context, scheme, listProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${scheme.rows.length} Lessons  •  ${(scheme.rows.length / 5).ceil()} Weeks  •  KICD Format',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => SchemePreviewScreen(scheme: scheme)),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 17),
                    label: const Text('Preview & Print', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Scheme scheme, SchemeListProvider listProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Scheme?'),
        content: Text('Are you sure you want to delete ${scheme.gradeName ?? "Grade"} ${scheme.subjectName ?? "Subject"}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              listProvider.deleteScheme(scheme.id, isGuest: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scheme deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
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
                  color: AppTheme.primaryBlueLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Saved Schemes Yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Schemes you generate will appear here so you can view, print, or share them anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (onNavigateTab != null) {
                    onNavigateTab!(0);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const GenerateWizardScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Create New Scheme', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
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
