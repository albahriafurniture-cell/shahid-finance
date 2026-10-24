import 'package:intl/intl.dart';

/// Pakistani digit grouping: thousands, then pairs — Rs 1,28,450.
/// Whole rupees only, everywhere (master §2 conventions).
String groupPakistani(int value) {
  final negative = value < 0;
  var digits = value.abs().toString();
  if (digits.length <= 3) return negative ? '-$digits' : digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  final grouped = '${parts.join(',')},$last3';
  return negative ? '-$grouped' : grouped;
}

/// "Rs 1,28,450" — unsigned, Rs prefix.
String fmtRs(int value) => 'Rs ${groupPakistani(value)}';

/// Signed movement amount: income "+Rs 86,000", expense "−Rs 57,550".
String fmtSigned(int value, {required bool income}) {
  final sign = income ? '+' : '−';
  return '$sign${fmtRs(value.abs())}';
}

/// Strip non-digits and parse an amount field's raw value.
int parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

/// Group digits while typing (Pakistani grouping, no Rs prefix).
String groupTyped(String text) {
  final v = parseAmount(text);
  if (v == 0 && text.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) return '';
  return groupPakistani(v);
}

final _dateFmt = DateFormat('d MMM yyyy');
final _dateFmtFull = DateFormat('EEE, d MMM yyyy');
final _monthFmt = DateFormat('MMMM yyyy');
final _timeFmt = DateFormat('h:mm a');

String fmtDate(DateTime d) => _dateFmt.format(d);
String fmtDateFull(DateTime d) => _dateFmtFull.format(d);
String fmtMonth(DateTime d) => _monthFmt.format(d);
String fmtTime(DateTime d) => _timeFmt.format(d);

String dayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(n.year, n.month, n.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return fmtDateFull(d);
}

/// A budget cycle: starts on [startDay] of a month (or the last day when
/// startDay is 29–31 and the month is shorter / startDay == 0 meaning
/// "last day of month"), ends the day before the next cycle starts.
extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class Cycle {
  final DateTime start;
  final DateTime end; // inclusive
  const Cycle(this.start, this.end);

  int get totalDays => end.difference(start).inDays + 1;

  int daysRemaining({DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (today.isBefore(start)) return totalDays;
    if (today.isAfter(end)) return 0;
    return end.difference(today).inDays + 1;
  }

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

/// Resolve the cycle containing [anchor] for a given start-day setting.
/// startDaySetting: 1..28 = that day; 0 = last day of month;
/// 25/26/27/28-style salary days are just their day numbers.
Cycle cycleFor(int startDaySetting, DateTime anchor) {
  DateTime cycleStart(int year, int month) {
    if (startDaySetting <= 0) {
      // Last day of month.
      return DateTime(year, month + 1, 0);
    }
    final lastDay = DateTime(year, month + 1, 0).day;
    final d = startDaySetting > lastDay ? lastDay : startDaySetting;
    return DateTime(year, month, d);
  }

  var start = cycleStart(anchor.year, anchor.month);
  if (anchor.isBefore(start)) {
    final prev = DateTime(anchor.year, anchor.month - 1);
    start = cycleStart(prev.year, prev.month);
  }
  final nextMonth = DateTime(start.year, start.month + 1);
  final nextStart = cycleStart(nextMonth.year, nextMonth.month);
  final end = nextStart.subtract(const Duration(days: 1));
  return Cycle(DateTime(start.year, start.month, start.day),
      DateTime(end.year, end.month, end.day));
}

/// Pacing rule (budgets spec §0.2): left ÷ days remaining (incl. today),
/// rounded to the nearest Rs 10.
int pacePerDay(int left, int daysRemaining) {
  if (daysRemaining <= 0) return left;
  final raw = left / daysRemaining;
  return ((raw / 10).round()) * 10;
}

/// Percentage rounded to nearest whole number (.5 rounds up).
int percentOf(int part, int total) {
  if (total <= 0) return 0;
  return ((part * 100) / total).round();
}

/// Ordinal label for a cycle start day: 1 -> "1st", 25 -> "25th", 0 -> "Last day".
String cycleDayLabel(int startDay) {
  if (startDay <= 0) return 'Last day of month';
  if (startDay == 1) return '1st';
  if (startDay == 2) return '2nd';
  if (startDay == 3) return '3rd';
  return '${startDay}th';
}
