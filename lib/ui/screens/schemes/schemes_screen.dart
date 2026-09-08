import 'package:flutter/material.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../services/curriculum_service.dart';
import '../generate/generate_wizard_screen.dart';
import 'scheme_detail_screen.dart';

class SchemesScreen extends StatefulWidget {
  final Grade? selectedGrade;
  final Subject? selectedSubject;
  final String? initialQuery;

  const SchemesScreen({
    super.key,
    this.selectedGrade,
    this.selectedSubject,
    this.initialQuery,
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
  String _selectedTerm = 'Term 3'; // 'All Terms', 'Term 1', 'Term 2', 'Term 3'
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
      final subs = await _curriculum.getSubjects(grade.id);
      _gradeSubjectsMap[grade.id] = subs;
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    // Determine list of displayed grades
    final activeGrades = _selectedGrade != null
        ? [_selectedGrade!]
        : _allGrades;

    // Build the list of scheme items matching current search and filters
    final List<({Grade grade, Subject subject, String term, int year, int weeks, int lessons})> schemeItems = [];

    final termsToInclude = _selectedTerm == 'All Terms'
        ? ['Term 3', 'Term 2', 'Term 1']
        : [_selectedTerm];

    for (final g in activeGrades) {
      final subjects = _gradeSubjectsMap[g.id] ?? [];
      for (final s in subjects) {
        // Check search filter
        final matchSearch = _searchQuery.isEmpty ||
            g.name.toLowerCase().contains(_searchQuery) ||
            s.name.toLowerCase().contains(_searchQuery) ||
            (s.code?.toLowerCase().contains(_searchQuery) ?? false);

        if (matchSearch) {
          for (final t in termsToInclude) {
            final weeks = t == 'Term 3' ? 9 : (t == 'Term 2' ? 14 : 13);
            final lessons = weeks * 5;
            schemeItems.add((
              grade: g,
              subject: s,
              term: t,
              year: 2026,
              weeks: weeks,
              lessons: lessons,
            ));
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Available CBC Schemes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: Colors.white,
            child: Column(
              children: [
                // Search Field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search schemes by grade or subject...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
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

                const SizedBox(height: 8),

                // Term Filter Chips
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildTermChip('Term 3'),
                      _buildTermChip('Term 2'),
                      _buildTermChip('Term 1'),
                      _buildTermChip('All Terms'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Schemes List View
          Expanded(
            child: schemeItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No Schemes Found',
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
                                _selectedTerm = 'Term 3';
                              });
                            },
                            child: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: schemeItems.length,
                    itemBuilder: (ctx, idx) {
                      final item = schemeItems[idx];
                      return _buildSchemeCard(
                        context: context,
                        grade: item.grade,
                        subject: item.subject,
                        termName: item.term,
                        year: item.year,
                        weeks: item.weeks,
                        lessons: item.lessons,
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
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedGrade = grade),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
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

  Widget _buildTermChip(String term) {
    final isSelected = _selectedTerm == term;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedTerm = term),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreenLight : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
              width: 1.1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            term,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchemeCard({
    required BuildContext context,
    required Grade grade,
    required Subject subject,
    required String termName,
    required int year,
    required int weeks,
    required int lessons,
  }) {
    Color cardColor = AppTheme.primaryGreen;
    Color lightColor = AppTheme.primaryGreenLight;

    if (termName == 'Term 2') {
      cardColor = AppTheme.accentBlue;
      lightColor = AppTheme.accentBlueLight;
    } else if (termName == 'Term 1') {
      cardColor = AppTheme.accentOrange;
      lightColor = AppTheme.accentOrangeLight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
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
                  color: lightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.menu_book_rounded, color: cardColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${grade.name} ${subject.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$termName – $year',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: cardColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  $weeks Wks ($lessons Lessons)',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Text(
            'Complete KICD-compliant CBC scheme with outcomes, activities, inquiry questions & assessments.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => SchemeDetailScreen(
                          grade: grade,
                          subject: subject,
                          termName: termName,
                          year: year,
                          weeks: weeks,
                          lessons: lessons,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    side: const BorderSide(color: AppTheme.borderSubtle, width: 1.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => GenerateWizardScreen(
                          initialGrade: grade,
                          initialSubject: subject,
                          initialTerm: termName,
                          initialYear: year,
                          initialWeeks: weeks,
                          initialLessonsPerWeek: (lessons ~/ weeks) > 0 ? (lessons ~/ weeks) : 5,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('Generate Scheme', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
