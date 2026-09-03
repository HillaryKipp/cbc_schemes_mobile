import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../services/curriculum_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/scheme_list_provider.dart';
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

  void _onFindSchemes() {
    if (_selectedGrade != null && _selectedSubject != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => SchemesScreen(
            selectedGrade: _selectedGrade,
            selectedSubject: _selectedSubject,
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
    }

    if (matchedGrade != null) {
      _curriculum.getSubjects(matchedGrade.id).then((subs) {
        if (query.contains('Mathematics')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('math'), orElse: () => subs.first);
        } else if (query.contains('English')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('eng'), orElse: () => subs.first);
        } else if (query.contains('Science')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('sci'), orElse: () => subs.first);
        } else if (query.contains('Kiswahili')) {
          matchedSubject = subs.firstWhere((s) => s.name.toLowerCase().contains('kisw'), orElse: () => subs.first);
        }

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
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
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
                const SnackBar(content: Text('Term 3 2026 CBC Schemes curriculum banks are now updated!')),
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
                  TextSpan(text: 'Find, Preview & Generate\n'),
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
              'Access CBC schemes for all grades and subjects. No login required.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textMuted,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search schemes of work...\ne.g. Grade 6 Mathematics, Grade 4 English',
                  hintMaxLines: 2,
                  prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _onPopularSearch(val.trim());
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // "Find a Scheme" Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find a Scheme',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 12),

                  // Select Grade Dropdown
                  DropdownButtonFormField<Grade>(
                    value: _selectedGrade,
                    hint: const Text('Select Grade'),
                    decoration: const InputDecoration(
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
                  const SizedBox(height: 10),

                  // Select Subject Dropdown
                  DropdownButtonFormField<Subject>(
                    value: _selectedSubject,
                    hint: const Text('Select Subject'),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (val) => setState(() => _selectedSubject = val),
                  ),
                  const SizedBox(height: 10),

                  // Select Term Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTerm,
                    hint: const Text('Select Term'),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Term 1', child: Text('Term 1')),
                      DropdownMenuItem(value: 'Term 2', child: Text('Term 2')),
                      DropdownMenuItem(value: 'Term 3', child: Text('Term 3')),
                    ],
                    onChanged: (val) => setState(() => _selectedTerm = val ?? 'Term 3'),
                  ),
                  const SizedBox(height: 14),

                  // Find Schemes Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _onFindSchemes,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Find Schemes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Popular Searches
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Searches',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => SchemesScreen(
                          selectedGrade: _selectedGrade,
                          selectedSubject: _selectedSubject,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSearchChip('Grade 6 Mathematics'),
                _buildSearchChip('Grade 5 English'),
                _buildSearchChip('Grade 7 Science'),
                _buildSearchChip('Grade 4 Kiswahili'),
              ],
            ),

            const SizedBox(height: 20),

            // Popular Schemes
            const Text(
              'Popular Schemes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),

            // Popular Scheme Card
            InkWell(
              onTap: () {
                final g6 = _grades.firstWhere((g) => g.id == 'grade-6', orElse: () => _grades.first);
                _curriculum.getSubjects(g6.id).then((subs) {
                  final math = subs.firstWhere((s) => s.name.toLowerCase().contains('math'), orElse: () => subs.first);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => SchemeDetailScreen(
                        grade: g6,
                        subject: math,
                        termName: 'Term 3',
                        year: 2026,
                        weeks: 9,
                        lessons: 45,
                      ),
                    ),
                  );
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
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
                          const Text(
                            'Grade 6 Mathematics',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Term 3 – 2026',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '9 Weeks  •  45 Lessons',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
