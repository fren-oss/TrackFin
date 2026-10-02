import 'package:flutter/material.dart';

/// Icon mapping from the Material Symbols names used in the HTML designs to
/// the equivalent built-in Flutter Material icons. Avoids shipping a
/// variable icon font and keeps the visual weight consistent.
IconData ms(String name) {
  switch (name) {
    case 'account_balance_wallet':
      return Icons.account_balance_wallet;
    case 'account_balance':
      return Icons.account_balance;
    case 'wallet':
      return Icons.wallet;
    case 'savings':
      return Icons.savings;
    case 'payments':
      return Icons.payments;
    case 'add_card':
      return Icons.add_card;
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_subway':
      return Icons.directions_subway;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'medical_services':
      return Icons.medical_services;
    case 'school':
      return Icons.school;
    case 'more_horiz':
      return Icons.more_horiz;
    case 'bolt':
      return Icons.bolt;
    case 'calendar_today':
      return Icons.calendar_today;
    case 'calendar_month':
      return Icons.calendar_month;
    case 'query_stats':
      return Icons.query_stats;
    case 'pie_chart':
      return Icons.pie_chart;
    case 'analytics':
      return Icons.analytics;
    case 'trending_up':
      return Icons.trending_up;
    case 'trending_down':
      return Icons.trending_down;
    case 'add':
      return Icons.add;
    case 'add_circle':
      return Icons.add_circle;
    case 'check_circle':
      return Icons.check_circle;
    case 'check':
      return Icons.check;
    case 'task_alt':
      return Icons.task_alt;
    case 'edit':
      return Icons.edit;
    case 'edit_note':
      return Icons.edit_note;
    case 'backspace':
      return Icons.backspace_outlined;
    case 'visibility':
      return Icons.visibility;
    case 'visibility_off':
      return Icons.visibility_off;
    case 'notifications':
      return Icons.notifications_none;
    case 'expand_more':
      return Icons.expand_more;
    case 'sort':
      return Icons.sort;
    case 'verified':
      return Icons.verified;
    case 'priority_high':
      return Icons.priority_high;
    case 'stars':
      return Icons.star;
    case 'insights':
      return Icons.insights;
    case 'tips_and_updates':
      return Icons.tips_and_updates;
    case 'photo_camera':
      return Icons.photo_camera;
    case 'attach_file':
      return Icons.attach_file;
    case 'warning':
      return Icons.warning;
    case 'progress_activity':
      return Icons.autorenew;
    case 'refresh':
      return Icons.refresh;
    case 'delete':
      return Icons.delete_outline;
    case 'delete_forever':
      return Icons.delete_forever_outlined;
    case 'event':
      return Icons.event;
    case 'settings':
      return Icons.settings_outlined;
    case 'key':
      return Icons.key;
    case 'chevron_left':
      return Icons.chevron_left;
    case 'chevron_right':
      return Icons.chevron_right;
    case 'arrow_upward':
      return Icons.arrow_upward;
    case 'arrow_downward':
      return Icons.arrow_downward;
    case 'swap_horiz':
      return Icons.swap_horiz;
    case 'inbox':
      return Icons.inbox_outlined;
    case 'flag':
      return Icons.flag_outlined;
    default:
      return Icons.circle;
  }
}

/// Accent colours cycled through for category slices so the donut always has
/// enough distinct segments. Kept in sync with [BColorsTint].
const List<Color> kSlicePalette = [
  Color(0xFF1A1A1A), // primary / near-black
  Color(0xFFE63B2E), // secondary / accent red
  Color(0xFF0055FF), // tertiary / accent blue
  Color(0xFFFFCC00), // primaryContainer / yellow
  Color(0xFF4A4A4A), // onSurfaceVariant
  Color(0xFFA8C6FF), // tertiaryFixedDim
  Color(0xFFFFB3AB), // secondaryFixedDim
  Color(0xFFD0CBC3), // outlineVariant
];

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.icon,
    required this.accent,
    this.isPrimary = false,
    this.isSource = false,
  });

  final String id;
  final String name;
  final int balance;
  final String icon;

  /// Card accent for the wallet list tile.
  final Color accent;
  final bool isPrimary;
  final bool isSource;

  Wallet copyWith({
    int? balance,
    bool? isSource,
    String? name,
    String? icon,
    Color? accent,
    bool? isPrimary,
  }) {
    return Wallet(
      id: id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      accent: accent ?? this.accent,
      isPrimary: isPrimary ?? this.isPrimary,
      isSource: isSource ?? this.isSource,
    );
  }
}

class Category {
  const Category(this.id, this.label, this.icon);

  final String id;
  final String label;
  final String icon;

  /// Longer form used on the Analisis breakdown rows, where the tile has room.
  String get longLabel => switch (id) {
        'makanan' => 'Makanan & Minuman',
        'transport' => 'Transportasi',
        'belanja' => 'Belanja Kebutuhan',
        'hiburan' => 'Hiburan',
        'tagihan' => 'Tagihan & Langganan',
        'kesehatan' => 'Kesehatan',
        'pendidikan' => 'Edukasi',
        _ => 'Lainnya',
      };
}

/// One recorded expense. [date] is the source of truth for every date-based
/// figure in the app; [time] and [dayHeader] are display helpers only.
class Transaction {
  const Transaction({
    required this.title,
    required this.walletName,
    required this.time,
    required this.amount,
    required this.categoryLabel,
    required this.icon,
    required this.accent,
    required this.id,
    this.dayHeader,
    this.categoryId,
    this.walletId,
    this.date,
  });

  /// Stable row key. Sheets upserts on this, so a record keeps one row no
  /// matter how many times it is re-synced.
  final String id;

  final String title;
  final String walletName;
  final String time;
  final int amount;
  final String categoryLabel;
  final String icon;
  final Color accent;

  /// Non-null when this row should render a date divider above it.
  final String? dayHeader;
  final String? categoryId;

  /// Set by [AppState] so a wallet can be deleted together with its rows.
  final String? walletId;

  /// Actual timestamp the expense was recorded at. Required for the Analisis
  /// week / month / year / custom-range filtering to work at all.
  final DateTime? date;

  Transaction copyWith({
    String? title,
    String? walletName,
    int? amount,
    Color? accent,
    DateTime? date,
    String? categoryId,
    String? walletId,
  }) {
    return Transaction(
      id: id,
      title: title ?? this.title,
      walletName: walletName ?? this.walletName,
      time: time,
      amount: amount ?? this.amount,
      categoryLabel: categoryLabel,
      icon: icon,
      accent: accent ?? this.accent,
      dayHeader: dayHeader,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      date: date ?? this.date,
    );
  }
}

class WeeklyPoint {
  const WeeklyPoint(this.label, this.amount, this.heightPct, this.isPeak);

  final String label;
  final int amount;
  final double heightPct;
  final bool isPeak;
}

class CategorySlice {
  const CategorySlice(
    this.name,
    this.amount,
    this.count,
    this.pct,
    this.color,
    this.icon,
  );

  final String name;
  final int amount;
  final int count;
  final double pct;
  final Color color;
  final String icon;
}

/// Formats an integer as Indonesian rupiah with dot thousands separators.
String formatIDR(num value) {
  final int v = value.round();
  final String digits = v.abs().toString();
  final StringBuffer out = StringBuffer(v < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Compact form used on chart axis labels, e.g. 1290000 -> "1.290k".
String formatCompact(num value) {
  final int v = value.round();
  if (v >= 1000000) {
    final double m = v / 1000000;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}jt';
  }
  if (v >= 1000) {
    final double k = v / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
  }
  return v.toString();
}

// ---------------------------------------------------------------------------
// Date helpers — everything the Analisis screen needs to bucket expenses.
// ---------------------------------------------------------------------------

const List<String> _dayNames = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min'
];
const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const List<String> _monthNamesLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String dayShort(DateTime d) => _dayNames[d.weekday - 1];
String monthShort(DateTime d) => _monthNames[d.month - 1];
String monthLong(DateTime d) => _monthNamesLong[d.month - 1];

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Monday 00:00 of the week containing [d] (Indonesian weeks start on Monday).
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// First day of the month containing [d].
DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

/// First day of the year containing [d].
DateTime startOfYear(DateTime d) => DateTime(d.year);

/// `dd MMM yyyy`, e.g. "1 Jan 2026".
String formatDateDMY(DateTime d) => '${d.day} ${monthShort(d)} ${d.year}';

/// `dd MMM yyyy, HH.mm`, used on the transaction rows.
String formatDateTimeDMY(DateTime d) =>
    '${formatDateDMY(d)}, ${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

/// "Hari ini" / "Kemarin" / "3 Okt" — the divider above a group of rows.
String dayHeaderLabel(DateTime d, {DateTime? now}) {
  final DateTime today = startOfDay(now ?? DateTime.now());
  final DateTime day = startOfDay(d);
  final int diff = today.difference(day).inDays;
  if (diff == 0) return 'Hari ini, ${formatDateDMY(day)}';
  if (diff == 1) return 'Kemarin, ${formatDateDMY(day)}';
  return formatDateDMY(day);
}
