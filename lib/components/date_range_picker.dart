import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/finance.dart';

/// Neo-brutalist range picker: pick a start day, then an end day. Navigation
/// uses chevron blocks; a selected range paints every day between the two
/// anchors so the span is obvious at a glance.
///
/// Returns null when dismissed. The caller normalises a reversed pick.
Future<DateTimeRange?> showNeoRangePicker(
  BuildContext context, {
  required DateTime initialStart,
  required DateTime initialEnd,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: BColors.onSurface.withValues(alpha: 0.55),
    builder: (BuildContext context) => _NeoRangePickerSheet(
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

enum _Step { pickStart, pickEnd }

class _NeoRangePickerSheet extends StatefulWidget {
  const _NeoRangePickerSheet(
      {required this.initialStart, required this.initialEnd});

  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_NeoRangePickerSheet> createState() => _NeoRangePickerSheetState();
}

class _NeoRangePickerSheetState extends State<_NeoRangePickerSheet> {
  late DateTime _visibleMonth;
  late DateTime _start;
  late DateTime _end;
  _Step _step = _Step.pickStart;

  @override
  void initState() {
    super.initState();
    _start = startOfDay(widget.initialStart);
    _end = startOfDay(widget.initialEnd);
    if (_end.isBefore(_start)) _end = _start;
    _visibleMonth = DateTime(_start.year, _start.month);
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  /// A tap either anchors the start or closes the span, then re-arms the next
  /// tap to start a fresh range.
  void _onDayTap(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_step == _Step.pickStart) {
        _start = day;
        _end = day;
        _step = _Step.pickEnd;
      } else {
        if (day.isBefore(_start)) {
          _start = day;
        } else {
          _end = day;
          _step = _Step.pickStart;
        }
      }
    });
  }

  bool _inSpan(DateTime day) {
    final DateTime lower = _start.isBefore(_end) ? _start : _end;
    final DateTime upper = _start.isBefore(_end) ? _end : _start;
    return !day.isBefore(lower) && !day.isAfter(upper);
  }

  bool _isEdge(DateTime day) => day == _start || day == _end;

  void _apply() {
    final DateTime lower = _start.isBefore(_end) ? _start : _end;
    final DateTime upper = _start.isBefore(_end) ? _end : _start;
    Navigator.of(context).pop(DateTimeRange(start: lower, end: upper));
  }

  void _preset(int days) {
    HapticFeedback.selectionClick();
    final DateTime today = startOfDay(DateTime.now());
    setState(() {
      _start = today.subtract(Duration(days: days - 1));
      _end = today;
      _step = _Step.pickEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int spanDays =
        startOfDay(_end).difference(startOfDay(_start)).inDays + 1;

    return Container(
      decoration: const BoxDecoration(
        color: BColors.surface,
        border: Border(
            top: BorderSide(color: BColors.outline, width: BBorder.thick)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BSpace.margin,
              BSpace.lg,
              BSpace.margin,
              BSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    color: BColors.outline,
                  ),
                ),
                const SizedBox(height: BSpace.lg),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'PILIH RENTANG KUSTOM',
                        style: TextStyle(
                          fontFamily: BFont.headline,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.15,
                          color: BColors.onSurface,
                        ),
                      ),
                    ),
                    _IconBlock(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: BSpace.sm),
                Text(
                  _step == _Step.pickStart
                      ? 'Ketuk tanggal mulai. Semua catatan setelahnya ikut dihitung.'
                      : 'Ketuk tanggal selesai. Ketuk tanggal yang lebih awal untuk menggeser tanggal mulai.',
                  style: BText.bodySmall.copyWith(fontSize: 12),
                ),
                const SizedBox(height: BSpace.md),
                _SelectedSummary(
                  start: _start,
                  end: _end,
                  spanDays: spanDays,
                  step: _step,
                ),
                const SizedBox(height: BSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconBlock(
                      icon: Icons.chevron_left,
                      onTap: () => _shiftMonth(-1),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${monthLong(_visibleMonth)} ${_visibleMonth.year}',
                          style: BText.h2,
                        ),
                      ),
                    ),
                    _IconBlock(
                      icon: Icons.chevron_right,
                      onTap: () => _shiftMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: BSpace.md),
                _MonthGrid(
                  month: _visibleMonth,
                  isInSpan: _inSpan,
                  isEdge: _isEdge,
                  onTap: _onDayTap,
                ),
                const SizedBox(height: BSpace.md),
                Row(
                  children: [
                    for (final ({String label, int days}) p in const [
                      (label: '7 HARI', days: 7),
                      (label: '30 HARI', days: 30),
                      (label: '90 HARI', days: 90),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: BSpace.sm),
                        child: _PresetChip(
                          label: p.label,
                          onTap: () => _preset(p.days),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: BSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: _BlockButton(
                        label: 'BATAL',
                        background: BColors.surfaceContainerLowest,
                        foreground: BColors.onSurface,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: BSpace.sm),
                    Expanded(
                      flex: 2,
                      child: _BlockButton(
                        label: 'TERAPKAN RENTANG',
                        background: BColors.primary,
                        foreground: BColors.primaryContainer,
                        onTap: _apply,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({
    required this.start,
    required this.end,
    required this.spanDays,
    required this.step,
  });

  final DateTime? start;
  final DateTime? end;
  final int spanDays;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BSpace.md),
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLowest,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        boxShadow: BShadow.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MULAI',
                  style:
                      BText.labelTiny.copyWith(color: BColors.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  start == null ? '-' : formatDateDMY(start!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BText.h3.copyWith(
                    fontSize: 14,
                    color: step == _Step.pickStart
                        ? BColors.primary
                        : BColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: BBorder.thick,
            height: 34,
            color: BColors.outline,
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_forward,
                size: 16, color: BColors.primaryContainer),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELESAI',
                  style:
                      BText.labelTiny.copyWith(color: BColors.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  end == null ? '-' : formatDateDMY(end!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BText.h3.copyWith(
                    fontSize: 14,
                    color: step == _Step.pickEnd
                        ? BColors.primary
                        : BColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.isInSpan,
    required this.isEdge,
    required this.onTap,
  });

  final DateTime month;
  final bool Function(DateTime) isInSpan;
  final bool Function(DateTime) isEdge;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime first = DateTime(month.year, month.month);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first offset.
    final int leading = first.weekday - 1;
    final int cells = leading + daysInMonth;
    final int rows = (cells / 7).ceil();
    final DateTime today = startOfDay(DateTime.now());

    const List<String> headers = <String>[
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
      'Min'
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final String h in headers)
              Expanded(
                child: Center(
                  child: Text(
                    h.toUpperCase(),
                    style: BText.labelTiny.copyWith(
                      color: BColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (int row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (int col = 0; col < 7; col++)
                  Expanded(
                      child: _dayCell(
                          first, leading, daysInMonth, row, col, today)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(
    DateTime first,
    int leading,
    int daysInMonth,
    int row,
    int col,
    DateTime today,
  ) {
    final int dayNumber = row * 7 + col - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 38);
    }

    final DateTime day = DateTime(first.year, first.month, dayNumber);
    final bool edge = isEdge(day);
    final bool span = isInSpan(day);
    final bool isToday = day == today;

    Color background;
    Color foreground;
    if (edge) {
      background = BColors.primary;
      foreground = BColors.primaryContainer;
    } else if (span) {
      background = BColors.primaryContainer;
      foreground = BColors.onSurface;
    } else {
      background = BColors.surfaceContainerLowest;
      foreground = BColors.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => onTap(day),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: isToday ? BColors.secondary : BColors.outline,
              width: BBorder.thin,
            ),
            boxShadow: edge ? BShadow.sm : const <BoxShadow>[],
          ),
          child: Text(
            '$dayNumber',
            style: BText.amountMd.copyWith(
              fontSize: 12,
              color: foreground,
              fontWeight: edge ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBlock extends StatelessWidget {
  const _IconBlock({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BColors.surfaceContainerLowest,
          border: Border.all(color: BColors.outline, width: BBorder.thick),
          boxShadow: BShadow.sm,
        ),
        child: Icon(icon, size: 20, color: BColors.onSurface),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: BColors.surfaceContainerLowest,
          border: Border.all(color: BColors.outline, width: BBorder.thin),
          boxShadow: BShadow.sm,
        ),
        child: Text(
          label,
          style: BText.label.copyWith(fontSize: 11, letterSpacing: 0.6),
        ),
      ),
    );
  }
}

class _BlockButton extends StatelessWidget {
  const _BlockButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? background : BColors.surfaceContainer,
          border: Border.all(color: BColors.outline, width: BBorder.thick),
          boxShadow: BShadow.md,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BText.label.copyWith(
            color: active ? foreground : BColors.onSurfaceVariant,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
