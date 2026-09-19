import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../../../models/strand.dart';
import '../../../../models/term_settings.dart';
import '../../../../services/scheme_generator.dart';

class ScopeAndSequenceCustomizer extends StatelessWidget {
  final List<Strand> strands;
  final Map<int, List<TermSubStrandAssignment>> assignments;
  final Map<int, TermSettings> termSettings;
  final int activeTermFilter; // 0 = all terms, 1 = Term 1, 2 = Term 2, 3 = Term 3
  final bool isBundleMode;
  final ValueChanged<Map<int, List<TermSubStrandAssignment>>> onAssignmentsChanged;
  final ValueChanged<int> onSelectTermFilter;
  final VoidCallback onAutoBalance;

  const ScopeAndSequenceCustomizer({
    super.key,
    required this.strands,
    required this.assignments,
    required this.termSettings,
    required this.activeTermFilter,
    required this.isBundleMode,
    required this.onAssignmentsChanged,
    required this.onSelectTermFilter,
    required this.onAutoBalance,
  });

  int _getAllocatedLessons(int term) {
    final list = assignments[term] ?? [];
    return list.fold<int>(0, (sum, a) => sum + a.allocatedLessons);
  }

  int? _findAssignedTerm(String subStrandId) {
    for (int t = 1; t <= 3; t++) {
      if ((assignments[t] ?? []).any((a) => a.subStrandId == subStrandId)) {
        return t;
      }
    }
    return null;
  }

  int _getSubStrandAllocatedLessons(int term, String subStrandId, int defaultLessons) {
    final match = (assignments[term] ?? []).cast<TermSubStrandAssignment?>().firstWhere(
      (a) => a?.subStrandId == subStrandId,
      orElse: () => null,
    );
    return match?.allocatedLessons ?? defaultLessons;
  }

  void _moveEntireStrand(Strand strand, int targetTerm) {
    final subStrandIds = strand.subStrands.map((s) => s.id).toSet();
    final updated = <int, List<TermSubStrandAssignment>>{
      1: (assignments[1] ?? []).where((a) => !subStrandIds.contains(a.subStrandId)).toList(),
      2: (assignments[2] ?? []).where((a) => !subStrandIds.contains(a.subStrandId)).toList(),
      3: (assignments[3] ?? []).where((a) => !subStrandIds.contains(a.subStrandId)).toList(),
    };

    for (final ss in strand.subStrands) {
      final lessons = ss.suggestedLessons > 0 ? ss.suggestedLessons : 4;
      updated[targetTerm]!.add(TermSubStrandAssignment(
        termNumber: targetTerm,
        strandId: strand.id,
        subStrandId: ss.id,
        allocatedLessons: lessons,
        lessonOffset: 0,
      ));
    }

    onAssignmentsChanged(updated);
  }

  void _moveSubStrand(String subStrandId, String strandId, int targetTerm, int defaultLessons) {
    var lessons = defaultLessons;
    for (int t = 1; t <= 3; t++) {
      final found = (assignments[t] ?? []).cast<TermSubStrandAssignment?>().firstWhere(
        (a) => a?.subStrandId == subStrandId,
        orElse: () => null,
      );
      if (found != null) {
        lessons = found.allocatedLessons;
        break;
      }
    }

    final updated = <int, List<TermSubStrandAssignment>>{
      1: (assignments[1] ?? []).where((a) => a.subStrandId != subStrandId).toList(),
      2: (assignments[2] ?? []).where((a) => a.subStrandId != subStrandId).toList(),
      3: (assignments[3] ?? []).where((a) => a.subStrandId != subStrandId).toList(),
    };

    updated[targetTerm]!.add(TermSubStrandAssignment(
      termNumber: targetTerm,
      strandId: strandId,
      subStrandId: subStrandId,
      allocatedLessons: lessons,
      lessonOffset: 0,
    ));

    onAssignmentsChanged(updated);
  }

  void _changeSubStrandLessons(int term, String subStrandId, int delta) {
    final list = assignments[term] ?? [];
    final updatedList = list.map((a) {
      if (a.subStrandId == subStrandId) {
        final newLessons = (a.allocatedLessons + delta).clamp(1, 60);
        return a.copyWith(allocatedLessons: newLessons);
      }
      return a;
    }).toList();

    final updated = Map<int, List<TermSubStrandAssignment>>.from(assignments);
    updated[term] = updatedList;
    onAssignmentsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3-Term Capacity Cards
        _buildTermCapacityCards(),
        const SizedBox(height: 14),

        // Quick Distribution Presets Bar
        _buildPresetsBar(),
        const SizedBox(height: 16),

        // Strands & Sub-strands List
        ...strands.asMap().entries.map((entry) {
          final strandIdx = entry.key;
          final strand = entry.value;
          return _buildStrandCard(strand, strandIdx);
        }),
      ],
    );
  }

  Widget _buildTermCapacityCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 550;
        final cards = [1, 2, 3].map((term) {
          final settings = termSettings[term]!;
          final totalLessons = _getAllocatedLessons(term);
          final teachingSlots = settings.availableTeachingSlots;
          final pct = teachingSlots > 0 ? (totalLessons / teachingSlots).clamp(0.0, 1.0) : 0.0;
          final isSelected = activeTermFilter == term || (activeTermFilter == 0 && isBundleMode);

          return InkWell(
            onTap: () => onSelectTermFilter(activeTermFilter == term ? 0 : term),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreenLight.withValues(alpha: 0.3) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.borderSubtle,
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settings.termName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryGreen : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$totalLessons lessons',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${settings.weeks} wks • ${settings.lessonsPerWeek} lpw ($teachingSlots teaching slots)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(assignments[term] ?? []).length} sub-strands',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                      Text(
                        '${(pct * 100).round()}% teaching slots filled',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList();

        if (isWide) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        }

        return Column(
          children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList(),
        );
      },
    );
  }

  Widget _buildPresetsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryGreen),
              SizedBox(width: 6),
              Text(
                'Quick distribution presets:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: onAutoBalance,
            icon: const Icon(Icons.sync_rounded, size: 14, color: AppTheme.primaryGreen),
            label: const Text(
              'Auto-balance across 3 Terms',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: AppTheme.primaryGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrandCard(Strand strand, int strandIdx) {
    // Filter sub-strands if a term filter is selected
    final filteredSubStrands = strand.subStrands.where((ss) {
      if (activeTermFilter == 0) return true;
      final assignedTerm = _findAssignedTerm(ss.id);
      return assignedTerm == activeTermFilter;
    }).toList();

    if (activeTermFilter != 0 && filteredSubStrands.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalSuggestedLessons = strand.subStrands.fold<int>(
      0,
      (sum, s) => sum + (s.suggestedLessons > 0 ? s.suggestedLessons : 4),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strand Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            color: const Color(0xFFF9FAFB),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreenLight,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${strandIdx + 1}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Strand ${strandIdx + 1}: ${strand.name}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                      ),
                      Text(
                        '${strand.subStrands.length} sub-strands • ~$totalSuggestedLessons total lessons',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                // Quick "Move all to" action
                PopupMenuButton<int>(
                  tooltip: 'Move entire strand to a term',
                  icon: const Icon(Icons.drive_file_move_outlined, size: 18, color: AppTheme.primaryGreen),
                  onSelected: (term) => _moveEntireStrand(strand, term),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('Move all to:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const PopupMenuItem(value: 1, child: Text('Term 1')),
                    const PopupMenuItem(value: 2, child: Text('Term 2')),
                    const PopupMenuItem(value: 3, child: Text('Term 3')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Sub-strands List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSubStrands.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, subIdx) {
              final subStrand = filteredSubStrands[subIdx];
              final defaultLessons = subStrand.suggestedLessons > 0 ? subStrand.suggestedLessons : 4;
              final assignedTerm = _findAssignedTerm(subStrand.id) ?? 1;
              final currentLessons = _getSubStrandAllocatedLessons(assignedTerm, subStrand.id, defaultLessons);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${strandIdx + 1}.${subIdx + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subStrand.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'KICD curriculum recommendation: $defaultLessons lessons',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Term selector chips & Lesson counter
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        // Term Chips [T1] [T2] [T3]
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [1, 2, 3].map((t) {
                            final isCurTerm = assignedTerm == t;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => _moveSubStrand(subStrand.id, strand.id, t, defaultLessons),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCurTerm ? AppTheme.primaryGreen : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCurTerm ? AppTheme.primaryGreen : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    'T$t',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isCurTerm ? FontWeight.w800 : FontWeight.w600,
                                      color: isCurTerm ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Lesson count stepper
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Lessons: ',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderSubtle),
                                color: const Color(0xFFF9FAFB),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _changeSubStrandLessons(assignedTerm, subStrand.id, -1),
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(3),
                                      child: Icon(Icons.remove, size: 14, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '$currentLessons',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _changeSubStrandLessons(assignedTerm, subStrand.id, 1),
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(3),
                                      child: Icon(Icons.add, size: 14, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
