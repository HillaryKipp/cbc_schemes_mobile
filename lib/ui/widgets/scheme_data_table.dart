import 'package:flutter/material.dart';
import '../../core/config/theme.dart';
import '../../models/scheme_row.dart';
import '../../services/curriculum_service.dart';
import 'content_picker_sheet.dart';

class SchemeDataTable extends StatelessWidget {
  final List<SchemeRow> rows;
  final Function(int, SchemeRow) onRowUpdated;
  final Function(int) onInsertBelow;
  final Function(int) onDelete;
  final String? referenceBookTitle;

  const SchemeDataTable({
    super.key,
    required this.rows,
    required this.onRowUpdated,
    required this.onInsertBelow,
    required this.onDelete,
    this.referenceBookTitle,
  });

  void _openPicker(
    BuildContext context, {
    required int index,
    required SchemeRow row,
    required String title,
    required String categoryName,
    required List<String> currentItems,
    required Function(List<String>) onSaved,
  }) async {
    final curriculum = CurriculumService.instance;
    final bank = await curriculum.getContentBankForSubStrand(subStrandId: 'any');

    List<String> options = [];
    if (categoryName == 'Outcomes') {
      options = bank.outcomes.map((e) => e.content).toList();
    } else if (categoryName == 'Questions') {
      options = bank.questions.map((e) => e.question).toList();
    } else if (categoryName == 'Experiences') {
      options = bank.experiences.map((e) => e.description).toList();
    } else if (categoryName == 'Resources') {
      options = bank.resources.map((e) => e.title).toList();
    } else if (categoryName == 'Assessments') {
      options = bank.assessments.map((e) => e.name).toList();
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContentPickerSheet(
        title: title,
        categoryName: categoryName,
        availableOptions: options,
        selectedOptions: currentItems,
        bookTitle: referenceBookTitle,
        onSave: onSaved,
      ),
    );
  }

  void _editReflections(BuildContext context, int index, SchemeRow row) {
    final controller = TextEditingController(text: row.reflections);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reflections - Wk ${row.weekNumber} Lsn ${row.lessonNumber}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter teacher self-evaluation...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onRowUpdated(index, row.copyWith(reflections: controller.text));
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.primaryEmerald),
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 120,
          border: TableBorder.all(color: AppTheme.borderSubtle, width: 0.8),
          columns: const [
            DataColumn(label: Text('Wk', textAlign: TextAlign.center)),
            DataColumn(label: Text('Lsn', textAlign: TextAlign.center)),
            DataColumn(label: Text('Strand')),
            DataColumn(label: Text('Sub-Strand')),
            DataColumn(label: Text('Specific Learning Outcomes')),
            DataColumn(label: Text('Key Inquiry Questions')),
            DataColumn(label: Text('Learning Experiences')),
            DataColumn(label: Text('Learning Resources')),
            DataColumn(label: Text('Assessment Methods')),
            DataColumn(label: Text('Reflections')),
            DataColumn(label: Text('Actions')),
          ],
          rows: List.generate(rows.length, (index) {
            final row = rows[index];
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (index % 2 == 1) return const Color(0xFFF8FAFC);
                return Colors.white;
              }),
              cells: [
                DataCell(Center(child: Text('${row.weekNumber}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                DataCell(Center(child: Text('${row.lessonNumber}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Text(row.strandName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Text(row.subStrandName, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                DataCell(
                  _buildClickableListCell(
                    width: 220,
                    items: row.learningOutcomes,
                    onTap: () => _openPicker(
                      context,
                      index: index,
                      row: row,
                      title: 'Specific Learning Outcomes',
                      categoryName: 'Outcomes',
                      currentItems: row.learningOutcomes,
                      onSaved: (items) => onRowUpdated(index, row.copyWith(learningOutcomes: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildClickableListCell(
                    width: 180,
                    items: row.keyInquiryQuestions,
                    onTap: () => _openPicker(
                      context,
                      index: index,
                      row: row,
                      title: 'Key Inquiry Questions',
                      categoryName: 'Questions',
                      currentItems: row.keyInquiryQuestions,
                      onSaved: (items) => onRowUpdated(index, row.copyWith(keyInquiryQuestions: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildClickableListCell(
                    width: 200,
                    items: row.learningExperiences,
                    onTap: () => _openPicker(
                      context,
                      index: index,
                      row: row,
                      title: 'Learning Experiences',
                      categoryName: 'Experiences',
                      currentItems: row.learningExperiences,
                      onSaved: (items) => onRowUpdated(index, row.copyWith(learningExperiences: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildClickableListCell(
                    width: 180,
                    items: row.learningResources,
                    onTap: () => _openPicker(
                      context,
                      index: index,
                      row: row,
                      title: 'Learning Resources',
                      categoryName: 'Resources',
                      currentItems: row.learningResources,
                      onSaved: (items) => onRowUpdated(index, row.copyWith(learningResources: items)),
                    ),
                  ),
                ),
                DataCell(
                  _buildClickableListCell(
                    width: 160,
                    items: row.assessmentMethods,
                    onTap: () => _openPicker(
                      context,
                      index: index,
                      row: row,
                      title: 'Assessment Methods',
                      categoryName: 'Assessments',
                      currentItems: row.assessmentMethods,
                      onSaved: (items) => onRowUpdated(index, row.copyWith(assessmentMethods: items)),
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _editReflections(context, index, row),
                    child: SizedBox(
                      width: 140,
                      child: Text(
                        row.reflections.isNotEmpty ? row.reflections : '(Tap to write reflection)',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: row.reflections.isEmpty ? FontStyle.italic : FontStyle.normal,
                          color: row.reflections.isEmpty ? AppTheme.textMuted : AppTheme.textDark,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryEmerald),
                        tooltip: 'Insert Lesson Below',
                        onPressed: () => onInsertBelow(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                        tooltip: 'Delete Lesson',
                        onPressed: () => onDelete(index),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildClickableListCell({
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
              const Text('• (Tap to select)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted))
            else
              ...items.take(3).map(
                    (e) => Text(
                      '• $e',
                      style: const TextStyle(fontSize: 11, height: 1.2, color: AppTheme.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            if (items.length > 3)
              Text('+${items.length - 3} more...', style: const TextStyle(fontSize: 10, color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
