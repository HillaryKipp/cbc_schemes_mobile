import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/scheme.dart';
import '../../../models/scheme_row.dart';
import '../../../services/pdf_export_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/scheme_editor_provider.dart';
import '../../widgets/claim_account_banner.dart';
import '../../widgets/content_picker_sheet.dart';
import '../auth/auth_modal.dart';
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

  void _openCellPicker({
    required int index,
    required SchemeRow row,
    required String title,
    required String categoryName,
    required List<String> currentItems,
    required Function(List<String>) onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContentPickerSheet(
        title: title,
        categoryName: categoryName,
        availableOptions: const [
          'Identify rational numbers in real life.',
          'Express rational numbers in different forms.',
          'Compare and order rational numbers.',
          'Apply arithmetic operations on fractions.',
          'Solve practical problems using decimals.',
        ],
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
        title: Text('Reflections (Wk ${row.weekNumber} Lsn ${row.lessonNumber})'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter teacher reflection notes...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<SchemeEditorProvider>().updateReflections(index, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<SchemeEditorProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isGuest = widget.scheme.id.startsWith('guest-') || authProvider.isGuest;
    final rows = editorProvider.rows;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: AppTheme.primaryGreen,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '${widget.scheme.gradeName ?? "Grade 6"} ${widget.scheme.subjectName ?? "Mathematics"} – ${widget.scheme.termName} (${widget.scheme.year})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Saved status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  editorProvider.saveStatus == SaveStatus.saving ? 'Saving...' : 'Saved',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Preview Pill
            InkWell(
              onTap: () {
                final currentScheme = editorProvider.updatedScheme;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => SchemePreviewScreen(scheme: currentScheme)),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Preview', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Download PDF Button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => PdfExportService.shareSchemePdf(editorProvider.updatedScheme),
                icon: const Icon(Icons.download_rounded, color: AppTheme.primaryGreen, size: 15),
                label: const Text('Download PDF', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 11.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Guest Banner
          if (isGuest)
            ClaimAccountBanner(
              onClaimPressed: () => AuthModal.show(context),
            ),

          // Tab Bar (Table View | Front Page | Calendar)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryGreen,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: const [
                Tab(text: 'Table View'),
                Tab(text: 'Front Page'),
                Tab(text: 'Calendar'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Subheader Info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF9FAFB),
            child: Text(
              '${rows.length} Lessons  •  ${(rows.length / 5).ceil()} Weeks',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Table View (Screen 7 spreadsheet in design)
                _buildSpreadsheetTableView(rows, editorProvider),

                // TAB 2: Front Page Cover View
                _buildFrontPageView(widget.scheme),

                // TAB 3: Calendar Breakdown View
                _buildCalendarView(rows),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: 10-Column Spreadsheet matching Screen 7
  Widget _buildSpreadsheetTableView(List<SchemeRow> rows, SchemeEditorProvider editorProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.primaryGreen),
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          dataRowMinHeight: 52,
          dataRowMaxHeight: 140,
          border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 0.8),
          columns: const [
            DataColumn(label: Text('WEEK', textAlign: TextAlign.center)),
            DataColumn(label: Text('LESSON', textAlign: TextAlign.center)),
            DataColumn(label: Text('STRAND')),
            DataColumn(label: Text('SUB-STRAND')),
            DataColumn(label: Text('LEARNING OUTCOMES')),
            DataColumn(label: Text('LEARNING EXPERIENCES')),
            DataColumn(label: Text('KEY INQUIRY\nQUESTIONS')),
            DataColumn(label: Text('LEARNING\nRESOURCES')),
            DataColumn(label: Text('ASSESSMENT\nMETHODS')),
            DataColumn(label: Text('REFLECTIONS')),
          ],
          rows: List.generate(rows.length, (index) {
            final row = rows[index];
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (index % 2 == 1) return const Color(0xFFF9FAFB);
                return Colors.white;
              }),
              cells: [
                DataCell(Center(child: Text('${row.weekNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                DataCell(Center(child: Text('${row.lessonNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(row.strandName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(row.subStrandName, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 200,
                    items: row.learningOutcomes,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Learning Outcomes',
                      categoryName: 'Outcomes',
                      currentItems: row.learningOutcomes,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(learningOutcomes: items)),
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
                    width: 180,
                    items: row.keyInquiryQuestions,
                    onTap: () => _openCellPicker(
                      index: index,
                      row: row,
                      title: 'Key Inquiry Questions',
                      categoryName: 'Questions',
                      currentItems: row.keyInquiryQuestions,
                      onSaved: (items) => editorProvider.updateRow(index, row.copyWith(keyInquiryQuestions: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildCellContent(
                    width: 160,
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
                    width: 160,
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
                    child: SizedBox(
                      width: 120,
                      child: Text(
                        row.reflections.isNotEmpty ? row.reflections : '—',
                        style: TextStyle(
                          fontSize: 11.5,
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
              const Text('—', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
            else
              ...items.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $i',
                      style: const TextStyle(fontSize: 11, height: 1.25, color: AppTheme.textDark),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // TAB 2: Front Page Cover View
  Widget _buildFrontPageView(Scheme scheme) {
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
                'REPUBLIC OF KENYA',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              const Text(
                'MINISTRY OF EDUCATION',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.shield_outlined, color: AppTheme.primaryGreen, size: 40),
              const SizedBox(height: 16),
              const Text(
                'SCHEMES OF WORK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 4),
              Text(
                (scheme.subjectName ?? 'MATHEMATICS').toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${(scheme.gradeName ?? "GRADE 6").toUpperCase()}  •  ${scheme.termName.toUpperCase()} ${scheme.year}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              _buildCoverDetail('School Name:', scheme.schoolName ?? 'Not specified'),
              _buildCoverDetail('Teacher Name:', scheme.teacherName ?? 'Not specified'),
              _buildCoverDetail('TSC Number:', scheme.tscNumber ?? 'Not specified'),
              _buildCoverDetail('HOD Name:', scheme.hodName ?? 'Not specified'),
              _buildCoverDetail('Course Book:', scheme.referenceBookTitle ?? 'All KICD Approved Books'),
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
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppTheme.textDark)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }

  // TAB 3: Calendar Breakdown View
  Widget _buildCalendarView(List<SchemeRow> rows) {
    final weeks = rows.map((r) => r.weekNumber).toSet().toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (context, index) {
        final week = weeks[index];
        final weekRows = rows.where((r) => r.weekNumber == week).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Week $week', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                    Text('${weekRows.length} Lessons', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
                const Divider(height: 14),
                ...weekRows.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        'Lesson ${r.lessonNumber}: ${r.strandName} — ${r.subStrandName}',
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textDark),
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
