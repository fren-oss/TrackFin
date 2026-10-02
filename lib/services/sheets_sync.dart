import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/finance.dart';
import 'jsonp_transport.dart' show JsonpTransportError, jsonpRequest, useJsonp;
import 'net_diagnostic.dart';

/// Result of one push to the Apps Script Web App.
class SheetsSyncResult {
  const SheetsSyncResult({
    required this.walletIds,
    required this.expenseIds,
    required this.removedWalletIds,
    required this.removedExpenseIds,
    this.message,
  });

  const SheetsSyncResult.ok()
      : walletIds = const <String>[],
        expenseIds = const <String>[],
        removedWalletIds = const <String>[],
        removedExpenseIds = const <String>[],
        message = null;

  /// Ids the sheet acknowledged as written.
  final List<String> walletIds;
  final List<String> expenseIds;

  /// Ids the sheet acknowledged as deleted.
  final List<String> removedWalletIds;
  final List<String> removedExpenseIds;

  final String? message;

  int get written => walletIds.length + expenseIds.length;
  int get removed => removedWalletIds.length + removedExpenseIds.length;

  bool get hasWork => written > 0 || removed > 0;
}

/// Talks to a deployed Google Apps Script Web App that appends rows to a Google
/// Sheet. No OAuth: the Web App URL is the whole configuration, and it can be
/// deployed as "Anyone with the link".
///
/// Every row carries a stable id. The script upserts on it, so re-sending an
/// expense updates its row instead of duplicating it.
class SheetsSyncService {
  SheetsSyncService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Generous because an Apps Script Web App cold start can take 15-30s on the
  /// first call after a deploy, especially right after a fresh install.
  static const Duration _timeout = Duration(seconds: 60);

  /// Ping retries once because the first call often pays the cold-start cost.
  static const int _pingAttempts = 2;

  /// Releases the underlying connection pool. The settings page owns one
  /// service and closes it on dispose.
  void close() => _client.close();

  /// Asks the script whether it is reachable. Used by the "Test connection"
  /// button so a typo in the URL surfaces immediately.
  Future<String> ping(String url) async {
    final Uri base = _requireHttpUrl(url);

    SheetsSyncException? last;
    for (int attempt = 0; attempt < _pingAttempts; attempt++) {
      try {
        final String raw = await _transport(
          () => useJsonp
              ? _jsonp(
                  base,
                  const <String, String>{'action': 'ping'},
                )
              : _get(base.replace(
                  queryParameters: const <String, String>{'action': 'ping'})),
        );
        return _parse(raw).message ?? 'Terhubung';
      } on SheetsSyncException catch (e) {
        last = e;
        if (!e.isTimeout) rethrow;
      }
    }
    throw last!;
  }

  /// Pushes one batch. The arguments come from `AppState.sheetsBatch()`.
  Future<SheetsSyncResult> push(
    String url, {
    required List<Wallet> wallets,
    required List<Transaction> expenses,
    required List<String> deletedWalletIds,
    required List<String> deletedExpenseIds,
    String? sourceWalletId,
  }) async {
    if (wallets.isEmpty &&
        expenses.isEmpty &&
        deletedWalletIds.isEmpty &&
        deletedExpenseIds.isEmpty) {
      return const SheetsSyncResult.ok();
    }

    final Map<String, Object?> payload = <String, Object?>{
      'wallets': <Map<String, Object?>>[
        for (final Wallet w in wallets)
          _walletRow(w, isSource: w.id == sourceWalletId),
      ],
      'expenses': <Map<String, Object?>>[
        for (final Transaction t in expenses) _expenseRow(t),
      ],
      'deleteWallets': deletedWalletIds,
      'deleteExpenses': deletedExpenseIds,
    };

    final _Envelope env = _parse(
      await _transport(
        () => useJsonp
            // Browsers cannot POST cross-origin to Apps Script, so the batch
            // rides along as a URL parameter instead.
            ? _jsonp(
                _requireHttpUrl(url),
                <String, String>{
                  'action': 'push',
                  'payload': jsonEncode(payload),
                },
              )
            : _post(_requireHttpUrl(url), payload),
      ),
    );
    return SheetsSyncResult(
      walletIds: env.walletIds,
      expenseIds: env.expenseIds,
      removedWalletIds: env.removedWalletIds,
      removedExpenseIds: env.removedExpenseIds,
      message: env.message,
    );
  }

  /// Maps every transport failure onto something the settings page can show.
  Future<String> _transport(Future<String> Function() send) async {
    try {
      return await send().timeout(_timeout);
    } on TimeoutException {
      throw const SheetsSyncException(
        'Server tidak menjawab dalam 60 detik. Koneksi internet mungkin '
        'lambat, atau Web App masih cold start. Coba lagi.',
        isTimeout: true,
      );
    } on SheetsSyncException {
      rethrow;
    } on JsonpTransportError catch (e) {
      throw SheetsSyncException(e.message);
    } on http.ClientException catch (e) {
      throw SheetsSyncException('Koneksi ditolak. Detail: ${e.message}');
    } catch (e) {
      throw SheetsSyncException(describeNetworkError(e));
    }
  }

  /// Native-only read. The browser always goes through JSONP instead, since
  /// Apps Script never sets the CORS headers this would need.
  Future<String> _get(Uri uri) async {
    final http.Response res = await _client.get(uri);
    return _decodeBody(res);
  }

  /// Native-only write. See [_get] for why web cannot use this.
  Future<String> _post(Uri uri, Map<String, Object?> payload) async {
    final http.Response res = await _client.post(
      uri,
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decodeBody(res);
  }

  /// Web-only counterpart of [_post] and [_get].
  Future<String> _jsonp(Uri uri, Map<String, String> params) =>
      jsonpRequest(uri, params);

  /// On native the raw body is already what we want; on web the JSONP shim
  /// has handed back the payload with the callback wrapper stripped.
  String _decodeBody(http.Response res) {
    String body;
    try {
      body = utf8.decode(res.bodyBytes);
    } on FormatException {
      body = res.body;
    }
    return _requireOk(body);
  }

  /// Wallet payload. The id is the upsert key.
  static Map<String, Object?> _walletRow(
    Wallet w, {
    required bool isSource,
  }) =>
      <String, Object?>{
        'id': w.id,
        'nama': w.name,
        'saldo': w.balance,
        'ikon': w.icon,
        'utama': w.isPrimary,
        'sumber': isSource,
      };

  /// Expense payload. [date] is sent as an ISO local timestamp so the sheet can
  /// sort and filter without extra parsing.
  static Map<String, Object?> _expenseRow(Transaction t) => <String, Object?>{
        'id': t.id,
        'tanggal': t.date?.toIso8601String(),
        'jam': t.time,
        'jumlah': t.amount,
        'kategori': t.categoryId ?? '',
        'kategoriLabel': t.categoryLabel,
        'dompetId': t.walletId ?? '',
        'dompet': t.walletName,
        'catatan': t.title,
      };

  static Uri _requireHttpUrl(String raw) {
    final String trimmed = raw.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const SheetsSyncException(
        'URL tidak valid. Tempel URL Web App dari Google Apps Script.',
      );
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const SheetsSyncException('URL harus diawali https://');
    }
    return uri;
  }

  static _Envelope _parse(String body) {
    if (_looksLikeLoginPage(body)) {
      throw const SheetsSyncException(
        'Google meminta login. Buka Deploy > Manage deployments, lalu ubah '
        '"Who has access" menjadi Anyone, lalu deploy ulang.',
      );
    }

    return _parseJson(body);
  }

  /// Google serves its sign-in page with a 200 once a request is redirected, so
  /// the status code alone cannot tell "not deployed" from "needs login".
  static bool _looksLikeLoginPage(String body) {
    final String head = body.length > 600 ? body.substring(0, 600) : body;
    return head.contains('accounts.google.com') ||
        head.contains('ServiceLogin') ||
        head.contains('Sign in - Google Accounts');
  }

  static String _requireOk(String body) {
    if (_looksLikeLoginPage(body)) {
      throw const SheetsSyncException(
        'Google meminta login. Buka Deploy > Manage deployments, lalu ubah '
        '"Who has access" menjadi Anyone, lalu deploy ulang.',
      );
    }
    return body;
  }

  static _Envelope _parseJson(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SheetsSyncException(
        'Respons bukan JSON. Web App mungkin belum di-deploy, atau versinya '
        'lama. Deploy ulang Code.gs terbaru lalu coba lagi.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const SheetsSyncException('Format respons tidak dikenali.');
    }

    if (decoded['ok'] == false) {
      throw SheetsSyncException(
        (decoded['error'] as String?) ?? 'Sinkronisasi ditolak server.',
      );
    }

    return _Envelope(
      walletIds: _ids(decoded['wallets']),
      expenseIds: _ids(decoded['expenses']),
      removedWalletIds: _ids(decoded['deletedWallets']),
      removedExpenseIds: _ids(decoded['deletedExpenses']),
      message: decoded['message'] as String?,
    );
  }

  /// The script may answer with id lists or with plain counts; both are fine.
  static List<String> _ids(Object? raw) {
    if (raw is List<dynamic>) {
      return <String>[
        for (final Object? item in raw)
          if (item != null) '$item',
      ];
    }
    return const <String>[];
  }
}

class _Envelope {
  const _Envelope({
    required this.walletIds,
    required this.expenseIds,
    required this.removedWalletIds,
    required this.removedExpenseIds,
    this.message,
  });

  final List<String> walletIds;
  final List<String> expenseIds;
  final List<String> removedWalletIds;
  final List<String> removedExpenseIds;
  final String? message;
}

/// Raised for anything the user can act on: a bad URL, a Web App that is not
/// deployed, or a script-side error.
class SheetsSyncException implements Exception {
  const SheetsSyncException(this.message, {this.isTimeout = false});

  final String message;

  /// True only for a timeout, which is the one failure worth retrying.
  final bool isTimeout;

  @override
  String toString() => message;
}
