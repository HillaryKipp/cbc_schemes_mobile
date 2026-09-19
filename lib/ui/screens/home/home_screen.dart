import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../core/utils/scheme_search_matcher.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/term_settings.dart';
import '../../../services/curriculum_service.dart';
import '../../../models/strand.dart';
import '../../../services/guest_storage_service.dart';
import '../../../services/scheme_generator.dart';
import '../../../services/seed_data.dart';
import '../../../state/scheme_editor_provider.dart';
import '../../../state/scheme_list_provider.dart';
import '../../widgets/whatsapp_support_button.dart';
import '../preview/scheme_preview_screen.dart';
import '../generate/widgets/term_calendar_customizer.dart';
import '../generate/widgets/scope_and_sequence_customizer.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _curriculum = CurriculumService.instance;
  final _guestStorage = GuestStorageService.instance;

  int _currentStep = 1; // 1: Curriculum, 2: Timetable, 3: Cover Details, 4: Generating
  bool _isLoading = true;

  // Grade & Curriculum Selection
  List<Grade> _grades = [];
  List<Subject> _subjects = [];
  List<Map<String, dynamic>> _allSubjectsForSearch = [];

  Grade? _selectedGrade;
  Subject? _selectedSubject;
  String _selectedTerm = 'Term 1';
  final int _selectedYear = 2026;
  static const String _pacingMode = 'progressive'; // strictly progressive (no comprehensive option)

  // Scope & Sequence customization
  List<Strand> _strands = [];
  Map<int, List<TermSubStrandAssignment>> _assignments = {1: [], 2: [], 3: []};
  bool _isLoadingStrands = false;
  bool _showScopeAndSequence = false;
  int _activeTermScopeFilter = 0; // 0 = all terms, 1 = Term 1, etc.

  // 2026 Academic Term Settings
  late Map<int, TermSettings> _termSettings;

  bool _isLoadingSubjects = false;

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
    _termSettings = TermSettings.getOfficial2026Defaults(defaultLessonsPerWeek: 5);
    _loadInitialData();
  }

  int get _activeTermNumber {
    if (_selectedTerm.contains('3')) return 3;
    if (_selectedTerm.contains('2')) return 2;
    return 1;
  }

  TermSettings get _currentTermSettings => _termSettings[_activeTermNumber]!;

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final cached = _guestStorage.getTeacherProfile();
    _schoolController.text = cached['school_name'] ?? '';
    _tscController.text = cached['tsc_number'] ?? '';
    _hodController.text = cached['hod_name'] ?? '';
    _teacherController.text = cached['teacher_name'] ?? '';

    _grades = await _curriculum.getGrades();
    _selectedGrade = null;
    _selectedSubject = null;
    _subjects = [];

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

  Future<void> _loadStrandsForSubject(Subject? subject) async {
    if (subject == null) {
      setState(() {
        _strands = [];
        _assignments = {1: [], 2: [], 3: []};
      });
      return;
    }

    setState(() => _isLoadingStrands = true);
    final strands = await _curriculum.getStrandsWithSubStrands(subject.id);
    if (!mounted) return;

    setState(() {
      _strands = strands.isNotEmpty ? strands : SeedData.defaultStrands;
      _isLoadingStrands = false;
    });

    _autoBalanceAssignments();
  }

  void _autoBalanceAssignments() {
    final effectiveStrands = _strands.isNotEmpty ? _strands : SeedData.defaultStrands;

    final strandsMap = effectiveStrands.map((s) => s.toJson()).toList();
    final subStrandsMap = <Map<String, dynamic>>[];
    for (final s in effectiveStrands) {
      for (final ss in s.subStrands) {
        subStrandsMap.add(ss.toJson());
      }
    }

    final capacities = [
      TermCapacity(termNumber: 1, totalLessons: _termSettings[1]!.availableTeachingSlots),
      TermCapacity(termNumber: 2, totalLessons: _termSettings[2]!.availableTeachingSlots),
      TermCapacity(termNumber: 3, totalLessons: _termSettings[3]!.availableTeachingSlots),
    ];

    final result = SchemeGenerator.autoDistributeSubStrandsToTerms(
      strands: strandsMap,
      subStrands: subStrandsMap,
      termCapacities: capacities,
    );

    setState(() {
      _assignments = result;
    });
  }

  Future<void> _onGradeChanged(Grade grade) async {
    setState(() {
      _selectedGrade = grade;
      _isLoadingSubjects = true;
      _subjects = [];
      _selectedSubject = null;
      _strands = [];
      _assignments = {1: [], 2: [], 3: []};
    });

    final subs = await _curriculum.getSubjects(grade.id, grade: grade);
    if (!mounted) return;

    final firstSub = subs.isNotEmpty ? subs.first : null;
    setState(() {
      _subjects = subs;
      _isLoadingSubjects = false;
      _selectedSubject = firstSub;
    });

    await _loadStrandsForSubject(firstSub);
  }

  Future<void> selectGradeAndSubject(Grade grade, Subject subject) async {
    setState(() {
      _selectedGrade = grade;
      _isLoadingSubjects = true;
      _subjects = [];
      _selectedSubject = null;
      _strands = [];
      _assignments = {1: [], 2: [], 3: []};
    });

    final subs = await _curriculum.getSubjects(grade.id, grade: grade);
    if (!mounted) return;

    final matched = subs.firstWhere(
      (s) => s.id == subject.id || s.name.toLowerCase() == subject.name.toLowerCase(),
      orElse: () => subject,
    );

    setState(() {
      _subjects = subs;
      _isLoadingSubjects = false;
      _selectedSubject = matched;
      _currentStep = 1;
    });

    await _loadStrandsForSubject(matched);
  }

  void _onTermChanged(String term) {
    setState(() {
      _selectedTerm = term;
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
      setState(() => _selectedSubject = matchSubject);
      await _loadStrandsForSubject(matchSubject);
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
      final curSettings = _currentTermSettings;
      final scheme = await SchemeGenerator.generateScheme(
        grade: _selectedGrade!,
        subject: _selectedSubject!,
        referenceBook: null,
        termName: curSettings.termName,
        year: _selectedYear,
        weeks: curSettings.weeks,
        lessonsPerWeek: curSettings.lessonsPerWeek,
        pacingMode: _pacingMode,
        halfTermWeek: curSettings.includeHalfTerm ? curSettings.halfTermWeek : null,
        assessmentWeeks: curSettings.assessmentWeeks,
        assignedSubStrands: _assignments[_activeTermNumber],
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
          builder: (ctx) => SchemePreviewScreen(scheme: scheme),
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
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CBC SCHEMES OF WORK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    'Official Lesson Planning & Curriculum Engine',
                    textAlign: TextAlign.center,
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
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator circles and connecting lines
          Row(
            children: [
              _buildStepIndicatorCircle(1),
              _buildStepConnectingLine(1),
              _buildStepIndicatorCircle(2),
              _buildStepConnectingLine(2),
              _buildStepIndicatorCircle(3),
              _buildStepConnectingLine(3),
              _buildStepIndicatorCircle(4),
            ],
          ),
          const SizedBox(height: 8),
          // Step text labels aligned underneath each circle
          Row(
            children: [
              _buildStepTextLabel(1, 'STEP 1', 'Curriculum'),
              const SizedBox(width: 8),
              _buildStepTextLabel(2, 'STEP 2', 'Timetable'),
              const SizedBox(width: 8),
              _buildStepTextLabel(3, 'STEP 3', 'Cover Details'),
              const SizedBox(width: 8),
              _buildStepTextLabel(4, 'STEP 4', 'Generate'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorCircle(int step) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    Widget content;
    if (isDone) {
      content = const Icon(Icons.check_rounded, size: 18, color: Colors.white);
    } else {
      switch (step) {
        case 1:
          content = ClipOval(
            child: Image.asset(
              'assets/images/stepper_kicd.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.school_rounded, size: 16, color: AppTheme.primaryGreen),
            ),
          );
          break;
        case 2:
          content = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/images/stepper_calendar.png',
              width: 20,
              height: 20,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.primaryGreen),
            ),
          );
          break;
        case 3:
          content = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/images/stepper_cover.png',
              width: 20,
              height: 20,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.badge_rounded, size: 16, color: AppTheme.primaryGreen),
            ),
          );
          break;
        case 4:
        default:
          content = Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: isCurrent ? Colors.white : const Color(0xFF9CA3AF),
          );
          break;
      }
    }

    return InkWell(
      onTap: () {
        if (step < _currentStep && _currentStep != 4) {
          setState(() => _currentStep = step);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone
              ? const Color(0xFF22C55E) // Completed vivid green
              : (isCurrent
                  ? (step == 4 ? AppTheme.primaryGreen : Colors.white)
                  : const Color(0xFFF9FAFB)),
          border: isCurrent
              ? Border.all(color: AppTheme.primaryGreen, width: 2.2)
              : (isDone
                  ? null
                  : Border.all(color: const Color(0xFFE5E7EB), width: 1.5)),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildStepConnectingLine(int step) {
    final isDone = _currentStep > step;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 3.5,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStepTextLabel(int step, String stepNum, String title) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (step < _currentStep && _currentStep != 4) {
            setState(() => _currentStep = step);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              stepNum,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isCurrent
                    ? AppTheme.primaryGreen
                    : (isDone ? const Color(0xFF16A34A) : AppTheme.textMuted),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w800 : (isDone ? FontWeight.w700 : FontWeight.w600),
                color: (isCurrent || isDone) ? AppTheme.textDark : AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Curriculum();
      case 2:
        return _buildStep2Timetable();
      case 3:
        return _buildStep3CoverDetails();
      case 4:
        return _buildStep4Generating();
      default:
        return _buildStep1Curriculum();
    }
  }

  // STEP 1: Simple Curriculum Selection (Grade, Subject, Term) + Live Term Calendar Preview
  Widget _buildStep1Curriculum() {
    final curSettings = _currentTermSettings;
    final hasSelection = _selectedGrade != null && _selectedSubject != null;

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
                  hintText: 'Search schemes (e.g. "grade 4 math", "sst grade 7")',
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

        // 2. Primary Curriculum Selection Card
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
                hint: const Text('Select Grade Level'),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/images/stepper_kicd.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.school_outlined, color: AppTheme.primaryGreen, size: 20),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

              // Visible Grade Quick Selection Chips
              if (_grades.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _grades.map((g) {
                      final isSelected = _selectedGrade?.id == g.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(g.name),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGreenLight,
                          backgroundColor: const Color(0xFFF9FAFB),
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              _onGradeChanged(g);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              const Text('2. Learning Area / Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<Subject>(
                key: ValueKey('subject-select-${_selectedGrade?.id}-${_selectedSubject?.id}'),
                initialValue: _subjects.contains(_selectedSubject) ? _selectedSubject : null,
                isExpanded: true,
                hint: Text(
                  _selectedGrade == null
                      ? 'Select Grade Level first'
                      : (_isLoadingSubjects
                          ? 'Loading learning areas...'
                          : (_subjects.isEmpty
                              ? 'No learning areas available in database'
                              : 'Select Learning Area')),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: (_selectedGrade != null && !_isLoadingSubjects && _subjects.isEmpty)
                        ? Colors.red.shade600
                        : null,
                  ),
                ),
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
                onChanged: (_selectedGrade == null || _isLoadingSubjects || _subjects.isEmpty)
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _selectedSubject = val);
                          _loadStrandsForSubject(val);
                        }
                      },
              ),
              if (_selectedGrade != null && !_isLoadingSubjects && _subjects.isEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No subjects configured in Supabase for ${_selectedGrade!.name}.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
            ],
          ),
        ),

        // Prompt card when grade or subject is not selected yet
        if (!hasSelection) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/stepper_kicd.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.school_outlined, color: AppTheme.primaryGreen, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedGrade == null
                            ? 'Please Pick a Grade Level to Begin'
                            : 'Select a Learning Area',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedGrade == null
                            ? 'Choose a grade above to load official KICD learning areas and term calendar.'
                            : 'Select the subject for ${_selectedGrade!.name} to preview term dates and timetable settings.',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // 3. Live Term Date Calendar Preview (Displayed when Grade, Learning Area, and Term are selected)
        if (hasSelection) ...[
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Term Calendar (${curSettings.termName} 2026)',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${curSettings.weeks} Teaching Weeks',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.date_range, size: 15, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Term Dates: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                          Expanded(
                            child: Text(
                              '${curSettings.startDate} to ${curSettings.endDate}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.pause_circle_outline, size: 15, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          const Text('Half-Term Break: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                          Expanded(
                            child: Text(
                              curSettings.includeHalfTerm
                                  ? 'Week ${curSettings.halfTermWeek} (${curSettings.midTermStartDate.isNotEmpty ? '${curSettings.midTermStartDate} – ${curSettings.midTermEndDate}' : 'Included'})'
                                  : 'None (Disabled)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in_outlined, size: 15, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Assessment: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                          Expanded(
                            child: Text(
                              curSettings.assessmentWeeks.map((w) {
                                if (w == curSettings.weeks) return 'Week $w (End of Term)';
                                if (curSettings.includeHalfTerm && w == curSettings.halfTermWeek) return 'Week $w (Mid-Term)';
                                return 'Week $w';
                              }).join(', '),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 14, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You can adjust dates, break days, and assessment weeks in Step 2: Timetable.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Next Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_selectedGrade == null || _selectedSubject == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select Grade and Learning Area')),
                );
                return;
              }
              setState(() => _currentStep = 2);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next: Timetable & Calendar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
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

  // STEP 2: Timetable & Scope Customization
  Widget _buildStep2Timetable() {
    final curAssignments = _assignments[_activeTermNumber] ?? [];

    return ListView(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Lovable-style Term Calendar & Break Settings
        TermCalendarCustomizer(
          allTermSettings: _termSettings,
          currentTerm: _activeTermNumber,
          isBundleMode: false,
          onSelectTerm: (t) {
            setState(() => _selectedTerm = 'Term $t');
          },
          onTermSettingsChanged: (updated) {
            setState(() {
              _termSettings[_activeTermNumber] = updated;
            });
            _autoBalanceAssignments();
          },
        ),

        const SizedBox(height: 14),

        // Lovable-style Scope & Sequence (Terms 1, 2 & 3) Card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Scope & Sequence',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const Text(
                              '(Terms 1, 2 & 3)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGreenLight,
                                borderRadius: BorderRadius.all(Radius.circular(6)),
                              ),
                              child: const Text(
                                'Auto-balanced',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Review or reassign strands and sub-strands across Term 1, 2, and 3 to fit your teaching order.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Button to Toggle Scope & Sequence Customizer
              OutlinedButton.icon(
                onPressed: () {
                  if (_strands.isEmpty && _selectedSubject != null && !_isLoadingStrands) {
                    _loadStrandsForSubject(_selectedSubject);
                  }
                  setState(() => _showScopeAndSequence = !_showScopeAndSequence);
                },
                icon: Icon(
                  _showScopeAndSequence ? Icons.expand_less_rounded : Icons.tune_rounded,
                  size: 16,
                  color: AppTheme.primaryGreen,
                ),
                label: Text(
                  _showScopeAndSequence ? 'Hide Scope & Sequence' : 'Customize Scope & Sequence',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  side: const BorderSide(color: AppTheme.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: _showScopeAndSequence ? AppTheme.primaryGreenLight.withValues(alpha: 0.3) : Colors.white,
                ),
              ),

              if (!_showScopeAndSequence && _strands.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Currently allocated: ${curAssignments.length} sub-strands for Term $_activeTermNumber.',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],

              if (_showScopeAndSequence) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (_isLoadingStrands) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                    ),
                  ),
                ] else if (_strands.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No syllabus strands found for ${_selectedSubject?.name ?? "this learning area"} in database.',
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  ScopeAndSequenceCustomizer(
                    strands: _strands,
                    assignments: _assignments,
                    termSettings: _termSettings,
                    activeTermFilter: _activeTermScopeFilter,
                    isBundleMode: false,
                    onAssignmentsChanged: (newAssignments) {
                      setState(() => _assignments = newAssignments);
                    },
                    onSelectTermFilter: (term) {
                      setState(() => _activeTermScopeFilter = term);
                    },
                    onAutoBalance: _autoBalanceAssignments,
                  ),
                ],
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Navigation Buttons
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
                onPressed: () => setState(() => _currentStep = 3),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Next: Cover Details', style: TextStyle(fontWeight: FontWeight.w700)),
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

  // STEP 3: Cover Details (School & Teacher Profile) + Summary
  Widget _buildStep3CoverDetails() {
    final curSettings = _currentTermSettings;

    return ListView(
      key: const ValueKey(3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Teacher Profile Form
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
              const Text(
                'Cover Page Details',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'These details appear on the official exported DOCX/PDF scheme.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

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

        const SizedBox(height: 14),

        // Generation Summary Card
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
              const Row(
                children: [
                  Icon(Icons.summarize_outlined, color: AppTheme.primaryGreen, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Generation Summary',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSummaryRow('Subject', '${_selectedGrade?.name} – ${_selectedSubject?.name}'),
              _buildSummaryRow('Term & Year', '${curSettings.termName} ($_selectedYear)'),
              _buildSummaryRow('Teaching Duration', '${curSettings.weeks} Weeks (${curSettings.startDate} to ${curSettings.endDate})'),
              _buildSummaryRow('Lessons', '${curSettings.lessonsPerWeek} lessons/wk • Total ${curSettings.totalLessonSlots} lessons'),
              _buildSummaryRow('Half-Term Break', curSettings.includeHalfTerm ? 'Week ${curSettings.halfTermWeek} Break' : 'Disabled'),
              _buildSummaryRow('Assessment Weeks', curSettings.assessmentWeeks.map((w) => 'Wk $w').join(', ')),
              _buildSummaryRow('Pacing Mode', 'Progressive (CBC Step-by-Step)'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Navigation Buttons
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          ),
        ],
      ),
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
            const Text(
              'Generating KICD Scheme of Work',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
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
