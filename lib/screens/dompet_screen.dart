import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/dialogs.dart';
import '../components/neo.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/finance.dart';
import '../models/seed.dart';
import '../state/app_state.dart';

class DompetScreen extends StatelessWidget {
  const DompetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    // Nothing to consolidate before the first wallet exists.
    if (!state.hasWallet) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          BSpace.margin,
          BSpace.md,
          BSpace.margin,
          BSpace.xl,
        ),
        children: const [
          _NoWalletsYet(),
          SizedBox(height: BSpace.lg),
          AddWalletForm(),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: BSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BSpace.margin),
          child: Column(
            children: [
              _ConsolidationCard(
                  total: state.totalBalance, count: state.wallets.length),
              const SizedBox(height: BSpace.lg),
              _FeaturedWalletCard(state: state),
              const SizedBox(height: BSpace.lg),
              _SectionHeading(count: state.wallets.length),
              const SizedBox(height: BSpace.sm),
              for (final Wallet w in state.wallets)
                Padding(
                  padding: const EdgeInsets.only(bottom: BSpace.sm),
                  child: _WalletTile(wallet: w, state: state),
                ),
              const SizedBox(height: BSpace.lg),
              const AddWalletForm(),
              const SizedBox(height: BSpace.xl),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown above the add-wallet form when the list is still empty.
class _NoWalletsYet extends StatelessWidget {
  const _NoWalletsYet();

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      background: BColors.primary,
      padding: const EdgeInsets.all(BSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BColors.primaryContainer,
              border: Border.all(color: BColors.outline, width: BBorder.thick),
              boxShadow: BShadow.sm,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.account_balance_wallet,
                size: 24, color: BColors.primary),
          ),
          const SizedBox(height: BSpace.md),
          Text(
            'MULAI DARI NOL',
            style: BText.labelWide.copyWith(
              color: BColors.primaryContainer,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada dompet',
            style: BText.h1.copyWith(color: BColors.onPrimary, fontSize: 22),
          ),
          const SizedBox(height: BSpace.sm),
          Text(
            'Tambahkan dompet pertama di bawah ini, lalu mulai mencatat pengeluaran. '
            'Semua angka di Beranda dan Analisis akan terisi otomatis dari data tersebut.',
            style: BText.body.copyWith(
              color: BColors.surfaceContainerHigh,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsolidationCard extends StatelessWidget {
  const _ConsolidationCard({required this.total, required this.count});

  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: BSpace.sm),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: BColors.primary.withValues(alpha: 0.2),
                  width: BBorder.thin,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance,
                    size: 18, color: BColors.primary),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'TOTAL SALDO BERSIH',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: BFont.headline,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      height: 1.2,
                      color: BColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: BSpace.sm),
                NeoTag(
                  text: '$count Dompet Manual',
                  dot: true,
                  fontSize: 11,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rp ${formatIDR(total)}',
              style: BText.amountHero.copyWith(color: BColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Konsolidasi seluruh dompet dan rekening aktif.',
            style: TextStyle(
              fontFamily: BFont.body,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: BColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Black "hero" card for the primary wallet, with a rotated outlined square
/// bleeding off the bottom-right corner.
class _FeaturedWalletCard extends StatelessWidget {
  const _FeaturedWalletCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // The featured card tracks the Dompet Utama marker, falling back to the
    // source wallet so it never renders an unnamed placeholder.
    final Wallet primary = state.wallets.firstWhere(
      (Wallet w) => w.isPrimary,
      orElse: () => state.sourceWallet ?? state.wallets.first,
    );

    return Container(
      height: 184,
      decoration: BoxDecoration(
        color: BColors.primary,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        borderRadius: BorderRadius.circular(BRadius.md),
        boxShadow: BShadow.lg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -24,
            child: Transform.rotate(
              angle: 0.21,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: BColors.primaryContainer.withValues(alpha: 0.2),
                    width: 4,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const NeoTag(
                            text: 'Dompet Utama Aktif',
                            icon: Icons.star,
                            fontSize: 12,
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                          ),
                          const SizedBox(height: BSpace.sm),
                          Text(
                            primary.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BText.h1.copyWith(
                                color: BColors.onPrimary, fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: BSpace.sm),
                    const Icon(
                      Icons.wallet,
                      size: 32,
                      color: BColors.primaryContainer,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALDO TERSEDIA'.toUpperCase(),
                      style: BText.labelWide.copyWith(
                        color: BColors.surfaceContainer.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Rp ${formatIDR(primary.balance)}',
                        style: BText.amountLg.copyWith(
                          color: BColors.primaryContainer,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.only(top: BSpace.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: BColors.onPrimary.withValues(alpha: 0.2),
                        width: BBorder.thin,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: BColors.surfaceContainer,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Sumber Pengeluaran Default',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BText.label.copyWith(
                                  color: BColors.surfaceContainer,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        color: BColors.onPrimary.withValues(alpha: 0.1),
                        child: Text(
                          'Pos Aktif',
                          style: BText.label.copyWith(
                            color: BColors.onPrimary,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEMUA DOMPET', style: BText.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              const Text(
                'Atur alokasi dana dan sumber pengeluaran harian',
                style: TextStyle(
                  fontFamily: BFont.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: BColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: BSpace.sm),
        NeoButton(
          // Scrolls to the add-wallet form so "Kelola" is not a dead button.
          onTap: () => _scrollToAddForm(context),
          background: BColors.surfaceContainerLowest,
          foreground: BColors.primary,
          shadow: BShadow.sm,
          borderRadius: BRadius.sm,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'KELOLA',
            style: BText.label.copyWith(
                color: BColors.primary, fontSize: 12, letterSpacing: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Scrolls the page to the add-wallet form anchored at the bottom.
void _scrollToAddForm(BuildContext context) {
  final ScrollableState? scrollable = Scrollable.maybeOf(context);
  if (scrollable == null) return;
  scrollable.position.animateTo(
    scrollable.position.maxScrollExtent,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOut,
  );
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.wallet, required this.state});

  final Wallet wallet;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final bool isSource = wallet.id == state.sourceWalletId;
    final int expenseCount = state.countTransactionsOf(wallet.id);

    return NeoCard(
      padding: const EdgeInsets.all(BSpace.md),
      child: Column(
        children: [
          Row(
            children: [
              NeoIconTile(
                icon: ms(wallet.icon),
                background: wallet.accent,
                foreground: wallet.accent.computeLuminance() > 0.5
                    ? BColors.onSurface
                    : BColors.onPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BText.h3,
                      ),
                    ),
                    if (wallet.isPrimary) ...[
                      const SizedBox(width: BSpace.sm),
                      const Flexible(
                        child: NeoTag(
                          text: 'UTAMA',
                          background: BColors.primary,
                          foreground: BColors.onPrimary,
                          fontSize: 10,
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: BSpace.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'Rp ${formatIDR(wallet.balance)}',
                  style: BText.amountMd.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          if (expenseCount > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$expenseCount catatan pengeluaran',
                style: BText.labelTiny.copyWith(
                  color: BColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ],
          const SizedBox(height: BSpace.sm),
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
              children: [
                Flexible(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: isSource,
                          onChanged: (_) {
                            HapticFeedback.selectionClick();
                            state.setSourceWallet(wallet.id);
                          },
                          side: const BorderSide(
                              color: BColors.outline, width: 2),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          fillColor: WidgetStateProperty.resolveWith(
                            (Set<WidgetState> s) =>
                                s.contains(WidgetState.selected)
                                    ? BColors.primary
                                    : Colors.transparent,
                          ),
                          checkColor: BColors.onPrimary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: BSpace.sm),
                      const Flexible(
                        child: Text(
                          'Jadikan Sumber Pengeluaran',
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
                    ],
                  ),
                ),
                const SizedBox(width: BSpace.xs),
                NeoButton(
                  onTap: () => _editWallet(context, state, wallet),
                  background: BColors.surfaceContainer,
                  foreground: BColors.primary,
                  shadow: const [
                    BoxShadow(color: BColors.outline, offset: Offset(1, 1))
                  ],
                  borderRadius: BRadius.sm,
                  borderWidth: BBorder.thin,
                  padding: const EdgeInsets.all(6),
                  child:
                      const Icon(Icons.edit, size: 16, color: BColors.primary),
                ),
                const SizedBox(width: 6),
                NeoButton(
                  onTap: () => _confirmDelete(context, state, wallet),
                  background: BColors.errorContainer,
                  foreground: BColors.error,
                  shadow: const [
                    BoxShadow(color: BColors.outline, offset: Offset(1, 1))
                  ],
                  borderRadius: BRadius.sm,
                  borderWidth: BBorder.thin,
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: BColors.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rename / rebalance an existing wallet.
Future<void> _editWallet(
  BuildContext context,
  AppState state,
  Wallet wallet,
) async {
  HapticFeedback.selectionClick();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: BColors.onSurface.withValues(alpha: 0.55),
    builder: (BuildContext context) => _WalletEditSheet(wallet: wallet),
  );
}

/// Confirm-and-delete. The dialog names the wallet and, when it holds
/// expenses, spells out that those records go too, so nothing is silently lost.
Future<void> _confirmDelete(
  BuildContext context,
  AppState state,
  Wallet wallet,
) async {
  HapticFeedback.selectionClick();

  final int expenseCount = state.countTransactionsOf(wallet.id);
  final bool isSource = wallet.id == state.sourceWalletId;
  final bool isPrimary = wallet.isPrimary;

  final StringBuffer detail = StringBuffer();
  if (expenseCount > 0) {
    detail.write('$expenseCount catatan pengeluaran pada dompet ini '
        'akan ikut terhapus permanen.');
  } else {
    detail.write('Dompet ini belum punya catatan pengeluaran.');
  }
  if (isSource) {
    detail.write(' Sumber pengeluaran otomatis dialihkan ke dompet pertama.');
  }
  if (isPrimary) {
    detail.write(' Slot Dompet Utama dilepas.');
  }

  final bool confirmed = await showNeoConfirm(
    context,
    title: 'Hapus "${wallet.name}"?',
    message: detail.toString(),
    confirmLabel: 'HAPUS',
    icon: Icons.delete_forever_outlined,
  );

  if (!confirmed || !context.mounted) return;
  state.removeWallet(wallet.id);
}

/// Bottom sheet with a name field and a "koreksi saldo" toggle. Left as-is the
/// balance is untouched; entering a value sets it explicitly.
class _WalletEditSheet extends StatefulWidget {
  const _WalletEditSheet({required this.wallet});

  final Wallet wallet;

  @override
  State<_WalletEditSheet> createState() => _WalletEditSheetState();
}

class _WalletEditSheetState extends State<_WalletEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  bool _adjustBalance = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.wallet.name);
    _balance = TextEditingController(text: '${widget.wallet.balance}');
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) return;
    context.read<AppState>().updateWallet(
          widget.wallet.id,
          name: name,
          newBalance: _adjustBalance
              ? (int.tryParse(_balance.text) ?? widget.wallet.balance)
              : null,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(BSpace.margin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child:
                      Container(width: 48, height: 5, color: BColors.outline),
                ),
                const SizedBox(height: BSpace.lg),
                Row(
                  children: [
                    const Expanded(
                      child: Text('EDIT DOMPET', style: BText.h1),
                    ),
                    NeoButton(
                      onTap: () => Navigator.of(context).pop(),
                      background: BColors.surfaceContainerLowest,
                      shadow: BShadow.sm,
                      borderRadius: BRadius.sm,
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.close,
                          size: 18, color: BColors.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: BSpace.lg),
                const _FieldLabel('NAMA DOMPET'),
                const SizedBox(height: 4),
                _NeoInput(
                  controller: _name,
                  hint: 'Nama dompet',
                  validator: (String? v) => (v == null || v.trim().isEmpty)
                      ? 'Nama dompet wajib diisi'
                      : null,
                ),
                const SizedBox(height: BSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _adjustBalance,
                        onChanged: (bool? v) =>
                            setState(() => _adjustBalance = v ?? false),
                        side:
                            const BorderSide(color: BColors.outline, width: 2),
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                        fillColor: WidgetStateProperty.resolveWith(
                          (Set<WidgetState> s) =>
                              s.contains(WidgetState.selected)
                                  ? BColors.primary
                                  : Colors.transparent,
                        ),
                        checkColor: BColors.onPrimary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Koreksi saldo',
                        style: TextStyle(
                          fontFamily: BFont.headline,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.topCenter,
                  child: _adjustBalance
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Stack(
                            children: [
                              _NeoInput(
                                controller: _balance,
                                hint: 'Saldo',
                                fontFamily: BFont.headline,
                                fontWeight: FontWeight.w600,
                                keyboardType: TextInputType.number,
                                contentPadding:
                                    const EdgeInsets.fromLTRB(44, 12, 14, 12),
                              ),
                              Positioned(
                                left: 14,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Text(
                                    'Rp',
                                    style: BText.h3.copyWith(
                                      color: BColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: BSpace.lg),
                NeoButton(
                  onTap: _save,
                  background: BColors.primary,
                  foreground: BColors.primaryContainer,
                  shadow: BShadow.md,
                  borderRadius: BRadius.md,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check,
                          size: 20, color: BColors.primaryContainer),
                      const SizedBox(width: BSpace.sm),
                      Text(
                        'SIMPAN PERUBAHAN',
                        style: BText.label.copyWith(
                          color: BColors.primaryContainer,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public so the onboarding screen can reuse the exact same form.
class AddWalletForm extends StatefulWidget {
  const AddWalletForm({super.key});

  @override
  State<AddWalletForm> createState() => AddWalletFormState();
}

class AddWalletFormState extends State<AddWalletForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _balance = TextEditingController(text: '0');
  String _type = Seed.walletTypes.first.label;
  bool _asPrimary = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  /// Digits-only input, re-formatted with dot separators on every change.
  void _onBalanceChanged(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final int parsed = int.tryParse(digits) ?? 0;
    final String formatted = formatIDR(parsed);
    if (formatted != value) {
      _balance.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _saved = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    context.read<AppState>().addWallet(
          name: _name.text.trim(),
          balance:
              int.tryParse(_balance.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0,
          icon: Seed.walletTypes
              .firstWhere(
                (({String label, String icon, Color accent}) t) =>
                    t.label == _type,
                orElse: () => Seed.walletTypes.first,
              )
              .icon,
          asSource: _asPrimary,
        );

    setState(() {
      _saving = false;
      _saved = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _formKey.currentState?.reset();
    setState(() {
      _saved = false;
      _asPrimary = false;
      _type = Seed.walletTypes.first.label;
      _balance.text = '0';
      _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      padding: const EdgeInsets.all(BSpace.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: BColors.primary,
                    border: Border.all(
                        color: BColors.outline, width: BBorder.thick),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add_card,
                    size: 18,
                    color: BColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TAMBAH DOMPET BARU',
                        style: TextStyle(
                          fontFamily: BFont.headline,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          color: BColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Catat instrumen atau pos dompet secara manual (tanpa koneksi bank)',
                        style: TextStyle(
                          fontFamily: BFont.body,
                          fontSize: 12,
                          color: BColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BSpace.md),
            const _FieldLabel('NAMA DOMPET'),
            const SizedBox(height: 4),
            _NeoInput(
              controller: _name,
              hint: 'cth: Dompet Harian, Tabungan Darurat',
              validator: (String? v) => (v == null || v.trim().isEmpty)
                  ? 'Nama dompet wajib diisi'
                  : null,
            ),
            const SizedBox(height: BSpace.md),
            const _FieldLabel('TIPE AKUN'),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: BColors.surfaceContainerLowest,
                border:
                    Border.all(color: BColors.outline, width: BBorder.thick),
                boxShadow: BShadow.sm,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more,
                      size: 20, color: BColors.primary),
                  style: BText.body
                      .copyWith(fontSize: 14, color: BColors.onSurface),
                  dropdownColor: BColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.zero,
                  items: [
                    for (final ({String label, String icon, Color accent}) t
                        in Seed.walletTypes)
                      DropdownMenuItem<String>(
                        value: t.label,
                        child: Row(
                          children: [
                            Icon(ms(t.icon),
                                size: 16, color: BColors.onSurface),
                            const SizedBox(width: BSpace.sm),
                            Flexible(
                              child: Text(
                                t.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (String? v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: BSpace.md),
            const _FieldLabel('SALDO AWAL'),
            const SizedBox(height: 4),
            Stack(
              children: [
                _NeoInput(
                  controller: _balance,
                  hint: '0',
                  fontFamily: BFont.headline,
                  fontWeight: FontWeight.w600,
                  keyboardType: TextInputType.number,
                  onChanged: _onBalanceChanged,
                  contentPadding: const EdgeInsets.fromLTRB(44, 12, 14, 12),
                ),
                Positioned(
                  left: 14,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      'Rp',
                      style: BText.h3
                          .copyWith(color: BColors.primary, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _asPrimary,
                    onChanged: (bool? v) =>
                        setState(() => _asPrimary = v ?? false),
                    side: const BorderSide(color: BColors.outline, width: 2),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    fillColor: WidgetStateProperty.resolveWith(
                      (Set<WidgetState> s) => s.contains(WidgetState.selected)
                          ? BColors.primary
                          : Colors.transparent,
                    ),
                    checkColor: BColors.onPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Setel sebagai sumber pengeluaran',
                        style: TextStyle(
                          fontFamily: BFont.headline,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.read<AppState>().hasWallet
                            ? 'Transaksi pengeluaran baru akan memotong dompet ini. Kosongkan untuk memakai dompet pertama.'
                            : 'Dompet pertama otomatis menjadi sumber pengeluaran.',
                        style: const TextStyle(
                          fontFamily: BFont.body,
                          fontSize: 12,
                          color: BColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BSpace.sm),
            NeoButton(
              onTap: _saving || _saved ? null : _submit,
              enabled: !_saving && !_saved,
              background: _saved ? BColors.primaryContainer : BColors.primary,
              foreground: _saved ? BColors.primary : BColors.onPrimary,
              shadow: BShadow.md,
              borderRadius: BRadius.md,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_saving)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _saved ? BColors.primary : BColors.onPrimary,
                      ),
                    )
                  else
                    Icon(
                      _saved ? Icons.check : Icons.add,
                      size: 20,
                      color: _saved ? BColors.primary : BColors.onPrimary,
                    ),
                  const SizedBox(width: BSpace.sm),
                  Flexible(
                    child: Text(
                      _saving
                          ? 'MENYIMPAN...'
                          : _saved
                              ? 'TERSIMPAN!'
                              : 'TAMBAH DOMPET BARU',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: BFont.headline,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: _saved ? BColors.primary : BColors.onPrimary,
                      ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: BFont.headline,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        height: 1.2,
        color: BColors.onSurface,
      ),
    );
  }
}

class _NeoInput extends StatelessWidget {
  const _NeoInput({
    required this.controller,
    this.hint = '',
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.fontFamily = BFont.body,
    this.fontWeight = FontWeight.w400,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String fontFamily;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLowest,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        boxShadow: BShadow.sm,
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        onChanged: onChanged,
        cursorColor: BColors.primary,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: fontWeight,
          color: BColors.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: BColors.surfaceContainerLowest,
          border: InputBorder.none,
          contentPadding: contentPadding,
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: BColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
