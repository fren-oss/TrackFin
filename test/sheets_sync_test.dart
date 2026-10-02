import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_client;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackfin/models/finance.dart';
import 'package:trackfin/services/jsonp_transport.dart';
import 'package:trackfin/services/sheets_sync.dart';
import 'package:trackfin/state/app_state.dart';

/// Local stand-in for the Apps Script Web App. Records every request so tests
/// can assert on the payload shape, and echoes back the ids it "accepted".
class FakeWebApp {
  FakeWebApp();

  final List<Map<String, dynamic>> posts = <Map<String, dynamic>>[];
  int pings = 0;
  int statusCode = 200;
  Object? error;

  static const String url = 'https://script.google.com/macros/s/TEST/exec';

  http.Response get _route {
    if (pings > 0 || posts.isNotEmpty) {
      final bool isPing = posts.isEmpty || _lastWasGet;
      if (isPing) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'message': 'TrackFin siap menerima data.',
          }),
          200,
        );
      }
      final Map<String, dynamic> p = posts.last;
      if (error != null) {
        return http.Response(
          jsonEncode(<String, Object?>{'ok': false, 'error': '$error'}),
          statusCode,
        );
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'expenses': (p['expenses'] as List<dynamic>)
              .map((dynamic e) => (e as Map<String, dynamic>)['id'])
              .toList(),
          'wallets': (p['wallets'] as List<dynamic>)
              .map((dynamic w) => (w as Map<String, dynamic>)['id'])
              .toList(),
          'deletedExpenses': p['deleteExpenses'],
          'deletedWallets': p['deleteWallets'],
          'message': 'OK',
        }),
        200,
      );
    }
    return http.Response('', 404);
  }

  bool _lastWasGet = false;

  http.Client client() => http_client.MockClient((http.Request req) async {
        if (req.method == 'GET') {
          _lastWasGet = true;
          pings++;
        } else {
          _lastWasGet = false;
          posts.add(jsonDecode(req.body) as Map<String, dynamic>);
        }
        return _route;
      });
}

SharedPreferences? _prefs;

Future<AppState> _stateWithData({bool attach = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppState state = AppState();
  if (attach) {
    await state.attachStorage();
    _prefs = await SharedPreferences.getInstance();
  }
  state.addWallet(name: 'Dompet Utama', balance: 500000);
  state.addWallet(name: 'Dompet Harian', balance: 150000);
  state.addExpense(amount: 25000, categoryId: 'makanan', note: 'Kopi');
  // Explicitly on w2, since the source wallet stays on the first one.
  state.addExpense(
    amount: 12000,
    categoryId: 'transport',
    note: 'Gojek',
    walletId: 'w2',
  );
  return state;
}

/// Simulates an app restart against the same store.
Future<AppState> _reopen() async {
  final AppState state = AppState(prefs: _prefs!);
  await state.attachStorage();
  return state;
}

void main() {
  group('payload shape', () {
    test('wallet and expense rows carry the sheet headers', () async {
      final FakeWebApp fake = FakeWebApp();
      final AppState state = await _stateWithData();
      final batch = state.sheetsBatch();
      final service = SheetsSyncService(client: fake.client());

      await service.push(
        FakeWebApp.url,
        wallets: batch.wallets,
        expenses: batch.expenses,
        deletedWalletIds: batch.deletedWallets,
        deletedExpenseIds: batch.deletedExpenses,
        sourceWalletId: state.sourceWalletId,
      );

      expect(fake.posts, hasLength(1));
      final Map<String, dynamic> p = fake.posts.single;

      final List<dynamic> wallets = p['wallets'] as List<dynamic>;
      expect(wallets, hasLength(2));
      final Map<String, dynamic> w = wallets.first as Map<String, dynamic>;
      expect(w['id'], 'w1');
      expect(w['nama'], 'Dompet Utama');
      // 500.000 less the 25.000 Kopi expense booked against this wallet.
      expect(w['saldo'], 475000);
      expect(w['utama'], true);
      expect(w['sumber'], true);
      expect(
        (wallets.last as Map<String, dynamic>)['sumber'],
        false,
        reason: 'only the wallet expenses default to is flagged',
      );

      final List<dynamic> expenses = p['expenses'] as List<dynamic>;
      expect(expenses, hasLength(2));
      // Newest-first internally; order in the payload is not contractual.
      final Map<String, dynamic> e = expenses
          .cast<Map<String, dynamic>>()
          .firstWhere((Map<String, dynamic> row) => row['id'] == 'e1');
      expect(e['jumlah'], 25000);
      expect(e['kategori'], 'makanan');
      expect(e['dompetId'], 'w1');
      expect(e['catatan'], 'Kopi');
      expect(e['tanggal'], isA<String>());
    });

    test('an empty batch makes no request', () async {
      final FakeWebApp fake = FakeWebApp();
      final service = SheetsSyncService(client: fake.client());

      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: <Wallet>[],
        expenses: <Transaction>[],
        deletedWalletIds: <String>[],
        deletedExpenseIds: <String>[],
      );

      expect(fake.posts, isEmpty);
      expect(res.hasWork, isFalse);
    });
  });

  group('pending tracking', () {
    test('a deleted expense is queued for removal from the sheet', () async {
      final AppState state = await _stateWithData();
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      final first = state.sheetsBatch();
      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: first.wallets,
        expenses: first.expenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: res.removedWalletIds,
        removedExpenseIds: res.removedExpenseIds,
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );
      expect(state.pendingCount, 0);

      // Deleting e1 also credits the wallet, so both facts have to reach the
      // sheet: the row is gone and the wallet balance moved.
      state.removeTransactionById('e1');
      final batch = state.sheetsBatch();
      expect(batch.deletedExpenses, contains('e1'));
      expect(batch.wallets.where((Wallet w) => w.id == 'w1'), isNotEmpty);

      final SheetsSyncResult del = await service.push(
        FakeWebApp.url,
        wallets: batch.wallets,
        expenses: batch.expenses,
        deletedWalletIds: batch.deletedWallets,
        deletedExpenseIds: batch.deletedExpenses,
      );
      expect(del.removedExpenseIds, contains('e1'));

      state.applySheetsResult(
        walletIds: del.walletIds,
        expenseIds: del.expenseIds,
        removedWalletIds: del.removedWalletIds,
        removedExpenseIds: del.removedExpenseIds,
        requestedWalletDeletions: batch.deletedWallets,
        requestedExpenseDeletions: batch.deletedExpenses,
        at: DateTime(2026, 10, 3),
      );
      expect(state.pendingCount, 0);
      expect(state.sheetsBatch().deletedExpenses, isEmpty);
    });

    test('new rows are pending and clear after a successful push', () async {
      final AppState state = await _stateWithData();
      expect(state.pendingCount, 4);
      expect(state.pendingWallets, hasLength(2));
      expect(state.pendingExpenses, hasLength(2));

      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncResult res =
          await SheetsSyncService(client: fake.client()).push(
        FakeWebApp.url,
        wallets: state.pendingWallets,
        expenses: state.pendingExpenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: res.removedWalletIds,
        removedExpenseIds: res.removedExpenseIds,
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );

      expect(state.pendingCount, 0);
      expect(state.lastSheetsSync, DateTime(2026, 10, 2));
    });

    test('a second sync sends nothing', () async {
      final AppState state = await _stateWithData();
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      for (int round = 0; round < 2; round++) {
        final batch = state.sheetsBatch();
        if (batch.wallets.isEmpty &&
            batch.expenses.isEmpty &&
            batch.deletedWallets.isEmpty &&
            batch.deletedExpenses.isEmpty) {
          break;
        }
        final SheetsSyncResult res = await service.push(
          FakeWebApp.url,
          wallets: batch.wallets,
          expenses: batch.expenses,
          deletedWalletIds: batch.deletedWallets,
          deletedExpenseIds: batch.deletedExpenses,
        );
        state.applySheetsResult(
          walletIds: res.walletIds,
          expenseIds: res.expenseIds,
          removedWalletIds: res.removedWalletIds,
          removedExpenseIds: res.removedExpenseIds,
          requestedWalletDeletions: const <String>[],
          requestedExpenseDeletions: const <String>[],
          at: DateTime(2026, 10, 2),
        );
      }

      expect(fake.posts, hasLength(1));
      expect(state.sheetsBatch().wallets, isEmpty);
      expect(state.sheetsBatch().expenses, isEmpty);
    });

    test('new expenses and the wallet they debit are both queued', () async {
      final AppState state = await _stateWithData();
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      final first = state.sheetsBatch();
      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: first.wallets,
        expenses: first.expenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: const <String>[],
        removedExpenseIds: const <String>[],
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );
      expect(state.pendingCount, 0);

      // A fresh expense is pending; the previously synced one is untouched.
      // Its wallet balance moved too, so that row is stale as well.
      state.addExpense(amount: 9000, categoryId: 'hiburan', note: 'Bioskop');
      expect(state.pendingExpenses, hasLength(1));
      expect(state.changedExpenses, isEmpty);
      expect(state.changedWallets.map((Wallet w) => w.id), contains('w1'));
      expect(state.pendingCount, 2);
    });

    test('deleting a wallet queues its rows for removal from the sheet',
        () async {
      final AppState state = await _stateWithData();
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      final first = state.sheetsBatch();
      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: first.wallets,
        expenses: first.expenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: const <String>[],
        removedExpenseIds: const <String>[],
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );

      // 'w2' (Dompet Harian) owns e2.
      state.removeWallet('w2');
      final batch = state.sheetsBatch();
      expect(batch.deletedWallets, contains('w2'));
      expect(batch.deletedExpenses, contains('e2'));
      expect(batch.wallets.where((Wallet w) => w.id == 'w2'), isEmpty);

      final SheetsSyncResult del = await service.push(
        FakeWebApp.url,
        wallets: batch.wallets,
        expenses: batch.expenses,
        deletedWalletIds: batch.deletedWallets,
        deletedExpenseIds: batch.deletedExpenses,
      );
      expect(del.removedWalletIds, contains('w2'));
      expect(del.removedExpenseIds, contains('e2'));

      state.applySheetsResult(
        walletIds: del.walletIds,
        expenseIds: del.expenseIds,
        removedWalletIds: del.removedWalletIds,
        removedExpenseIds: del.removedExpenseIds,
        requestedWalletDeletions: batch.deletedWallets,
        requestedExpenseDeletions: batch.deletedExpenses,
        at: DateTime(2026, 10, 3),
      );
      expect(state.pendingCount, 0);
      expect(state.sheetsBatch().deletedWallets, isEmpty);
      expect(state.sheetsBatch().deletedExpenses, isEmpty);
    });

    test('resetting forces a full re-push', () async {
      final AppState state = await _stateWithData();
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      final first = state.sheetsBatch();
      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: first.wallets,
        expenses: first.expenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: const <String>[],
        removedExpenseIds: const <String>[],
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );
      expect(state.pendingCount, 0);

      state.resetSheetsSyncState();
      expect(state.pendingCount, 4);
      expect(state.lastSheetsSync, isNull);
    });

    test('changing the URL clears what the old sheet already had', () async {
      final AppState state = await _stateWithData();
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      final first = state.sheetsBatch();
      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: first.wallets,
        expenses: first.expenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: const <String>[],
        removedExpenseIds: const <String>[],
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );

      state.setSheetsUrl('https://example.com/other');
      expect(state.pendingCount, 4);
    });

    test('changing the URL drops deletions aimed at the old sheet', () async {
      final AppState state = await _stateWithData(attach: true);
      state.setSheetsUrl('https://example.com/first');

      final first = state.sheetsBatch();
      state.applySheetsResult(
        walletIds: first.wallets.map((Wallet w) => w.id),
        expenseIds: first.expenses.map((Transaction t) => t.id),
        removedWalletIds: const <String>[],
        removedExpenseIds: const <String>[],
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );

      // Pending removal belongs to the first sheet, so it must not follow the
      // user to the second one.
      state.removeWallet('w2');
      expect(state.sheetsBatch().deletedWallets, contains('w2'));

      state.setSheetsUrl('https://example.com/second');
      expect(state.sheetsBatch().deletedWallets, isEmpty);
      expect(state.sheetsBatch().deletedExpenses, isEmpty);
      // w2 and its expense are gone locally, so only w1 and e1 are rewritten.
      expect(state.pendingCount, 2);
    });

    test('fingerprint and deletion queues survive a restart', () async {
      final AppState state = await _stateWithData(attach: true);
      final FakeWebApp fake = FakeWebApp();
      final SheetsSyncService service =
          SheetsSyncService(client: fake.client());

      final first = state.sheetsBatch();
      final SheetsSyncResult res = await service.push(
        FakeWebApp.url,
        wallets: first.wallets,
        expenses: first.expenses,
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );
      state.applySheetsResult(
        walletIds: res.walletIds,
        expenseIds: res.expenseIds,
        removedWalletIds: const <String>[],
        removedExpenseIds: const <String>[],
        requestedWalletDeletions: const <String>[],
        requestedExpenseDeletions: const <String>[],
        at: DateTime(2026, 10, 2),
      );
      // Removing a wallet both queues its row for deletion and lowers its
      // balance elsewhere, so the pending set is deliberately mixed.
      state.removeWallet('w2');
      expect(state.pendingCount, 2);
      expect(state.sheetsBatch().deletedExpenses, contains('e2'));

      // Same storage, fresh state object: nothing should look unsynced.
      final AppState reopened = await _reopen();
      expect(reopened.sheetsConfigured, isFalse);
      expect(reopened.changedWallets, isEmpty);
      expect(reopened.changedExpenses, isEmpty);
      expect(reopened.sheetsBatch().deletedWallets, contains('w2'));
      expect(reopened.sheetsBatch().deletedExpenses, contains('e2'));
      expect(reopened.pendingCount, 2);
    });

    test('expense ids do not restart from one after a reopen', () async {
      final AppState state = await _stateWithData(attach: true);
      state.addExpense(amount: 5000, categoryId: 'tagihan', note: 'Listrik');
      // Newest first, so the new row is at the head.
      expect(state.pendingExpenses.first.id, 'e3');

      final AppState reopened = await _reopen();
      reopened.addExpense(amount: 7000, categoryId: 'tagihan', note: 'Air');
      // A repeat of e1/e2/e3 would collide with a row already in the sheet.
      expect(reopened.pendingExpenses.first.id, 'e4');
    });
  });

  group('errors', () {
    test('a script-side error surfaces its message', () async {
      final FakeWebApp fake = FakeWebApp()..error = 'Sheet tidak ditemukan';
      final AppState state = await _stateWithData();
      final batch = state.sheetsBatch();

      await expectLater(
        SheetsSyncService(client: fake.client()).push(
          FakeWebApp.url,
          wallets: batch.wallets,
          expenses: batch.expenses,
          deletedWalletIds: batch.deletedWallets,
          deletedExpenseIds: batch.deletedExpenses,
        ),
        throwsA(
          isA<SheetsSyncException>().having(
              (SheetsSyncException e) => e.message,
              'message',
              contains('Sheet tidak ditemukan')),
        ),
      );
    });

    test('a malformed URL is rejected before any request', () async {
      final FakeWebApp fake = FakeWebApp();
      await expectLater(
        SheetsSyncService(client: fake.client()).ping('bukan-url'),
        throwsA(isA<SheetsSyncException>()),
      );
      expect(fake.pings, 0);
    });

    test('non-JSON response is reported clearly', () async {
      final service = SheetsSyncService(
        client: http_client.MockClient(
          (_) async => http.Response('<html>login</html>', 200),
        ),
      );
      await expectLater(
        service.ping(FakeWebApp.url),
        throwsA(
          isA<SheetsSyncException>().having(
            (SheetsSyncException e) => e.message,
            'message',
            contains('JSON'),
          ),
        ),
      );
    });

    test('a rejected URL is not retried', () async {
      int calls = 0;
      final service = SheetsSyncService(
        client: http_client.MockClient((http.Request req) async {
          calls++;
          return http.Response(
            jsonEncode(<String, Object?>{'ok': false, 'error': 'ditolak'}),
            200,
          );
        }),
      );
      await expectLater(
        service.ping(FakeWebApp.url),
        throwsA(isA<SheetsSyncException>()),
      );
      expect(calls, 1, reason: 'a rejection will not change on a retry');
    });

    test('ping reports the sheet greeting', () async {
      final FakeWebApp fake = FakeWebApp();
      final String message =
          await SheetsSyncService(client: fake.client()).ping(FakeWebApp.url);
      expect(fake.pings, 1);
      expect(message, 'TrackFin siap menerima data.');
    });
  });

  group('transport', () {
    // The web build cannot POST to Apps Script, so it switches to JSONP. These
    // tests pin the native half of that contract: ping must stay a GET (a POST
    // would be handled as a push and answer "OK" instead of the greeting), and
    // push must stay a POST carrying the bare payload.
    test('native keeps the plain JSON POST', () {
      expect(useJsonp, isFalse);
    });

    test('ping sends a GET carrying action=ping', () async {
      final List<http.Request> seen = <http.Request>[];
      final service = SheetsSyncService(
        client: http_client.MockClient((http.Request req) async {
          seen.add(req);
          return http.Response(
            jsonEncode(<String, Object?>{'ok': true, 'message': 'halo'}),
            200,
          );
        }),
      );

      await service.ping(FakeWebApp.url);

      expect(seen, hasLength(1));
      expect(seen.single.method, 'GET');
      expect(seen.single.url.queryParameters['action'], 'ping');
    });

    test('push sends a POST whose body is the bare payload', () async {
      final List<http.Request> seen = <http.Request>[];
      final service = SheetsSyncService(
        client: http_client.MockClient((http.Request req) async {
          seen.add(req);
          return http.Response(
            jsonEncode(<String, Object?>{
              'ok': true,
              'expenses': <String>['e1'],
              'wallets': <String>[],
              'deletedExpenses': <String>[],
              'deletedWallets': <String>[],
              'message': 'OK',
            }),
            200,
          );
        }),
      );

      final SheetsSyncResult result = await service.push(
        FakeWebApp.url,
        wallets: const <Wallet>[],
        expenses: const <Transaction>[
          Transaction(
            id: 'e1',
            amount: 25000,
            categoryId: 'makanan',
            categoryLabel: 'Makanan',
            accent: Color(0xFF123456),
            icon: 'coffee',
            walletName: 'Dompet Utama',
            title: 'Kopi',
            time: '10:00',
          ),
        ],
        deletedWalletIds: const <String>[],
        deletedExpenseIds: const <String>[],
      );

      expect(seen.single.method, 'POST');
      final Map<String, dynamic> body =
          jsonDecode(seen.single.body) as Map<String, dynamic>;
      // The script's doPost reads these straight off the body, so they must not
      // be nested under an "action"/"payload" envelope.
      expect(body.containsKey('expenses'), isTrue);
      expect(body.containsKey('action'), isFalse);
      expect(body.containsKey('payload'), isFalse);
      expect(result.expenseIds, <String>['e1']);
    });
  });
}
