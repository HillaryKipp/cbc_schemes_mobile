import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../models/app_settings.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/strand.dart';
import '../../../services/curriculum_service.dart';
import '../../../state/auth_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _curriculum = CurriculumService.instance;

  bool _isLoading = true;
  AppSettings _appSettings = AppSettings();

  // Curriculum Data
  List<Grade> _grades = [];
  Grade? _selectedGrade;
  List<Subject> _subjects = [];
  Subject? _selectedSubject;
  List<Strand> _strands = [];

  // Controllers for Settings
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    _appSettings = await _curriculum.getAppSettings();
    _priceController.text = _appSettings.pricePerScheme.toStringAsFixed(0);
    _phoneController.text = _appSettings.supportPhone ?? '';

    _grades = await _curriculum.getGrades();
    if (_grades.isNotEmpty) {
      _selectedGrade = _grades.first;
      await _loadSubjectsForGrade(_selectedGrade!);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadSubjectsForGrade(Grade grade) async {
    _selectedGrade = grade;
    _subjects = await _curriculum.getSubjects(grade.id, grade: grade);
    if (_subjects.isNotEmpty) {
      _selectedSubject = _subjects.first;
      await _loadStrandsForSubject(_selectedSubject!);
    } else {
      _selectedSubject = null;
      _strands = [];
    }
  }

  Future<void> _loadStrandsForSubject(Subject subject) async {
    _selectedSubject = subject;
    _strands = await _curriculum.getStrandsWithSubStrands(subject.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // CRUD DIALOGS & ACTIONS
  // -------------------------------------------------------------

  void _showAddOrEditGradeDialog({Grade? existing}) {
    final idCtrl = TextEditingController(text: existing?.id ?? 'grade-${_grades.length + 1}');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final levelCtrl = TextEditingController(text: existing?.level ?? 'Primary School');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add New Grade' : 'Edit Grade'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Grade Name (e.g. Grade 9)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: levelCtrl,
                decoration: const InputDecoration(labelText: 'Level / Category (e.g. Junior School)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newGrade = Grade(
                id: idCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                level: levelCtrl.text.trim(),
                orderIndex: existing?.orderIndex ?? (_grades.length + 1),
              );
              Navigator.pop(ctx);
              try {
                await _curriculum.saveGrade(newGrade);
                await _loadAdminData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Grade "${newGrade.name}" saved successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving grade: $e')),
                  );
                }
              }
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGrade(Grade grade) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Grade?'),
        content: Text('Are you sure you want to delete ${grade.name}? This will remove associated subjects and strands.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _curriculum.deleteGrade(grade.id);
                await _loadAdminData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Grade "${grade.name}" deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting grade: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditSubjectDialog({Subject? existing}) {
    if (_selectedGrade == null) return;
    final idCtrl = TextEditingController(text: existing?.id ?? 'subj-${_selectedGrade!.id}-${DateTime.now().millisecondsSinceEpoch % 1000}');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Subject to ${_selectedGrade!.name}' : 'Edit Subject'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Subject Name (e.g. Creative Arts)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Subject Code (e.g. ARTS)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newSubject = Subject(
                id: idCtrl.text.trim(),
                gradeId: _selectedGrade!.id,
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim(),
                orderIndex: existing?.orderIndex ?? (_subjects.length + 1),
              );
              Navigator.pop(ctx);
              try {
                await _curriculum.saveSubject(newSubject);
                await _loadSubjectsForGrade(_selectedGrade!);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Subject "${newSubject.name}" saved successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving subject: $e')),
                  );
                }
              }
            },
            child: const Text('Save Subject'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubject(Subject subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Are you sure you want to delete ${subject.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _curriculum.deleteSubject(subject.id);
                await _loadSubjectsForGrade(_selectedGrade!);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Subject "${subject.name}" deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting subject: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditStrandDialog({Strand? existing}) {
    if (_selectedSubject == null) return;
    final idCtrl = TextEditingController(text: existing?.id ?? 'strand-${DateTime.now().millisecondsSinceEpoch}');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Strand to ${_selectedSubject!.name}' : 'Edit Strand'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Strand Name (e.g. Numbers, Algebra)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStrand = Strand(
                id: idCtrl.text.trim(),
                subjectId: _selectedSubject!.id,
                name: nameCtrl.text.trim(),
                orderIndex: existing?.orderIndex ?? (_strands.length + 1),
                subStrands: existing?.subStrands ?? [],
              );
              Navigator.pop(ctx);
              try {
                await _curriculum.saveStrand(newStrand);
                await _loadStrandsForSubject(_selectedSubject!);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Strand "${newStrand.name}" saved successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving strand: $e')),
                  );
                }
              }
            },
            child: const Text('Save Strand'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStrand(Strand strand) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Strand?'),
        content: Text('Are you sure you want to delete "${strand.name}" and all its sub-strands?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _curriculum.deleteStrand(strand.id);
                await _loadStrandsForSubject(_selectedSubject!);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Strand "${strand.name}" deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting strand: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditSubStrandDialog(Strand strand, {SubStrand? existing}) {
    final idCtrl = TextEditingController(text: existing?.id ?? 'substrand-${DateTime.now().millisecondsSinceEpoch}');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Sub-Strand to ${strand.name}' : 'Edit Sub-Strand'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Sub-Strand Name (e.g. Rational Numbers)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newSubStrand = SubStrand(
                id: idCtrl.text.trim(),
                strandId: strand.id,
                name: nameCtrl.text.trim(),
                orderIndex: existing?.orderIndex ?? (strand.subStrands.length + 1),
              );
              Navigator.pop(ctx);
              try {
                await _curriculum.saveSubStrand(newSubStrand);
                await _loadStrandsForSubject(_selectedSubject!);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sub-Strand "${newSubStrand.name}" saved!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving sub-strand: $e')),
                  );
                }
              }
            },
            child: const Text('Save Sub-Strand'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubStrand(SubStrand subStrand) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sub-Strand?'),
        content: Text('Are you sure you want to delete "${subStrand.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _curriculum.deleteSubStrand(subStrand.id);
                await _loadStrandsForSubject(_selectedSubject!);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sub-Strand "${subStrand.name}" deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting sub-strand: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      final updated = AppSettings(
        paymentsEnabled: _appSettings.paymentsEnabled,
        adsEnabled: _appSettings.adsEnabled,
        pricePerScheme: double.tryParse(_priceController.text) ?? 100.0,
        currency: 'KES',
        supportPhone: _phoneController.text.trim(),
        supportEmail: _appSettings.supportEmail,
      );

      await _curriculum.saveAppSettings(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Settings & Pricing saved successfully!'), backgroundColor: AppTheme.primaryGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Admin & Curriculum Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryGreen,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Grades & Subjects'),
              Tab(text: 'Strands & Topics'),
              Tab(text: 'App Settings'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: Grades & Subjects CRUD
                  _buildGradesAndSubjectsTab(),

                  // TAB 2: Strands & Sub-strands CRUD
                  _buildStrandsTab(),

                  // TAB 3: App Settings & Pricing
                  _buildSettingsTab(authProvider),
                ],
              ),
      ),
    );
  }

  // TAB 1: Grades & Subjects
  Widget _buildGradesAndSubjectsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Grades Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Curriculum Grades (${_grades.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            ElevatedButton.icon(
              onPressed: () => _showAddOrEditGradeDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Grade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Horizontal Grade Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _grades.length,
            itemBuilder: (ctx, idx) {
              final g = _grades[idx];
              final isSelected = _selectedGrade?.id == g.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g.name),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryGreenLight,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                  ),
                  onSelected: (val) {
                    if (val) {
                      _loadSubjectsForGrade(g).then((_) => setState(() {}));
                    }
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Selected Grade Management Card
        if (_selectedGrade != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedGrade!.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                    Text('Level: ${_selectedGrade!.level ?? "Primary School"}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
                      onPressed: () => _showAddOrEditGradeDialog(existing: _selectedGrade),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                      onPressed: () => _confirmDeleteGrade(_selectedGrade!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Subjects Section for Selected Grade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subjects for ${_selectedGrade!.name} (${_subjects.length})', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditSubjectDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Text('No subjects added for this grade yet.', style: TextStyle(color: AppTheme.textMuted)),
            )
          else
            ..._subjects.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                          Text('Code: ${s.code ?? "—"}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
                            onPressed: () => _showAddOrEditSubjectDialog(existing: s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                            onPressed: () => _confirmDeleteSubject(s),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ],
    );
  }

  // TAB 2: Strands & Sub-strands
  Widget _buildStrandsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dropdown Grade & Subject Selectors
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<Grade>(
                key: ValueKey(_selectedGrade?.id),
                initialValue: _selectedGrade,
                decoration: const InputDecoration(labelText: 'Select Grade', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                onChanged: (g) {
                  if (g != null) {
                    _loadSubjectsForGrade(g).then((_) => setState(() {}));
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Subject>(
                key: ValueKey(_selectedSubject?.id),
                initialValue: _selectedSubject,
                decoration: const InputDecoration(labelText: 'Select Subject', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                onChanged: (s) {
                  if (s != null) {
                    _loadStrandsForSubject(s).then((_) => setState(() {}));
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Strands Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Strands & Topics (${_strands.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            ElevatedButton.icon(
              onPressed: () => _showAddOrEditStrandDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Strand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_strands.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('No strands found for this subject.', style: TextStyle(color: AppTheme.textMuted)),
          )
        else
          ..._strands.map((strand) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: ExpansionTile(
                  title: Text(strand.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${strand.subStrands.length} Sub-strands', style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryGreen),
                        tooltip: 'Add Sub-Strand',
                        onPressed: () => _showAddOrEditSubStrandDialog(strand),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
                        onPressed: () => _showAddOrEditStrandDialog(existing: strand),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                        onPressed: () => _confirmDeleteStrand(strand),
                      ),
                    ],
                  ),
                  children: strand.subStrands.map((sub) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    dense: true,
                    leading: const Icon(Icons.subdirectory_arrow_right, size: 16, color: AppTheme.primaryGreen),
                    title: Text(sub.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted),
                          onPressed: () => _showAddOrEditSubStrandDialog(strand, existing: sub),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.errorRed),
                          onPressed: () => _confirmDeleteSubStrand(sub),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              )),
      ],
    );
  }

  // TAB 3: App Settings
  Widget _buildSettingsTab(AuthProvider authProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // App Settings Card
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
              const Text('Monetization & Gate Controls', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require Payment to Download & Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: const Text('When disabled, all teachers generate, download and share for free without payment gates'),
                value: _appSettings.paymentsEnabled,
                activeThumbColor: AppTheme.primaryGreen,
                onChanged: (val) => setState(() => _appSettings = AppSettings(
                  paymentsEnabled: val,
                  adsEnabled: _appSettings.adsEnabled,
                  pricePerScheme: _appSettings.pricePerScheme,
                  supportPhone: _appSettings.supportPhone,
                  supportEmail: _appSettings.supportEmail,
                )),
              ),
              const Divider(height: 20),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price per Scheme (KES)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Support Phone / M-Pesa Till',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save App Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Session info & Logout
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
              const Text('Admin Session', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 4),
              Text('Signed in as ${authProvider.user?.email ?? "Administrator"}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  authProvider.signOut();
                  Navigator.maybePop(context);
                },
                icon: const Icon(Icons.logout, size: 16, color: AppTheme.errorRed),
                label: const Text('Sign Out of Admin', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
