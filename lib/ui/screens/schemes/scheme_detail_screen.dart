import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/theme.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/reference_book.dart';
import '../generate/generate_wizard_screen.dart';

class SchemeDetailScreen extends StatelessWidget {
  final Grade grade;
  final Subject subject;
  final String termName;
  final int year;
  final int weeks;
  final int lessons;
  final ReferenceBook? referenceBook;

  const SchemeDetailScreen({
    super.key,
    required this.grade,
    required this.subject,
    this.termName = 'Term 3',
    this.year = 2026,
    this.weeks = 9,
    this.lessons = 45,
    this.referenceBook,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: () {
              Share.share(
                'CBC Scheme of Work: ${grade.name} ${subject.name} - $termName $year ($weeks Weeks, $lessons Lessons). Generate yours on CBC Schemes of Work app!',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Text(
              '${grade.name} ${subject.name}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$termName – $year',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'CBC Scheme of Work',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),

            const SizedBox(height: 16),

            // Metadata Grid Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildMetaRow(Icons.description_outlined, 'Grade:', grade.name),
                  const SizedBox(height: 10),
                  _buildMetaRow(Icons.edit_note_outlined, 'Subject:', subject.name),
                  const SizedBox(height: 10),
                  _buildMetaRow(Icons.calendar_month_outlined, 'Term:', termName),
                  const SizedBox(height: 10),
                  _buildMetaRow(Icons.calendar_today_outlined, 'Year:', '$year'),
                  const SizedBox(height: 10),
                  _buildMetaRow(Icons.hourglass_empty_outlined, 'Weeks:', '$weeks'),
                  const SizedBox(height: 10),
                  _buildMetaRow(Icons.timer_outlined, 'Lessons:', '$lessons'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Preview Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _navigateToGenerate(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'View Full Scheme',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Document Preview Paper Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'SCHEMES OF WORK',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject.name.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${grade.name.toUpperCase()}  ${termName.toUpperCase()}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),

                  // School Lines
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLine('School:'),
                        _buildLine('TSC Number:'),
                        _buildLine('HOD Name:'),
                        _buildLine('HOD Signature:'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Kenya Ministry Emblem Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppTheme.primaryGreen, size: 28),
                        const SizedBox(height: 2),
                        Text(
                          'REPUBLIC OF KENYA\nMINISTRY OF EDUCATION',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.textDark.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Mini table header preview
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Table(
                      border: TableBorder.all(color: AppTheme.borderSubtle, width: 0.5),
                      columnWidths: const {
                        0: FixedColumnWidth(28),
                        1: FixedColumnWidth(32),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(2.2),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                          children: [
                            _buildMiniHeader('WEEK'),
                            _buildMiniHeader('LESSON'),
                            _buildMiniHeader('STRAND'),
                            _buildMiniHeader('SUB-STRAND'),
                            _buildMiniHeader('LEARNING OUTCOMES'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _buildMiniCell('1'),
                            _buildMiniCell('1'),
                            _buildMiniCell('Numbers'),
                            _buildMiniCell('Rational Numbers'),
                            _buildMiniCell('By the end of the lesson, the learner should be able to: identify rational numbers...'),
                          ],
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

      // Sticky Bottom Button
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToGenerate(context),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate My Scheme'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToGenerate(BuildContext context) {
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
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
        ),
      ],
    );
  }

  Widget _buildLine(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFD1D5DB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMiniCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: Text(
        text,
        style: const TextStyle(fontSize: 7.5),
      ),
    );
  }
}
