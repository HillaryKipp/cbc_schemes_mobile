import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../models/scheme_row.dart';
import '../../../models/guest_scheme.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/docx_export_service.dart';
import '../../../services/guest_storage_service.dart';
import '../../../services/mpesa_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/scheme_share_service.dart';
import '../../../state/scheme_editor_provider.dart';
import '../../widgets/content_picker_sheet.dart';
import '../../widgets/whatsapp_support_button.dart';
import '../preview/scheme_preview_screen.dart';

class SchemeEditorScreen extends StatefulWidget {
  final Scheme scheme;

  const SchemeEditorScreen({
    super.key,
    required this.scheme,
  });

  @override
  State<SchemeEditorScreen> createState() => _SchemeEditorScreenState();
}

class _SchemeEditorScreenState extends State<SchemeEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchemeEditorProvider>().setScheme(widget.scheme);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _verifyPaymentGate(Scheme scheme) async {
    final bypass = await MpesaService.instance.shouldBypassPayment(scheme);
    if (bypass) return true;

    final appSettings = await CurriculumService.instance.getAppSettings();
    if (!mounted) return false;

    final success = await MpesaService.instance.showMpesaCheckoutSheet(
      context: context,
      scheme: scheme,
      amount: appSettings.pricePerScheme,
      onPaymentSuccess: () {
        context.read<SchemeEditorProvider>().setScheme(scheme.copyWith(isPaid: true));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheme unlocked successfully! Proceeding with export...'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      },
    );

    return success;
  }

  Future<void> _exportDocx(Scheme scheme) async {
    final allowed = await _verifyPaymentGate(scheme);
    if (!allowed || !mounted) return;

    setState(() => _isExporting = true);
    try {
      await DocxExportService.shareDocx(scheme);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Word export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf(Scheme scheme) async {
    final allowed = await _verifyPaymentGate(scheme);
    if (!allowed || !mounted) return;

    setState(() => _isExporting = true);
    try {
      await PdfExportService.shareSchemePdf(scheme);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _printPdf(Scheme scheme) async {
    final allowed = await _verifyPaymentGate(scheme);
    if (!allowed || !mounted) return;

    setState(() => _isExporting = true);
    try {
      await PdfExportService.printScheme(scheme);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showEditCoverDialog(Scheme currentScheme) {
    final schoolController = TextEditingController(text: currentScheme.schoolName ?? '');
    final teacherController = TextEditingController(text: currentScheme.teacherName ?? '');
    final tscController = TextEditingController(text: currentScheme.tscNumber ?? '');
    final hodController = TextEditingController(text: currentScheme.hodName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Cover Page Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('School Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              TextField(controller: schoolController, decoration: const InputDecoration(hintText: 'School Name')),
              const SizedBox(height: 12),

              const Text('Teacher Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              TextField(controller: teacherController, decoration: const InputDecoration(hintText: 'Teacher Name')),
              const SizedBox(height: 12),

              const Text('TSC / ID Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              TextField(controller: tscController, decoration: const InputDecoration(hintText: 'TSC Number')),
              const SizedBox(height: 12),

              const Text('H.O.D Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              TextField(controller: hodController, decoration: const InputDecoration(hintText: 'HOD Name')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<SchemeEditorProvider>().updateCoverDetails(
                schoolName: schoolController.text.trim(),
                teacherName: teacherController.text.trim(),
                tscNumber: tscController.text.trim(),
                hodName: hodController.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cover details updated & auto-saved!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  void _openCellPicker({
    required int index,
    required SchemeRow row,
    required String title,
    required String categoryName,
    required List<String> currentItems,
    required Function(List<String>) onSaved,
  }) async {
    // Attempt to load sub-strand content bank options
    List<String> options = [];
    if (row.subStrandId != null && row.subStrandId!.isNotEmpty) {
      try {
        final bank = await CurriculumService.instance.getContentBankForSubStrand(
          subStrandId: row.subStrandId!,
        );
        if (categoryName.contains('Outcome')) {
          options = bank.outcomes.map((o) => o.content).toList();
        } else if (categoryName.contains('Question')) {
          options = bank.questions.map((q) => q.question).toList();
        } else if (categoryName.contains('Experience')) {
          options = bank.experiences.map((e) => e.description).toList();
        } else if (categoryName.contains('Resource')) {
          options = bank.resources.map((r) => r.title).toList();
        } else if (categoryName.contains('Assessment')) {
          options = bank.assessments.map((a) => a.name).toList();
        }
      } catch (_) {}
    }

    if (options.isEmpty) {
      options = currentItems;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContentPickerSheet(
        title: title,
        categoryName: categoryName,
        availableOptions: options.isNotEmpty ? options : currentItems,
        selectedOptions: currentItems,
        bookTitle: widget.scheme.referenceBookTitle,
        onSave: onSaved,
      ),
    );
  }

  void _editReflectionsDialog(int index, SchemeRow row) {
    final controller = TextEditingController(text: row.reflections);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reflections: Wk ${row.weekNumber} Lsn ${row.lessonNumber}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter teacher observations, learner achievements, or next steps...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<SchemeEditorProvider>().updateReflections(index, controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Save Reflection'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(Scheme scheme) async {
    final allowed = await _verifyPaymentGate(scheme);
    if (!allowed || !mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share Scheme of Work', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('Share via WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Send scheme directly to WhatsApp contacts or school groups'),
                onTap: () {
                  Navigator.pop(ctx);
                  SchemeShareService.shareViaWhatsApp(context, scheme);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.email_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Share via Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Email PDF document with formal scheme summary'),
                onTap: () {
                  Navigator.pop(ctx);
                  SchemeShareService.shareViaEmail(context, scheme);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3F4F6),
                  child: Icon(Icons.share_outlined, color: AppTheme.textDark),
                ),
                title: const Text('All Apps (Share Sheet)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Google Drive, Bluetooth, Telegram, Files'),
                onTap: () {
                  Navigator.pop(ctx);
                  SchemeShareService.shareViaSocialMedia(context, scheme);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<SchemeEditorProvider>();
    final currentScheme = editorProvider.updatedScheme;
    final rows = editorProvider.rows;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            backgroundColor: AppTheme.primaryGreen,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentScheme.gradeName ?? "Grade"} ${currentScheme.subjectName ?? "Subject"}',
                  style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${currentScheme.termName} ${currentScheme.year} • ${rows.length} Lessons',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                tooltip: 'Share',
                onPressed: () => _showShareOptions(currentScheme),
              ),
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                  tooltip: 'Export & Print',
                  onSelected: (value) {
                  if (value == 'docx') _exportDocx(currentScheme);
                  if (value == 'pdf') _exportPdf(currentScheme);
                  if (value == 'print') _printPdf(currentScheme);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'docx',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text('Export Word (.docx)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Export PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Print Scheme'),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.badge_outlined, color: Colors.white, size: 20),
                tooltip: 'Edit Cover Details',
                onPressed: () => _showEditCoverDialog(currentScheme),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // 3-Term Companion Scheme Navigation Bar
                _build3TermCompanionNavigationBar(currentScheme),

                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryGreen,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.primaryGreen,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: '10-Column Table'),
                      Tab(text: 'Cover Page'),
                      Tab(text: 'Preview & Print'),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Autosave Subheader Status Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFF9FAFB),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${rows.length} Lessons  •  ${(rows.length / 5).ceil()} Weeks  •  KICD 10-Col',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                      ),
                      Row(
                        children: [
                          if (editorProvider.saveStatus == SaveStatus.saving)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                            )
                          else
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            editorProvider.saveStatus == SaveStatus.saving
                                ? 'Autosaving...'
                                : editorProvider.saveStatus == SaveStatus.error
                                    ? 'Autosave failed'
                                    : 'Autosaved (600ms)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: editorProvider.saveStatus == SaveStatus.error ? AppTheme.errorRed : AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: 10-Column Spreadsheet Table View
                      _build10ColumnTable(rows, editorProvider),

                      // TAB 2: Front Cover Page View
                      _buildCoverView(currentScheme),

                      // TAB 3: Preview & Print View
                      SchemePreviewScreen(scheme: currentScheme),
                    ],
                  ),
                ),
              ],
            ),

            // Floating Bottom Action Bar (Word, PDF, Share)
            _buildFloatingBottomActionBar(currentScheme),
          ],
        ),
        floatingActionButton: const Padding(
          padding: EdgeInsets.only(bottom: 60.0),
          child: WhatsAppSupportButton(mini: true),
        ),
      ),
    );
  }

  void _switchCompanionTerm(BundleTermInfo termInfo) {
    if (termInfo.schemeId.isEmpty) return;
    final guestScheme = GuestStorageService.instance.getGuestScheme(termInfo.schemeId);
    if (guestScheme != null) {
      context.read<SchemeEditorProvider>().setScheme(guestScheme.toScheme());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${termInfo.termName}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _build3TermCompanionNavigationBar(Scheme currentScheme) {
    final bundleTerms = currentScheme.bundleTerms;
    if (bundleTerms == null || bundleTerms.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: bundleTerms.map((termInfo) {
            final isCurrent = currentScheme.termName.toLowerCase().trim() == termInfo.termName.toLowerCase().trim() ||
                currentScheme.id == termInfo.schemeId;
            final lessonCount = termInfo.termNumber == 1 ? 65 : (termInfo.termNumber == 2 ? 70 : 45);

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text('${termInfo.termName} · $lessonCount lessons'),
                selected: isCurrent,
                selectedColor: AppTheme.primaryGreenLight,
                backgroundColor: const Color(0xFFF3F4F6),
                labelStyle: TextStyle(
                  color: isCurrent ? AppTheme.primaryGreen : AppTheme.textDark,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isCurrent ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                  width: 1,
                ),
                onSelected: (selected) {
                  if (selected && !isCurrent) {
                    _switchCompanionTerm(termInfo);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomActionBar(Scheme currentScheme) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.25)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => _exportDocx(currentScheme),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Word (.docx)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _exportPdf(currentScheme),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showShareOptions(currentScheme),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // TAB 1: 10-Column Table View
  Widget _build10ColumnTable(List<SchemeRow> rows, SchemeEditorProvider editorProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFE6F1EA)),
          headingTextStyle: const TextStyle(color: Color(0xFF141414), fontWeight: FontWeight.bold, fontSize: 11),
          dataRowMinHeight: 56,
          dataRowMaxHeight: 160,
          border: TableBorder.all(color: const Color(0xFFBEBEBE), width: 0.6),
          columns: const [
            DataColumn(label: Text('Actions', textAlign: TextAlign.center)),
            DataColumn(label: Text('Wk', textAlign: TextAlign.center)),
            DataColumn(label: Text('Lsn', textAlign: TextAlign.center)),
            DataColumn(label: Text('Strand')),
            DataColumn(label: Text('Sub-strand')),
            DataColumn(label: Text('Specific Learning Outcomes')),
            DataColumn(label: Text('Key Inquiry Questions')),
            DataColumn(label: Text('Learning Experiences')),
            DataColumn(label: Text('Learning Resources')),
            DataColumn(label: Text('Assessment Methods')),
            DataColumn(label: Text('Reflection')),
          ],
          rows: List.generate(rows.length, (index) {
            final row = rows[index];
            if (row.isMilestone) {
              final isHalf = row.milestoneType == MilestoneType.halfTerm;
              final bannerBg = isHalf ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF);
              final bannerTextColor = isHalf ? const Color(0xFF92400E) : const Color(0xFF1E40AF);

              return DataRow(
                color: WidgetStateProperty.all(bannerBg),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen, size: 18),
                          tooltip: 'Insert Lesson Below',
                          onPressed: () => editorProvider.insertRowBelow(index),
                        ),
                        if (rows.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 18),
                            tooltip: 'Delete Milestone',
                            onPressed: () => editorProvider.deleteRow(index),
                          ),
                      ],
                    ),
                  ),
                  DataCell(Center(child: Text('${row.weekNumber}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: bannerTextColor)))),
                  DataCell(Center(child: Text('—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: bannerTextColor)))),
                  DataCell(
                    SizedBox(
                      width: 110,
                      child: Text(row.milestoneBannerText, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: bannerTextColor)),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(row.reflections.isNotEmpty ? row.reflections : (isHalf ? 'MID-TERM BREAK' : 'ASSESSMENT'), style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: bannerTextColor)),
                    ),
                  ),
                  DataCell(Center(child: Text('—', style: TextStyle(color: bannerTextColor)))),
                  DataCell(Center(child: Text('—', style: TextStyle(color: bannerTextColor)))),
                  DataCell(Center(child: Text('—', style: TextStyle(color: bannerTextColor)))),
                  DataCell(Center(child: Text('—', style: TextStyle(color: bannerTextColor)))),
                  DataCell(Center(child: Text('—', style: TextStyle(color: bannerTextColor)))),
                  DataCell(
                    InkWell(
                      onTap: () => _editReflectionsDialog(index, row),
                      child: Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          row.reflections.isNotEmpty ? row.reflections : 'Tap to reflect',
                          style: TextStyle(
                            fontSize: 11,
                            color: bannerTextColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (index % 2 == 1) return const Color(0xFFF9FAFB);
                return Colors.white;
              }),
              cells: [
                // Row Management Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen, size: 18),
                        tooltip: 'Insert Lesson Below',
                        onPressed: () => editorProvider.insertRowBelow(index),
                      ),
                      if (rows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 18),
                          tooltip: 'Delete Lesson',
                          onPressed: () => editorProvider.deleteRow(index),
                        ),
                    ],
                  ),
                ),
                DataCell(Center(child: Text('${row.weekNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                DataCell(Center(child: Text('${row.lessonNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                DataCell(
                  SizedBox(
                    width: 110,
                    child: Text(row.strandName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(row.subStrandName, style: const TextStyle(fontSize: 11.5)),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 220,
                    items: row.learningOutcomes,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Learning Outcomes',
                      categoryName: 'Specific Learning Outcomes',
                      currentItems: row.learningOutcomes,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(learningOutcomes: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 170,
                    items: row.keyInquiryQuestions,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Key Inquiry Questions',
                      categoryName: 'Inquiry Questions',
                      currentItems: row.keyInquiryQuestions,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(keyInquiryQuestions: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 220,
                    items: row.learningExperiences,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Learning Experiences',
                      categoryName: 'Experiences',
                      currentItems: row.learningExperiences,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(learningExperiences: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 150,
                    items: row.learningResources,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Learning Resources',
                      categoryName: 'Resources',
                      currentItems: row.learningResources,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(learningResources: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 150,
                    items: row.assessmentMethods,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Assessment Methods',
                      categoryName: 'Assessments',
                      currentItems: row.assessmentMethods,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(assessmentMethods: items)),
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _editReflectionsDialog(index, row),
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        row.reflections.isNotEmpty ? row.reflections : 'Tap to reflect',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: row.reflections.isEmpty ? FontStyle.italic : FontStyle.normal,
                          color: row.reflections.isEmpty ? AppTheme.textMuted : AppTheme.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCellContent({
    required double width,
    required List<String> items,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (items.isEmpty)
              const Text('-', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
            else
              ...items.map((i) {
                final isLeadIn = i.toLowerCase().contains('by the end of');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    i,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: isLeadIn ? FontStyle.italic : FontStyle.normal,
                      height: 1.25,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // TAB 2: Cover Page View
  Widget _buildCoverView(Scheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            children: [
              const Text(
                'SCHEMES OF WORK',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                (scheme.subjectName ?? 'LEARNING AREA').toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${scheme.gradeName ?? "Grade"} — ${scheme.year} — ${scheme.termName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              _buildCoverDetail('School Name:', scheme.schoolName ?? '____________________________________'),
              _buildCoverDetail('Teacher Name:', scheme.teacherName ?? '____________________________________'),
              _buildCoverDetail('TSC Number:', scheme.tscNumber ?? '____________________'),
              if (scheme.referenceBookTitle != null)
                _buildCoverDetail('Reference book:', scheme.referenceBookTitle!),
              const SizedBox(height: 16),
              _buildCoverDetail('H.O.D:', scheme.hodName ?? '____________________________________'),
              _buildCoverDetail('Signature:', '____________________   Date: ____________'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showEditCoverDialog(scheme),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Edit Cover Information'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }
}
