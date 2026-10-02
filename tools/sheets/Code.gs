/**
 * TrackFin -> Google Sheets bridge.
 *
 * Deploy once, then paste the /exec URL into TrackFin > Pengaturan.
 *
 *   Extensions > Apps Script > paste this file > Save
 *   Deploy > New deployment > type "Web app"
 *   Execute as: Me     |     Who has access: Anyone
 *
 * Accepts POST with JSON:
 *   { wallets: [{id, nama, saldo, ikon, utama}],
 *     expenses: [{id, tanggal, jam, jumlah, kategori, kategoriLabel,
 *                 dompetId, dompet, catatan}],
 *     deleteWallets: [id, ...],
 *     deleteExpenses: [id, ...] }
 *
 * Every row is upserted on `id`, so re-sending the same expense updates its row
 * instead of adding a duplicate. Rows named in deleteWallets/deleteExpenses are
 * removed. GET ?action=ping is the connectivity check.
 */

var PING_MESSAGE = 'TrackFin siap menerima data.';

/** Tab names; created with headers on first write. */
var TAB_EXPENSES = 'Pengeluaran';
var TAB_WALLETS = 'Dompet';

var EXPENSE_HEADERS = [
  'ID',
  'Tanggal',
  'Jam',
  'Tanggal ISO',
  'Jumlah',
  'Kategori',
  'Kategori Label',
  'Dompet ID',
  'Dompet',
  'Catatan',
];

var WALLET_HEADERS = [
  'ID',
  'Nama',
  'Saldo',
  'Ikon',
  'Dompet Utama',
  'Dompet Sumber',
];

/**
 * GET serves two purposes: the connection test, and the browser transport.
 *
 * The web build cannot POST here because Apps Script never sends CORS headers,
 * so the browser blocks the response. JSONP is the only way around that, and
 * it works by loading the response as a <script>, which is exempt from CORS.
 * That means the payload arrives as query parameters on this GET.
 */
function doGet(e) {
  var params = (e && e.parameter) || {};
  var action = params.action || 'ping';

  if (action === 'push') {
    var payload;
    try {
      payload = JSON.parse(params.payload || '{}');
    } catch (err) {
      return respond_({ ok: false, error: 'Payload bukan JSON yang valid.' }, params.callback);
    }
    return respond_(handlePush_(payload), params.callback);
  }

  return respond_({ ok: true, message: PING_MESSAGE }, params.callback);
}

/**
 * Wraps [obj] in a JSONP callback when the client asked for one, otherwise
 * returns plain JSON for native clients.
 */
function respond_(obj, callback) {
  var body = JSON.stringify(obj);

  if (!callback || !/^[A-Za-z_$][A-Za-z0-9_$.]*$/.test(callback)) {
    // Pass the object through untouched: native needs the id lists to know
    // which rows the sheet acknowledged.
    return json_(obj);
  }

  return ContentService.createTextOutput(
    '/**/ ' + callback + '(' + body + ');'
  ).setMimeType(ContentService.MimeType.JAVASCRIPT);
}

function doPost(e) {
  var payload;
  try {
    payload = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  } catch (err) {
    return json_({ ok: false, error: 'Payload bukan JSON yang valid.' });
  }
  return json_(handlePush_(payload));
}

/** Shared by both transports. Returns the response object, never a ContentService. */
function handlePush_(payload) {
  try {
    var expenses = Array.isArray(payload.expenses) ? payload.expenses : [];
    var wallets = Array.isArray(payload.wallets) ? payload.wallets : [];
    var delExpenses = Array.isArray(payload.deleteExpenses) ? payload.deleteExpenses : [];
    var delWallets = Array.isArray(payload.deleteWallets) ? payload.deleteWallets : [];

    // Deletions run first so a re-created id does not get deleted in the same
    // batch.
    var removedExpenses = removeById_(TAB_EXPENSES, delExpenses);
    var removedWallets = removeById_(TAB_WALLETS, delWallets);

    var sheet = sheet_(TAB_EXPENSES);
    var writtenExpenses = upsert_(sheet, EXPENSE_HEADERS, expenses, expenseRow_);
    var sheetWallets = sheet_(TAB_WALLETS);
    var writtenWallets = upsert_(sheetWallets, WALLET_HEADERS, wallets, walletRow_);

    return {
      ok: true,
      expenses: writtenExpenses,
      wallets: writtenWallets,
      deletedExpenses: removedExpenses,
      deletedWallets: removedWallets,
      message: 'OK',
    };
  } catch (err) {
    return { ok: false, error: String(err && err.message ? err.message : err) };
  }
}

/** Lazily create the tab and write the header row when the sheet is empty. */
function sheet_(name) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(name);
  if (!sheet) sheet = ss.insertSheet(name);
  return sheet;
}

function ensureHeader_(sheet, headers) {
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
  }
}

function expenseRow_(r) {
  var iso = r.tanggal || '';
  var tanggal = iso ? Utilities.formatDate(new Date(iso), 'Asia/Jakarta', 'dd/MM/yyyy') : '';
  return [
    String(r.id || ''),
    tanggal,
    String(r.jam || ''),
    iso,
    Number(r.jumlah) || 0,
    String(r.kategori || ''),
    String(r.kategoriLabel || ''),
    String(r.dompetId || ''),
    String(r.dompet || ''),
    String(r.catatan || ''),
  ];
}

function walletRow_(r) {
  return [
    String(r.id || ''),
    String(r.nama || ''),
    Number(r.saldo) || 0,
    String(r.ikon || ''),
    r.utama ? 'YA' : '',
    r.sumber ? 'YA' : '',
  ];
}

/**
 * Writes [rows], updating in place any row whose column A already matches the
 * incoming id. Returns the ids that are now present.
 */
function upsert_(sheet, headers, rows, toRow) {
  if (!rows.length) return [];
  ensureHeader_(sheet, headers);

  var existing = indexById_(sheet);
  // Every id in the batch, whether it was updated in place or appended: the
  // app treats a returned id as "the sheet agrees with this row now".
  var touched = [];
  var appended = [];

  for (var i = 0; i < rows.length; i++) {
    var id = String(rows[i].id || '');
    if (!id) continue;
    var values = toRow(rows[i]);
    if (existing[id] !== undefined) {
      sheet.getRange(existing[id], 1, 1, values.length).setValues([values]);
    } else {
      appended.push(values);
    }
    touched.push(id);
  }

  if (appended.length) {
    var lastRow = sheet.getLastRow();
    sheet
      .getRange(lastRow + 1, 1, appended.length, appended[0].length)
      .setValues(appended);
  }

  return touched;
}

/** Maps column A values to their 1-based row number. */
function indexById_(sheet) {
  var map = {};
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return map;
  var ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    var id = String(ids[i][0] || '');
    if (id) map[id] = i + 2;
  }
  return map;
}

/** Deletes every row whose column A matches one of [ids]. Returns the ids found. */
function removeById_(tabName, ids) {
  if (!ids.length) return [];
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(tabName);
  if (!sheet) return [];

  var index = indexById_(sheet);
  // Keep each id paired with its row number, then delete from the bottom so the
  // row numbers gathered earlier stay valid.
  var targets = [];
  for (var i = 0; i < ids.length; i++) {
    var id = String(ids[i]);
    if (index[id] !== undefined) targets.push({ row: index[id], id: id });
  }
  targets.sort(function (a, b) {
    return b.row - a.row;
  });

  var removed = [];
  for (var j = 0; j < targets.length; j++) {
    removed.push(targets[j].id);
    sheet.deleteRow(targets[j].row);
  }
  return removed;
}

/** Apps Script cannot send a plain object, so JSON goes out as text. */
function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(
    ContentService.MimeType.JSON
  );
}