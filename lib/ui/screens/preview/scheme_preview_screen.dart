import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/scheme.dart';
import '../../../models/scheme_row.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/docx_export_service.dart';
import '../../../services/guest_storage_service.dart';
import '../../../services/mpesa_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/scheme_generator.dart';
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
  bool _isPopulatingRows = false;
  late Scheme _currentScheme;

  @override
  void initState() {
    super.initState();
    _currentScheme = widget.scheme;
    if (_currentScheme.rows.isEmpty) {
      _ensureRowsPopulated();
    }
  }

  Future<void> _ensureRowsPopulated() async {
    setState(() => _isPopulatingRows = true);
    try {
      final grade = Grade(
        id: _currentScheme.gradeId,
        name: _currentScheme.gradeName ?? 'Grade 1',
      );
      final subject = Subject(
        id: _currentScheme.subjectId,
        gradeId: grade.id,
        name: _currentScheme.subjectName ?? 'Learning Area',
      );
      final generated = await SchemeGenerator.generateScheme(
        grade: grade,
        subject: subject,
        termName: _currentScheme.termName,
        year: _currentScheme.year,
        weeks: 13,
        lessonsPerWeek: 5,
        schoolName: _currentScheme.schoolName,
        teacherName: _currentScheme.teacherName,
        tscNumber: _currentScheme.tscNumber,
        hodName: _currentScheme.hodName,
      );
      if (!mounted) return;
      setState(() {
        _currentScheme = _currentScheme.copyWith(rows: generated.rows);
        _isPopulatingRows = false;
      });
      GuestStorageService.instance.saveGuestScheme(_currentScheme.toGuestScheme());
    } catch (e) {
      debugPrint('Error populating fallback scheme rows: $e');
      if (mounted) setState(() => _isPopulatingRows = false);
    }
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
              backgroundColor: AppTheme.primaryBlue,
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

  void _editCoverDetails() {
    final schoolCtrl = TextEditingController(text: _currentScheme.schoolName ?? '');
    final teacherCtrl = TextEditingController(text: _currentScheme.teacherName ?? '');
    final tscCtrl = TextEditingController(text: _currentScheme.tscNumber ?? '');
    final hodCtrl = TextEditingController(text: _currentScheme.hodName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Cover Page Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: schoolCtrl,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  prefixIcon: Icon(Icons.school_outlined, color: AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teacher Name',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tscCtrl,
                      decoration: const InputDecoration(
                        labelText: 'TSC / ID No.',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: hodCtrl,
                      decoration: const InputDecoration(
                        labelText: 'H.O.D Name',
                        prefixIcon: Icon(Icons.supervisor_account_outlined, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final updated = _currentScheme.copyWith(
                      schoolName: schoolCtrl.text.trim(),
                      teacherName: teacherCtrl.text.trim(),
                      tscNumber: tscCtrl.text.trim(),
                      hodName: hodCtrl.text.trim(),
                    );
                    setState(() => _currentScheme = updated);
                    GuestStorageService.instance.saveTeacherProfile(
                      schoolName: schoolCtrl.text.trim(),
                      teacherName: teacherCtrl.text.trim(),
                      tscNumber: tscCtrl.text.trim(),
                      hodName: hodCtrl.text.trim(),
                    );
                    await GuestStorageService.instance.saveGuestScheme(updated.toGuestScheme());
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cover details updated successfully!')),
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Cover Details', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _currentScheme;
    final sortedRows = List<SchemeRow>.from(scheme.rows)..sort((a, b) => a.position.compareTo(b.position));

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            '${scheme.gradeName ?? "Grade"} ${scheme.subjectName ?? "Subject"}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton.icon(
              onPressed: _editCoverDetails,
              icon: const Icon(Icons.edit_document, size: 16, color: AppTheme.primaryBlue),
              label: const Text(
                'Edit Cover',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryBlueLight,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4),
            const WhatsAppSupportButton(mini: true),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildFloatingActionBar(),
        body: _isPopulatingRows
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryBlue),
                    SizedBox(height: 14),
                    Text(
                      'Generating complete CBC scheme rows...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.textDark),
                    ),
                  ],
                ),
              )
            : sortedRows.isEmpty
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
                : PdfPreview(
                    key: ValueKey(
                      '${_currentScheme.id}_${_currentScheme.schoolName}_${_currentScheme.teacherName}_${_currentScheme.tscNumber}_${_currentScheme.hodName}_${_currentScheme.rows.length}',
                    ),
                    build: (format) => PdfExportService.generateSchemePdf(_currentScheme),
                    initialPageFormat: PdfPageFormat.a4.landscape,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    useActions: false,
                    previewPageMargin: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 84),
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryBlue),
                          SizedBox(height: 12),
                          Text(
                            'Rendering official print-ready PDF scheme document...',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildFloatingActionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isExporting
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                  ),
                  SizedBox(width: 10),
                  Text('Exporting scheme...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                ],
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Print Button
                ElevatedButton.icon(
                  onPressed: () => _handleDownload('print'),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Print', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 6),

                // PDF Button
                ElevatedButton.icon(
                  onPressed: () => _handleDownload('pdf'),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 6),

                // Word DOCX Button
                OutlinedButton.icon(
                  onPressed: () => _handleDownload('docx'),
                  icon: const Icon(Icons.description_rounded, size: 15, color: Color(0xFF2563EB)),
                  label: const Text('Word', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 6),

                // WhatsApp Share Button
                ElevatedButton.icon(
                  onPressed: () => _handleShare('whatsapp'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
    );
  }
}
