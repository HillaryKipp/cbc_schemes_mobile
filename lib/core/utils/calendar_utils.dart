/// Calendar & Term utility for calculating lesson slots and term dates
class CalendarUtils {
  /// Standard CBC term structure
  static const int defaultWeeksPerTerm = 12;
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
}
