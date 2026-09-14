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
import '../../widgets/step_progress_bar.dart';
import '../editor/scheme_editor_screen.dart';

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
    this.initialTerm = 'Term 3',
    this.initialYear = 2026,
    this.initialWeeks = 9,
    this.initialLessonsPerWeek = 5,
  });

  @override
  State<GenerateWizardScreen> createState() => _GenerateWizardScreenState();
}

class _GenerateWizardScreenState extends State<GenerateWizardScreen> {
  final _curriculum = CurriculumService.instance;
  final _guestStorage = GuestStorageService.instance;

  int _currentStep = 1; // 1: School Details, 2: Calendar, 3: Generating
  bool _isLoading = true;

  // Grade & Subject
  late Grade _grade;
  late Subject _subject;
  ReferenceBook? _selectedBook;
  late String _termName;
  late int _year;
  late int _weeks;
  late int _lessonsPerWeek;

  // Teaching Days
  final Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  // School Details Controllers
  final _schoolController = TextEditingController();
  final _tscController = TextEditingController();
  final _hodController = TextEditingController();
  final _teacherController = TextEditingController();

  // Generation Steps Progress Checklist
  final List<String> _progressTasks = [
    'Loading KICD curriculum content',
    'Selecting strands & sub-strands',
    'Adding learning outcomes',
    'Adding learning experiences',
    'Adding inquiry questions',
    'Adding learning resources',
    'Adding assessment methods',
    'Organizing weekly lessons',
  ];
  int _completedTaskCount = 0;

  @override
  void initState() {
    super.initState();
    _termName = widget.initialTerm;
    _year = widget.initialYear;
    _weeks = widget.initialWeeks;
    _lessonsPerWeek = widget.initialLessonsPerWeek;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final cached = _guestStorage.getTeacherProfile();
    _schoolController.text = cached['school_name'] ?? '';
    _tscController.text = cached['tsc_number'] ?? '';
    _hodController.text = cached['hod_name'] ?? '';
    _teacherController.text = cached['teacher_name'] ?? '';

    final grades = await _curriculum.getGrades();
    _grade = widget.initialGrade ?? grades.firstWhere(
      (g) => g.id == 'grade-6' || g.name.toLowerCase() == 'grade 6',
      orElse: () => grades.first,
    );

    final subjects = await _curriculum.getSubjects(_grade.id, grade: _grade);
    _subject = widget.initialSubject ?? subjects.firstWhere((s) => s.name.toLowerCase().contains('math'), orElse: () => subjects.first);

    final books = await _curriculum.getReferenceBooks(_subject.id);
    _selectedBook = books.isNotEmpty ? books.first : null;

    setState(() => _isLoading = false);
  }

  void _startGeneration() async {
    setState(() {
      _currentStep = 3;
      _completedTaskCount = 0;
    });

    final timer = Timer.periodic(const Duration(milliseconds: 320), (t) {
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
      final scheme = await SchemeGenerator.generateScheme(
        grade: _grade,
        subject: _subject,
        referenceBook: _selectedBook,
        termName: _termName,
        year: _year,
        weeks: _weeks,
        lessonsPerWeek: _lessonsPerWeek,
        schoolName: _schoolController.text.trim(),
        teacherName: _teacherController.text.trim(),
        tscNumber: _tscController.text.trim(),
        hodName: _hodController.text.trim(),
      );

      await Future.delayed(const Duration(milliseconds: 2600));
      timer.cancel();

      if (!mounted) return;

      context.read<SchemeEditorProvider>().setScheme(scheme);
      context.read<SchemeListProvider>().loadSchemes();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => SchemeEditorScreen(scheme: scheme),
        ),
      );
    } catch (e) {
      timer.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating scheme: $e')),
      );
      setState(() => _currentStep = 2);
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
        if (!didPop && _currentStep > 1 && _currentStep < 3) {
          setState(() => _currentStep--);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () {
              if (_currentStep > 1 && _currentStep < 3) {
                setState(() => _currentStep--);
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: Text('${_grade.name} ${_subject.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            StepProgressBar(currentStep: _currentStep),
            const Divider(height: 1),
            Expanded(
              child: _currentStep == 1
                  ? _buildStep1SchoolDetails()
                  : _currentStep == 2
                      ? _buildStep2TermCalendar()
                      : _buildStep3Generating(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1SchoolDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: School & Teacher Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Saved automatically to pre-fill future schemes.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

          const Text('School Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _schoolController,
            decoration: const InputDecoration(
              hintText: 'Enter school name',
              prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Teacher Name (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _teacherController,
            decoration: const InputDecoration(
              hintText: 'Enter teacher name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TSC Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tscController,
                      decoration: const InputDecoration(
                        hintText: 'TSC / ID',
                        prefixIcon: Icon(Icons.badge_outlined, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HOD Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _hodController,
                      decoration: const InputDecoration(
                        hintText: 'HOD Name',
                        prefixIcon: Icon(Icons.supervisor_account_outlined, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                _guestStorage.saveTeacherProfile(
                  schoolName: _schoolController.text.trim(),
                  teacherName: _teacherController.text.trim(),
                  tscNumber: _tscController.text.trim(),
                  hodName: _hodController.text.trim(),
                );
                setState(() => _currentStep = 2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue to Calendar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2TermCalendar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2: Term Calendar & Lessons',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review lessons per week and duration',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

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
                      '$_termName – $_year',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total ${_weeks * _lessonsPerWeek} Lessons across $_weeks Weeks',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Lessons per week',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: AppTheme.textDark),
                  onPressed: () {
                    if (_lessonsPerWeek > 1) {
                      setState(() => _lessonsPerWeek--);
                    }
                  },
                ),
                Text(
                  '$_lessonsPerWeek',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppTheme.textDark),
                  onPressed: () {
                    if (_lessonsPerWeek < 10) {
                      setState(() => _lessonsPerWeek++);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Teaching Days',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textDark),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
              final isSelected = _selectedDays.contains(day);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGreenLight : const Color(0xFFF3F4F6),
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
                          fontSize: 12.5,
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

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startGeneration,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate Scheme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Generating() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Step 3: Generating Scheme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Please wait while we build your KICD-compliant scheme',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 28),

          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreenLight,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.article_rounded,
              color: AppTheme.primaryGreen,
              size: 40,
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Generating your scheme...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: List.generate(_progressTasks.length, (index) {
                final task = _progressTasks[index];
                final isDone = index < _completedTaskCount;
                final isCurrent = index == _completedTaskCount;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      if (isDone)
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primaryGreen)
                      else if (isCurrent)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                        )
                      else
                        const Icon(Icons.radio_button_unchecked, size: 18, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task,
                          style: TextStyle(
                            fontSize: 13,
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
    );
  }
}
