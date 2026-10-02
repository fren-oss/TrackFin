import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/date_range_picker.dart';
import '../components/neo.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/finance.dart';
import '../state/analytics.dart';
import '../state/app_state.dart';

class AnalisisScreen extends StatelessWidget {
  const AnalisisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final Analytics data = state.analytics;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BSpace.margin,
        BSpace.sm,
        BSpace.margin,
        BSpace.xl,
      ),
      children: [
        _PeriodTabs(
          index: state.periodTab,
          range: state.activeRange,
          hasCustom: state.customRange != null,
          onSelect: (int i) => _selectPeriod(context, state, i),
        ),
        const SizedBox(height: BSpace.sm),
        _RangeCaption(range: state.activeRange, count: data.count),
        const SizedBox(height: BSpace.md),
        _TotalCard(data: data, kind: state.periodKind),
        const SizedBox(height: BSpace.lg),
        _TrendCard(data: data),
        const SizedBox(height: BSpace.lg),
        _DistributionCard(
            data: data,
            sortOrder: state.categorySortOrder,
            onSort: state.setCategorySortOrder),
        const SizedBox(height: BSpace.md),
        _InsightCard(data: data),
      ],
    );
  }

  /// Presets just move the chip; the custom chip opens the date picker so the
  /// range is actually chosen rather than silently falling back to this month.
  Future<void> _selectPeriod(
      BuildContext context, AppState state, int index) async {
    HapticFeedback.selectionClick();

    if (index != kCustomPeriodIndex) {
      state.setPeriodTab(index);
      return;
    }

    final DateRange current = state.activeRange;
    final DateTimeRange? picked = await showNeoRangePicker(
      context,
      initialStart: state.customRange?.start ?? current.start,
      initialEnd: state.customRange?.end ?? current.end,
    );
    if (picked == null) return;
    state.setCustomRange(picked);
  }
}

/// Scrollable period selector. The active chip fills yellow and grows its
/// shadow; the custom-range chip carries a calendar icon and echoes the picked
/// dates once a range exists.
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({
    required this.index,
    required this.range,
    required this.hasCustom,
    required this.onSelect,
  });

  final int index;
  final DateRange range;
  final bool hasCustom;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periodTabLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: BSpace.sm),
        itemBuilder: (BuildContext context, int i) {
          final bool active = i == index;
          final bool isRange = i == kCustomPeriodIndex;
          return NeoButton(
            onTap: () => onSelect(i),
            background: active
                ? BColors.primaryContainer
                : BColors.surfaceContainerLowest,
            foreground: BColors.primary,
            shadow: BShadow.sm,
            borderRadius: BRadius.sm,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (isRange && hasCustom ? range.label : periodTabLabels[i])
                      .toUpperCase(),
                  style: BText.label.copyWith(
                    color: BColors.primary,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                if (isRange) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_month,
                      size: 16, color: BColors.primary),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The exact day span behind the selected chip, so the numbers are never
/// ambiguous about what they cover.
class _RangeCaption extends StatelessWidget {
  const _RangeCaption({required this.range, required this.count});

  final DateRange range;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event, size: 14, color: BColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            range.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BText.bodySmall
                .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '$count catatan',
          style: BText.labelTiny
              .copyWith(color: BColors.onSurfaceVariant, fontSize: 10),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.data, required this.kind});

  final Analytics data;
  final PeriodKind kind;

  static const Map<PeriodKind, String> _headings = <PeriodKind, String>{
    PeriodKind.week: 'TOTAL PENGELUARAN MINGGU INI',
    PeriodKind.month: 'TOTAL PENGELUARAN BULAN INI',
    PeriodKind.year: 'TOTAL PENGELUARAN TAHUN INI',
    PeriodKind.custom: 'TOTAL PENGELUARAN RENTANG KUSTOM',
  };

  @override
  Widget build(BuildContext context) {
    final double? change = data.changePct;
    final bool hasBaseline = change != null && data.previousTotal > 0;

    return NeoCard(
      padding: const EdgeInsets.all(BSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _headings[kind]!,
                  style: const TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    height: 1.2,
                    color: BColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: BSpace.sm),
              if (hasBaseline)
                NeoTag(
                  text: '${data.isSaving ? 'Hemat' : 'Naik'} '
                      '${change.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
                  icon: data.isSaving ? Icons.trending_down : Icons.trending_up,
                  fontSize: 12,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                )
              else
                const NeoTag(
                  text: 'Belum ada pembanding',
                  background: BColors.surfaceContainer,
                  foreground: BColors.onSurfaceVariant,
                  fontSize: 12,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
            ],
          ),
          const SizedBox(height: BSpace.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Rp',
                    style: BText.h1
                        .copyWith(color: BColors.onSurface, fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  formatIDR(data.total),
                  style: BText.amountDisplay.copyWith(fontSize: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: BSpace.sm),
          Container(
            padding: const EdgeInsets.only(top: BSpace.sm),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: BColors.primary.withValues(alpha: 0.1),
                  width: BBorder.thick,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasBaseline
                            ? 'Dibanding periode lalu (Rp ${formatIDR(data.previousTotal)})'
                            : 'Belum ada pengeluaran di periode sebelumnya',
                        style: BText.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: BSpace.sm),
                    NeoTag(
                      text: data.isSaving ? 'Hemat' : 'Naik',
                      background: data.isSaving
                          ? BColors.surfaceContainer
                          : BColors.errorContainer,
                      foreground:
                          data.isSaving ? BColors.primary : BColors.error,
                      icon:
                          data.isSaving ? Icons.verified : Icons.priority_high,
                      fontSize: 12,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ],
                ),
                const SizedBox(height: BSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'RATA-RATA / HARI',
                        value: 'Rp ${formatIDR(data.averagePerDay)}',
                      ),
                    ),
                    const SizedBox(width: BSpace.sm),
                    Expanded(
                      child: _MiniStat(
                        label: 'PER CATATAN',
                        value: 'Rp ${formatIDR(data.averagePerEntry)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLow,
        border: Border.all(color: BColors.outline, width: BBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BText.labelTiny.copyWith(
              color: BColors.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: BText.amountMd.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Trend bar chart. Buckets come from [Analytics.buckets] — daily for a week,
/// weekly for a couple of months, monthly for a year or longer — so the bars
/// always reflect the selected range.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});

  final Analytics data;

  @override
  Widget build(BuildContext context) {
    final TrendBucket? peak = data.peak;

    return NeoCard(
      padding: const EdgeInsets.all(BSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TREN PENGELUARAN',
                      style: TextStyle(
                        fontFamily: BFont.headline,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.15,
                        color: BColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.range.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: BFont.body,
                        fontSize: 12,
                        color: BColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BSpace.sm),
              if (peak != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BColors.secondary.withValues(alpha: 0.1),
                    border:
                        Border.all(color: BColors.outline, width: BBorder.thin),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 10, height: 10, color: BColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Puncak Tertinggi',
                        style: BText.label
                            .copyWith(fontSize: 12, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: BSpace.md),
          if (data.isEmpty)
            const _ChartEmpty(message: 'Belum ada pengeluaran di periode ini')
          else
            Container(
              padding: const EdgeInsets.only(top: BSpace.sm, bottom: 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: BColors.outline, width: BBorder.thick),
                ),
              ),
              child: SizedBox(
                height: 186,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final TrendBucket b in data.buckets)
                      Expanded(child: _Bar(bucket: b)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: BSpace.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BColors.surfaceContainer,
              border: Border.all(color: BColors.outline, width: BBorder.thin),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Rata-rata pengeluaran harian',
                        style: TextStyle(
                          fontFamily: BFont.body,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: BColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Rp ${formatIDR(data.averagePerDay)}',
                      style: BText.amountMd.copyWith(fontSize: 15),
                    ),
                  ],
                ),
                if (peak != null) ...[
                  const SizedBox(height: BSpace.sm),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Puncak',
                          style: TextStyle(
                            fontFamily: BFont.body,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: BColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${peak.label} · Rp ${formatIDR(peak.amount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: BText.amountMd.copyWith(
                            fontSize: 13,
                            color: BColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bucket});

  final TrendBucket bucket;

  static const double _plotHeight = 186;
  static const double _labelZone = 22;
  static const double _xAxisZone = 28;

  @override
  Widget build(BuildContext context) {
    // Reserve headroom above the tallest bar for the value label, and extra
    // headroom for the peak bar's flag.
    const double available = _plotHeight - _labelZone - _xAxisZone;
    final double barHeight = math.max(6, available * bucket.heightPct);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: _labelZone,
          child: bucket.isPeak
              ? Transform.translate(
                  offset: const Offset(0, 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: BColors.secondary,
                      border: Border.all(
                          color: BColors.outline, width: BBorder.thin),
                      boxShadow: BShadow.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high,
                            size: 10, color: BColors.onPrimary),
                        const SizedBox(width: 2),
                        Text(
                          'PEAK',
                          style: BText.labelTiny.copyWith(
                            color: BColors.onPrimary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: bucket.amount == 0
                      ? Text(
                          '-',
                          style: BText.amountSm.copyWith(fontSize: 11),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCompact(bucket.amount),
                            style: BText.amountSm.copyWith(
                              color: BColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
        ),
        const SizedBox(height: 6),
        Container(
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: bucket.isPeak
                ? BColors.secondary
                : BColors.surfaceContainerHigh,
            border: Border.all(color: BColors.outline, width: BBorder.thick),
          ),
        ),
        const SizedBox(height: BSpace.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            bucket.label.toUpperCase(),
            style: BText.label.copyWith(
              fontSize: 11,
              color: bucket.isPeak ? BColors.secondary : BColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.data,
    required this.sortOrder,
    required this.onSort,
  });

  final Analytics data;
  final CategorySort sortOrder;
  final ValueChanged<CategorySort> onSort;

  @override
  Widget build(BuildContext context) {
    final List<CategorySlice> slices = switch (sortOrder) {
      CategorySort.amount => data.slices,
      CategorySort.count => (List<CategorySlice>.of(data.slices)
        ..sort(
            (CategorySlice a, CategorySlice b) => b.count.compareTo(a.count))),
      CategorySort.name => (List<CategorySlice>.of(data.slices)
        ..sort((CategorySlice a, CategorySlice b) => a.name.compareTo(b.name))),
    };

    final CategorySlice? top = data.topSlice;

    return NeoCard(
      padding: const EdgeInsets.all(BSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISTRIBUSI KATEGORI',
                      style: TextStyle(
                        fontFamily: BFont.headline,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.15,
                        color: BColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.slices.isEmpty
                          ? 'Belum ada kategori'
                          : 'Berdasarkan ${data.slices.length} kategori pengeluaran',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: BFont.body,
                        fontSize: 12,
                        color: BColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BSpace.sm),
              NeoButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSort(CategorySort.values[
                      (sortOrder.index + 1) % CategorySort.values.length]);
                },
                background: BColors.surfaceContainer,
                foreground: BColors.primary,
                shadow: BShadow.sm,
                borderRadius: BRadius.sm,
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.sort, size: 18, color: BColors.primary),
              ),
            ],
          ),
          const SizedBox(height: BSpace.md),
          Center(
            child: SizedBox(
              width: 192,
              height: 192,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(192),
                    painter: _DonutPainter(slices: data.slices),
                  ),
                  if (top != null)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TERBESAR'.toUpperCase(),
                          style: BText.labelWide.copyWith(
                            color: BColors.onSurfaceVariant,
                            fontSize: 10,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(top.pct * 100).round()}%',
                          style: BText.amountDisplay
                              .copyWith(fontSize: 26, height: 1.05),
                        ),
                        Text(
                          top.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: BText.labelWide.copyWith(
                            color: BColors.primary,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '0%',
                      style: BText.amountDisplay
                          .copyWith(fontSize: 26, height: 1.05),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: BSpace.lg),
          if (slices.isEmpty)
            const _ChartEmpty(message: 'Diagram muncul setelah ada pengeluaran')
          else
            for (final CategorySlice s in slices)
              Padding(
                padding: const EdgeInsets.only(bottom: BSpace.md),
                child: _CategoryBreakdown(slice: s),
              ),
        ],
      ),
    );
  }
}

/// Shared "nothing here yet" block so every chart degrades the same way.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: BSpace.xl, horizontal: BSpace.md),
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLow,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        boxShadow: BShadow.sm,
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              size: 28, color: BColors.onSurfaceVariant),
          const SizedBox(height: BSpace.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: BText.bodySmall
                .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            'Catat pengeluaran lewat menu + Catat Keluar',
            textAlign: TextAlign.center,
            style: BText.labelTiny.copyWith(
              color: BColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<CategorySlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 16;
    const double stroke = 14;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = BColors.surfaceContainer,
    );

    if (slices.isEmpty) return;

    // Segments, starting at 12 o'clock and sweeping clockwise.
    double startAngle = -math.pi / 2;
    for (final CategorySlice s in slices) {
      final double sweep = s.pct * 2 * math.pi;
      canvas.drawArc(
        rect,
        startAngle,
        math.max(sweep - 0.02, 0.005),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => oldDelegate.slices != slices;
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.slice});

  final CategorySlice slice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BSpace.sm),
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLow,
        border: Border.all(
          color: BColors.primary.withValues(alpha: 0.2),
          width: BBorder.thin,
        ),
        borderRadius: BorderRadius.circular(BRadius.sm),
      ),
      child: Column(
        children: [
          Row(
            children: [
              NeoIconTile(
                icon: ms(slice.icon),
                background: slice.color,
                foreground: slice.color.computeLuminance() > 0.5
                    ? BColors.onSurface
                    : BColors.onPrimary,
                size: 32,
                iconSize: 18,
                borderWidth: BBorder.thin,
                shadow: const <BoxShadow>[],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        slice.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BText.h3.copyWith(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${slice.count}x)',
                      style: BText.bodySmall.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Amount and share are the two right-hand columns; let the share
              // shrink before the amount so the row never overflows.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text('Rp ${formatIDR(slice.amount)}',
                      style: BText.amountMd),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${(slice.pct * 100).round()}%',
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: BText.label.copyWith(
                    fontSize: 12,
                    color: slice.color.computeLuminance() > 0.5
                        ? BColors.onSurface
                        : slice.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          NeoProgressBar(
            value: slice.pct,
            color: slice.color,
            height: 8,
          ),
        ],
      ),
    );
  }
}

/// Plain-language read-out of whatever the data says. Every number here comes
/// from [Analytics], so the copy can never drift from the chart above it.
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.data});

  final Analytics data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return NeoCard(
        background: BColors.surfaceContainerLow,
        padding: const EdgeInsets.all(BSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InsightHeading(),
            const SizedBox(height: BSpace.sm),
            Text(
              'Belum ada catatan pada ${data.range.label}. '
              'Tambahkan pengeluaran dulu, lalu insight ini akan otomatis berubah.',
              style: BText.body.copyWith(
                  fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
            ),
          ],
        ),
      );
    }

    final CategorySlice top = data.topSlice!;
    final TrendBucket? peak = data.peak;

    return NeoCard(
      background: BColors.surfaceContainerLow,
      padding: const EdgeInsets.all(BSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InsightHeading(),
          const SizedBox(height: BSpace.sm),
          Text.rich(
            TextSpan(
              text: 'Pengeluaran terbesar pada periode ini adalah kategori ',
              children: <InlineSpan>[
                TextSpan(
                  text: top.name,
                  style: const TextStyle(
                    backgroundColor: BColors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' sebesar '),
                TextSpan(
                  text: 'Rp ${formatIDR(top.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' dari '),
                TextSpan(
                  text: '${data.count} catatan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationThickness: 2,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            style: const TextStyle(
              fontFamily: BFont.body,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: BColors.onSurface,
            ),
          ),
          const SizedBox(height: BSpace.sm),
          Text.rich(
            TextSpan(
              text: 'Rata-rata ',
              children: <InlineSpan>[
                TextSpan(
                  text: 'Rp ${formatIDR(data.averagePerDay)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' per hari'),
                if (peak != null) ...<InlineSpan>[
                  const TextSpan(text: ', puncak pengeluaran di '),
                  TextSpan(
                    text: peak.label.toLowerCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' ('),
                  TextSpan(
                    text: peak.detail,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ')'),
                ],
                const TextSpan(text: '.'),
              ],
            ),
            style: const TextStyle(
              fontFamily: BFont.body,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: BColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: BSpace.sm),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: BColors.primary.withValues(alpha: 0.2),
                  width: BBorder.thin,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates,
                    size: 18, color: BColors.secondary),
                const SizedBox(width: BSpace.sm),
                Expanded(
                  child: Text(
                    _tip(),
                    style: BText.bodySmall.copyWith(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One concrete, data-derived suggestion.
  String _tip() {
    final double? change = data.changePct;
    if (data.isSaving) {
      return 'Bagus! Pengeluaran periode ini ${change!.abs().toStringAsFixed(0)}% lebih rendah '
          'dibanding periode sebelumnya. Pertahankan ritmenya.';
    }
    if (change != null) {
      return 'Pengeluaran naik ${change.toStringAsFixed(0)}% dari periode sebelumnya. '
          'Fokuskan kategori "${data.topSlice!.name}" karena porsi terbesar ada di sana.';
    }
    if (data.buckets.length > 1) {
      return 'Belum ada pembanding periode lalu. Catat pengeluaran secara rutin agar '
          'tren naik-turunnya bisa terlihat.';
    }
    return 'Tambahkan catatan pengeluaran agar tren dan distribusi kategori bisa dihitung.';
  }
}

class _InsightHeading extends StatelessWidget {
  const _InsightHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          color: BColors.primary,
          alignment: Alignment.center,
          child: const Icon(Icons.insights, size: 15, color: BColors.onPrimary),
        ),
        const SizedBox(width: 6),
        Text(
          'CATATAN CERDAS',
          style: BText.labelWide.copyWith(color: BColors.primary, fontSize: 12),
        ),
      ],
    );
  }
}
