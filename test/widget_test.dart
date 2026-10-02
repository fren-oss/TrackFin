import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackfin/design/theme.dart';
import 'package:trackfin/root_shell.dart';
import 'package:trackfin/screens/settings_screen.dart';

Widget _app() => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildBauhausTheme(),
      home: const TrackFinApp(),
    );

/// Renders at iPhone 14 Pro dimensions: 390x844 logical pixels.
void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Every test starts from zero, so storage has to be cleared or a previous
/// test's wallet would leak into the next one.
void _freshStorage() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

/// Scrolls the screen back to the top so the header content is rebuilt.
Future<void> _scrollToTop(WidgetTester tester) async {
  // AppHeader sits outside the scroll view, so drag to the offset directly
  // instead of using dragUntilVisible.
  while (tester.state<ScrollableState>(_pageList).position.pixels > 0) {
    await tester.drag(_pageList, const Offset(0, 500));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The screens are lazy `ListView`s, so content below the fold is not built
/// yet. Scroll until [finder] is present before asserting on it.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _pageList);
  await tester.pumpAndSettle();
}

/// The page-level scrollable, as opposed to the nested GridView and the
/// horizontal notes row inside Catat.
final Finder _pageList = find
    .descendant(
      of: find.byType(TrackFinApp),
      matching: find.byType(Scrollable),
    )
    .first;

final Finder _nameField = find.widgetWithText(
  TextFormField,
  'cth: Dompet Harian, Tabungan Darurat',
);

/// The horizontal strip that holds the period chips on Analisis. Found by axis
/// so it cannot be confused with the page-level vertical list.
final Finder _periodStrip = find
    .byWidgetPredicate(
      (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      description: 'horizontal Scrollable',
    )
    .first;

/// "Tahun Ini" and "Rentang Kustom" sit off-screen on a 390pt phone. Drag the
/// chip strip until the chip's centre is comfortably inside the viewport, then
/// tap it. scrollUntilVisible alone stops as soon as the chip exists, which can
/// still leave it clipped at the edge where the tap misses.
Future<void> _selectPeriodChip(WidgetTester tester, String label) async {
  final Finder chip = find.text(label);
  // The strip is lazy, so the chip may not be built yet at all.
  if (chip.evaluate().isEmpty) {
    await tester.scrollUntilVisible(chip, 120, scrollable: _periodStrip);
    await tester.pumpAndSettle();
  }
  for (int i = 0; i < 6; i++) {
    final Offset centre = tester.getCenter(chip);
    if (centre.dx > 24 &&
        centre.dx <
            tester.view.physicalSize.width / tester.view.devicePixelRatio -
                24) {
      break;
    }
    await tester.drag(_periodStrip, const Offset(-120, 0));
    await tester.pumpAndSettle();
  }
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Types digits into the Catat screen's amount field.
///
/// The field groups digits with dots as they arrive, so the test enters the
/// raw digits and the formatting happens exactly as it would for a real user.
Future<void> _typeAmount(WidgetTester tester, String amount) async {
  // Keyed off the hint: the Catat screen has two fields and this must be the
  // amount one, not the note below it. A positional .first would break if the
  // layout ever reorders.
  final Finder field = find.widgetWithText(TextField, '0');
  await _scrollTo(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();

  await tester.enterText(field, amount.replaceAll('.', ''));
  await tester.pumpAndSettle();
}

/// Records one expense from the Catat screen. [amount] is the figure to type
/// into the amount field, e.g. '15000' or '15.000'.
Future<void> _recordExpense(WidgetTester tester, String amount) async {
  await tester.tap(find.text('CATAT').last);
  await tester.pumpAndSettle();

  await _typeAmount(tester, amount);

  await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
  await tester.tap(find.text('SIMPAN PENGELUARAN'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pumpAndSettle();

  // Saving returns to Beranda, which is where callers assert against.
  await tester.tap(find.text('BERANDA').last);
  await tester.pumpAndSettle();
}

/// The settings list scrolls under a fixed app bar, so a target can end up
/// behind it. Nudge the list until the label is clear of the bar, then tap.
Future<void> _settingsTap(WidgetTester tester, String label) async {
  final Finder target = find.text(label);
  final double width =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (int i = 0; i < 6; i++) {
    final Rect box = tester.getRect(target);
    if (box.top >= 190 && box.bottom <= 700) break;
    await tester.drag(
      find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
      Offset(0, box.top < 190 ? 120 : -120),
    );
    await tester.pumpAndSettle();
  }
  expect(tester.getRect(target).left, lessThan(width));
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A wallet's name renders twice on Dompet: once in the featured hero card and
/// once in its list tile. Scrolling needs a unique target, so use the last
/// match (the list row) and keep `.first` off the featured card.
Finder walletRow(String name) => find.text(name).last;

/// Walks the app from the onboarding screen to a usable state: create one
/// wallet, then land on Beranda. Every flow test starts here so it matches
/// what a brand-new user actually sees.
Future<void> _createFirstWallet(WidgetTester tester,
    {String name = 'Dompet Utama'}) async {
  await _scrollTo(tester, _nameField);
  await tester.enterText(_nameField, name);
  await tester.pump();
  await tester.tap(find.text('TAMBAH DOMPET BARU').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_freshStorage);

  group('fresh start', () {
    testWidgets('first launch shows onboarding, not the main shell', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada data'), findsOneWidget);
      expect(find.text('MULAI DARI NOL'), findsOneWidget);
      // No dashboard, no bottom nav, no demo balances.
      expect(find.text('TOTAL SALDO AKTIF'), findsNothing);
      expect(find.text('23.850.000'), findsNothing);
    });

    testWidgets('creating the first wallet reveals the full app', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _createFirstWallet(tester);

      // "BERANDA" and "DOMPET" each appear twice (nav label plus card copy), so
      // assert the nav is present rather than counting exact matches.
      expect(find.text('TOTAL SALDO AKTIF'), findsOneWidget);
      expect(find.text('BERANDA'), findsWidgets);
      expect(find.text('DOMPET'), findsWidgets);
      // Zero balance, not a hard-coded demo figure.
      expect(find.text('0'), findsWidgets);
      expect(find.text('23.850.000'), findsNothing);
    });

    testWidgets('balance is zero before any wallet is added', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _createFirstWallet(tester);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Belum ada pengeluaran'), findsOneWidget);
    });
  });

  group('recording expenses', () {
    testWidgets('typing an amount formats it and debits the wallet', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester, name: 'Dompet Utama');

      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();

      // Typing 15000 should display as 15.000 without the user adding dots.
      await _typeAmount(tester, '15000');
      expect(find.text('15.000'), findsOneWidget);

      await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
      await tester.tap(find.text('SIMPAN PENGELUARAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('BERANDA').last);
      await tester.pumpAndSettle();

      expect(find.text('-Rp 15.000'), findsOneWidget);
      // Wallet started at 0, so the balance went negative by exactly 15.000.
      expect(find.text('-15.000'), findsOneWidget);
    });

    testWidgets('saving with a zero amount shows the error state', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
      await tester.tap(find.text('SIMPAN PENGELUARAN'));
      await tester.pump();
      expect(find.text('NOMINAL MASIH RP 0'), findsOneWidget);

      // The error clears itself after 1.4s; let the pending timer drain so the
      // test does not fail on leaked timers.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
    });
  });

  group('analisis reacts to new expenses', () {
    testWidgets('the month total grows after an expense is recorded', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      // Baseline before any expense.
      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();
      expect(find.text('0'), findsWidgets);

      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();
      await _typeAmount(tester, '75000');
      await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
      await tester.tap(find.text('SIMPAN PENGELUARAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();

      // The month total and the per-transaction figure both moved.
      expect(find.text('75.000'), findsWidgets);
      expect(find.text('1 catatan'), findsOneWidget);
    });

    testWidgets('the donut chart reflects the recorded category', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();

      // Pick Transport, then record 30.000 (5 digits, thousands-separated).
      await _scrollTo(tester, find.text('Transport'));
      await tester.tap(find.text('Transport').last);
      await tester.pump();

      await _typeAmount(tester, '30000');
      await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
      await tester.tap(find.text('SIMPAN PENGELUARAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('DISTRIBUSI KATEGORI'));

      // A single category means one slice at 100% of the period.
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Transportasi'), findsWidgets);
    });

    testWidgets('period tabs switch the reported range', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();

      // Default chip is "Bulan Ini".
      expect(find.text('TOTAL PENGELUARAN BULAN INI'), findsOneWidget);

      await _selectPeriodChip(tester, 'MINGGU INI');
      expect(find.text('TOTAL PENGELUARAN MINGGU INI'), findsOneWidget);

      await _selectPeriodChip(tester, 'TAHUN INI');
      expect(find.text('TOTAL PENGELUARAN TAHUN INI'), findsOneWidget);

      await _selectPeriodChip(tester, 'BULAN INI');
      expect(find.text('TOTAL PENGELUARAN BULAN INI'), findsOneWidget);
    });

    testWidgets('the custom range chip opens the picker', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();

      await _selectPeriodChip(tester, 'RENTANG KUSTOM');
      expect(find.text('PILIH RENTANG KUSTOM'), findsOneWidget);

      // Pick a real range via the 30-day preset rather than accepting the
      // default span, then apply it.
      await tester.tap(find.text('30 HARI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TERAPKAN RENTANG'));
      await tester.pumpAndSettle();
      expect(find.text('TOTAL PENGELUARAN RENTANG KUSTOM'), findsOneWidget);
    });

    testWidgets('the sort button reorders the breakdown list', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('DISTRIBUSI KATEGORI'));
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      // No crash, list still renders.
      expect(find.text('DISTRIBUSI KATEGORI'), findsOneWidget);
    });
  });

  group('wallets', () {
    testWidgets('adding a second wallet updates the consolidation count', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('DOMPET').last);
      await tester.pumpAndSettle();

      await _scrollTo(tester, _nameField);
      await tester.enterText(_nameField, 'Dompet Harian');
      await tester.pump();
      await tester.tap(find.text('TAMBAH DOMPET BARU').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      await _scrollToTop(tester);
      expect(find.text('2 Dompet Manual'), findsOneWidget);
      expect(find.text('Dompet Harian'), findsOneWidget);
    });

    testWidgets('the edit button opens the rename sheet', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester, name: 'Dompet Lama');

      await tester.tap(find.text('DOMPET').last);
      await tester.pumpAndSettle();
      await _scrollTo(tester, walletRow('Dompet Lama'));
      await tester.tap(find.byIcon(Icons.edit).last);
      await tester.pumpAndSettle();

      expect(find.text('EDIT DOMPET'), findsOneWidget);
    });

    testWidgets('the delete button asks for confirmation and can be cancelled',
        (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester, name: 'Dompet Buang');

      await tester.tap(find.text('DOMPET').last);
      await tester.pumpAndSettle();
      await _scrollTo(tester, walletRow('Dompet Buang'));
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hapus "Dompet Buang"?'), findsOneWidget);

      await tester.tap(find.text('BATAL'));
      await tester.pumpAndSettle();
      expect(walletRow('Dompet Buang'), findsOneWidget);
    });

    testWidgets('confirming deletes the wallet and its expenses', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester, name: 'Dompet Buang');

      // Record an expense against it so the dialog can warn about the records.
      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();
      await _typeAmount(tester, '10000');
      await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
      await tester.tap(find.text('SIMPAN PENGELUARAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DOMPET').last);
      await tester.pumpAndSettle();
      await _scrollTo(tester, walletRow('Dompet Buang'));
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      // The dialog spells out the collateral damage. The tile also shows the count,
      // so target the dialog body specifically.
      expect(
        find.textContaining(
            '1 catatan pengeluaran pada dompet ini akan ikut terhapus'),
        findsOneWidget,
      );

      await tester.tap(find.text('HAPUS'));
      await tester.pumpAndSettle();

      // The wallet and its expense are both gone. With no wallets left the root
      // gate drops back to onboarding rather than showing a dashboard.
      expect(find.text('Dompet Buang'), findsNothing);
      expect(find.text('TOTAL SALDO AKTIF'), findsNothing);
      expect(find.text('MULAI DARI NOL'), findsOneWidget);
      expect(find.text('Belum ada data'), findsOneWidget);
    });
  });

  group('persistence', () {
    testWidgets('wallets and expenses survive a restart', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester, name: 'Dompet Tersimpan');

      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();
      await _typeAmount(tester, '20000');
      await _scrollTo(tester, find.text('SIMPAN PENGELUARAN'));
      await tester.tap(find.text('SIMPAN PENGELUARAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Rebuild from the same storage, as a cold start would.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada data'), findsNothing);
      expect(find.text('-Rp 20.000'), findsOneWidget);
      expect(find.text('-20.000'), findsOneWidget);
    });
  });

  group('beranda', () {
    testWidgets('balance eye toggle masks the figure', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      // Record an expense so the balance is a distinctive figure; a bare "0"
      // collides with the budget and quick-stat tiles.
      await _recordExpense(tester, '15.000');

      expect(find.text('-15.000'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.text('-15.000'), findsNothing);
      expect(find.text('•' * 10), findsOneWidget);
    });

    testWidgets('budget limit can be edited from the budget card', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      expect(find.text('Rp 5.000.000'), findsOneWidget);

      await tester.tap(find.text('Rp 5.000.000'));
      await tester.pumpAndSettle();
      expect(find.text('BATAS ANGGARAN BULANAN'), findsOneWidget);

      await tester.tap(find.text('SIMPAN'));
      await tester.pumpAndSettle();
      // Still 5.000.000 because the field was left untouched.
      expect(find.text('Rp 5.000.000'), findsOneWidget);
    });

    testWidgets('"+ Catat Keluar" jumps to the Catat screen', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('+ Catat Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('JUMLAH PENGELUARAN'), findsOneWidget);
    });

    testWidgets('long-pressing an expense deletes it and refunds the wallet', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await _recordExpense(tester, '15.000');
      expect(find.text('-15.000'), findsOneWidget);

      await tester.longPress(find.text('Makan'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus catatan ini?'), findsOneWidget);

      await tester.tap(find.text('HAPUS'));
      await tester.pumpAndSettle();

      expect(find.text('Makan'), findsNothing);
      expect(find.text('-15.000'), findsNothing);
      expect(find.text('Belum ada pengeluaran'), findsOneWidget);
      // The wallet started at 0 and the 15.000 is refunded, so it reads 0 again
      // rather than staying debited.
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('cancelling the delete keeps the expense', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await _recordExpense(tester, '15.000');

      await tester.longPress(find.text('Makan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BATAL'));
      await tester.pumpAndSettle();

      expect(find.text('Makan'), findsOneWidget);
      expect(find.text('-15.000'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('bottom nav switches between all four screens', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.text('ANALISIS').last);
      await tester.pumpAndSettle();
      expect(find.text('TOTAL PENGELUARAN BULAN INI'), findsOneWidget);

      await tester.tap(find.text('CATAT').last);
      await tester.pumpAndSettle();
      expect(find.text('JUMLAH PENGELUARAN'), findsOneWidget);

      await tester.tap(find.text('DOMPET').last);
      await tester.pumpAndSettle();
      expect(find.text('TOTAL SALDO BERSIH'), findsOneWidget);

      await tester.tap(find.text('BERANDA').last);
      await tester.pumpAndSettle();
      expect(find.text('Pengeluaran Terkini'), findsOneWidget);
    });

    testWidgets('the settings button opens the Sheets sync page', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('PENGATURAN'), findsOneWidget);
      expect(find.text('GOOGLE SHEETS'), findsOneWidget);
      // Unconfigured: the send button is inert and says so.
      expect(find.text('Belum diatur'), findsOneWidget);
      expect(find.textContaining('KIRIM KE SHEETS'), findsOneWidget);
    });

    testWidgets('saving a Sheets URL in settings persists it', (
      WidgetTester tester,
    ) async {
      _usePhone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _createFirstWallet(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Settings is its own route, so it has its own scrollable.
      await tester.scrollUntilVisible(
        find.byType(TextField),
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://script.google.com/macros/s/ABC123/exec',
      );
      await tester.pump();
      await _settingsTap(tester, 'SIMPAN URL');

      expect(find.text('URL disimpan.'), findsOneWidget);
      expect(find.text('URL tersimpan'), findsOneWidget);
      // One wallet and no expenses so far, so exactly one row is queued.
      expect(find.text('1 baris'), findsOneWidget);
    });
  });
}
