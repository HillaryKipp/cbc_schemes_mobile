import 'package:intl/intl.dart';

class Formatters {
  static final DateFormat shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat isoDate = DateFormat('yyyy-MM-dd');
  static final NumberFormat currency = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return shortDate.format(date);
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
