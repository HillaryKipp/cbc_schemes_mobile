import 'package:flutter/material.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/docx_export_service.dart';
import '../../../services/mpesa_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/scheme_share_service.dart';

import '../../widgets/whatsapp_support_button.dart';

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
  late Scheme _currentScheme;

  @override
  void initState() {
    super.initState();
    _currentScheme = widget.scheme;
  }

  Future<bool> _verifyAccess() async {
    final bypass = await MpesaService.instance.shouldBypassPayment(_currentScheme);
    if (bypass) return true;

    try {
      final appSettings = await CurriculumService.instance.getAppSettings();
      if (!mounted) return false;

      final success = await MpesaService.instance.showMpesaCheckoutSheet(
        context: context,
        scheme: _currentScheme,
        amount: appSettings.pricePerScheme,
        onPaymentSuccess: () {
          setState(() {
            _currentScheme = _currentScheme.copyWith(isPaid: true);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verified! Scheme unlocked for download and sharing.'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        },
      );
      return success;
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleDownload(String type) async {
    final allowed = await _verifyAccess();
    if (!allowed || !mounted) return;

    setState(() => _isExporting = true);

    try {
      if (type == 'print') {
        await PdfExportService.printScheme(_currentScheme);
      } else if (type == 'pdf') {
        await PdfExportService.shareSchemePdf(_currentScheme);
      } else if (type == 'docx') {
        await DocxExportService.shareDocx(_currentScheme);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleShare(String channel) async {
    final allowed = await _verifyAccess();
    if (!allowed || !mounted) return;

    setState(() => _isExporting = true);

    try {
      if (channel == 'whatsapp') {
        await SchemeShareService.shareViaWhatsApp(context, _currentScheme);
      } else if (channel == 'email') {
        await SchemeShareService.shareViaEmail(context, _currentScheme);
      } else if (channel == 'docx') {
        await SchemeShareService.shareViaSocialMedia(context, _currentScheme, format: 'docx');
      } else {
        await SchemeShareService.shareViaSocialMedia(context, _currentScheme, format: 'pdf');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _currentScheme;
    final sortedRows = List.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Preview, Share & Download', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: 'Print Scheme',
              icon: const Icon(Icons.print_outlined),
              onPressed: _isExporting ? null : () => _handleDownload('print'),
            ),
          ],
        ),
        floatingActionButton: const WhatsAppSupportButton(mini: true),
        body: sortedRows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 40, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${scheme.gradeName ?? "Grade"} ${scheme.subjectName ?? "Subject"} Scheme Being Finalized',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This scheme of work is currently being prepared according to the 2026 KICD CBC curriculum designs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          WhatsAppSupportButton.openWhatsApp(
                            context,
                            'Hello! I would like to request the scheme of work for ${scheme.gradeName ?? "Grade"} ${scheme.subjectName ?? "Subject"} ${scheme.termName}.',
                          );
                        },
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('Request Scheme on WhatsApp (0734232994)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Download Actions Bar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Download & Export Options',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : () => _handleDownload('pdf'),
                            icon: const Icon(Icons.picture_as_pdf, size: 17),
                            label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isExporting ? null : () => _handleDownload('docx'),
                            icon: const Icon(Icons.description, size: 17, color: Color(0xFF2563EB)),
                            label: const Text('Download Word', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Share Channels Card (WhatsApp, Email, Social Media)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Scheme With Colleagues',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // WhatsApp Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : () => _handleShare('whatsapp'),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Email Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : () => _handleShare('email'),
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: const Text('Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Social / All Apps Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : () => _handleShare('social'),
                            icon: const Icon(Icons.share_outlined, size: 16),
                            label: const Text('More Apps', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B5563),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Document Paper Container (Preview)
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 12),

                    // Metadata Summary Box
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
                          _buildMetaItem('COURSE BOOK', scheme.referenceBookTitle ?? 'KICD Approved'),
                          _buildMetaItem('H.O.D', scheme.hodName ?? '-'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Complete official scheme with ${sortedRows.length} lesson slots across 10 official KICD columns.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),

                    // Mini preview table
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppTheme.primaryGreen),
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
                        rows: sortedRows.take(8).map((r) {
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
                    if (sortedRows.length > 8) ...[
                      const SizedBox(height: 8),
                      Text(
                        '+ ${sortedRows.length - 8} more lesson rows included in export',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
