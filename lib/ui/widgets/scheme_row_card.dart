import 'package:flutter/material.dart';
import '../../core/config/theme.dart';
import '../../models/scheme_row.dart';
import '../../services/curriculum_service.dart';
import 'content_picker_sheet.dart';
import 'stat_badge.dart';

class SchemeRowCard extends StatefulWidget {
  final SchemeRow row;
  final int index;
  final int totalRows;
  final Function(SchemeRow) onRowUpdated;
  final VoidCallback onInsertBelow;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String? referenceBookTitle;

  const SchemeRowCard({
    super.key,
    required this.row,
    required this.index,
    required this.totalRows,
    required this.onRowUpdated,
    required this.onInsertBelow,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.referenceBookTitle,
  });

  @override
  State<SchemeRowCard> createState() => _SchemeRowCardState();
}

class _SchemeRowCardState extends State<SchemeRowCard> {
  bool _isExpanded = false;
  late TextEditingController _reflectionController;

  @override
  void initState() {
    super.initState();
    _reflectionController = TextEditingController(text: widget.row.reflections);
  }

  @override
  void didUpdateWidget(covariant SchemeRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.reflections != widget.row.reflections &&
        _reflectionController.text != widget.row.reflections) {
      _reflectionController.text = widget.row.reflections;
    }
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  void _openPicker({
    required String title,
    required String categoryName,
    required List<String> currentItems,
    required Function(List<String>) onItemsSaved,
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

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContentPickerSheet(
        title: title,
        categoryName: categoryName,
        availableOptions: options,
        selectedOptions: currentItems,
        bookTitle: widget.referenceBookTitle,
        onSave: onItemsSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isExpanded ? AppTheme.primaryEmerald.withOpacity(0.5) : AppTheme.borderSubtle,
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Week/Lesson & Action menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Row(
              children: [
                StatBadge(
                  label: 'Wk ${row.weekNumber} • Lsn ${row.lessonNumber}',
                  icon: Icons.calendar_today_outlined,
                  color: AppTheme.primaryEmerald.withOpacity(0.12),
                  textColor: AppTheme.primaryEmeraldDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.strandName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                  onSelected: (val) {
                    if (val == 'insert') widget.onInsertBelow();
                    if (val == 'up') widget.onMoveUp?.call();
                    if (val == 'down') widget.onMoveDown?.call();
                    if (val == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'insert',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryEmerald),
                          SizedBox(width: 8),
                          Text('Insert Lesson Below'),
                        ],
                      ),
                    ),
                    if (widget.onMoveUp != null)
                      const PopupMenuItem(
                        value: 'up',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, size: 18),
                            SizedBox(width: 8),
                            Text('Move Up'),
                          ],
                        ),
                      ),
                    if (widget.onMoveDown != null)
                      const PopupMenuItem(
                        value: 'down',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 18),
                            SizedBox(width: 8),
                            Text('Move Down'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                          SizedBox(width: 8),
                          Text('Delete Lesson', style: TextStyle(color: AppTheme.errorRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sub-strand title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              row.subStrandName.isNotEmpty ? row.subStrandName : 'General Planning Slot',
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textDark.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Chips / Summary Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildCountChip(
                  label: '${row.learningOutcomes.length} Outcomes',
                  icon: Icons.flag_outlined,
                  onTap: () => _openPicker(
                    title: 'Specific Learning Outcomes',
                    categoryName: 'Outcomes',
                    currentItems: row.learningOutcomes,
                    onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(learningOutcomes: items)),
                  ),
                ),
                _buildCountChip(
                  label: '${row.keyInquiryQuestions.length} Questions',
                  icon: Icons.help_outline,
                  onTap: () => _openPicker(
                    title: 'Key Inquiry Questions',
                    categoryName: 'Questions',
                    currentItems: row.keyInquiryQuestions,
                    onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(keyInquiryQuestions: items)),
                  ),
                ),
                _buildCountChip(
                  label: '${row.learningExperiences.length} Experiences',
                  icon: Icons.lightbulb_outline,
                  onTap: () => _openPicker(
                    title: 'Learning Experiences',
                    categoryName: 'Experiences',
                    currentItems: row.learningExperiences,
                    onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(learningExperiences: items)),
                  ),
                ),
                _buildCountChip(
                  label: '${row.learningResources.length} Resources',
                  icon: Icons.menu_book_outlined,
                  onTap: () => _openPicker(
                    title: 'Learning Resources',
                    categoryName: 'Resources',
                    currentItems: row.learningResources,
                    onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(learningResources: items)),
                  ),
                ),
                _buildCountChip(
                  label: '${row.assessmentMethods.length} Assessments',
                  icon: Icons.fact_check_outlined,
                  onTap: () => _openPicker(
                    title: 'Assessment Methods',
                    categoryName: 'Assessments',
                    currentItems: row.assessmentMethods,
                    onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(assessmentMethods: items)),
                  ),
                ),
              ],
            ),
          ),

          // Expand / Collapse details button
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isExpanded ? 'Hide full details' : 'View & edit details',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryEmerald),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppTheme.primaryEmerald,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content Area
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionPreview(
                    title: 'Specific Learning Outcomes',
                    items: row.learningOutcomes,
                    onEdit: () => _openPicker(
                      title: 'Specific Learning Outcomes',
                      categoryName: 'Outcomes',
                      currentItems: row.learningOutcomes,
                      onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(learningOutcomes: items)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionPreview(
                    title: 'Key Inquiry Questions',
                    items: row.keyInquiryQuestions,
                    onEdit: () => _openPicker(
                      title: 'Key Inquiry Questions',
                      categoryName: 'Questions',
                      currentItems: row.keyInquiryQuestions,
                      onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(keyInquiryQuestions: items)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionPreview(
                    title: 'Learning Experiences',
                    items: row.learningExperiences,
                    onEdit: () => _openPicker(
                      title: 'Learning Experiences',
                      categoryName: 'Experiences',
                      currentItems: row.learningExperiences,
                      onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(learningExperiences: items)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionPreview(
                    title: 'Learning Resources',
                    items: row.learningResources,
                    onEdit: () => _openPicker(
                      title: 'Learning Resources',
                      categoryName: 'Resources',
                      currentItems: row.learningResources,
                      onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(learningResources: items)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionPreview(
                    title: 'Assessment Methods',
                    items: row.assessmentMethods,
                    onEdit: () => _openPicker(
                      title: 'Assessment Methods',
                      categoryName: 'Assessments',
                      currentItems: row.assessmentMethods,
                      onItemsSaved: (items) => widget.onRowUpdated(row.copyWith(assessmentMethods: items)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reflections / Self-Evaluation',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _reflectionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Enter teacher lesson reflection note...',
                      isDense: true,
                    ),
                    onChanged: (text) {
                      widget.onRowUpdated(row.copyWith(reflections: text));
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppTheme.textDark),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionPreview({
    required String title,
    required List<String> items,
    required VoidCallback onEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            InkWell(
              onTap: onEdit,
              child: const Text('Edit', style: TextStyle(fontSize: 11.5, color: AppTheme.primaryEmerald, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (items.isEmpty)
          const Text('None selected', style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.textMuted))
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $item', style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark, height: 1.3)),
              )),
      ],
    );
  }
}
