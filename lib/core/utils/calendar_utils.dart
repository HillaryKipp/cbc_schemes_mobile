/// Calendar & Term utility for calculating lesson slots and term dates
class CalendarUtils {
  /// Standard CBC term structure defaults
  static const int defaultWeeksPerTerm = 13;
  static const int defaultLessonsPerWeek = 5;

  /// Calculate total slots from weeks and lessons per week
  static int calculateTotalSlots({
    required int weeks,
    required int lessonsPerWeek,
  }) {
    return (weeks > 0 ? weeks : defaultWeeksPerTerm) * 
           (lessonsPerWeek > 0 ? lessonsPerWeek : defaultLessonsPerWeek);
  }

  /// Given slot index (0-based), returns (weekNumber, lessonNumber) both 1-based
  static ({int week, int lesson}) getWeekAndLesson(
    int slotIndex,
    int lessonsPerWeek,
  ) {
    final lpw = lessonsPerWeek > 0 ? lessonsPerWeek : defaultLessonsPerWeek;
    final week = (slotIndex ~/ lpw) + 1;
    final lesson = (slotIndex % lpw) + 1;
    return (week: week, lesson: lesson);
  }

  /// Calculates number of teaching weeks between two dates, optionally accounting for half-term break
  static int calculateWeeksBetween(
    DateTime startDate,
    DateTime endDate, {
    int breakDays = 0,
  }) {
    final diffDays = endDate.difference(startDate).inDays;
    if (diffDays <= 0) return defaultWeeksPerTerm;
    final teachingDays = diffDays - breakDays;
    final weeks = (teachingDays / 7).round();
    return weeks > 0 ? weeks : 1;
  }

  /// Exact web-matching computeWeeks implementation from src/lib/calendar.ts
  static int computeWeeks(String startDateStr, String endDateStr, List<Map<String, dynamic>> breaks) {
    if (startDateStr.isEmpty || endDateStr.isEmpty) return 0;
    try {
      final startIso = startDateStr.contains('T') ? startDateStr : '${startDateStr}T00:00:00Z';
      final endIso = endDateStr.contains('T') ? endDateStr : '${endDateStr}T00:00:00Z';
      final start = DateTime.parse(startIso);
      final end = DateTime.parse(endIso);
      
      final totalDays = (end.difference(start).inMilliseconds / 86400000).round() + 1;
      int weeks = (totalDays / 7).round();

      for (final b in breaks) {
        if (b['start'] == null || b['end'] == null) continue;
        final bStartStr = b['start'].toString();
        final bEndStr = b['end'].toString();
        final bStartIso = bStartStr.contains('T') ? bStartStr : '${bStartStr}T00:00:00Z';
        final bEndIso = bEndStr.contains('T') ? bEndStr : '${bEndStr}T00:00:00Z';
        final bStart = DateTime.parse(bStartIso);
        final bEnd = DateTime.parse(bEndIso);
        final bDays = (bEnd.difference(bStart).inMilliseconds / 86400000).round() + 1;
        weeks -= (bDays / 7).round();
      }
      return weeks < 1 ? 1 : weeks;
    } catch (_) {
      return defaultWeeksPerTerm;
    }
  }

  /// Generates ordered lesson slots [(week 1, lesson 1), (week 1, lesson 2)...]
  static List<({int week, int lesson})> computeLessonSlots(int weeks, int lessonsPerWeek) {
    final slots = <({int week, int lesson})>[];
    for (var w = 1; w <= weeks; w++) {
      for (var l = 1; l <= lessonsPerWeek; l++) {
        slots.add((week: w, lesson: l));
      }
    }
    return slots;
  }
}
