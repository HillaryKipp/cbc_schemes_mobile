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

  String _selectedTermFilter = 'All Terms';
  late Grade _grade;
  late Subject _subject;
  bool _isLoading = true;
  List<Grade> _allGrades = [];
  List<Subject> _allSubjects = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _allGrades = await _curriculum.getGrades();

    _grade = widget.selectedGrade ??
        _allGrades.firstWhere((g) => g.id == 'grade-6', orElse: () => _allGrades.first);

    _allSubjects = await _curriculum.getSubjects(_grade.id);
    _subject = widget.selectedSubject ??
        _allSubjects.firstWhere((s) => s.name.toLowerCase().contains('math'), orElse: () => _allSubjects.first);

    setState(() => _isLoading = false);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Schemes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<Grade>(
                value: _grade,
                decoration: const InputDecoration(labelText: 'Grade'),
                items: _allGrades.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _grade = val);
                    _curriculum.getSubjects(val.id).then((subs) {
                      setState(() {
                        _allSubjects = subs;
                        if (subs.isNotEmpty) _subject = subs.first;
                      });
                    });
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Subject>(
                value: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: _allSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subject = val);
                    Navigator.pop(ctx);
                  }
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    final terms = [
      (
        name: 'Term 3',
        year: 2026,
        weeks: 9,
        lessons: 45,
        color: AppTheme.primaryGreen,
        lightColor: AppTheme.primaryGreenLight,
        icon: Icons.grid_view_rounded,
      ),
      (
        name: 'Term 2',
        year: 2026,
        weeks: 14,
        lessons: 70,
        color: AppTheme.accentBlue,
        lightColor: AppTheme.accentBlueLight,
        icon: Icons.description_outlined,
      ),
      (
        name: 'Term 1',
        year: 2026,
        weeks: 13,
        lessons: 65,
        color: AppTheme.accentOrange,
        lightColor: AppTheme.accentOrangeLight,
        icon: Icons.article_outlined,
      ),
    ];

    final filteredTerms = _selectedTermFilter == 'All Terms'
        ? terms
        : terms.where((t) => t.name == _selectedTermFilter).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Search Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, size: 22),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Title
          Text(
            '${_grade.name} ${_subject.name}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Schemes of Work',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),

          const SizedBox(height: 14),

          // Term Filter Pills
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterPill('All Terms'),
                _buildFilterPill('Term 1'),
                _buildFilterPill('Term 2'),
                _buildFilterPill('Term 3'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Term Scheme Result Cards
          ...filteredTerms.map((item) {
            return _buildTermSchemeCard(
              context: context,
              termName: item.name,
              year: item.year,
              weeks: item.weeks,
              lessons: item.lessons,
              color: item.color,
              lightColor: item.lightColor,
              icon: item.icon,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label) {
    final isSelected = _selectedTermFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedTermFilter = label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermSchemeCard({
    required BuildContext context,
    required String termName,
    required int year,
    required int weeks,
    required int lessons,
    required Color color,
    required Color lightColor,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              // Icon Box
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),

              // Title & Term Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_grade.name} ${_subject.name}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$termName – $year',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Metadata text: 9 Weeks • 45 Lessons
          Text(
            '$weeks Weeks  •  $lessons Lessons',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Comprehensive scheme of work aligned to CBC curriculum.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4B5563),
            ),
          ),

          const SizedBox(height: 14),

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
                          grade: _grade,
                          subject: _subject,
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: AppTheme.borderSubtle, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => GenerateWizardScreen(
                          initialGrade: _grade,
                          initialSubject: _subject,
                          initialTerm: termName,
                          initialYear: year,
                          initialWeeks: weeks,
                          initialLessonsPerWeek: (lessons ~/ weeks) > 0 ? (lessons ~/ weeks) : 5,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Generate Scheme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
