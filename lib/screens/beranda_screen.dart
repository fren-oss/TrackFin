import 'package:flutter/material.dart';

import '../components/nav_scope.dart';
import '../components/neo.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/finance.dart';
import '../state/analytics.dart';
import '../state/app_state.dart';

class BerandaScreen extends StatelessWidget {
  const BerandaScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: BSpace.md),
        const _BalanceCard(),
        const SizedBox(height: BSpace.md),
        const _BudgetCard(),
        const SizedBox(height: BSpace.md),
        const _QuickStats(),
        const SizedBox(height: 20),
        const _RecentExpenses(),
        const SizedBox(height: BSpace.lg),
      ],
    );
  }
}

/// Month-over-month spending change, shown under the balance.
class _BalanceDelta {
  const _BalanceDelta(this.text, this.subtitle, this.spendingMore);

  final String text;
  final String subtitle;
  final bool spendingMore;
}

_BalanceDelta _balanceDelta(BuildContext context) {
  final AppState state = context.read<AppState>();
  final Analytics now = computeAnalytics(
    transactions: state.transactions,
    range: rangeFor(PeriodKind.month, null),
  );
  final double? pct = now.changePct;
  if (pct == null) {
    return const _BalanceDelta(
      'Bulan pertama',
      'belum ada pembanding bulan lalu',
      false,
    );
  }
  final String magnitude = pct.abs().toStringAsFixed(1).replaceAll('.', ',');
  return _BalanceDelta(
    pct >= 0 ? '+$magnitude%' : '-$magnitude%',
    pct >= 0 ? 'lebih banyak dari bulan lalu' : 'lebih hemat dari bulan lalu',
    pct >= 0,
  );
}

/// Black hero card: balance, month-over-month delta, two quick actions,
/// plus the eye toggle that masks the figure.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BSpace.margin),
      padding: const EdgeInsets.all(BSpace.lg),
      decoration: BoxDecoration(
        color: BColors.primary,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        borderRadius: BorderRadius.circular(BRadius.lg),
        boxShadow: BShadow.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: NeoTag(
                  text: 'Dompet & Kas Manual',
                  icon: Icons.account_balance_wallet,
                  fontSize: 12,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
              ),
              const SizedBox(width: BSpace.sm),
              _EyeToggle(
                visible: state.balanceVisible,
                onTap: state.toggleBalanceVisibility,
              ),
            ],
          ),
          const SizedBox(height: BSpace.md),
          Text(
            'TOTAL SALDO AKTIF',
            style: BText.labelWide.copyWith(
              color: BColors.surfaceContainer.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rp',
                  style: BText.labelWide.copyWith(
                    color: BColors.primaryContainer,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.balanceVisible
                      ? formatIDR(state.totalBalance)
                      : '•' * 10,
                  style: BText.amountDisplay.copyWith(
                    color: BColors.onPrimary,
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BSpace.sm),
          // Spending delta vs. last month, derived from the transaction list.
          Builder(
            builder: (BuildContext context) {
              final _BalanceDelta delta = _balanceDelta(context);
              return Row(
                children: [
                  NeoTag(
                    text: delta.text,
                    icon: delta.spendingMore
                        ? Icons.trending_up
                        : Icons.trending_down,
                    fontSize: 12,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      delta.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BText.bodySmall.copyWith(
                        color: BColors.surfaceContainerHigh,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: BSpace.md),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  onTap: () => NavScope.maybeOf(context)?.goTo(3),
                  background: BColors.surfaceContainerLowest,
                  foreground: BColors.primary,
                  shadow: BShadow.sm,
                  hoverBackground: BColors.surfaceBright,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: const _ActionLabel(
                    icon: Icons.account_balance_wallet,
                    label: 'Kelola Dompet',
                    color: BColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: BSpace.sm),
              Expanded(
                child: NeoButton(
                  onTap: () => NavScope.maybeOf(context)?.goTo(2),
                  background: BColors.primaryContainer,
                  foreground: BColors.onPrimaryContainer,
                  hoverBackground: const Color(0xFFFFD400),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: const _ActionLabel(
                    icon: Icons.add_circle,
                    label: '+ Catat Keluar',
                    color: BColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Icon + label that scales down rather than overflowing a narrow button.
class _ActionLabel extends StatelessWidget {
  const _ActionLabel(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: BFont.headline,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EyeToggle extends StatefulWidget {
  const _EyeToggle({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  State<_EyeToggle> createState() => _EyeToggleState();
}

class _EyeToggleState extends State<_EyeToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          transform: _pressed ? Matrix4.translationValues(2, 2, 0) : null,
          decoration: BoxDecoration(
            color: BColors.surfaceContainerLowest,
            border: Border.all(color: BColors.outline, width: BBorder.thick),
            boxShadow: BShadow.sm,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.visible ? Icons.visibility : Icons.visibility_off,
            size: 18,
            color: BColors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Budget summary: month spend vs. limit with a bordered progress bar.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final bool overBudget =
        state.budgetRemaining <= 0 && state.monthExpense > 0;
    final Color barColor = overBudget ? BColors.error : BColors.secondary;

    return NeoCard(
      margin: const EdgeInsets.symmetric(horizontal: BSpace.margin),
      padding: const EdgeInsets.all(BSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENGELUARAN ${monthLong(DateTime.now()).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BText.labelWide.copyWith(
                        color: BColors.onSurfaceVariant,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Rp',
                            style: BText.label.copyWith(
                              color: BColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatIDR(state.monthExpense),
                            style: BText.amountMd.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BSpace.sm),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'BATAS ANGGARAN',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BText.labelWide.copyWith(
                        color: BColors.onSurfaceVariant,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Tapping the limit opens a small editor so the target is
                    // never a magic number the user cannot change.
                    GestureDetector(
                      onTap: () => _editBudget(context, state),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Rp ${formatIDR(state.budgetLimit)}',
                                style: BText.amountMd,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 12,
                            color:
                                BColors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BSpace.sm),
          NeoProgressBar(
            value: state.budgetUsedFraction,
            color: barColor,
            height: 14,
            background: BColors.surfaceContainer,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: barColor),
              const SizedBox(width: 5),
              Text(
                '${state.budgetUsedPct}% Terpakai',
                style: BText.label.copyWith(color: barColor),
              ),
              const SizedBox(width: BSpace.sm),
              Expanded(
                child: Text(
                  overBudget
                      ? 'Lewat Rp ${formatIDR(state.monthExpense - state.budgetLimit)}'
                      : 'Sisa Rp ${formatIDR(state.budgetRemaining)}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BText.label.copyWith(color: BColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prompt for a new monthly budget limit.
Future<void> _editBudget(BuildContext context, AppState state) async {
  final int? value = await showDialog<int>(
    context: context,
    builder: (BuildContext context) => _BudgetDialog(limit: state.budgetLimit),
  );

  if (value != null) state.setBudgetLimit(value);
}

/// Owns its own controller so it is disposed with the dialog's State. Building
/// the controller in the caller and disposing it after `showDialog` returns
/// leaves the closing animation holding a disposed controller.
class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.limit});

  final int limit;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.limit}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = _controller;
    return AlertDialog(
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: BColors.outline, width: BBorder.thick),
        borderRadius: BorderRadius.all(Radius.circular(BRadius.md)),
      ),
      title: const Text('BATAS ANGGARAN BULANAN', style: BText.h2),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: BText.amountMd.copyWith(fontSize: 16),
        decoration: InputDecoration(
          prefixText: 'Rp ',
          prefixStyle: BText.label.copyWith(color: BColors.primary),
          filled: true,
          fillColor: BColors.surfaceContainerLowest,
          enabledBorder: const OutlineInputBorder(
            borderSide:
                BorderSide(color: BColors.outline, width: BBorder.thick),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide:
                BorderSide(color: BColors.primary, width: BBorder.thick),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BATAL',
              style: TextStyle(
                  fontFamily: BFont.headline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: BColors.onSurface)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            int.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                0,
          ),
          child: const Text('SIMPAN',
              style: TextStyle(
                  fontFamily: BFont.headline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: BColors.onSurface)),
        ),
      ],
    );
  }
}

/// Three compact tiles: today, daily average, largest category. All three read
/// from the running month so they move the moment an expense is saved.
class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final CategorySlice? top = state.monthTopSlice;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BSpace.margin),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.calendar_today,
              label: 'HARI INI',
              value: 'Rp ${formatIDR(state.todayExpense)}',
              note: state.todayExpense == 0 ? 'Belum ada' : 'Terkendali',
              noteColor: state.todayExpense == 0
                  ? BColors.onSurfaceVariant
                  : BColors.secondary,
            ),
          ),
          const SizedBox(width: BSpace.xs),
          Expanded(
            child: _StatTile(
              icon: Icons.query_stats,
              label: 'RATA-RATA/HR',
              value: 'Rp ${formatIDR(state.averagePerDay)}',
              note: 'Bulan ${monthShort(DateTime.now())}',
              noteColor: BColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: BSpace.xs),
          Expanded(
            child: _StatTile(
              icon: Icons.pie_chart,
              label: 'TERBESAR',
              value: top == null ? 'Belum ada' : top.name,
              note: top == null
                  ? 'Data kosong'
                  : '${(top.pct * 100).round()}% Porsi',
              noteColor:
                  top == null ? BColors.onSurfaceVariant : BColors.secondary,
              valueSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.noteColor,
    this.valueSize = 13,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color noteColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLowest,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        borderRadius: BorderRadius.circular(BRadius.md),
        boxShadow: BShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: BColors.onSurface),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      BText.labelTiny.copyWith(fontSize: 9, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: BText.amountMd.copyWith(fontSize: valueSize),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BText.labelTiny.copyWith(color: noteColor, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Recent expense rows, grouped by day with an uppercase divider.
class _RecentExpenses extends StatelessWidget {
  const _RecentExpenses();

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BSpace.margin),
          child: Row(
            children: [
              const Flexible(
                child: Text(
                  'Pengeluaran Terkini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    height: 1.2,
                    color: BColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: BSpace.sm),
              NeoTag(
                text: '${state.transactions.length} catatan',
                fontSize: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: BSpace.sm),
        if (state.transactions.isEmpty)
          _EmptyRecent(onTap: () => NavScope.maybeOf(context)?.goTo(2))
        else
          for (int i = 0; i < state.transactions.length; i++)
            _dayGroupedRow(state.transactions, i),
      ],
    );
  }
}

/// One transaction row, prefixed with a day divider when it is the first row
/// of its calendar day in the newest-first list.
Widget _dayGroupedRow(List<Transaction> all, int index) {
  final Transaction t = all[index];
  final DateTime? date = t.date;
  final bool opensGroup = date != null &&
      (index == 0 ||
          startOfDay(all[index - 1].date ?? date) != startOfDay(date));

  return Padding(
    padding:
        const EdgeInsets.fromLTRB(BSpace.margin, 0, BSpace.margin, BSpace.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (opensGroup) ...[
          const SizedBox(height: BSpace.xs),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              dayHeaderLabel(date).toUpperCase(),
              style: BText.labelWide.copyWith(
                color: BColors.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
        _TransactionRow(tx: t),
      ],
    ),
  );
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BSpace.margin),
      child: NeoCard(
        padding: const EdgeInsets.all(BSpace.lg),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BColors.primaryContainer,
                border:
                    Border.all(color: BColors.outline, width: BBorder.thick),
                boxShadow: BShadow.sm,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.receipt_long,
                  size: 20, color: BColors.primary),
            ),
            const SizedBox(height: BSpace.md),
            Text('Belum ada pengeluaran',
                style: BText.h2.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Catat pengeluaran pertamamu dan grafik Analisis langsung terisi.',
              textAlign: TextAlign.center,
              style: BText.bodySmall.copyWith(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: BSpace.md),
            NeoButton(
              onTap: onTap,
              background: BColors.primary,
              foreground: BColors.primaryContainer,
              shadow: BShadow.md,
              borderRadius: BRadius.md,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle,
                      size: 18, color: BColors.primaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    'CATAT PENGELUARAN',
                    style: BText.label.copyWith(
                      color: BColors.primaryContainer,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _confirmRemoveExpense(context, tx),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BColors.surfaceContainerLowest,
          border: Border.all(color: BColors.outline, width: BBorder.thick),
          borderRadius: BorderRadius.circular(BRadius.md),
          boxShadow: BShadow.sm,
        ),
        child: Row(
          children: [
            NeoIconTile(
              icon: ms(tx.icon),
              background: tx.accent,
              foreground: BColors.onSurface,
            ),
            const SizedBox(width: BSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BText.h3.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.walletName} • ${tx.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BText.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: BSpace.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-Rp ${formatIDR(tx.amount)}',
                    style: BText.amountMd.copyWith(
                      color: BColors.secondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tx.categoryLabel.toUpperCase(),
                    style: BText.labelTiny.copyWith(
                      color: BColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Long-press a row on Beranda to delete it. Names the amount and the wallet so
/// the user knows the balance will be credited back before they confirm.
Future<void> _confirmRemoveExpense(BuildContext context, Transaction tx) async {
  final AppState state = context.read<AppState>();
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: BColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BRadius.md),
        side: const BorderSide(color: BColors.outline, width: BBorder.thick),
      ),
      title: Text('Hapus catatan ini?', style: BText.h2.copyWith(fontSize: 17)),
      content: Text(
        '"${tx.title}"Sejumlah ${formatIDR(tx.amount)} akan dihapus, dan '
        'saldo ${tx.walletName} dikembalikan penuh.',
        style: BText.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('BATAL', style: BText.label),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('HAPUS',
              style: BText.label.copyWith(color: BColors.secondary)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  state.removeTransactionById(tx.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Catatan "${tx.title}" dihapus.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
