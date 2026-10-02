import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/nav_scope.dart';
import '../components/neo.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/finance.dart';
import '../models/seed.dart';
import '../state/app_state.dart';

enum _SavePhase { idle, invalid, saving, done, noWallet }

class CatatScreen extends StatefulWidget {
  const CatatScreen({super.key});

  @override
  State<CatatScreen> createState() => _CatatScreenState();
}

class _CatatScreenState extends State<CatatScreen> {
  /// Holds the amount with dot separators, e.g. '15.000'. The digits-only
  /// value is derived on demand, so there is a single source of truth.
  final TextEditingController _amountCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  String _categoryId = Seed.categories.first.id;
  final TextEditingController _note = TextEditingController();
  _SavePhase _phase = _SavePhase.idle;

  /// Transaction date the user can move back a few days; defaults to now.
  DateTime _date = DateTime.now();

  String get _amountDigits =>
      _amountCtrl.text.replaceAll(_nonDigit, '').replaceAll(_dot, '');

  int get _amount => int.tryParse(_amountDigits) ?? 0;

  /// The wallet this expense will be charged to.
  String? get _walletId => context.read<AppState>().sourceWalletId;

  @override
  void initState() {
    super.initState();
    // Reformat as the user types so the figure stays readable while the OS
    // numeric keyboard is up.
    _amountCtrl.addListener(_reformatAmount);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_reformatAmount);
    _amountCtrl.dispose();
    _amountFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  static final RegExp _nonDigit = RegExp(r'[^0-9]');
  static const String _dot = '.';

  /// Guards against a paste that would overflow the integer column.
  static const int _maxDigits = 12;

  void _reformatAmount() {
    final String raw = _amountCtrl.text.replaceAll(_nonDigit, '');
    final String digits = raw.substring(0, raw.length.clamp(0, _maxDigits));

    final String formatted = _groupThousands(digits);
    if (formatted == _amountCtrl.text) return;

    _amountCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _groupThousands(String digits) {
    if (digits.isEmpty) return '';
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return out.toString();
  }

  void _addQuick(int delta) {
    HapticFeedback.selectionClick();
    final int total = _amount + delta;
    _amountCtrl.text =
        _groupThousands(total.toString().substring(0, _maxDigits));
    setState(() => _phase = _SavePhase.idle);
  }

  void _resetAmount() {
    HapticFeedback.selectionClick();
    _amountCtrl.clear();
    setState(() => _phase = _SavePhase.idle);
  }

  void _onAmountChanged(String _) {
    if (_phase != _SavePhase.idle) {
      setState(() => _phase = _SavePhase.idle);
    }
  }

  Future<void> _save() async {
    final AppState state = context.read<AppState>();

    if (!state.canRecordExpense) {
      setState(() => _phase = _SavePhase.noWallet);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _phase = _SavePhase.idle);
      return;
    }

    if (_amount <= 0) {
      setState(() => _phase = _SavePhase.invalid);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _phase = _SavePhase.idle);
      return;
    }

    setState(() => _phase = _SavePhase.saving);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Preserve the chosen time-of-day but use the picked calendar date.
    final DateTime now = DateTime.now();
    final DateTime when = DateTime(
      _date.year,
      _date.month,
      _date.day,
      now.hour,
      now.minute,
    );

    state.addExpense(
      amount: _amount,
      categoryId: _categoryId,
      note: _note.text,
      walletId: _walletId,
      date: when,
    );

    setState(() {
      _phase = _SavePhase.done;
      _amountCtrl.clear();
      _note.clear();
      _date = DateTime.now();
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _phase = _SavePhase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BSpace.margin,
        BSpace.md,
        BSpace.margin,
        BSpace.lg,
      ),
      children: [
        _AmountField(
          controller: _amountCtrl,
          focusNode: _amountFocus,
          onChanged: _onAmountChanged,
          onAdd: _addQuick,
          onReset: _resetAmount,
        ),
        const SizedBox(height: BSpace.md),
        _WalletSelector(state: state),
        const SizedBox(height: BSpace.md),
        _CategoryGrid(
          selected: _categoryId,
          onSelect: (id) {
            HapticFeedback.selectionClick();
            setState(() => _categoryId = id);
          },
        ),
        const SizedBox(height: BSpace.md),
        _DetailCard(
          controller: _note,
          date: _date,
          onPickDate: (DateTime d) {
            HapticFeedback.selectionClick();
            setState(() => _date = d);
          },
        ),
        const SizedBox(height: BSpace.md),
        _SubmitButton(phase: _phase, onTap: _save),
      ],
    );
  }
}

/// The amount input.
///
/// Tapping anywhere on the field raises the OS numeric keyboard, which is what
/// people already expect and beats an in-app numpad they have to aim at. The
/// quick chips stay because for the common round amounts they are fewer
/// keystrokes than typing.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onAdd,
    required this.onReset,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onAdd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BSpace.lg),
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLowest,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        borderRadius: BorderRadius.circular(BRadius.lg),
        boxShadow: BShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rotated yellow square in the corner — a deliberate Bauhaus accent.
          Align(
            alignment: Alignment.topRight,
            child: Transform.translate(
              offset: const Offset(14, -18),
              child: Transform.rotate(
                angle: 0.21,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: BColors.primaryContainer,
                    border: Border.all(
                        color: BColors.outline, width: BBorder.thick),
                  ),
                ),
              ),
            ),
          ),
          Text(
            'JUMLAH PENGELUARAN',
            style: BText.labelTiny.copyWith(fontSize: 11, letterSpacing: 1.2),
          ),
          const SizedBox(height: BSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Rp',
                style: BText.amountLg.copyWith(
                  color: BColors.secondary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  // numberWithOptions keeps the platform keyboard numeric
                  // while still allowing a paste of a plain figure.
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  cursorColor: BColors.primary,
                  style: BText.amountDisplay.copyWith(fontSize: 34),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0',
                    hintStyle: BText.amountDisplay.copyWith(
                      fontSize: 34,
                      color: BColors.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onReset,
                icon: const Icon(Icons.backspace_outlined,
                    size: 20, color: BColors.error),
                tooltip: 'Hapus nominal',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: BSpace.sm),
          Text(
            'TAP NOMINAL UNTUK MENGETIK',
            style: BText.labelTiny.copyWith(
              fontSize: 10,
              letterSpacing: 1.1,
              color: BColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: BSpace.sm),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: BSpace.sm,
            runSpacing: BSpace.sm,
            children: [
              for (final int v in const [10000, 50000, 100000])
                _QuickChip(label: '+${formatIDR(v)}', onTap: () => onAdd(v)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoButton(
      onTap: onTap,
      background: BColors.surfaceContainer,
      foreground: BColors.onSurface,
      hoverBackground: BColors.primaryContainer,
      shadow: BShadow.sm,
      borderRadius: BRadius.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: BFont.headline,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: BColors.onSurface,
        ),
      ),
    );
  }
}

class _WalletSelector extends StatelessWidget {
  const _WalletSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'SUMBER DANA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.2,
                    color: BColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: BSpace.sm),
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    NavScope.maybeOf(context)?.goTo(3);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Kelola Dompet Manual',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BText.label.copyWith(
                      color: BColors.secondary,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 62,
          child: state.wallets.isEmpty
              ? _NoWalletHint()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: state.wallets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int i) {
                    final Wallet w = state.wallets[i];
                    return _WalletChip(
                      wallet: w,
                      active: w.id == state.sourceWalletId,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        state.setSourceWallet(w.id);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Replaces the wallet strip when the app somehow reaches this screen with no
/// wallet (the root gate normally blocks it, but a deleted last wallet can
/// land here mid-session).
class _NoWalletHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NeoButton(
      onTap: () => NavScope.maybeOf(context)?.goTo(3),
      background: BColors.errorContainer,
      foreground: BColors.error,
      shadow: BShadow.sm,
      borderRadius: BRadius.sm,
      padding: const EdgeInsets.symmetric(horizontal: BSpace.md, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.warning, size: 18, color: BColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Belum ada dompet. Ketuk untuk membuat dompet.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BText.label.copyWith(color: BColors.error, fontSize: 12),
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: BColors.error),
        ],
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  const _WalletChip(
      {required this.wallet, required this.active, required this.onTap});

  final Wallet wallet;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoButton(
      onTap: onTap,
      background: active ? BColors.primary : BColors.surfaceContainerLowest,
      foreground: active ? BColors.onPrimary : BColors.onSurface,
      shadow: active ? BShadow.md : BShadow.sm,
      borderRadius: BRadius.sm,
      padding: const EdgeInsets.symmetric(horizontal: BSpace.md, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  active ? BColors.primaryContainer : BColors.surfaceContainer,
              border: Border.all(
                color: active ? BColors.onPrimary : BColors.outline,
                width: BBorder.thin,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              ms(wallet.icon),
              size: 18,
              color: active ? BColors.primary : BColors.onSurface,
            ),
          ),
          const SizedBox(width: BSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                wallet.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: BFont.headline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: active ? BColors.onPrimary : BColors.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Rp ${formatIDR(wallet.balance)}',
                style: TextStyle(
                  fontFamily: BFont.amount,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: active
                      ? BColors.primaryContainer
                      : BColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'KATEGORI PENGELUARAN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.2,
                    color: BColors.onSurface,
                  ),
                ),
              ),
              SizedBox(width: BSpace.sm),
              Flexible(
                child: Text(
                  'Pilih satu',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1.2,
                    color: BColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: Seed.categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: BSpace.sm,
            mainAxisSpacing: BSpace.sm,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (BuildContext context, int i) {
            final Category c = Seed.categories[i];
            return _CategoryTile(
              category: c,
              active: c.id == selected,
              onTap: () => onSelect(c.id),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(
      {required this.category, required this.active, required this.onTap});

  final Category category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoButton(
      onTap: onTap,
      background:
          active ? BColors.primaryContainer : BColors.surfaceContainerLowest,
      foreground: BColors.onSurface,
      shadow: active ? BShadow.md : BShadow.sm,
      borderRadius: BRadius.sm,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active ? BColors.primary : BColors.surfaceContainer,
              border: Border.all(color: BColors.outline, width: BBorder.thin),
              boxShadow: active ? BShadow.sm : const <BoxShadow>[],
            ),
            alignment: Alignment.center,
            child: Icon(
              ms(category.icon),
              size: 20,
              color: active ? BColors.primaryContainer : BColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: BFont.headline,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              height: 1.2,
              color: BColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.controller,
    required this.date,
    required this.onPickDate,
  });

  final TextEditingController controller;
  final DateTime date;
  final ValueChanged<DateTime> onPickDate;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      padding: const EdgeInsets.all(BSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 20, color: BColors.primary),
              const SizedBox(width: BSpace.sm),
              const Flexible(
                child: Text(
                  'WAKTU TRANSAKSI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1.2,
                    color: BColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: BSpace.sm),
              Flexible(
                child: NeoButton(
                  onTap: () => _pickDate(context),
                  background: BColors.surfaceContainerLow,
                  foreground: BColors.onSurface,
                  shadow: BShadow.sm,
                  borderRadius: BRadius.sm,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          dayHeaderLabel(date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: BFont.headline,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: BColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more,
                          size: 16, color: BColors.onSurface),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BSpace.md),
          Text('CATATAN TRANSAKSI',
              style: BText.labelWide.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: BSpace.md, vertical: BSpace.sm),
            decoration: BoxDecoration(
              color: BColors.surfaceContainerLow,
              border: Border.all(color: BColors.outline, width: BBorder.thick),
              borderRadius: BorderRadius.circular(BRadius.sm),
              boxShadow: BShadow.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note,
                    size: 20, color: BColors.onSurfaceVariant),
                const SizedBox(width: BSpace.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: BText.body
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                    cursorColor: BColors.primary,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      hintText: 'cth: Makan siang rendang bareng tim',
                      hintStyle: TextStyle(
                        fontFamily: BFont.body,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: date.isAfter(now) ? now : date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'TANGGAL TRANSAKSI',
    );
    if (picked != null) onPickDate(picked);
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.phase, required this.onTap});

  final _SavePhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String label;

    switch (phase) {
      case _SavePhase.idle:
        bg = BColors.primary;
        fg = BColors.primaryContainer;
        icon = Icons.check_circle;
        label = 'Simpan Pengeluaran';
      case _SavePhase.invalid:
        bg = BColors.error;
        fg = BColors.onError;
        icon = Icons.warning;
        label = 'Nominal masih Rp 0';
      case _SavePhase.saving:
        bg = BColors.primary;
        fg = BColors.primaryContainer;
        icon = Icons.autorenew;
        label = 'Menyimpan...';
      case _SavePhase.done:
        bg = BColors.secondary;
        fg = BColors.onPrimary;
        icon = Icons.task_alt;
        label = 'Tercatat Rapi!';
      case _SavePhase.noWallet:
        bg = BColors.error;
        fg = BColors.onError;
        icon = Icons.account_balance_wallet;
        label = 'Tambah Dompet Dulu';
    }

    return NeoButton(
      onTap: phase == _SavePhase.idle ? onTap : null,
      enabled: phase != _SavePhase.saving,
      background: bg,
      foreground: fg,
      borderRadius: BRadius.md,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (phase == _SavePhase.saving)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
            )
          else
            Icon(icon, size: 22, color: fg),
          const SizedBox(width: BSpace.sm),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: BFont.headline,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
