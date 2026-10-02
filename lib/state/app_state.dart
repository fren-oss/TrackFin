import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance.dart';
import '../models/seed.dart';
import 'analytics.dart';

/// Single source of truth for the whole app.
///
/// The app deliberately starts from zero: no wallets, no expenses, nothing but
/// the category list which is a fixed part of the design. Everything the
/// Analisis and Beranda screens show is derived from [transactions], so adding
/// or removing an expense immediately moves every chart and total.
class AppState extends ChangeNotifier {
  AppState({SharedPreferences? prefs}) : _prefs = prefs {
    if (_prefs != null) _restore(_prefs!);
  }

  static const String _kWallets = 'trackfin.wallets';
  static const String _kTransactions = 'trackfin.transactions';
  static const String _kSource = 'trackfin.sourceWalletId';
  static const String _kBalanceVisible = 'trackfin.balanceVisible';
  static const String _kPeriodIndex = 'trackfin.periodIndex';
  static const String _kCustomStart = 'trackfin.customStart';
  static const String _kCustomEnd = 'trackfin.customEnd';
  static const String _kBudget = 'trackfin.budgetLimit';
  static const String _kSheetsUrl = 'trackfin.sheetsUrl';
  static const String _kSheetsSyncedExpenses = 'trackfin.sheetsSyncedExpenses';
  static const String _kSheetsSyncedWallets = 'trackfin.sheetsSyncedWallets';
  static const String _kSheetsDeletedExpenses =
      'trackfin.sheetsDeletedExpenses';
  static const String _kSheetsDeletedWallets = 'trackfin.sheetsDeletedWallets';
  static const String _kSheetsLastSync = 'trackfin.sheetsLastSync';
  static const String _kSheetsWalletPrints = 'trackfin.sheetsWalletPrints';
  static const String _kSheetsTxPrints = 'trackfin.sheetsTxPrints';

  /// Fallback monthly budget shown on Beranda until the user sets one.
  static const int defaultBudgetLimit = 5000000;

  SharedPreferences? _prefs;
  bool _storageResolved = false;

  List<Wallet> _wallets = <Wallet>[];
  List<Transaction> _transactions = <Transaction>[];
  String? _sourceWalletId;
  bool _balanceVisible = true;
  int _periodTab = 1; // "Bulan Ini"
  DateTimeRange? _customRange;
  int _budgetLimit = defaultBudgetLimit;
  CategorySort _categorySortOrder = CategorySort.amount;
  int _walletCounter = 0;
  int _txCounter = 0;

  /// Fingerprints of what the sheet currently holds, so a sync can tell an
  /// edited row from an untouched one.
  final Map<String, String> _walletFingerprints = <String, String>{};
  final Map<String, String> _txFingerprints = <String, String>{};

  // ---- Google Sheets sync bookkeeping ----

  String _sheetsUrl = '';

  /// Ids already accepted by the sheet, so a second Sync is a no-op.
  Set<String> _syncedExpenses = <String>{};
  Set<String> _syncedWallets = <String>{};

  /// Ids removed locally but not yet removed from the sheet. Drained on the
  /// next successful sync, then cleared.
  List<String> _deletedExpenses = <String>[];
  List<String> _deletedWallets = <String>[];

  DateTime? _lastSheetsSync;

  // ---- Reads ----

  List<Wallet> get wallets => List<Wallet>.unmodifiable(_wallets);
  List<Transaction> get transactions =>
      List<Transaction>.unmodifiable(_transactions);
  String? get sourceWalletId => _sourceWalletId;
  bool get balanceVisible => _balanceVisible;
  int get periodTab => _periodTab;
  DateTimeRange? get customRange => _customRange;
  int get budgetLimit => _budgetLimit;
  CategorySort get categorySortOrder => _categorySortOrder;

  void setCategorySortOrder(CategorySort order) {
    if (order == _categorySortOrder) return;
    _categorySortOrder = order;
    notifyListeners();
  }

  /// False until persisted data has been read back, so the onboarding screen
  /// does not flash before the real wallets arrive.
  bool get hasStorage => _prefs != null;

  /// True once storage has been read *or* has definitively failed. The root
  /// gate waits on this rather than on [hasStorage], because a platform without
  /// the plugin never gets a prefs instance and would be stuck on a splash.
  bool get storageResolved => _storageResolved;

  /// The app has nothing to show until at least one wallet exists.
  bool get hasWallet => _wallets.isNotEmpty;

  /// Expenses only make sense once there is somewhere to draw from.
  bool get canRecordExpense => _wallets.isNotEmpty && _sourceWalletId != null;

  int get totalBalance =>
      _wallets.fold(0, (int sum, Wallet w) => sum + w.balance);

  Wallet? get sourceWallet {
    for (final Wallet w in _wallets) {
      if (w.id == _sourceWalletId) return w;
    }
    return null;
  }

  PeriodKind get periodKind => kindForIndex(_periodTab);

  DateRange get activeRange => rangeFor(periodKind, _customRange);

  /// All live analytics for the active period.
  Analytics get analytics =>
      computeAnalytics(transactions: _transactions, range: activeRange);

  /// Row count of the active period, used for empty states.
  int get periodTransactionCount => analytics.count;

  int get monthExpense => monthExpenseOf(_transactions);
  int get todayExpense => todayExpenseOf(_transactions);
  int get averagePerDay => averagePerDayOf(_transactions);

  /// Share of the monthly budget already spent, 0..1.
  double get budgetUsedFraction =>
      _budgetLimit <= 0 ? 0 : (monthExpense / _budgetLimit).clamp(0.0, 1.0);

  int get budgetUsedPct => (budgetUsedFraction * 100).round();
  int get budgetRemaining =>
      _budgetLimit - monthExpense < 0 ? 0 : _budgetLimit - monthExpense;

  // ---- Google Sheets sync ----

  /// Deployed Apps Script Web App URL. Empty until configured in Pengaturan.
  String get sheetsUrl => _sheetsUrl;

  bool get sheetsConfigured => _sheetsUrl.trim().isNotEmpty;

  DateTime? get lastSheetsSync => _lastSheetsSync;

  /// Wallets added or changed since the last successful sync.
  List<Wallet> get pendingWallets => _wallets
      .where((Wallet w) => !_syncedWallets.contains(w.id))
      .toList(growable: false);

  /// Expenses added since the last successful sync.
  List<Transaction> get pendingExpenses => _transactions
      .where((Transaction t) => !_syncedExpenses.contains(t.id))
      .toList(growable: false);

  /// Rows the next sync will act on: new, edited, and pending deletions. The
  /// count has to match [sheetsBatch], otherwise the settings page reports
  /// "nothing to send" while there is still work queued.
  int get pendingCount {
    final ({
      List<Wallet> wallets,
      List<Transaction> expenses,
      List<String> deletedWallets,
      List<String> deletedExpenses
    }) batch = sheetsBatch();
    return batch.wallets.length +
        batch.expenses.length +
        batch.deletedWallets.length +
        batch.deletedExpenses.length;
  }

  /// Wallets renamed, rebalanced, re-flagged as primary, or deleted locally
  /// since the last sync. Their sheets rows are stale even though the id was
  /// already pushed once.
  List<Wallet> get changedWallets => _wallets
      .where((Wallet w) =>
          _syncedWallets.contains(w.id) && !_unchangedSinceSync(w))
      .toList(growable: false);

  bool _unchangedSinceSync(Wallet w) =>
      _walletFingerprints[w.id] == _fingerprint(w);

  /// Expenses whose amount, note, category, or date changed after being synced.
  List<Transaction> get changedExpenses => _transactions
      .where((Transaction t) =>
          _syncedExpenses.contains(t.id) &&
          _txFingerprints[t.id] != _fingerprintTx(t))
      .toList(growable: false);

  static String _fingerprint(Wallet w) =>
      '${w.name}|${w.balance}|${w.icon}|${w.isPrimary}';

  static String _fingerprintTx(Transaction t) =>
      '${t.title}|${t.amount}|${t.walletId}|${t.categoryId}|${t.date?.millisecondsSinceEpoch}';

  /// Everything the next sync will push, plus deletions to apply.
  ({
    List<Wallet> wallets,
    List<Transaction> expenses,
    List<String> deletedWallets,
    List<String> deletedExpenses
  }) sheetsBatch() {
    final Map<String, Wallet> wallets = <String, Wallet>{
      for (final Wallet w in pendingWallets) w.id: w,
      for (final Wallet w in changedWallets) w.id: w,
    };
    final Map<String, Transaction> expenses = <String, Transaction>{
      for (final Transaction t in pendingExpenses) t.id: t,
      for (final Transaction t in changedExpenses) t.id: t,
    };
    return (
      wallets: wallets.values.toList(growable: false),
      expenses: expenses.values.toList(growable: false),
      deletedWallets: List<String>.of(_deletedWallets),
      deletedExpenses: List<String>.of(_deletedExpenses),
    );
  }

  /// Called after the sheet accepted a batch. Records fingerprints so the next
  /// sync only carries real changes, and clears the deletion queue.
  ///
  /// [requestedWalletDeletions] / [requestedExpenseDeletions] are what the batch
  /// asked the sheet to drop. They are cleared wholesale because a successful
  /// response means the script ran: an id the sheet no longer holds is already
  /// in the desired state, and retrying it forever would pin pendingCount.
  void applySheetsResult({
    required Iterable<String> walletIds,
    required Iterable<String> expenseIds,
    required Iterable<String> removedWalletIds,
    required Iterable<String> removedExpenseIds,
    required Iterable<String> requestedWalletDeletions,
    required Iterable<String> requestedExpenseDeletions,
    required DateTime at,
  }) {
    for (final Wallet w in _wallets) {
      if (walletIds.contains(w.id) || removedWalletIds.contains(w.id)) {
        _syncedWallets.add(w.id);
        _walletFingerprints[w.id] = _fingerprint(w);
      }
    }
    for (final Transaction t in _transactions) {
      if (expenseIds.contains(t.id) || removedExpenseIds.contains(t.id)) {
        _syncedExpenses.add(t.id);
        _txFingerprints[t.id] = _fingerprintTx(t);
      }
    }

    _syncedWallets.removeAll(removedWalletIds);
    _syncedWallets.removeWhere(
      (String id) => !_wallets.any((Wallet w) => w.id == id),
    );
    _syncedExpenses.removeAll(removedExpenseIds);
    _syncedExpenses.removeWhere(
      (String id) => !_transactions.any((Transaction t) => t.id == id),
    );

    _deletedWallets = _deletedWallets
        .where((String id) => !requestedWalletDeletions.contains(id))
        .toList();
    _deletedExpenses = _deletedExpenses
        .where((String id) => !requestedExpenseDeletions.contains(id))
        .toList();

    _lastSheetsSync = at;
    _persist();
    notifyListeners();
  }

  /// Stores the Web App URL. Blank input clears the configuration.
  void setSheetsUrl(String url) {
    final String next = url.trim();
    if (next == _sheetsUrl) return;
    _sheetsUrl = next;
    // Pointing at a different sheet: it has never seen these rows, so forget
    // what the previous one held and push everything again. Queued deletions
    // belonged to the old sheet, so they are dropped too.
    if (next.isNotEmpty && _lastSheetsSync != null) {
      _syncedWallets = <String>{};
      _syncedExpenses = <String>{};
      _deletedWallets = <String>[];
      _deletedExpenses = <String>[];
    }
    _persist();
    notifyListeners();
  }

  /// Forgets what the sheet already has, so the next Sync rewrites every row.
  void resetSheetsSyncState() {
    _syncedWallets = <String>{};
    _syncedExpenses = <String>{};
    _deletedExpenses = <String>[];
    _deletedWallets = <String>[];
    _lastSheetsSync = null;
    _persist();
    notifyListeners();
  }

  /// Largest category of the running month, or null when nothing is recorded.
  CategorySlice? get monthTopSlice {
    final Analytics a = computeAnalytics(
        transactions: _transactions, range: rangeFor(PeriodKind.month, null));
    return a.topSlice;
  }

  // ---- Writes ----

  void toggleBalanceVisibility() {
    _balanceVisible = !_balanceVisible;
    _persist();
    notifyListeners();
  }

  void setSourceWallet(String id) {
    if (id == _sourceWalletId) return;
    _sourceWalletId = id;
    _persist();
    notifyListeners();
  }

  void setPeriodTab(int index) {
    if (index == _periodTab) return;
    _periodTab = index;
    _persist();
    notifyListeners();
  }

  void setCustomRange(DateTimeRange range) {
    _customRange = range;
    _periodTab = kCustomPeriodIndex;
    _persist();
    notifyListeners();
  }

  void setBudgetLimit(int value) {
    final int next = value < 0 ? 0 : value;
    if (next == _budgetLimit) return;
    _budgetLimit = next;
    _persist();
    notifyListeners();
  }

  /// Records an expense against [walletId] (defaults to the active source
  /// wallet) and returns the stored row. Returns null when no wallet exists.
  Transaction? addExpense({
    required int amount,
    required String categoryId,
    required String note,
    String? walletId,
    DateTime? date,
  }) {
    final Wallet? wallet = _walletById(walletId) ??
        sourceWallet ??
        (_wallets.isEmpty ? null : _wallets.first);
    if (wallet == null) return null;

    final Category cat = categoryFor(categoryId);
    final DateTime when = date ?? DateTime.now();
    _txCounter++;

    final Transaction tx = Transaction(
      id: 'e$_txCounter',
      title: note.trim().isEmpty ? cat.label : note.trim(),
      walletName: wallet.name,
      time: '${when.hour.toString().padLeft(2, '0')}:'
          '${when.minute.toString().padLeft(2, '0')} WIB',
      amount: amount,
      categoryLabel: cat.label,
      icon: cat.icon,
      accent: BColorsTint.forCategory(cat.id),
      categoryId: cat.id,
      walletId: wallet.id,
      date: when,
    );

    _wallets = _wallets
        .map((Wallet w) =>
            w.id == wallet.id ? w.copyWith(balance: w.balance - amount) : w)
        .toList();

    _transactions = <Transaction>[tx, ..._transactions];
    _persist();
    notifyListeners();
    return tx;
  }

  /// Removes one expense by id and refunds its amount to the wallet. Matching on
  /// id rather than amount/title matters: two identical coffees are two rows,
  /// and deleting one must not take the other with it.
  void removeTransactionById(String id) {
    final Transaction? tx =
        _transactions.where((Transaction t) => t.id == id).firstOrNull;
    if (tx == null) return;
    _queueExpenseDeletion(tx.id);
    _transactions = _transactions.where((Transaction t) => t.id != id).toList();
    if (tx.walletId != null) {
      _wallets = _wallets
          .map((Wallet w) => w.id == tx.walletId
              ? w.copyWith(balance: w.balance + tx.amount)
              : w)
          .toList();
    }
    _persist();
    notifyListeners();
  }

  /// Removes a single expense and refunds its amount to the wallet.
  void removeTransaction(String walletId, int amount, {String? title}) {
    final List<Transaction> kept = _transactions
        .where((Transaction t) => !(t.walletId == walletId &&
            t.amount == amount &&
            (title == null || t.title == title)))
        .toList();
    // Queue the sheet-side cleanup before dropping the rows.
    for (final Transaction t in _transactions) {
      if (!kept.contains(t)) _queueExpenseDeletion(t.id);
    }
    _transactions = kept;
    _wallets = _wallets
        .map((Wallet w) =>
            w.id == walletId ? w.copyWith(balance: w.balance + amount) : w)
        .toList();
    _persist();
    notifyListeners();
  }

  void addWallet({
    required String name,
    required int balance,
    String icon = 'account_balance_wallet',
    bool asSource = false,
  }) {
    _walletCounter++;
    final Wallet wallet = Wallet(
      id: 'w$_walletCounter',
      name: name,
      balance: balance,
      icon: icon,
      accent: BColorsTint.forWallet(_walletCounter - 1),
      // The first wallet becomes both the main card and the default source.
      isPrimary: _wallets.isEmpty,
    );

    _wallets = <Wallet>[..._wallets, wallet];
    // Always keep a valid source: first wallet wins, otherwise honour the flag.
    if (_sourceWalletId == null || asSource) {
      _sourceWalletId = wallet.id;
    }

    _persist();
    notifyListeners();
  }

  /// Renames a wallet and/or changes its balance to [newBalance]. An empty
  /// [newBalance] (null) leaves the balance alone.
  void updateWallet(String id, {String? name, int? newBalance, String? icon}) {
    _wallets = _wallets
        .map((Wallet w) => w.id == id
            ? w.copyWith(
                name: name,
                balance: newBalance,
                icon: icon,
              )
            : w)
        .toList();
    _persist();
    notifyListeners();
  }

  /// Deletes a wallet together with every expense recorded against it, as
  /// confirmed by the caller. Re-points the source wallet when needed so the
  /// Catat screen never points at a wallet that no longer exists.
  void removeWallet(String id) {
    _wallets = _wallets.where((Wallet w) => w.id != id).toList();
    final List<Transaction> kept =
        _transactions.where((Transaction t) => t.walletId != id).toList();
    for (final Transaction t in _transactions) {
      if (!kept.contains(t)) _queueExpenseDeletion(t.id);
    }
    _transactions = kept;
    _queueWalletDeletion(id);

    if (_sourceWalletId == id) {
      _sourceWalletId = _wallets.isEmpty ? null : _wallets.first.id;
    }

    _persist();
    notifyListeners();
  }

  /// Promotes a wallet to be the featured "Dompet Utama" card.
  void setPrimaryWallet(String id) {
    _wallets =
        _wallets.map((Wallet w) => w.copyWith(isPrimary: w.id == id)).toList();
    _persist();
    notifyListeners();
  }

  /// How many expenses reference [walletId] — shown in the delete dialog.
  int countTransactionsOf(String walletId) =>
      _transactions.where((Transaction t) => t.walletId == walletId).length;

  Wallet? _walletById(String? id) {
    if (id == null) return null;
    for (final Wallet w in _wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  static Category categoryFor(String id) => Seed.categories.firstWhere(
        (Category c) => c.id == id,
        orElse: () => Seed.categories.last,
      );

  // ---- Persistence ----

  Future<void> attachStorage() async {
    if (_storageResolved) return;
    try {
      final SharedPreferences prefs =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      _restore(prefs);
    } catch (_) {
      // Storage unavailable (e.g. a platform without a plugin registered):
      // keep running in-memory rather than blocking the first screen.
      _prefs = null;
    }
    _storageResolved = true;
    notifyListeners();
  }

  void _restore(SharedPreferences prefs) {
    final List<Wallet> wallets = _decodeWallets(prefs.getString(_kWallets));
    final List<Transaction> txs =
        _decodeTransactions(prefs.getString(_kTransactions));

    // Sheet bookkeeping is independent of the records themselves: a saved URL
    // still has to survive a restart even when the user has no data yet.
    _restoreSheetsBookkeeping(prefs);

    if (wallets.isEmpty && txs.isEmpty && !prefs.containsKey(_kWallets)) return;

    _wallets = wallets;
    _transactions = txs;
    _balanceVisible = prefs.getBool(_kBalanceVisible) ?? true;
    _periodTab = prefs.getInt(_kPeriodIndex) ?? 1;
    _budgetLimit = prefs.getInt(_kBudget) ?? defaultBudgetLimit;

    final int? start = prefs.getInt(_kCustomStart);
    final int? end = prefs.getInt(_kCustomEnd);
    if (start != null && end != null) {
      _customRange = DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(start),
        end: DateTime.fromMillisecondsSinceEpoch(end),
      );
    }

    final String? source = prefs.getString(_kSource);
    _sourceWalletId =
        _walletById(source)?.id ?? (wallets.isEmpty ? null : wallets.first.id);
  }

  void _restoreSheetsBookkeeping(SharedPreferences prefs) {
    _sheetsUrl = prefs.getString(_kSheetsUrl) ?? '';
    _syncedWallets =
        (prefs.getStringList(_kSheetsSyncedWallets) ?? <String>[]).toSet();
    _syncedExpenses =
        (prefs.getStringList(_kSheetsSyncedExpenses) ?? <String>[]).toSet();
    _deletedWallets = prefs.getStringList(_kSheetsDeletedWallets) ?? <String>[];
    _deletedExpenses =
        prefs.getStringList(_kSheetsDeletedExpenses) ?? <String>[];
    _walletFingerprints.addAll(_decodeFingerprints(_kSheetsWalletPrints));
    _txFingerprints.addAll(_decodeFingerprints(_kSheetsTxPrints));
    final int? synced = prefs.getInt(_kSheetsLastSync);
    if (synced != null) {
      _lastSheetsSync = DateTime.fromMillisecondsSinceEpoch(synced);
    }
  }

  Map<String, String> _decodeFingerprints(String key) {
    final String? raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((String k, dynamic v) => MapEntry<String, String>(k, '$v'));
    } catch (_) {
      return <String, String>{};
    }
  }

  void _persist() {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;

    prefs.setString(
      _kWallets,
      jsonEncode(<Map<String, Object?>>[
        for (final Wallet w in _wallets)
          <String, Object?>{
            'id': w.id,
            'name': w.name,
            'balance': w.balance,
            'icon': w.icon,
            'accent': w.accent.toARGB32(),
            'primary': w.isPrimary,
          },
      ]),
    );

    prefs.setString(
      _kTransactions,
      jsonEncode(<Map<String, Object?>>[
        for (final Transaction t in _transactions)
          <String, Object?>{
            'id': t.id,
            'title': t.title,
            'walletId': t.walletId,
            'wallet': t.walletName,
            'amount': t.amount,
            'categoryId': t.categoryId,
            'date': t.date?.millisecondsSinceEpoch,
          },
      ]),
    );

    if (_sourceWalletId != null) prefs.setString(_kSource, _sourceWalletId!);
    prefs.setBool(_kBalanceVisible, _balanceVisible);
    prefs.setInt(_kPeriodIndex, _periodTab);
    prefs.setInt(_kBudget, _budgetLimit);

    if (_customRange != null) {
      prefs.setInt(_kCustomStart, _customRange!.start.millisecondsSinceEpoch);
      prefs.setInt(_kCustomEnd, _customRange!.end.millisecondsSinceEpoch);
    } else {
      prefs.remove(_kCustomStart);
      prefs.remove(_kCustomEnd);
    }

    prefs.setString(_kSheetsUrl, _sheetsUrl);
    prefs.setStringList(_kSheetsSyncedWallets, _syncedWallets.toList());
    prefs.setStringList(_kSheetsSyncedExpenses, _syncedExpenses.toList());
    prefs.setStringList(_kSheetsDeletedWallets, _deletedWallets);
    prefs.setStringList(_kSheetsDeletedExpenses, _deletedExpenses);
    // Fingerprints are what stop every row being re-pushed after a restart.
    prefs.setString(_kSheetsWalletPrints, jsonEncode(_walletFingerprints));
    prefs.setString(_kSheetsTxPrints, jsonEncode(_txFingerprints));
    if (_lastSheetsSync != null) {
      prefs.setInt(_kSheetsLastSync, _lastSheetsSync!.millisecondsSinceEpoch);
    }
  }

  List<Wallet> _decodeWallets(String? raw) {
    if (raw == null || raw.isEmpty) return <Wallet>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<Wallet> out = <Wallet>[];
      int maxId = 0;
      for (final dynamic item in list) {
        final Map<String, dynamic> m = item as Map<String, dynamic>;
        final String id = m['id'] as String;
        final int numeric = int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? 0;
        if (numeric > maxId) maxId = numeric;
        out.add(Wallet(
          id: id,
          name: m['name'] as String,
          balance: (m['balance'] as num).toInt(),
          icon: (m['icon'] as String?) ?? 'account_balance_wallet',
          accent: Color(
              (m['accent'] as num?)?.toInt() ?? BColorsTint.yellow.toARGB32()),
          isPrimary: (m['primary'] as bool?) ?? false,
        ));
      }
      _walletCounter = maxId;
      return out;
    } catch (_) {
      return <Wallet>[];
    }
  }

  List<Transaction> _decodeTransactions(String? raw) {
    if (raw == null || raw.isEmpty) return <Transaction>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<Transaction> out = <Transaction>[];
      int maxId = 0;
      for (final dynamic item in list) {
        final Map<String, dynamic> m = item as Map<String, dynamic>;
        final int? stamp = (m['date'] as num?)?.toInt();
        if (stamp == null) continue;
        final DateTime when = DateTime.fromMillisecondsSinceEpoch(stamp);
        final Category cat = categoryFor((m['categoryId'] as String?) ?? '');
        final String? stored = m['id'] as String?;
        if (stored != null) {
          final int numeric =
              int.tryParse(stored.replaceAll(RegExp(r'\D'), '')) ?? 0;
          if (numeric > maxId) maxId = numeric;
        }
        out.add(Transaction(
          // Rows saved before the sheet integration have no id; mint one so
          // every record is addressable in the sheet.
          id: stored ?? 'e${++maxId}',
          title: m['title'] as String,
          walletName: (m['wallet'] as String?) ?? 'Dompet',
          time: '${when.hour.toString().padLeft(2, '0')}:'
              '${when.minute.toString().padLeft(2, '0')} WIB',
          amount: (m['amount'] as num).toInt(),
          categoryLabel: cat.label,
          icon: cat.icon,
          accent: BColorsTint.forCategory(cat.id),
          categoryId: cat.id,
          walletId: m['walletId'] as String?,
          date: when,
        ));
      }
      _txCounter = maxId;
      return out;
    } catch (_) {
      return <Transaction>[];
    }
  }

  /// Wipes every wallet and expense. Not wired to the UI yet, but kept so the
  /// storage layer has a tested reset path.
  void resetAll() {
    for (final Transaction t in _transactions) {
      _queueExpenseDeletion(t.id);
    }
    for (final Wallet w in _wallets) {
      _queueWalletDeletion(w.id);
    }
    _wallets = <Wallet>[];
    _transactions = <Transaction>[];
    _sourceWalletId = null;
    _customRange = null;
    _periodTab = 1;
    _walletCounter = 0;
    _txCounter = 0;
    _prefs?.remove(_kWallets);
    _prefs?.remove(_kTransactions);
    _prefs?.remove(_kSource);
    _prefs?.remove(_kCustomStart);
    _prefs?.remove(_kCustomEnd);
    notifyListeners();
  }

  // ---- Sheet deletion queue ----

  /// Records a local removal so the sheet row is deleted on the next sync. Only
  /// rows the sheet actually knows about are queued; an unsynced row never made
  /// it there, so there is nothing to clean up.
  void _queueExpenseDeletion(String id) {
    if (_syncedExpenses.remove(id)) {
      if (!_deletedExpenses.contains(id)) _deletedExpenses.add(id);
    }
    _txFingerprints.remove(id);
  }

  void _queueWalletDeletion(String id) {
    if (_syncedWallets.remove(id)) {
      if (!_deletedWallets.contains(id)) _deletedWallets.add(id);
    }
    _walletFingerprints.remove(id);
  }
}

/// Accent palette used for dynamic rows so newly added data stays on-brand.
class BColorsTint {
  BColorsTint._();
  static const yellow = Color(0xFFFFCC00);
  static const red = Color(0xFFE63B2E);
  static const blue = Color(0xFF0055FF);
  static const paper = Color(0xFFE2DDD4);
  static const black = Color(0xFF1A1A1A);
  static const paperBlue = Color(0xFFD6E3FF);

  /// Cycles as wallets are added so every tile keeps a distinct fill.
  static Color forWallet(int index) {
    const List<Color> accents = <Color>[black, yellow, red, blue, paper];
    return accents[index % accents.length];
  }

  static Color forCategory(String id) {
    switch (id) {
      case 'makanan':
        return yellow;
      case 'transport':
        return paperBlue;
      case 'belanja':
        return const Color(0xFFFFDAD6);
      case 'hiburan':
        return const Color(0xFFFFB3AB);
      case 'tagihan':
        return const Color(0xFFE8E3DA);
      case 'kesehatan':
        return const Color(0xFFD6E3FF);
      case 'pendidikan':
        return const Color(0xFFE2DDD4);
      default:
        return paper;
    }
  }
}

/// Minimal `InheritedNotifier` scope so the app needs no state-management
/// package. Rebuilds dependents whenever [AppState] notifies.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope(
      {super.key, required AppState notifier, required super.child})
      : super(notifier: notifier);
}

extension AppStateAccess on BuildContext {
  AppState watch<T>() {
    final AppStateScope? scope =
        dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing from the widget tree');
    return scope!.notifier!;
  }

  AppState read<T>() {
    final AppStateScope? scope = getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
