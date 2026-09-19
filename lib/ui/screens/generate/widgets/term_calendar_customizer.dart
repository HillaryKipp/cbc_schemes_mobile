import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../../../models/term_settings.dart';

class TermCalendarCustomizer extends StatelessWidget {
  final Map<int, TermSettings> allTermSettings;
  final int currentTerm;
  final bool isBundleMode;
  final ValueChanged<int> onSelectTerm;
  final ValueChanged<TermSettings> onTermSettingsChanged;

  const TermCalendarCustomizer({
    super.key,
    required this.allTermSettings,
    required this.currentTerm,
    required this.isBundleMode,
    required this.onSelectTerm,
    required this.onTermSettingsChanged,
  });

  Future<void> _pickDate(BuildContext context, String initialDateStr, ValueChanged<String> onDatePicked) async {
    DateTime initialDate = DateTime.tryParse(initialDateStr) ?? DateTime(2026, 1, 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2028, 12, 31),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      onDatePicked(formatted);
    }
  }

  int _calculateWeeksBetween(String startStr, String endStr, int fallbackWeeks) {
    final start = DateTime.tryParse(startStr);
    final end = DateTime.tryParse(endStr);
    if (start != null && end != null && end.isAfter(start)) {
      final days = end.difference(start).inDays;
      final computed = (days / 7).ceil();
      return computed.clamp(1, 20);
    }
    return fallbackWeeks;
  }

  void _toggleAssessmentWeek(TermSettings settings, int week) {
    final current = List<int>.from(settings.assessmentWeeks);
    if (current.contains(week)) {
      current.remove(week);
      if (current.isEmpty) {
        // At least keep the final week if all unselected
        current.add(settings.weeks);
      }
    } else {
      current.add(week);
      current.sort();
    }
    onTermSettingsChanged(settings.copyWith(assessmentWeeks: current));
  }

  void _toggleMidTermAssessment(TermSettings settings) {
    final current = List<int>.from(settings.assessmentWeeks);
    final midWeek = settings.halfTermWeek;
    if (current.contains(midWeek)) {
      current.remove(midWeek);
      if (current.isEmpty) current.add(settings.weeks);
    } else {
      current.add(midWeek);
      current.sort();
    }
    onTermSettingsChanged(settings.copyWith(assessmentWeeks: current));
  }

  @override
  Widget build(BuildContext context) {
    final settings = allTermSettings[currentTerm]!;
    final totalWeeks = settings.weeks;
    final isMidTermAssessmentActive = settings.assessmentWeeks.contains(settings.halfTermWeek);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isBundleMode
                      ? '3. Academic Calendar & Assessment Weeks'
                      : '3. Term Calendar & Break Settings (${settings.termName})',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${settings.termName}: $totalWeeks Wks',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bundle Mode Term Switcher Buttons
          if (isBundleMode) ...[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [1, 2, 3].map((t) {
                  final tSettings = allTermSettings[t]!;
                  final isCur = currentTerm == t;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onSelectTerm(t),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isCur ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isCur ? [const BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Term $t (${tSettings.weeks}w)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCur ? FontWeight.w800 : FontWeight.w600,
                            color: isCur ? AppTheme.primaryGreen : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Dates & Lessons per week row
          Row(
            children: [
              // Start Date
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, settings.startDate, (newDate) {
                    final newWeeks = _calculateWeeksBetween(newDate, settings.endDate, settings.weeks);
                    onTermSettingsChanged(settings.copyWith(
                      startDate: newDate,
                      weeks: newWeeks,
                    ));
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderSubtle),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 14, color: AppTheme.primaryGreen),
                            const SizedBox(width: 4),
                            Text(settings.startDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // End Date
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, settings.endDate, (newDate) {
                    final newWeeks = _calculateWeeksBetween(settings.startDate, newDate, settings.weeks);
                    onTermSettingsChanged(settings.copyWith(
                      endDate: newDate,
                      weeks: newWeeks,
                    ));
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderSubtle),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 14, color: AppTheme.primaryGreen),
                            const SizedBox(width: 4),
                            Text(settings.endDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Lessons per week
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderSubtle),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF9FAFB),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lessons / Wk', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (settings.lessonsPerWeek > 1) {
                              onTermSettingsChanged(settings.copyWith(lessonsPerWeek: settings.lessonsPerWeek - 1));
                            }
                          },
                          child: const Icon(Icons.remove, size: 14, color: AppTheme.primaryGreen),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('${settings.lessonsPerWeek}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        InkWell(
                          onTap: () {
                            if (settings.lessonsPerWeek < 12) {
                              onTermSettingsChanged(settings.copyWith(lessonsPerWeek: settings.lessonsPerWeek + 1));
                            }
                          },
                          child: const Icon(Icons.add, size: 14, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Half-Term Break Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: settings.includeHalfTerm,
                              activeColor: AppTheme.primaryGreen,
                              onChanged: (val) {
                                onTermSettingsChanged(settings.copyWith(includeHalfTerm: val ?? true));
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Include Half Term Break (MID-TERM)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (settings.includeHalfTerm) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Week ${settings.halfTermWeek} Break',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (settings.includeHalfTerm) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Mid-Term Start Date
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(
                            context,
                            settings.midTermStartDate.isNotEmpty ? settings.midTermStartDate : '2026-02-25',
                            (newDate) {
                              onTermSettingsChanged(settings.copyWith(midTermStartDate: newDate));
                            },
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.borderSubtle),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Break Start', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.event, size: 12, color: AppTheme.primaryGreen),
                                    const SizedBox(width: 3),
                                    Text(
                                      settings.midTermStartDate.isNotEmpty ? settings.midTermStartDate : 'Pick date',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Mid-Term End Date
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(
                            context,
                            settings.midTermEndDate.isNotEmpty ? settings.midTermEndDate : '2026-03-01',
                            (newDate) {
                              onTermSettingsChanged(settings.copyWith(midTermEndDate: newDate));
                            },
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.borderSubtle),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Break End', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.event_available, size: 12, color: AppTheme.primaryGreen),
                                    const SizedBox(width: 3),
                                    Text(
                                      settings.midTermEndDate.isNotEmpty ? settings.midTermEndDate : 'Pick date',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Half Term Week Selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderSubtle),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Break Week', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                              DropdownButton<int>(
                                value: settings.halfTermWeek.clamp(1, totalWeeks),
                                isDense: true,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                items: List.generate(totalWeeks, (i) => i + 1).map((w) {
                                  return DropdownMenuItem(
                                    value: w,
                                    child: Text(
                                      'Week $w',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    onTermSettingsChanged(settings.copyWith(halfTermWeek: val));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '2026 Guideline: Term 1 (Feb 25–Mar 1), Term 2 (Jun 24–28), Term 3 (Early Oct).',
                    style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Assessment Weeks Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${settings.termName} Assessment Weeks',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Defaults to end week. Click chips to add/remove.',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${settings.assessmentWeeks.length} ${settings.assessmentWeeks.length == 1 ? 'week' : 'weeks'}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick buttons
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        onTermSettingsChanged(settings.copyWith(assessmentWeeks: [totalWeeks]));
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: settings.assessmentWeeks.length == 1 && settings.assessmentWeeks.contains(totalWeeks)
                            ? AppTheme.primaryGreenLight
                            : Colors.white,
                      ),
                      child: Text(
                        'Default: End Week (Wk $totalWeeks)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                    ),
                    if (settings.includeHalfTerm)
                      OutlinedButton.icon(
                        onPressed: () => _toggleMidTermAssessment(settings),
                        icon: Icon(
                          isMidTermAssessmentActive ? Icons.check : Icons.add,
                          size: 13,
                          color: isMidTermAssessmentActive ? AppTheme.primaryGreen : AppTheme.textDark,
                        ),
                        label: Text(
                          isMidTermAssessmentActive ? 'Mid-Term Assessment Active' : 'Add Mid-Term Assessment',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMidTermAssessmentActive ? AppTheme.primaryGreen : AppTheme.textDark,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          backgroundColor: isMidTermAssessmentActive ? AppTheme.primaryGreenLight : Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Week selector chips
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: List.generate(totalWeeks, (i) {
                    final week = i + 1;
                    final isAssessed = settings.assessmentWeeks.contains(week);
                    final isEnd = week == totalWeeks;
                    final isMid = settings.includeHalfTerm && week == settings.halfTermWeek;

                    return InkWell(
                      onTap: () => _toggleAssessmentWeek(settings, week),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAssessed ? AppTheme.primaryGreen : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAssessed ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Wk $week',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isAssessed ? FontWeight.bold : FontWeight.w500,
                                color: isAssessed ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                            if (isEnd) ...[
                              const SizedBox(width: 3),
                              Text(
                                '(End)',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isAssessed ? Colors.white70 : AppTheme.textMuted,
                                ),
                              ),
                            ] else if (isMid) ...[
                              const SizedBox(width: 3),
                              Text(
                                '(Mid)',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isAssessed ? Colors.white70 : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),

                // Selected assessment summary
                Text(
                  'Selected: ${settings.assessmentWeeks.map((w) {
                    if (w == totalWeeks) return 'Week $w (ASSESSMENT - End)';
                    if (settings.includeHalfTerm && w == settings.halfTermWeek) return 'Week $w (MID-TERM & ASSESSMENT)';
                    return 'Week $w (ASSESSMENT)';
                  }).join(', ')}',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
