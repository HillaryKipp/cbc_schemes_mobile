import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/reference_book.dart';
import '../../../services/curriculum_service.dart';
import '../../../services/guest_storage_service.dart';
import '../../../services/scheme_generator.dart';
import '../../../state/scheme_editor_provider.dart';
import '../../../state/scheme_list_provider.dart';
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

  Grade? _selectedGrade;
  Subject? _selectedSubject;
  ReferenceBook? _selectedBook;
  String _selectedTerm = 'Term 3';
  int _selectedYear = 2026;
  int _weeks = 9;
  int _lessonsPerWeek = 5;

  bool _isLoadingSubjects = false;
  bool _isLoadingBooks = false;

  // Teaching Days
  final Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  // School & Teacher Profile Controllers
  final _schoolController = TextEditingController();
  final _tscController = TextEditingController();
  final _hodController = TextEditingController();
  final _teacherController = TextEditingController();

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

    // Load cached profile
    final cached = _guestStorage.getTeacherProfile();
    _schoolController.text = cached['school_name'] ?? '';
    _tscController.text = cached['tsc_number'] ?? '';
    _hodController.text = cached['hod_name'] ?? '';
    _teacherController.text = cached['teacher_name'] ?? '';

    _grades = await _curriculum.getGrades();
    if (_grades.isNotEmpty) {
      _selectedGrade = _grades.firstWhere(
        (g) => g.id == 'grade-6' || g.name.toLowerCase() == 'grade 6',
        orElse: () => _grades.first,
      );
      await _onGradeChanged(_selectedGrade!);
    }

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
        schoolName: _schoolController.text.trim(),
        teacherName: _teacherController.text.trim(),
        tscNumber: _tscController.text.trim(),
        hodName: _hodController.text.trim(),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
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
                    'Step-by-Step Scheme Generator',
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
            // Original Circle Milestone Stepper Navigation Header
            _buildStepperHeader(),
            const Divider(height: 1),

            // Step Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildCurrentStepWidget(),
              ),
            ),
          ],
        ),
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

  // STEP 1: Grade, Subject & Term Selection
  Widget _buildStep1Curriculum() {
    return ListView(
      key: const ValueKey(1),
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

              const Text('4. Year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
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
                  hint: Text(_isLoadingBooks ? 'Loading books...' : 'Select Approved Book'),
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
                  items: _referenceBooks.map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(
                      b.publisher.isEmpty ? b.title : '${b.title} (${b.publisher})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  )).toList(),
                  onChanged: _isLoadingBooks ? null : (val) => setState(() => _selectedBook = val),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick Preset Buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetButton('Grade 6 Math', 'grade-6', 'math', 'Term 3'),
              const SizedBox(width: 8),
              _buildPresetButton('Grade 7 Science', 'grade-7', 'sci', 'Term 3'),
              const SizedBox(width: 8),
              _buildPresetButton('Grade 5 English', 'grade-5', 'eng', 'Term 3'),
              const SizedBox(width: 8),
              _buildPresetButton('Grade 8 Agri', 'grade-8', 'agri', 'Term 3'),
            ],
          ),
        ),

        const SizedBox(height: 18),

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
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  _saveTeacherProfile();
                  setState(() => _currentStep = 3);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next: Timetable', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3: Calendar & Timetable Settings
  Widget _buildStep3Calendar() {
    return ListView(
      key: const ValueKey(3),
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
              // Scheme Overview Badge
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedGrade?.name} • ${_selectedSubject?.name}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$_selectedTerm $_selectedYear  •  Total ${_weeks * _lessonsPerWeek} Lessons across $_weeks Weeks',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
              ),
              const Divider(height: 20),

              // Lessons per week
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lessons per Week', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppTheme.primaryGreen),
                        onPressed: () {
                          if (_lessonsPerWeek > 1) setState(() => _lessonsPerWeek--);
                        },
                      ),
                      Text(
                        '$_lessonsPerWeek',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.primaryGreen),
                        onPressed: () {
                          if (_lessonsPerWeek < 10) setState(() => _lessonsPerWeek++);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Weeks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Number of Weeks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppTheme.primaryGreen),
                        onPressed: () {
                          if (_weeks > 1) setState(() => _weeks--);
                        },
                      ),
                      Text(
                        '$_weeks',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.primaryGreen),
                        onPressed: () {
                          if (_weeks < 16) setState(() => _weeks++);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Teaching Days
              const Text('Teaching Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              Row(
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              if (_selectedDays.length > 1) _selectedDays.remove(day);
                            } else {
                              _selectedDays.add(day);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryGreenLight : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _startGeneration,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  'Generate (${_weeks * _lessonsPerWeek} Lessons)',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
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

  // STEP 4: Live Generation Animation
  Widget _buildStep4Generating() {
    return Center(
      key: const ValueKey(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreenLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3.5, color: AppTheme.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Generating CBC Scheme',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedGrade?.name} • ${_selectedSubject?.name}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: List.generate(_progressTasks.length, (index) {
                  final task = _progressTasks[index];
                  final isDone = index < _completedTaskCount;
                  final isCurrent = index == _completedTaskCount;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (isDone)
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryGreen)
                        else if (isCurrent)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                          )
                        else
                          const Icon(Icons.radio_button_unchecked, size: 16, color: Color(0xFFD1D5DB)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            task,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
                              color: isDone
                                  ? AppTheme.textDark
                                  : isCurrent
                                      ? AppTheme.primaryGreen
                                      : AppTheme.textMuted,
                            ),
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
