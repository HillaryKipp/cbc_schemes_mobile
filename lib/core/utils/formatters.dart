import 'package:intl/intl.dart';

const outcomeLeadIn = "By the end of the sub strand, the learner should be able to;";

String cleanItemText(String item) {
  return item
      .trim()
      .replaceFirst(RegExp(r'^([•\-*–—_]+|[0-9]+[.)]|[a-zA-Z][.)])\s*'), '')
      .trim();
}

String getLetterLabel(int index) {
  String label = "";
  int n = index;
  while (n >= 0) {
    label = String.fromCharCode(97 + (n % 26)) + label;
    n = (n ~/ 26) - 1;
  }
  return label;
}

List<String> formatOutcomes(List<String> rawOutcomes) {
  final clean = rawOutcomes.map(cleanItemText).where((s) => s.isNotEmpty).toList();
  if (clean.isEmpty) return [];
  final formatted = <String>[outcomeLeadIn];
  for (int i = 0; i < clean.length; i++) {
    formatted.add('${getLetterLabel(i)}) ${clean[i]}');
  }
  return formatted;
}

List<String> formatQuestions(List<String> rawQuestions) {
  final clean = rawQuestions.map(cleanItemText).where((s) => s.isNotEmpty).toList();
  return clean.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').toList();
}

List<String> formatBullets(List<String> rawItems) {
  final clean = rawItems.map(cleanItemText).where((s) => s.isNotEmpty).toList();
  return clean.map((item) => '- $item').toList();
}

class Formatters {
  static final DateFormat shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat isoDate = DateFormat('yyyy-MM-dd');
  static final NumberFormat currency = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static String formatDate(dynamic date) {
    if (date == null) return '-';
    if (date is DateTime) return shortDate.format(date);
    if (date is String) {
      final parsed = DateTime.tryParse(date);
      return parsed != null ? shortDate.format(parsed) : date;
    }
    return '-';
  }

  static String formatAmount(num? amount) {
    if (amount == null) return 'KES 0';
    return currency.format(amount);
  }

  static String joinList(List<String>? items, {String separator = '\n• '}) {
    if (items == null || items.isEmpty) return '-';
    if (items.length == 1) return items.first;
    return '• ${items.join(separator)}';
  }
}
