// Real-browser check for the web build's Sheets transport.
//
// Flutter's `http` package cannot call Apps Script from a browser because the
// response carries no CORS headers, so the web build goes through JSONP. That
// path only runs on web and touches the DOM, so testing it on the VM would test
// nothing. This runs in Chrome against a fake Web App on another origin.
//
// Requires the fake app to be running:
//   dart tool/fake_web_app.dart
//
// Then:
//   flutter test --platform chrome test/sheets_sync_web_test.dart

@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:trackfin/models/finance.dart';
import 'package:trackfin/services/sheets_sync.dart';

const String kFakeApp = 'http://localhost:8898/webapp';

void main() {
  group('JSONP transport', () {
    test('ping reaches the script and returns its greeting', () async {
      final SheetsSyncService service = SheetsSyncService();
      addTearDown(service.close);

      expect(await service.ping(kFakeApp), 'TrackFin siap menerima data.');
    });

    test('push survives the trip as query parameters', () async {
      final SheetsSyncService service = SheetsSyncService();
      addTearDown(service.close);

      final SheetsSyncResult result = await service.push(
        kFakeApp,
        wallets: const <Wallet>[],
        expenses: const <Transaction>[],
        deletedWalletIds: const <String>['w1'],
        deletedExpenseIds: const <String>['e1'],
      );

      // The fake echoes the deletions back, which only happens if the whole
      // batch arrived as a URL parameter and the callback came back.
      expect(result.removedExpenseIds, <String>['e1']);
      expect(result.removedWalletIds, <String>['w1']);
      expect(result.message, 'OK');
    });

    test('a response that never calls back is reported, not hung on', () async {
      final SheetsSyncService service = SheetsSyncService();
      addTearDown(service.close);

      // This endpoint answers plain JSON, so loading it as a script will never
      // invoke our callback. The transport has to notice and give up.
      await expectLater(
        service.ping('http://localhost:8898/not_jsonp'),
        throwsA(isA<SheetsSyncException>()),
      );
    });

    test('an unreachable host is reported', () async {
      final SheetsSyncService service = SheetsSyncService();
      addTearDown(service.close);

      await expectLater(
        service.ping('http://localhost:9997/dead'),
        throwsA(isA<SheetsSyncException>()),
      );
    });
  });
}
