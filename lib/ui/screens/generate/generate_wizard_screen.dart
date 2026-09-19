import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/strand.dart';
import '../../../models/reference_book.dart';
import '../../../models/scheme.dart';
import '../../../models/term_settings.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/guest_storage_service.dart';
import '../../../services/scheme_generator.dart';
import '../../../state/scheme_editor_provider.dart';
import '../../../state/scheme_list_provider.dart';
import '../preview/scheme_preview_screen.dart';
import '../../widgets/whatsapp_support_button.dart';
import 'widgets/scope_and_sequence_customizer.dart';
import 'widgets/term_calendar_customizer.dart';

class GenerateWizardScreen extends StatefulWidget {
  final Grade? initialGrade;
  final Subject? initialSubject;
  final String initialTerm;
  final int initialYear;
  final int initialWeeks;
  final int initialLessonsPerWeek;

  const GenerateWizardScreen({
    super.key,
    this.initialGrade,
    this.initialSubject,
    this.initialTerm = 'Term 1',
    this.initialYear = 2026,
    this.initialWeeks = 13,
    this.initialLessonsPerWeek = 5,
  });

  @override
  State<GenerateWizardScreen> createState() => _GenerateWizardScreenState();
}

class _GenerateWizardScreenState extends State<GenerateWizardScreen> {
  final _curriculum = CurriculumService.instance;
  final _guestStorage = GuestStorageService.instance;

  int _currentStep = 1; // 1: Scope, 2: Scope & Sequence, 3: Calendar & Breaks, 4: Cover & Summary, 5: Generating
  bool _isLoading = true;

  // Grade & Subject
  List<Grade> _grades = [];
  List<Subject> _subjects = [];
  List<ReferenceBook> _referenceBooks = [];
  List<Strand> _strands = [];

  Grade? _selectedGrade;
  Subject? _selectedSubject;
  ReferenceBook? _selectedBook;
  bool _isFullYearBundle = false;
  int _targetTermNumber = 1;
  final int _year = 2026;
  String _pacingMode = 'progressive'; // 'progressive' or 'comprehensive'

  // Term Settings & Assignments
  late Map<int, TermSettings> _termSettings;
  Map<int, List<TermSubStrandAssignment>> _assignments = {1: [], 2: [], 3: []};
  int _activeTermFilter = 0; // 0 = all, 1 = T1, 2 = T2, 3 = T3
  int _calendarTermTab = 1;

  // School Details Controllers
  final _schoolController = TextEditingController();
  final _tscController = TextEditingController();
  final _hodController = TextEditingController();
  final _teacherController = TextEditingController();

  final List<String> _progressTasks = [
    'Loading KICD curriculum designs',
    'Selecting strands & sub-strands',
    'Applying pacing & progression mode',
    'Distributing specific learning outcomes',
    'Formatting inquiry questions & experiences',
    'Attaching CBC approved course books',
    'Finalizing 10-column scheme table',
  ];
  int _completedTaskCount = 0;

  @override
  void initState() {
    super.initState();
    _targetTermNumber = widget.initialTerm.contains('3')
        ? 3
        : (widget.initialTerm.contains('2') ? 2 : 1);
    _calendarTermTab = _targetTermNumber;

    _termSettings = TermSettings.getOfficial2026Defaults(
      defaultLessonsPerWeek: widget.initialLessonsPerWeek,
    );

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
      _selectedGrade = widget.initialGrade ??
          _grades.firstWhere(
            (g) => g.id == 'grade-4' || g.name.toLowerCase().contains('grade 4'),
            orElse: () => _grades.first,
          );

      _subjects = await _curriculum.getSubjects(_selectedGrade!.id, grade: _selectedGrade);
      _selectedSubject = widget.initialSubject ?? (_subjects.isNotEmpty ? _subjects.first : null);

      if (_selectedSubject != null) {
        _referenceBooks = await _curriculum.getReferenceBooks(_selectedSubject!.id);
        _selectedBook = _referenceBooks.isNotEmpty ? _referenceBooks.first : null;
        _strands = await _curriculum.getStrandsWithSubStrands(_selectedSubject!.id);
        _autoBalanceAssignments();
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _autoBalanceAssignments() {
    if (_strands.isEmpty) return;
    final strandsMap = _strands.map((s) => s.toJson()).toList();
    final subStrandsMap = <Map<String, dynamic>>[];
    for (final s in _strands) {
      for (final ss in s.subStrands) {
        subStrandsMap.add(ss.toJson());
      }
    }

    final capacities = [
      TermCapacity(termNumber: 1, totalLessons: _termSettings[1]!.totalLessonSlots),
      TermCapacity(termNumber: 2, totalLessons: _termSettings[2]!.totalLessonSlots),
      TermCapacity(termNumber: 3, totalLessons: _termSettings[3]!.totalLessonSlots),
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
      _subjects = [];
      _selectedSubject = null;
      _referenceBooks = [];
      _selectedBook = null;
      _strands = [];
      _assignments = {1: [], 2: [], 3: []};
    });

    final subs = await _curriculum.getSubjects(grade.id, grade: grade);
    if (!mounted) return;

    setState(() {
      _subjects = subs;
      _selectedSubject = subs.isNotEmpty ? subs.first : null;
    });

    if (_selectedSubject != null) {
      await _onSubjectChanged(_selectedSubject!);
    }
  }

  Future<void> _onSubjectChanged(Subject subject) async {
    setState(() {
      _selectedSubject = subject;
      _referenceBooks = [];
      _selectedBook = null;
      _strands = [];
      _assignments = {1: [], 2: [], 3: []};
    });

    final books = await _curriculum.getReferenceBooks(subject.id);
    final strands = await _curriculum.getStrandsWithSubStrands(subject.id);
    if (!mounted) return;

    setState(() {
      _referenceBooks = books;
      _selectedBook = books.isNotEmpty ? books.first : null;
      _strands = strands;
    });

    _autoBalanceAssignments();
  }

  void _startGeneration() async {
    if (_selectedGrade == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grade and subject')),
      );
      return;
    }

    _guestStorage.saveTeacherProfile(
      schoolName: _schoolController.text.trim(),
      teacherName: _teacherController.text.trim(),
      tscNumber: _tscController.text.trim(),
      hodName: _hodController.text.trim(),
    );

    setState(() {
      _currentStep = 5;
      _completedTaskCount = 0;
    });

    final timer = Timer.periodic(const Duration(milliseconds: 280), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_completedTaskCount < _progressTasks.length) {
        setState(() => _completedTaskCount++);
      } else {
        t.cancel();
      }
    });

    try {
      Scheme targetScheme;
      if (_isFullYearBundle) {
        final bundle = await SchemeGenerator.generateMultiTermBundle(
          grade: _selectedGrade!,
          subject: _selectedSubject!,
          referenceBook: _selectedBook,
          year: _year,
          lessonsPerWeek: _termSettings[1]!.lessonsPerWeek,
          pacingMode: _pacingMode,
          customAssignments: _assignments,
          customTermSettings: _termSettings,
          schoolName: _schoolController.text.trim(),
          teacherName: _teacherController.text.trim(),
          tscNumber: _tscController.text.trim(),
          hodName: _hodController.text.trim(),
        );
        targetScheme = bundle.first;
      } else {
        final curSettings = _termSettings[_targetTermNumber]!;
        targetScheme = await SchemeGenerator.generateScheme(
          grade: _selectedGrade!,
          subject: _selectedSubject!,
          referenceBook: _selectedBook,
          termName: curSettings.termName,
          year: _year,
          weeks: curSettings.weeks,
          lessonsPerWeek: curSettings.lessonsPerWeek,
          pacingMode: _pacingMode,
          halfTermWeek: curSettings.includeHalfTerm ? curSettings.halfTermWeek : null,
          assessmentWeeks: curSettings.assessmentWeeks,
          assignedSubStrands: _assignments[_targetTermNumber] ?? [],
          schoolName: _schoolController.text.trim(),
          teacherName: _teacherController.text.trim(),
          tscNumber: _tscController.text.trim(),
          hodName: _hodController.text.trim(),
        );
      }

      await Future.delayed(const Duration(milliseconds: 1200));
      timer.cancel();

      if (!mounted) return;

      context.read<SchemeEditorProvider>().setScheme(targetScheme);
      context.read<SchemeListProvider>().loadSchemes();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => SchemePreviewScreen(scheme: targetScheme),
        ),
      );
    } catch (e) {
      timer.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating scheme: $e')),
      );
      setState(() => _currentStep = 4);
    }
  }

  @override
  void dispose() {
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

    final stepLabels = [
      'Scope',
      'Scope & Sequence',
      'Calendar & Breaks',
      'Cover & Summary',
    ];

    return PopScope(
      canPop: _currentStep == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 1 && _currentStep < 5) {
          setState(() => _currentStep--);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        floatingActionButton: const WhatsAppSupportButton(mini: true),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () {
              if (_currentStep > 1 && _currentStep < 5) {
                setState(() => _currentStep--);
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: Text(
            _currentStep <= 4
                ? 'Generate Scheme: ${stepLabels[_currentStep - 1]} ($_currentStep/4)'
                : 'Generating Scheme...',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            if (_currentStep <= 4) ...[
              _buildProgressBar(),
              const Divider(height: 1),
            ],
            Expanded(
              child: _currentStep == 1
                  ? _buildStep1Curriculum()
                  : _currentStep == 2
                      ? _buildStep2ScopeAndSequence()
                      : _currentStep == 3
                          ? _buildStep3CalendarAndBreaks()
                          : _currentStep == 4
                              ? _buildStep4CoverAndSummary()
                              : _buildStep5Generating(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final stepTitles = ['Scope', 'Scope & Seq', 'Calendar', 'Cover'];
    final stepIcons = [
      Icons.school_rounded,
      Icons.account_tree_rounded,
      Icons.calendar_month_rounded,
      Icons.badge_rounded,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
          Row(
            children: [
              for (int i = 1; i <= 4; i++) ...[
                _buildWizardIndicatorCircle(i, stepIcons[i - 1]),
                if (i < 4) _buildWizardConnectingLine(i),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 1; i <= 4; i++) ...[
                if (i > 1) const SizedBox(width: 8),
                _buildWizardTextLabel(i, 'STEP $i', stepTitles[i - 1]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWizardIndicatorCircle(int step, IconData icon) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return InkWell(
      onTap: () {
        if (_currentStep != 5) {
          setState(() => _currentStep = step);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone
              ? const Color(0xFF22C55E)
              : (isCurrent ? AppTheme.primaryGreen : const Color(0xFFF3F4F6)),
          border: isCurrent
              ? Border.all(color: AppTheme.primaryGreenLight, width: 3)
              : (isDone
                  ? null
                  : Border.all(color: const Color(0xFFE5E7EB), width: 1.5)),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isDone
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : Icon(
                  icon,
                  size: 16,
                  color: isCurrent ? Colors.white : const Color(0xFF9CA3AF),
                ),
        ),
      ),
    );
  }

  Widget _buildWizardConnectingLine(int step) {
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

  Widget _buildWizardTextLabel(int step, String stepNum, String title) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_currentStep != 5) {
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

  // STEP 1: Class, subject and scope
  Widget _buildStep1Curriculum() {
    final hasNoSubjects = _subjects.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Class, subject and scope',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick grade, learning area, planning scope, and approved reference book',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),

          // Grade Selection
          const Text('Grade Level', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Grade>(
            key: ValueKey('grade-${_selectedGrade?.id}'),
            initialValue: _grades.contains(_selectedGrade) ? _selectedGrade : null,
            isExpanded: true,
            hint: const Text('Select Grade'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.school_outlined, color: AppTheme.primaryGreen),
            ),
            items: _grades.map((g) => DropdownMenuItem(
              value: g,
              child: Text('${g.name} (${g.displayLevel})'),
            )).toList(),
            onChanged: (val) {
              if (val != null) _onGradeChanged(val);
            },
          ),
          const SizedBox(height: 16),

          // Digitization Warning Banner
          if (hasNoSubjects) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedGrade?.name ?? "This Grade"} Schemes Are Currently Being Digitized for the 2026 KICD curriculum',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      WhatsAppSupportButton.openWhatsApp(
                        context,
                        'Hello, I would like to request schemes of work for ${_selectedGrade?.name ?? "this grade"}.',
                      );
                    },
                    icon: const Icon(Icons.chat, size: 16),
                    label: Text('Request ${_selectedGrade?.name ?? "Grade"} Schemes on WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Subject Selection
          if (!hasNoSubjects) ...[
            const Text('Learning Area / Subject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            DropdownButtonFormField<Subject>(
              key: ValueKey('subj-${_selectedGrade?.id}-${_selectedSubject?.id}'),
              initialValue: _subjects.contains(_selectedSubject) ? _selectedSubject : null,
              isExpanded: true,
              hint: const Text('Select Learning Area'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.menu_book_outlined, color: AppTheme.primaryGreen),
              ),
              items: _subjects.map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.name),
              )).toList(),
              onChanged: (val) {
                if (val != null) _onSubjectChanged(val);
              },
            ),
            const SizedBox(height: 16),
          ],

          // Scope Selector (Single Term vs Full Academic Year Bundle)
          const Text('Planning Scope', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isFullYearBundle = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_isFullYearBundle ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isFullYearBundle
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Single Term Scheme',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: !_isFullYearBundle ? FontWeight.w800 : FontWeight.w500,
                          color: !_isFullYearBundle ? AppTheme.primaryGreen : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isFullYearBundle = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _isFullYearBundle ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isFullYearBundle
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Full Year Bundle (Terms 1, 2 & 3)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _isFullYearBundle ? FontWeight.w800 : FontWeight.w500,
                          color: _isFullYearBundle ? AppTheme.primaryGreen : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Academic Term Selection (if Single Term)
          if (!_isFullYearBundle) ...[
            const Text('Target Term', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTargetTermChip(1, 'Term 1', '13 Weeks'),
                const SizedBox(width: 8),
                _buildTargetTermChip(2, 'Term 2', '14 Weeks'),
                const SizedBox(width: 8),
                _buildTargetTermChip(3, 'Term 3', '9 Weeks'),
              ],
            ),
            const SizedBox(height: 16),
          ],


          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: hasNoSubjects || _selectedGrade == null || _selectedSubject == null
                  ? null
                  : () => setState(() => _currentStep = 2),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                hasNoSubjects
                    ? '${_selectedGrade?.name ?? "Grade"} Not Available Yet'
                    : 'Next: Scope & Sequence Customization',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTermChip(int termNum, String term, String duration) {
    final isSelected = _targetTermNumber == termNum;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _targetTermNumber = termNum;
            _calendarTermTab = termNum;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreenLight : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
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
                duration,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 2: Scope & Sequence (Terms 1, 2 & 3)
  Widget _buildStep2ScopeAndSequence() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Scope & Sequence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Review or reassign strands and sub-strands across Term 1, 2, and 3 to fit your teaching order.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Auto-balanced',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Scope and sequence customizer widget
          ScopeAndSequenceCustomizer(
            strands: _strands,
            assignments: _assignments,
            termSettings: _termSettings,
            activeTermFilter: _activeTermFilter,
            isBundleMode: _isFullYearBundle,
            onAssignmentsChanged: (newAssignments) {
              setState(() => _assignments = newAssignments);
            },
            onSelectTermFilter: (term) {
              setState(() => _activeTermFilter = term);
            },
            onAutoBalance: _autoBalanceAssignments,
          ),

          const SizedBox(height: 28),

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
                  label: const Text('Next: Term Calendar & Breaks', style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );
  }

  // STEP 3: Term Calendar & Break Settings
  Widget _buildStep3CalendarAndBreaks() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Customizer Widget
          TermCalendarCustomizer(
            allTermSettings: _termSettings,
            currentTerm: _isFullYearBundle ? _calendarTermTab : _targetTermNumber,
            isBundleMode: _isFullYearBundle,
            onSelectTerm: (term) {
              setState(() => _calendarTermTab = term);
            },
            onTermSettingsChanged: (updated) {
              setState(() {
                _termSettings[updated.termNumber] = updated;
              });
            },
          ),
          const SizedBox(height: 16),

          // Pacing Mode (Progressive vs Comprehensive)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pacing & Progression Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _pacingMode = 'progressive'),
                  child: Row(
                    children: [
                      Icon(
                        _pacingMode == 'progressive' ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _pacingMode == 'progressive' ? AppTheme.primaryGreen : AppTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Progressive (Recommended)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(
                              'Distributes outcomes step-by-step per lesson slot without repeating every outcome.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                InkWell(
                  onTap: () => setState(() => _pacingMode = 'comprehensive'),
                  child: Row(
                    children: [
                      Icon(
                        _pacingMode == 'comprehensive' ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _pacingMode == 'comprehensive' ? AppTheme.primaryGreen : AppTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Comprehensive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(
                              'Assigns all sub-strand outcomes and experiences to every lesson slot.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

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
                  onPressed: () => setState(() => _currentStep = 4),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next: Cover Details & Summary', style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );
  }

  // STEP 4: Cover page details & Generation Summary
  Widget _buildStep4CoverAndSummary() {
    final activeTerm = _isFullYearBundle ? 1 : _targetTermNumber;
    final curSettings = _termSettings[activeTerm]!;

    final plannedSubStrands = _isFullYearBundle
        ? (_assignments[1]?.length ?? 0) + (_assignments[2]?.length ?? 0) + (_assignments[3]?.length ?? 0)
        : (_assignments[_targetTermNumber]?.length ?? 0);

    final allocatedLessons = _isFullYearBundle
        ? (_assignments[1]?.fold<int>(0, (s, a) => s + a.allocatedLessons) ?? 0) +
          (_assignments[2]?.fold<int>(0, (s, a) => s + a.allocatedLessons) ?? 0) +
          (_assignments[3]?.fold<int>(0, (s, a) => s + a.allocatedLessons) ?? 0)
        : (_assignments[_targetTermNumber]?.fold<int>(0, (s, a) => s + a.allocatedLessons) ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4. Cover page details & Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Details appear on your Word (.docx) & PDF document cover pages.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

          // Cover Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('School Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _schoolController,
                  decoration: const InputDecoration(hintText: 'e.g. Nairobi Primary School'),
                ),
                const SizedBox(height: 14),

                const Text('Teacher Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _teacherController,
                  decoration: const InputDecoration(hintText: 'e.g. Tr. Jane Doe'),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TSC Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _tscController,
                            decoration: const InputDecoration(hintText: 'TSC No.'),
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
                            decoration: const InputDecoration(hintText: 'H.O.D'),
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

          // Generation Summary Card matching web aside
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GENERATION SUMMARY',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8),
                    ),
                    Text(
                      '${_selectedGrade?.name} • ${_selectedSubject?.name}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Mode', _isFullYearBundle ? 'Full Academic Year Bundle (Terms 1, 2 & 3)' : '${curSettings.termName} ($_year)'),
                _buildSummaryRow('Teaching weeks', _isFullYearBundle ? '36 weeks (13 + 14 + 9)' : '${curSettings.weeks} weeks'),
                _buildSummaryRow('Lessons per week', '${curSettings.lessonsPerWeek}'),
                _buildSummaryRow('Total lesson slots', _isFullYearBundle ? '${36 * curSettings.lessonsPerWeek}' : '${curSettings.totalLessonSlots}'),
                const Divider(height: 16),
                _buildSummaryRow('Half term break', curSettings.includeHalfTerm ? 'Week ${curSettings.halfTermWeek}' : 'None'),
                _buildSummaryRow('Assessment', 'Wk ${curSettings.assessmentWeeks.join(', ')}'),
                const Divider(height: 16),
                _buildSummaryRow('Planned sub-strands', '$plannedSubStrands'),
                _buildSummaryRow('Allocated lessons', '$allocatedLessons lessons', isHighlight: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Generation CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _startGeneration,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text(
                _isFullYearBundle ? 'Generate 3-Term Scheme Bundle' : 'Generate ${curSettings.termName} Scheme',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Fully editable table with docx & PDF export after generating.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isHighlight ? AppTheme.primaryGreen : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 5: Generating Screen Animation
  Widget _buildStep5Generating() {
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
              '${_selectedGrade?.name} ${_selectedSubject?.name} • ${_isFullYearBundle ? "Full Year Bundle" : "Term $_targetTermNumber"} $_year',
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
