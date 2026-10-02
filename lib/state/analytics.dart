import 'package:flutter/material.dart';

import '../models/finance.dart';
import '../models/seed.dart';

/// An inclusive day range: [start] is 00:00:00.000 of the first day and [end]
/// is 23:59:59.999 of the last day.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get dayCount => startOfDay(end).difference(startOfDay(start)).inDays + 1;

  DateTimeRange get material => DateTimeRange(start: start, end: end);

  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);

  /// The equally long window immediately before this one, used for the
  /// "dibanding periode lalu" comparison.
  DateRange get previous {
    final DateTime prevEnd = start.subtract(const Duration(seconds: 1));
    final DateTime prevStart =
        startOfDay(prevEnd).subtract(Duration(days: dayCount - 1));
    return DateRange(prevStart, prevEnd);
  }

  String get label {
    if (dayCount == 1) return formatDateDMY(start);
    return '${formatDateDMY(start)} - ${formatDateDMY(end)}';
  }
}

/// How a range was chosen. Drives the active chip in the Analisis tab bar.
enum PeriodKind { week, month, year, custom }

/// Ordering of the category breakdown list on the Analisis screen.
enum CategorySort { amount, name, count }

/// One column of the trend chart.
class TrendBucket {
  const TrendBucket({
    required this.label,
    required this.amount,
    required this.heightPct,
    required this.isPeak,
    required this.detail,
  });

  final String label;
  final int amount;
  final double heightPct;
  final bool isPeak;

  /// Longer sub-label, e.g. "1 - 7 Okt".
  final String detail;
}

/// Everything the Analisis screen renders for one period, computed from the
/// live transaction list. No figure on that screen is hard-coded.
class Analytics {
  const Analytics({
    required this.range,
    required this.previousRange,
    required this.total,
    required this.previousTotal,
    required this.count,
    required this.buckets,
    required this.slices,
    required this.elapsedDays,
    required this.busiestDay,
    required this.busiestDayAmount,
  });

  final DateRange range;
  final DateRange previousRange;
  final int total;
  final int previousTotal;
  final int count;
  final List<TrendBucket> buckets;
  final List<CategorySlice> slices;

  /// Days of the range that have already happened (today included), which is
  /// what the daily average should divide by.
  final int elapsedDays;

  final String busiestDay;
  final int busiestDayAmount;

  bool get isEmpty => total == 0;

  /// Largest category slice, or null when there are no expenses yet. Always
  /// the biggest by amount, independent of how the breakdown list is sorted.
  CategorySlice? get topSlice {
    if (slices.isEmpty) return null;
    return slices.reduce(
      (CategorySlice a, CategorySlice b) => b.amount > a.amount ? b : a,
    );
  }

  TrendBucket? get peak {
    for (final TrendBucket b in buckets) {
      if (b.isPeak) return b;
    }
    return null;
  }

  /// Percentage change vs. the previous period. Negative means spending less.
  /// Null when there is no usable baseline to compare against.
  double? get changePct {
    if (previousTotal <= 0) return null;
    return ((total - previousTotal) / previousTotal) * 100;
  }

  /// True when this period is cheaper than the one before it.
  bool get isSaving => (changePct ?? 0) < 0;

  int get averagePerDay => total ~/ (elapsedDays < 1 ? 1 : elapsedDays);

  /// Average per transaction, rounded down.
  int get averagePerEntry => count == 0 ? 0 : total ~/ count;
}

/// Aggregate [transactions] that fall inside [range].
Analytics computeAnalytics({
  required List<Transaction> transactions,
  required DateRange range,
  DateTime? now,
}) {
  final DateTime n = now ?? DateTime.now();
  final DateTime today = startOfDay(n);

  final List<Transaction> inRange = transactions
      .where((Transaction t) => t.date != null && range.contains(t.date!))
      .toList();

  final int total = inRange.fold(0, (int sum, Transaction t) => sum + t.amount);

  final DateRange previous = range.previous;
  final int previousTotal = transactions
      .where((Transaction t) => t.date != null && previous.contains(t.date!))
      .fold(0, (int sum, Transaction t) => sum + t.amount);

  // Busiest single day, used by the insight card.
  final Map<String, int> perDay = <String, int>{};
  for (final Transaction t in inRange) {
    final String key = formatDateDMY(t.date!);
    perDay[key] = (perDay[key] ?? 0) + t.amount;
  }
  String busiestDay = '';
  int busiestDayAmount = 0;
  perDay.forEach((String k, int v) {
    if (v > busiestDayAmount) {
      busiestDayAmount = v;
      busiestDay = k;
    }
  });

  // Only count days that have actually happened, otherwise a range that ends
  // today would be diluted by empty future days.
  final int elapsedDays = today.difference(startOfDay(range.start)).inDays + 1;

  return Analytics(
    range: range,
    previousRange: previous,
    total: total,
    previousTotal: previousTotal,
    count: inRange.length,
    buckets: _buildBuckets(inRange, range),
    slices: _buildSlices(inRange),
    elapsedDays: elapsedDays < 1 ? 1 : elapsedDays,
    busiestDay: busiestDay,
    busiestDayAmount: busiestDayAmount,
  );
}

/// Buckets rows into daily / weekly / monthly columns depending on the span,
/// then normalises heights so the tallest bar fills the plot area.
List<TrendBucket> _buildBuckets(List<Transaction> inRange, DateRange range) {
  final int span = range.dayCount;
  final DateTime first = startOfDay(range.start);
  final DateTime last = startOfDay(range.end);

  final List<_Window> windows = <_Window>[];

  if (span <= 8) {
    for (int i = 0; i < span; i++) {
      final DateTime day = first.add(Duration(days: i));
      windows.add(_Window(
        label: span == 1 ? formatDateDMY(day) : dayShort(day),
        detail: formatDateDMY(day),
        from: day,
        to: endOfDay(day),
      ));
    }
  } else if (span <= 62) {
    DateTime cursor = first;
    int index = 1;
    while (!cursor.isAfter(last)) {
      final DateTime weekStart =
          cursor.weekday == DateTime.monday ? cursor : startOfWeek(cursor);
      DateTime weekEnd = endOfDay(weekStart.add(const Duration(days: 6)));
      if (weekEnd.isAfter(last)) weekEnd = endOfDay(last);
      windows.add(_Window(
        label: 'Mgg $index',
        detail: '${formatDateDMY(weekStart)} - ${formatDateDMY(weekEnd)}',
        from: weekStart,
        to: weekEnd,
      ));
      cursor = weekStart.add(const Duration(days: 7));
      index++;
    }
  } else {
    DateTime cursor = DateTime(first.year, first.month);
    while (!cursor.isAfter(last)) {
      DateTime monthEnd = endOfDay(DateTime(cursor.year, cursor.month + 1, 0));
      if (monthEnd.isAfter(last)) monthEnd = endOfDay(last);
      windows.add(_Window(
        label: monthShort(cursor),
        detail: monthLong(cursor),
        from: cursor,
        to: monthEnd,
      ));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }

  if (windows.isEmpty) return const <TrendBucket>[];

  // Very long ranges would produce unreadable slivers; fold them down to 12.
  final List<_Window> capped;
  if (windows.length > 12) {
    final int size = (windows.length / 12).ceil();
    final List<_Window> folded = <_Window>[];
    for (int i = 0; i < windows.length; i += size) {
      final _Window first = windows[i];
      final _Window last = windows[
          i + size - 1 < windows.length ? i + size - 1 : windows.length - 1];
      folded.add(_Window(
        label: first.label,
        detail: '${formatDateDMY(first.from)} - ${formatDateDMY(last.to)}',
        from: first.from,
        to: last.to,
      ));
    }
    capped = folded;
  } else {
    capped = windows;
  }

  final List<int> amounts = <int>[
    for (final _Window w in capped)
      inRange
          .where((Transaction t) =>
              t.date != null &&
              !t.date!.isBefore(w.from) &&
              !t.date!.isAfter(w.to))
          .fold(0, (int sum, Transaction t) => sum + t.amount),
  ];

  final int maxAmount = amounts.fold(0, (int m, int v) => v > m ? v : m);
  int peakIndex = -1;
  for (int i = 0; i < amounts.length; i++) {
    if (maxAmount > 0 && amounts[i] == maxAmount) peakIndex = i;
  }

  return <TrendBucket>[
    for (int i = 0; i < capped.length; i++)
      TrendBucket(
        label: capped[i].label,
        amount: amounts[i],
        // Keep a small floor so empty buckets still render a visible outline.
        heightPct:
            maxAmount == 0 ? 0 : (amounts[i] / maxAmount).clamp(0.04, 1.0),
        isPeak: i == peakIndex,
        detail: capped[i].detail,
      ),
  ];
}

class _Window {
  const _Window({
    required this.label,
    required this.detail,
    required this.from,
    required this.to,
  });

  final String label;
  final String detail;
  final DateTime from;
  final DateTime to;
}

/// Category share of the filtered rows, sorted by amount descending.
List<CategorySlice> _buildSlices(List<Transaction> inRange) {
  final int total = inRange.fold(0, (int sum, Transaction t) => sum + t.amount);
  if (total == 0) return const <CategorySlice>[];

  final Map<String, int> amounts = <String, int>{};
  final Map<String, int> counts = <String, int>{};
  for (final Transaction t in inRange) {
    final String key = t.categoryId ?? Seed.categories.last.id;
    amounts[key] = (amounts[key] ?? 0) + t.amount;
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final List<String> ids = amounts.keys.toList()
    ..sort(
        (String a, String b) => (amounts[b] ?? 0).compareTo(amounts[a] ?? 0));

  // Spread the palette across slices, then reuse it if there are more slices
  // than colours so the donut never runs out of distinct fills.
  final int stride = ids.length <= kSlicePalette.length
      ? 1
      : (ids.length / kSlicePalette.length).ceil();

  return <CategorySlice>[
    for (int i = 0; i < ids.length; i++)
      _sliceFor(
        ids[i],
        amounts[ids[i]] ?? 0,
        counts[ids[i]] ?? 0,
        total,
        kSlicePalette[(i * stride) % kSlicePalette.length],
      ),
  ];
}

CategorySlice _sliceFor(
  String id,
  int amount,
  int count,
  int total,
  Color color,
) {
  final Category cat = Seed.categories.firstWhere(
    (Category c) => c.id == id,
    orElse: () => Seed.categories.last,
  );
  return CategorySlice(
    cat.longLabel,
    amount,
    count,
    amount / total,
    color,
    cat.icon,
  );
}

// ---------------------------------------------------------------------------
// Period resolution
// ---------------------------------------------------------------------------

/// Chip labels shared by the Analisis tab bar and the copy around it.
const List<String> periodTabLabels = [
  'Minggu Ini',
  'Bulan Ini',
  'Tahun Ini',
  'Rentang Kustom',
];

const int kCustomPeriodIndex = 3;

PeriodKind kindForIndex(int index) =>
    index >= kCustomPeriodIndex ? PeriodKind.custom : PeriodKind.values[index];

/// Resolves the active period chip into a concrete day range.
DateRange rangeFor(
  PeriodKind kind,
  DateTimeRange? custom, {
  DateTime? now,
}) {
  final DateTime n = now ?? DateTime.now();
  switch (kind) {
    case PeriodKind.week:
      return DateRange(startOfWeek(n), endOfDay(n));
    case PeriodKind.month:
      final DateTime start = startOfMonth(n);
      final DateTime end = DateTime(start.year, start.month + 1, 0);
      return DateRange(start, endOfDay(end.isAfter(n) ? n : end));
    case PeriodKind.year:
      final DateTime start = startOfYear(n);
      final DateTime end = DateTime(n.year, 12, 31);
      return DateRange(start, endOfDay(end.isAfter(n) ? n : end));
    case PeriodKind.custom:
      if (custom == null) {
        return DateRange(startOfMonth(n), endOfDay(n));
      }
      return custom.start.isAfter(custom.end)
          ? DateRange(startOfDay(custom.end), endOfDay(custom.start))
          : DateRange(startOfDay(custom.start), endOfDay(custom.end));
  }
}

/// Chip caption: the plain label for presets, the picked dates for custom.
String periodLabelFor(PeriodKind kind, DateTimeRange? custom) {
  if (kind != PeriodKind.custom) return periodTabLabels[kind.index];
  if (custom == null) return periodTabLabels[kCustomPeriodIndex];
  return '${formatDateDMY(custom.start)} - ${formatDateDMY(custom.end)}';
}

// ---------------------------------------------------------------------------
// Beranda figures
// ---------------------------------------------------------------------------

/// Headline figure shown on Beranda for the running month.
int monthExpenseOf(List<Transaction> transactions, {DateTime? now}) {
  final DateTime n = now ?? DateTime.now();
  final DateTime start = startOfMonth(n);
  return transactions
      .where((Transaction t) => t.date != null && !t.date!.isBefore(start))
      .fold(0, (int sum, Transaction t) => sum + t.amount);
}

int todayExpenseOf(List<Transaction> transactions, {DateTime? now}) {
  final DateTime today = startOfDay(now ?? DateTime.now());
  return transactions
      .where((Transaction t) => t.date != null && startOfDay(t.date!) == today)
      .fold(0, (int sum, Transaction t) => sum + t.amount);
}

/// Average spend per elapsed day of the running month.
int averagePerDayOf(List<Transaction> transactions, {DateTime? now}) {
  final DateTime n = now ?? DateTime.now();
  final int days = n.difference(startOfMonth(n)).inDays + 1;
  return monthExpenseOf(transactions, now: n) ~/ (days < 1 ? 1 : days);
}
