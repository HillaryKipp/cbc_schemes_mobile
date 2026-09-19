import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../core/utils/scheme_search_matcher.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/reference_book.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/guest_storage_service.dart';
import '../../../services/scheme_generator.dart';
import '../../../state/scheme_editor_provider.dart';
import '../../../state/scheme_list_provider.dart';
import '../../widgets/whatsapp_support_button.dart';
import '../editor/scheme_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _curriculum = CurriculumService.instance;
  final _guestStorage = GuestStorageService.instance;

  int _currentStep = 1; // 1: Curriculum, 2: Cover Details, 3: Timetable, 4: Generating
  bool _isLoading = true;

  // Grade & Curriculum Selection
  List<Grade> _grades = [];
  List<Subject> _subjects = [];
  List<ReferenceBook> _referenceBooks = [];
  List<Map<String, dynamic>> _allSubjectsForSearch = [];

  Grade? _selectedGrade;
  Subject? _selectedSubject;
  ReferenceBook? _selectedBook;
  String _selectedTerm = 'Term 1';
  int _selectedYear = 2026;
  int _weeks = 13;
  int _lessonsPerWeek = 5;
  String _pacingMode = 'progressive'; // 'progressive' or 'comprehensive'

  bool _isLoadingSubjects = false;
  bool _isLoadingBooks = false;

  // School & Teacher Profile Controllers
  final _schoolController = TextEditingController();
  final _tscController = TextEditingController();
  final _hodController = TextEditingController();
  final _teacherController = TextEditingController();

  // Natural Language Search
  final _searchController = TextEditingController();
  List<SchemeSearchMatch> _searchMatches = [];

  // Progress animation tasks
  final List<String> _progressTasks = [
    'Loading KICD curriculum designs',
    'Selecting strands & sub-strands',
    'Generating learning outcomes & experiences',
    'Embedding inquiry questions & resources',
    'Structuring 10-column scheme table',
  ];
  int _completedTaskCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final cached = _guestStorage.getTeacherProfile();
    _schoolController.text = cached['school_name'] ?? '';
    _tscController.text = cached['tsc_number'] ?? '';
    _hodController.text = cached['hod_name'] ?? '';
    _teacherController.text = cached['teacher_name'] ?? '';

    _grades = await _curriculum.getGrades();
    if (_grades.isNotEmpty) {
      _selectedGrade = _grades.firstWhere(
        (g) => g.id == 'grade-4' || g.name.toLowerCase() == 'grade 4',
        orElse: () => _grades.first,
      );
      await _onGradeChanged(_selectedGrade!);
    }

    // Preload subjects for natural language search
    final allSubs = <Map<String, dynamic>>[];
    for (final g in _grades) {
      final subs = await _curriculum.getSubjects(g.id, grade: g);
      for (final s in subs) {
        allSubs.add(s.toJson());
      }
    }
    _allSubjectsForSearch = allSubs;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onGradeChanged(Grade grade) async {
    setState(() {
      _selectedGrade = grade;
      _isLoadingSubjects = true;
      _subjects = [];
      _selectedSubject = null;
      _referenceBooks = [];
      _selectedBook = null;
    });

    final subs = await _curriculum.getSubjects(grade.id, grade: grade);
    if (!mounted) return;

    setState(() {
      _subjects = subs;
      _isLoadingSubjects = false;
      _selectedSubject = subs.isNotEmpty ? subs.first : null;
    });

    if (_selectedSubject != null) {
      await _onSubjectChanged(_selectedSubject!);
    }
  }

  Future<void> _onSubjectChanged(Subject subject) async {
    setState(() {
      _selectedSubject = subject;
      _isLoadingBooks = true;
      _referenceBooks = [];
      _selectedBook = null;
    });

    final books = await _curriculum.getReferenceBooks(subject.id);
    if (!mounted) return;

    setState(() {
      _referenceBooks = books;
      _selectedBook = books.isNotEmpty ? books.first : null;
      _isLoadingBooks = false;
    });
  }

  void _onTermChanged(String term) {
    setState(() {
      _selectedTerm = term;
      if (term == 'Term 3') {
        _weeks = 9;
      } else if (term == 'Term 2') {
        _weeks = 14;
      } else {
        _weeks = 13;
      }
    });
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchMatches = []);
      return;
    }
    final matches = parseSchemeSearch(
      query,
      _grades.map((g) => g.toJson()).toList(),
      _allSubjectsForSearch,
    );
    setState(() => _searchMatches = matches);
  }

  void _applyQuickPreset({
    required String gradeId,
    required String subjectKeyword,
    required String term,
  }) async {
    final normalizedKey = gradeId.replaceAll('-', ' ').toLowerCase();
    final grade = _grades.firstWhere(
      (g) => g.id == gradeId || g.name.toLowerCase() == normalizedKey,
      orElse: () => _grades.first,
    );
    await _onGradeChanged(grade);
    if (_subjects.isNotEmpty) {
      final matchSubject = _subjects.firstWhere(
        (s) => s.name.toLowerCase().contains(subjectKeyword.toLowerCase()),
        orElse: () => _subjects.first,
      );
      await _onSubjectChanged(matchSubject);
    }
    _onTermChanged(term);
  }

  void _saveTeacherProfile() {
    _guestStorage.saveTeacherProfile(
      schoolName: _schoolController.text.trim(),
      teacherName: _teacherController.text.trim(),
      tscNumber: _tscController.text.trim(),
      hodName: _hodController.text.trim(),
    );
  }

  void _startGeneration() async {
    if (_selectedGrade == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grade and subject')),
      );
      return;
    }

    _saveTeacherProfile();

    setState(() {
      _currentStep = 4;
      _completedTaskCount = 0;
    });

    final progressTimer = Timer.periodic(const Duration(milliseconds: 280), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_completedTaskCount < _progressTasks.length) {
        setState(() => _completedTaskCount++);
      } else {
        timer.cancel();
      }
    });

    try {
      final scheme = await SchemeGenerator.generateScheme(
        grade: _selectedGrade!,
        subject: _selectedSubject!,
        referenceBook: _selectedBook,
        termName: _selectedTerm,
        year: _selectedYear,
        weeks: _weeks,
        lessonsPerWeek: _lessonsPerWeek,
        pacingMode: _pacingMode,
        schoolName: _schoolController.text.trim(),
        teacherName: _teacherController.text.trim(),
        tscNumber: _tscController.text.trim(),
        hodName: _hodController.text.trim(),
      );

      await Future.delayed(const Duration(milliseconds: 1400));
      progressTimer.cancel();

      if (!mounted) return;

      context.read<SchemeEditorProvider>().setScheme(scheme);
      context.read<SchemeListProvider>().loadSchemes();

      setState(() => _currentStep = 1);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => SchemeEditorScreen(scheme: scheme),
        ),
      );
    } catch (e) {
      progressTimer.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating scheme: $e')),
      );
      setState(() => _currentStep = 3);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _schoolController.dispose();
    _tscController.dispose();
    _hodController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    return PopScope(
      canPop: _currentStep == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 1 && _currentStep < 4) {
          setState(() => _currentStep--);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
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
                    'CBC SCHEMES OF WORK',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    'Official Lesson Planning & Curriculum Engine',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildStepperHeader(),
            const Divider(height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildCurrentStepWidget(),
              ),
            ),
          ],
        ),
        floatingActionButton: _currentStep != 4 ? const WhatsAppSupportButton(mini: true) : null,
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          _buildStepMilestone(1, 'Curriculum', Icons.school_outlined),
          _buildStepConnector(1),
          _buildStepMilestone(2, 'Cover Details', Icons.badge_outlined),
          _buildStepConnector(2),
          _buildStepMilestone(3, 'Timetable', Icons.calendar_month_outlined),
          _buildStepConnector(3),
          _buildStepMilestone(4, 'Generate', Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  Widget _buildStepMilestone(int step, String label, IconData icon) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Expanded(
      flex: 3,
      child: InkWell(
        onTap: () {
          if (step < _currentStep && _currentStep != 4) {
            setState(() => _currentStep = step);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? AppTheme.primaryGreen
                    : (isDone ? AppTheme.primaryGreenLight : const Color(0xFFF3F4F6)),
                border: Border.all(
                  color: (isCurrent || isDone) ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: AppTheme.primaryGreen)
                    : Icon(
                        icon,
                        size: 15,
                        color: isCurrent ? Colors.white : AppTheme.textMuted,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: isCurrent ? AppTheme.primaryGreen : AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isDone = _currentStep > step;
    return Expanded(
      flex: 1,
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        color: isDone ? AppTheme.primaryGreen : const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Curriculum();
      case 2:
        return _buildStep2SchoolDetails();
      case 3:
        return _buildStep3Calendar();
      case 4:
        return _buildStep4Generating();
      default:
        return _buildStep1Curriculum();
    }
  }

  // STEP 1: Natural Language Search + Term Cards + Workflow + Curriculum
  Widget _buildStep1Curriculum() {
    return ListView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. Natural Language Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search schemes (e.g. "grade 4 math term 1", "sst grade 7")',
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                onChanged: _onSearchChanged,
              ),

              // Search Suggestions
              if (_searchMatches.isNotEmpty) ...[
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchMatches.length,
                    itemBuilder: (ctx, i) {
                      final match = _searchMatches[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.auto_stories_outlined, color: AppTheme.primaryGreen, size: 18),
                        title: Text(
                          '${match.gradeName} ${match.subjectName}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: match.term != null ? Text(match.term!, style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen)) : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          _applyQuickPreset(
                            gradeId: match.gradeId,
                            subjectKeyword: match.subjectName,
                            term: match.term ?? _selectedTerm,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Official 2026 Term Shortcut Cards
        Row(
          children: [
            _buildTermDateCard('Term 1', 'Jan 5 – Apr 3', '13 Weeks', 13),
            const SizedBox(width: 8),
            _buildTermDateCard('Term 2', 'Apr 27 – Jul 31', '14 Weeks', 14),
            const SizedBox(width: 8),
            _buildTermDateCard('Term 3', 'Aug 24 – Oct 23', '9 Weeks', 9),
          ],
        ),

        const SizedBox(height: 14),

        // 3. 4-Step Workflow Guide
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: AppTheme.primaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'HOW IT WORKS: 4 EASY STEPS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildWorkflowStep('1. Choose', 'Grade, subject & term'),
                  _buildWorkflowStep('2. Generate', 'KICD outcomes & items'),
                  _buildWorkflowStep('3. Edit', 'Rows & reflections'),
                  _buildWorkflowStep('4. Export', 'DOCX, PDF & WhatsApp'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. Primary Curriculum Selection Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Grade Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<Grade>(
                key: ValueKey('grade-select-${_selectedGrade?.id}'),
                initialValue: _grades.contains(_selectedGrade) ? _selectedGrade : null,
                isExpanded: true,
                hint: const Text('Select Grade'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.school_outlined, color: AppTheme.primaryGreen, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _grades.map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(
                    '${g.name} (${g.displayLevel})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _onGradeChanged(val);
                  }
                },
              ),

              const SizedBox(height: 12),

              const Text('2. Learning Area / Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<Subject>(
                key: ValueKey('subject-select-${_selectedGrade?.id}-${_selectedSubject?.id}'),
                initialValue: _subjects.contains(_selectedSubject) ? _selectedSubject : null,
                isExpanded: true,
                hint: Text(_isLoadingSubjects ? 'Loading learning areas...' : 'Select Subject'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.menu_book_outlined, color: AppTheme.primaryGreen, size: 20),
                  suffixIcon: _isLoadingSubjects
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                          ),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _subjects.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _isLoadingSubjects ? null : (val) {
                  if (val != null) {
                    _onSubjectChanged(val);
                  }
                },
              ),

              const SizedBox(height: 14),

              const Text('3. Academic Term', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildTermChip('Term 1', '13 Wks'),
                  const SizedBox(width: 8),
                  _buildTermChip('Term 2', '14 Wks'),
                  const SizedBox(width: 8),
                  _buildTermChip('Term 3', '9 Wks'),
                ],
              ),

              const SizedBox(height: 14),

              const Text('4. Academic Year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              Row(
                children: [2025, 2026, 2027].map((yr) {
                  final isSelected = _selectedYear == yr;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _selectedYear = yr),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryGreenLight : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$yr',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_referenceBooks.isNotEmpty || _isLoadingBooks) ...[
                const SizedBox(height: 14),
                const Text('5. Reference Course Book', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                const SizedBox(height: 6),
                DropdownButtonFormField<ReferenceBook>(
                  key: ValueKey('book-select-${_selectedSubject?.id}-${_selectedBook?.id}'),
                  initialValue: _referenceBooks.contains(_selectedBook) ? _selectedBook : null,
                  isExpanded: true,
                  hint: Text(_isLoadingBooks ? 'Loading books...' : 'All KICD Approved Books'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.auto_stories_outlined, color: AppTheme.primaryGreen, size: 19),
                    suffixIcon: _isLoadingBooks
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                            ),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<ReferenceBook>(
                      value: null,
                      child: Text('All Approved Books (General)', style: TextStyle(fontSize: 12.5)),
                    ),
                    ..._referenceBooks.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(
                        b.publisher.isEmpty ? b.title : '${b.title} (${b.publisher})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    )),
                  ],
                  onChanged: _isLoadingBooks ? null : (val) => setState(() => _selectedBook = val),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Quick Preset Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetButton('Grade 4 Math', 'grade-4', 'math', 'Term 1'),
              const SizedBox(width: 8),
              _buildPresetButton('Grade 7 Science', 'grade-7', 'sci', 'Term 1'),
              const SizedBox(width: 8),
              _buildPresetButton('Grade 5 English', 'grade-5', 'eng', 'Term 1'),
              const SizedBox(width: 8),
              _buildPresetButton('Grade 8 Agri', 'grade-8', 'agri', 'Term 1'),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Next Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_selectedGrade == null || _selectedSubject == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select Grade and Subject')),
                );
                return;
              }
              setState(() => _currentStep = 2);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next: Cover Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermDateCard(String term, String dates, String duration, int weeks) {
    final isSelected = _selectedTerm == term;
    return Expanded(
      child: InkWell(
        onTap: () => _onTermChanged(term),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreenLight : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                term,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dates,
                style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowStep(String title, String subtitle) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: AppTheme.textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTermChip(String term, String duration) {
    final isSelected = _selectedTerm == term;
    return Expanded(
      child: InkWell(
        onTap: () => _onTermChanged(term),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreenLight : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                term,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, String gradeId, String subjectKey, String term) {
    return InkWell(
      onTap: () => _applyQuickPreset(gradeId: gradeId, subjectKeyword: subjectKey, term: term),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on_rounded, size: 14, color: AppTheme.primaryGreen),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          ],
        ),
      ),
    );
  }

  // STEP 2: School & Teacher Profile
  Widget _buildStep2SchoolDetails() {
    return ListView(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('School Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Nairobi Primary School / Academy',
                  prefixIcon: Icon(Icons.account_balance_outlined, size: 19),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Teacher Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _teacherController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Tr. Jane Doe',
                  prefixIcon: Icon(Icons.person_outline, size: 19),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TSC / ID No.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _tscController,
                          decoration: const InputDecoration(
                            hintText: 'TSC No.',
                            prefixIcon: Icon(Icons.badge_outlined, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('H.O.D Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _hodController,
                          decoration: const InputDecoration(
                            hintText: 'H.O.D',
                            prefixIcon: Icon(Icons.supervisor_account_outlined, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  _saveTeacherProfile();
                  setState(() => _currentStep = 3);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Next: Timetable & Pacing', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3: Timetable, Lessons & Pacing Mode
  Widget _buildStep3Calendar() {
    return ListView(
      key: const ValueKey(3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Summary Card
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
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryGreen, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '$_selectedTerm – $_selectedYear',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total ${_weeks * _lessonsPerWeek} Lessons across $_weeks Weeks',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Lessons per week
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
              const Text('Lessons per Week', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGreen),
                    onPressed: () {
                      if (_lessonsPerWeek > 1) {
                        setState(() => _lessonsPerWeek--);
                      }
                    },
                  ),
                  Text(
                    '$_lessonsPerWeek lessons / week',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
                    onPressed: () {
                      if (_lessonsPerWeek < 12) {
                        setState(() => _lessonsPerWeek++);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Pacing & Progression Mode
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
                'Lesson Pacing & Progression',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how outcomes & experiences are distributed across lessons:',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),

              // Option A: Progressive
              RadioListTile<String>(
                value: 'progressive',
                groupValue: _pacingMode,
                activeColor: AppTheme.primaryGreen,
                contentPadding: EdgeInsets.zero,
                title: const Text('Progressive (Recommended)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Distributes outcomes and questions step-by-step per lesson so teachers do not repeat every outcome in every lesson.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _pacingMode = val);
                },
              ),

              const Divider(height: 14),

              // Option B: Comprehensive
              RadioListTile<String>(
                value: 'comprehensive',
                groupValue: _pacingMode,
                activeColor: AppTheme.primaryGreen,
                contentPadding: EdgeInsets.zero,
                title: const Text('Comprehensive', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Assigns all sub-strand outcomes and experiences to every lesson slot.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _pacingMode = val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 2),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _startGeneration,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate Scheme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 4: Generating Screen Animation
  Widget _buildStep4Generating() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'Generating KICD Scheme of Work',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              '${_selectedGrade?.name} ${_selectedSubject?.name} • $_selectedTerm $_selectedYear',
              style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: List.generate(_progressTasks.length, (idx) {
                  final isDone = idx < _completedTaskCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          size: 16,
                          color: isDone ? AppTheme.primaryGreen : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _progressTasks[idx],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                            color: isDone ? AppTheme.textDark : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
