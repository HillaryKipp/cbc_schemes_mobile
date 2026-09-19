import 'package:flutter/material.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../services/curriculum_service.dart';

class SchemesScreen extends StatefulWidget {
  final Grade? selectedGrade;
  final Subject? selectedSubject;
  final String? initialQuery;
  final Function(Grade grade, Subject subject)? onSelectLearningArea;

  const SchemesScreen({
    super.key,
    this.selectedGrade,
    this.selectedSubject,
    this.initialQuery,
    this.onSelectLearningArea,
  });

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  final _curriculum = CurriculumService.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Grade> _allGrades = [];
  Grade? _selectedGrade; // null means 'All Grades'
  String _searchQuery = '';

  // Map of gradeId -> List<Subject>
  final Map<String, List<Subject>> _gradeSubjectsMap = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _searchQuery = widget.initialQuery!.toLowerCase();
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _allGrades = await _curriculum.getGrades();

    _selectedGrade = widget.selectedGrade;

    // Preload subjects for all grades
    for (final grade in _allGrades) {
      final subs = await _curriculum.getSubjects(grade.id, grade: grade);
      _gradeSubjectsMap[grade.id] = subs;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    // Determine list of displayed grades
    final activeGrades = _selectedGrade != null
        ? [_selectedGrade!]
        : _allGrades;

    // Build the list of learning area items matching current search and filters
    final List<({Grade grade, Subject subject})> learningAreaItems = [];

    for (final g in activeGrades) {
      final subjects = _gradeSubjectsMap[g.id] ?? [];
      for (final s in subjects) {
        final matchSearch = _searchQuery.isEmpty ||
            g.name.toLowerCase().contains(_searchQuery) ||
            s.name.toLowerCase().contains(_searchQuery) ||
            (s.code?.toLowerCase().contains(_searchQuery) ?? false);

        if (matchSearch) {
          learningAreaItems.add((grade: g, subject: s));
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: const Text(
          'Available Learning Areas',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner text
                const Text(
                  'Select any learning area below to autofill and generate your CBC scheme of work.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                ),
                const SizedBox(height: 10),

                // Search Field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search learning areas (e.g. Mathematics, Science)...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),

                const SizedBox(height: 10),

                // Grade Filter Chips (Horizontal List)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildGradeChip(null, 'All Grades'),
                      ..._allGrades.map((g) => _buildGradeChip(g, g.name)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Learning Areas List View
          Expanded(
            child: learningAreaItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No Learning Areas Found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try clearing filters or changing search keywords.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedGrade = null;
                              });
                            },
                            child: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: learningAreaItems.length,
                    itemBuilder: (ctx, idx) {
                      final item = learningAreaItems[idx];
                      return _buildLearningAreaCard(
                        context: context,
                        grade: item.grade,
                        subject: item.subject,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeChip(Grade? grade, String label) {
    final isSelected = _selectedGrade == grade;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedGrade = grade),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
              width: 1.1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearningAreaCard({
    required BuildContext context,
    required Grade grade,
    required Subject subject,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handlePick(context, grade, subject),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Subject Icon
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

                // Subject details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3FB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              grade.name,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            grade.displayLevel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Select & Generate Button
                ElevatedButton.icon(
                  onPressed: () => _handlePick(context, grade, subject),
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Generate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePick(BuildContext context, Grade grade, Subject subject) {
    if (widget.onSelectLearningArea != null) {
      widget.onSelectLearningArea!(grade, subject);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context, {'grade': grade, 'subject': subject});
    }
  }
}
