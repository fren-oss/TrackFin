import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/neo.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../services/sheets_sync.dart';
import '../state/app_state.dart';

/// Settings sheet: configure the Google Sheets Web App URL, check the
/// connection, and push the pending rows.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SheetsSyncService _service = SheetsSyncService();
  late final TextEditingController _url;

  bool _busy = false;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController();
  }

  @override
  void dispose() {
    _url.dispose();
    _service.close();
    super.dispose();
  }

  /// Reads the URL the user typed, falling back to the saved one so an
  /// unedited field still works.
  String _effectiveUrl(AppState state) {
    final String typed = _url.text.trim();
    return typed.isNotEmpty ? typed : state.sheetsUrl;
  }

  void _report(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = isError;
    });
  }

  Future<void> _testConnection(AppState state) async {
    final String url = _effectiveUrl(state);
    if (url.isEmpty) {
      _report('Tempel URL Web App dulu.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final String message = await _service.ping(url);
      _report('Terhubung. $message');
    } on SheetsSyncException catch (e) {
      _report(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync(AppState state) async {
    final String url = _effectiveUrl(state);
    if (url.isEmpty) {
      _report('Isi URL Web App Google Sheets terlebih dahulu.', isError: true);
      return;
    }

    final batch = state.sheetsBatch();
    if (batch.wallets.isEmpty &&
        batch.expenses.isEmpty &&
        batch.deletedWallets.isEmpty &&
        batch.deletedExpenses.isEmpty) {
      _report('Tidak ada data baru untuk dikirim.');
      return;
    }

    setState(() => _busy = true);
    try {
      final SheetsSyncResult res = await _service.push(
        url,
        wallets: batch.wallets,
        expenses: batch.expenses,
        deletedWalletIds: batch.deletedWallets,
        deletedExpenseIds: batch.deletedExpenses,
        sourceWalletId: state.sourceWalletId,
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: res.removedWalletIds,
        removedExpenseIds: res.removedExpenseIds,
        requestedWalletDeletions: batch.deletedWallets,
        requestedExpenseDeletions: batch.deletedExpenses,
        at: DateTime.now(),
      );
      _report(
        res.hasWork
            ? 'Terkirim: ${res.written} baris'
                '${res.removed > 0 ? ', ${res.removed} dihapus' : ''}.'
            : 'Server tidak mengonfirmasi baris mana yang ditulis.',
        isError: !res.hasWork,
      );
    } on SheetsSyncException catch (e) {
      _report(e.message, isError: true);
    } on TimeoutException {
      _report('Server tidak menjawab dalam 25 detik.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveUrl(AppState state) async {
    state.setSheetsUrl(_url.text);
    _report(
      state.sheetsConfigured
          ? 'URL disimpan.'
          : 'URL dikosongkan; sinkronisasi dimatikan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    if (_url.text.isEmpty && state.sheetsUrl.isNotEmpty) {
      _url.text = state.sheetsUrl;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          BSpace.margin, BSpace.md, BSpace.margin, BSpace.xl),
      children: [
        const _SectionLabel('GOOGLE SHEETS'),
        const SizedBox(height: 6),
        NeoCard(
          padding: const EdgeInsets.all(BSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data catatan pengeluaran dan dompet dikirim ke satu Google Sheet '
                'lewat Apps Script Web App.',
                style: BText.bodySmall.copyWith(fontSize: 12),
              ),
              const SizedBox(height: BSpace.md),
              _UrlField(controller: _url, enabled: !_busy),
              const SizedBox(height: BSpace.md),
              Row(
                children: [
                  Expanded(
                    child: _MiniButton(
                      label: 'UJI KONEKSI',
                      icon: Icons.wifi_tethering,
                      onTap: _busy ? null : () => _testConnection(state),
                    ),
                  ),
                  const SizedBox(width: BSpace.sm),
                  Expanded(
                    child: _MiniButton(
                      label: 'SIMPAN URL',
                      icon: Icons.save,
                      onTap: _busy ? null : () => _saveUrl(state),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: BSpace.lg),
        const _SectionLabel('STATUS SINKRONISASI'),
        const SizedBox(height: 6),
        NeoCard(
          padding: const EdgeInsets.all(BSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(
                label: 'Koneksi',
                value:
                    state.sheetsConfigured ? 'URL tersimpan' : 'Belum diatur',
                icon:
                    state.sheetsConfigured ? Icons.cloud_done : Icons.cloud_off,
                good: state.sheetsConfigured,
              ),
              const SizedBox(height: 8),
              _StatusRow(
                label: 'Menunggu kirim',
                value: '${state.pendingCount} baris',
                icon: state.pendingCount == 0
                    ? Icons.task_alt
                    : Icons.pending_actions,
                good: state.pendingCount == 0,
              ),
              const SizedBox(height: 8),
              _StatusRow(
                label: 'Terakhir sinkron',
                value: state.lastSheetsSync == null
                    ? 'Belum pernah'
                    : lastSyncLabel(state.lastSheetsSync!),
                icon: Icons.schedule,
                good: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: BSpace.lg),
        NeoButton(
          onTap: _busy || !state.sheetsConfigured ? null : () => _sync(state),
          enabled: !_busy && state.sheetsConfigured,
          height: 54,
          child: _busy
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 10),
                    Text('MENGIRIM...'),
                  ],
                )
              : Text(
                  'KIRIM KE SHEETS${state.pendingCount > 0 ? ' (${state.pendingCount})' : ''}',
                  style: const TextStyle(
                    fontFamily: BFont.headline,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
        ),
        if (_notice != null) ...[
          const SizedBox(height: BSpace.md),
          _NoticeCard(message: _notice!, isError: _noticeIsError),
        ],
        const SizedBox(height: BSpace.lg),
        const _SectionLabel('PANDUAN SINGKAT'),
        const SizedBox(height: 6),
        NeoCard(
          padding: const EdgeInsets.all(BSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (int i, String step) in _steps.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                _StepRow(number: i + 1, text: step),
              ],
            ],
          ),
        ),
        const SizedBox(height: BSpace.lg),
        NeoButton(
          onTap: _busy
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  final bool? ok = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      backgroundColor: BColors.surface,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(
                            color: BColors.outline, width: BBorder.thick),
                        borderRadius:
                            BorderRadius.all(Radius.circular(BRadius.md)),
                      ),
                      title: const Text('KIRIM ULANG SEMUA', style: BText.h2),
                      content: const Text(
                        'Semua baris akan dikirim ulang dari awal dan ditulis ulang '
                        'di sheet sesuai data saat ini. Lanjutkan?',
                        style: BText.bodySmall,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('BATAL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('KIRIM ULANG'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    state.resetSheetsSyncState();
                    _report(
                        'Status sinkron direset. Tekan kirim untuk menulis ulang.');
                  }
                },
          background: BColors.surfaceContainerLowest,
          foreground: BColors.onSurface,
          child: const Text('RESET STATUS SINKRONISASI'),
        ),
      ],
    );
  }

  static const List<String> _steps = <String>[
    'Buat Google Sheet kosong, lalu buka Extensions > Apps Script.',
    'Tempel kode Code.gs dari file tools/sheets/Code.gs di proyek ini.',
    'Simpan, pilih Deploy > New deployment > Web app.',
    'WAJIB: Execute as "Me" dan Who has access "Anyone". Salin URL /exec.',
    'Tempel URL itu di atas, tekan Uji Koneksi, lalu Kirim ke Sheets.',
    'Error "minta login"? Buka Deploy > Manage deployments, klik edit '
        '(pensil) pada deployment, pastikan access Anyone, lalu deploy ulang.',
  ];
}

String lastSyncLabel(DateTime when) {
  final DateTime now = DateTime.now();
  final int minutes = now.difference(when).inMinutes;
  if (minutes < 1) return 'Baru saja';
  if (minutes < 60) return '$minutes menit lalu';
  final int hours = minutes ~/ 60;
  if (hours < 24) return '$hours jam lalu';
  return '${when.day}/${when.month}/${when.year}';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: BText.labelWide.copyWith(
        color: BColors.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }
}

class _UrlField extends StatelessWidget {
  const _UrlField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLowest,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        boxShadow: BShadow.sm,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.url,
        autocorrect: false,
        cursorColor: BColors.primary,
        style: const TextStyle(
          fontFamily: BFont.amount,
          fontSize: 12,
          color: BColors.onSurface,
        ),
        decoration: const InputDecoration(
          isDense: true,
          filled: true,
          fillColor: BColors.surfaceContainerLowest,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          hintText: 'https://script.google.com/macros/s/XXXX/exec',
          hintStyle: TextStyle(
            fontFamily: BFont.amount,
            fontSize: 12,
            color: BColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = onTap != null;
    return NeoButton(
      onTap: onTap,
      enabled: active,
      background: BColors.surfaceContainerLowest,
      foreground: BColors.onSurface,
      shadow: BShadow.sm,
      borderRadius: BRadius.sm,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 16,
              color: active ? BColors.primary : BColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BText.label.copyWith(
                fontSize: 11,
                color: active ? BColors.onSurface : BColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.good,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 16, color: good ? BColors.primary : BColors.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label, style: BText.bodySmall.copyWith(fontSize: 12)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BText.label.copyWith(
              fontSize: 12,
              color: good ? BColors.onSurface : BColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        isError ? BColors.errorContainer : BColors.primaryContainer;
    final Color fg =
        isError ? BColors.onErrorContainer : BColors.onPrimaryContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BSpace.md),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        borderRadius: BorderRadius.circular(BRadius.sm),
        boxShadow: BShadow.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error : Icons.check_circle, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: BText.bodySmall.copyWith(fontSize: 12, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeoTag(text: '$number', fontSize: 11),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: BText.bodySmall.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Full-page wrapper used when Settings is pushed as its own route.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: BColors.outline, width: BBorder.thick),
        ),
        title: const Text('PENGATURAN', style: BText.h2),
      ),
      body: const SafeArea(top: false, child: SettingsScreen()),
    );
  }
}
