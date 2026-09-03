import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/docx_export_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../state/auth_provider.dart';
import '../auth/auth_modal.dart';

class SchemePreviewScreen extends StatefulWidget {
  final Scheme scheme;

  const SchemePreviewScreen({
    super.key,
    required this.scheme,
  });

  @override
  State<SchemePreviewScreen> createState() => _SchemePreviewScreenState();
}

class _SchemePreviewScreenState extends State<SchemePreviewScreen> {
  bool _isExporting = false;

  Future<void> _handleExport(String type) async {
    setState(() => _isExporting = true);

    try {
      final appSettings = await CurriculumService.instance.getAppSettings();

      // Check payment gate
      if (appSettings.paymentsEnabled && !widget.scheme.isPaid) {
        if (!mounted) return;
        _showPaymentPrompt(appSettings.pricePerScheme);
        return;
      }

      if (type == 'print') {
        await PdfExportService.printScheme(widget.scheme);
      } else if (type == 'pdf') {
        await PdfExportService.shareSchemePdf(widget.scheme);
      } else if (type == 'docx') {
        await DocxExportService.shareDocx(widget.scheme);
      }

      // If guest user, show post-download value prompt
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isGuest) {
        _showPostDownloadPrompt();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showPaymentPrompt(double price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: AppTheme.accentGold),
            SizedBox(width: 8),
            Text('Download Scheme'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: KES ${price.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            const Text(
              'A verified payment enables unlimited downloads and PDF printing for this scheme.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Google Play Billing / M-Pesa sandbox initiated.')),
              );
            },
            child: const Text('Pay with M-Pesa / Card'),
          ),
        ],
      ),
    );
  }

  void _showPostDownloadPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: const Text('Scheme generated! Save your schemes permanently by creating a free account.'),
        action: SnackBarAction(
          label: 'Save Account',
          textColor: Colors.amberAccent,
          onPressed: () => AuthModal.show(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final sortedRows = List.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Download'),
        actions: [
          IconButton(
            tooltip: 'Print Scheme',
            icon: const Icon(Icons.print_outlined),
            onPressed: _isExporting ? null : () => _handleExport('print'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Action Cards Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : () => _handleExport('pdf'),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryEmerald,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : () => _handleExport('docx'),
                      icon: const Icon(Icons.description, size: 18, color: Color(0xFF2563EB)),
                      label: const Text('Export Word'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Document Paper Container (Landscape preview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    (scheme.schoolName?.trim().isNotEmpty == true)
                        ? scheme.schoolName!.toUpperCase()
                        : 'KENYA COMPETENCY BASED CURRICULUM (CBC)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SCHEMES OF WORK - ${scheme.termName.toUpperCase()}, ${scheme.year}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                  ),
                  const SizedBox(height: 12),

                  // Metadata Grid
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildMetaItem('GRADE', scheme.gradeName ?? 'Grade'),
                        _buildMetaItem('LEARNING AREA', scheme.subjectName ?? 'Subject'),
                        _buildMetaItem('TEACHER', scheme.teacherName ?? '-'),
                        _buildMetaItem('TSC NO', scheme.tscNumber ?? '-'),
                        _buildMetaItem('COURSE BOOK', scheme.referenceBookTitle ?? 'All Books'),
                        _buildMetaItem('H.O.D', scheme.hodName ?? '-'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Table Preview Summary
                  Text(
                    'Document contains ${sortedRows.length} lesson slots across 10 official columns.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),

                  // Mini preview table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.primaryEmerald),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 60,
                      border: TableBorder.all(color: AppTheme.borderSubtle, width: 0.5),
                      columns: const [
                        DataColumn(label: Text('Wk')),
                        DataColumn(label: Text('Lsn')),
                        DataColumn(label: Text('Strand')),
                        DataColumn(label: Text('Sub-Strand')),
                        DataColumn(label: Text('Specific Learning Outcomes')),
                        DataColumn(label: Text('Key Inquiry Questions')),
                      ],
                      rows: sortedRows.take(10).map((r) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${r.weekNumber}')),
                            DataCell(Text('${r.lessonNumber}')),
                            DataCell(Text(r.strandName, style: const TextStyle(fontSize: 11))),
                            DataCell(Text(r.subStrandName, style: const TextStyle(fontSize: 11))),
                            DataCell(SizedBox(
                              width: 200,
                              child: Text(r.learningOutcomes.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5)),
                            )),
                            DataCell(SizedBox(
                              width: 160,
                              child: Text(r.keyInquiryQuestions.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5)),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  if (sortedRows.length > 10) ...[
                    const SizedBox(height: 8),
                    Text(
                      '+ ${sortedRows.length - 10} more lesson rows included in the export',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryEmerald),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      ],
    );
  }
}
