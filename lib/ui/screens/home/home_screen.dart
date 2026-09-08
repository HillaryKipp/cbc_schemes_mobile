import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../services/curriculum_service.dart';
import '../../../state/scheme_list_provider.dart';
import '../generate/generate_wizard_screen.dart';
import '../schemes/schemes_screen.dart';
import '../schemes/scheme_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _curriculum = CurriculumService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Grade> _grades = [];
  List<Subject> _subjects = [];
  Grade? _selectedGrade;
  Subject? _selectedSubject;
  String _selectedTerm = 'Term 3';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _grades = await _curriculum.getGrades();
    if (_grades.isNotEmpty) {
      _selectedGrade = _grades.firstWhere((g) => g.id == 'grade-6', orElse: () => _grades.first);
      await _loadSubjectsForGrade(_selectedGrade!);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadSubjectsForGrade(Grade grade) async {
    _subjects = await _curriculum.getSubjects(grade.id);
    _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
  }

  void _onGenerateDirectly() {
    if (_selectedGrade != null && _selectedSubject != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => GenerateWizardScreen(
            initialGrade: _selectedGrade,
            initialSubject: _selectedSubject,
            initialTerm: _selectedTerm,
            initialYear: 2026,
            initialWeeks: _selectedTerm == 'Term 3' ? 9 : (_selectedTerm == 'Term 2' ? 14 : 13),
            initialLessonsPerWeek: 5,
          ),
        ),
      );
    }
  }

  void _onPopularSearch(String query) {
    // Find matching grade and subject
    Grade? matchedGrade;
    Subject? matchedSubject;

    if (query.contains('Grade 6')) {
      matchedGrade = _grades.firstWhere((g) => g.id == 'grade-6', orElse: () => _grades.first);
    } else if (query.contains('Grade 5')) {
      matchedGrade = _grades.firstWhere((g) => g.id == 'grade-5', orElse: () => _grades.first);
    } else if (query.contains('Grade 7')) {
      matchedGrade = _grades.firstWhere((g) => g.id == 'grade-7', orElse: () => _grades.first);
    } else if (query.contains('Grade 4')) {
      matchedGrade = _grades.firstWhere((g) => g.id == 'grade-4', orElse: () => _grades.first);
    } else if (query.contains('Grade 8')) {
      matchedGrade = _grades.firstWhere((g) => g.id == 'grade-8', orElse: () => _grades.first);
    } else if (query.contains('Grade 3')) {
      matchedGrade = _grades.firstWhere((g) => g.id == 'grade-3', orElse: () => _grades.first);
    }

    if (matchedGrade != null) {
      _curriculum.getSubjects(matchedGrade.id).then((subs) {
        if (query.contains('Mathematics') || query.contains('Math')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('math'), orElse: () => subs.first);
        } else if (query.contains('English')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('eng'), orElse: () => subs.first);
        } else if (query.contains('Science')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('sci'), orElse: () => subs.first);
        } else if (query.contains('Kiswahili')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('kisw'), orElse: () => subs.first);
        } else if (query.contains('Agriculture')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('agri'), orElse: () => subs.first);
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => SchemesScreen(
              selectedGrade: matchedGrade,
              selectedSubject: matchedSubject ?? (subs.isNotEmpty ? subs.first : null),
              initialQuery: query,
            ),
          ),
        );
      });
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => SchemesScreen(
            initialQuery: query,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CBC SCHEMES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  'OF WORK',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Term 3 2026 CBC Schemes curriculum banks are updated and ready!')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
          if (mounted) {
            context.read<SchemeListProvider>().loadSchemes();
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const SizedBox(height: 8),

            // Hero Headline
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  height: 1.25,
                ),
                children: [
                  TextSpan(text: 'Generate & Customize\n'),
                  TextSpan(
                    text: 'CBC Schemes of Work\n',
                    style: TextStyle(color: AppTheme.primaryGreen),
                  ),
                  TextSpan(text: 'for Kenyan Teachers'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Pick any grade, subject and term to generate an editable, KICD-compliant scheme of work instantly downloadable as Word or PDF.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textMuted,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 16),

            // "Generate a Scheme" Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.mode_edit_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generate a Scheme',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                            ),
                            Text(
                              'Select details to generate instantly',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Select Grade Dropdown
                  DropdownButtonFormField<Grade>(
                    value: _selectedGrade,
                    hint: const Text('Select Grade'),
                    decoration: const InputDecoration(
                      labelText: 'Grade Level',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedGrade = val);
                        _loadSubjectsForGrade(val).then((_) => setState(() {}));
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Select Subject Dropdown
                  DropdownButtonFormField<Subject>(
                    value: _selectedSubject,
                    hint: const Text('Select Subject'),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (val) => setState(() => _selectedSubject = val),
                  ),
                  const SizedBox(height: 12),

                  // Select Term Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTerm,
                    hint: const Text('Select Term'),
                    decoration: const InputDecoration(
                      labelText: 'Term',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Term 1', child: Text('Term 1 (13 Weeks)')),
                      DropdownMenuItem(value: 'Term 2', child: Text('Term 2 (14 Weeks)')),
                      DropdownMenuItem(value: 'Term 3', child: Text('Term 3 (9 Weeks)')),
                    ],
                    onChanged: (val) => setState(() => _selectedTerm = val ?? 'Term 3'),
                  ),
                  const SizedBox(height: 18),

                  // Generate Scheme Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _onGenerateDirectly,
                      icon: const Icon(Icons.auto_awesome, size: 19),
                      label: const Text('Generate Scheme Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Pick & Generate Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available CBC Schemes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                InkWell(
                  onTap: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(1);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SchemesScreen()),
                      );
                    }
                  },
                  child: const Text(
                    'Browse all',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick any curriculum scheme below to generate or preview immediately:',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),

            // Popular Schemes Quick Pick List
            _buildSchemePickCard(
              gradeId: 'grade-6',
              gradeName: 'Grade 6',
              subjectKeyword: 'math',
              subjectName: 'Mathematics',
              termName: 'Term 3',
              year: 2026,
              weeks: 9,
              lessons: 45,
            ),
            _buildSchemePickCard(
              gradeId: 'grade-7',
              gradeName: 'Grade 7',
              subjectKeyword: 'sci',
              subjectName: 'Integrated Science',
              termName: 'Term 3',
              year: 2026,
              weeks: 9,
              lessons: 36,
            ),
            _buildSchemePickCard(
              gradeId: 'grade-5',
              gradeName: 'Grade 5',
              subjectKeyword: 'eng',
              subjectName: 'English Language',
              termName: 'Term 3',
              year: 2026,
              weeks: 9,
              lessons: 45,
            ),
            _buildSchemePickCard(
              gradeId: 'grade-4',
              gradeName: 'Grade 4',
              subjectKeyword: 'kisw',
              subjectName: 'Kiswahili',
              termName: 'Term 3',
              year: 2026,
              weeks: 9,
              lessons: 36,
            ),
            _buildSchemePickCard(
              gradeId: 'grade-7',
              gradeName: 'Grade 7',
              subjectKeyword: 'agri',
              subjectName: 'Agriculture & Nutrition',
              termName: 'Term 3',
              year: 2026,
              weeks: 9,
              lessons: 36,
            ),

            const SizedBox(height: 16),

            // Popular Search Chips
            const Text(
              'Quick Grade Search',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSearchChip('Grade 6 Mathematics'),
                _buildSearchChip('Grade 7 Science'),
                _buildSearchChip('Grade 5 English'),
                _buildSearchChip('Grade 4 Kiswahili'),
                _buildSearchChip('Grade 8 Agriculture'),
                _buildSearchChip('Grade 3 Environmental'),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemePickCard({
    required String gradeId,
    required String gradeName,
    required String subjectKeyword,
    required String subjectName,
    required String termName,
    required int year,
    required int weeks,
    required int lessons,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$gradeName $subjectName',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$termName – $year • $weeks Weeks ($lessons Lessons)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final grade = _grades.firstWhere((g) => g.id == gradeId, orElse: () => _grades.first);
                    final subjects = await _curriculum.getSubjects(grade.id);
                    final subj = subjects.firstWhere(
                      (s) => s.name.toLowerCase().contains(subjectKeyword),
                      orElse: () => subjects.first,
                    );
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => SchemeDetailScreen(
                          grade: grade,
                          subject: subj,
                          termName: termName,
                          year: year,
                          weeks: weeks,
                          lessons: lessons,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final grade = _grades.firstWhere((g) => g.id == gradeId, orElse: () => _grades.first);
                    final subjects = await _curriculum.getSubjects(grade.id);
                    final subj = subjects.firstWhere(
                      (s) => s.name.toLowerCase().contains(subjectKeyword),
                      orElse: () => subjects.first,
                    );
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => GenerateWizardScreen(
                          initialGrade: grade,
                          initialSubject: subj,
                          initialTerm: termName,
                          initialYear: year,
                          initialWeeks: weeks,
                          initialLessonsPerWeek: (lessons ~/ weeks) > 0 ? (lessons ~/ weeks) : 5,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('Generate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
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

  Widget _buildSearchChip(String label) {
    return InkWell(
      onTap: () => _onPopularSearch(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.textDark),
        ),
      ),
    );
  }
}
