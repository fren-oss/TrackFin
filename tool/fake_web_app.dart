// A stand-in for the Apps Script Web App, used to verify the web build's JSONP
// transport in a real browser.
//
// It follows the same contract as tools/sheets/Code.gs: read `action` and
// `payload` from the query string, and when a `callback` is present, wrap the
// reply so the browser evaluates it.
//
// Serving this from a different port than the app is deliberate: the browser
// blocks cross-origin reads, which is the whole problem JSONP solves. If this
// worked same-origin it would prove nothing.
//
// Usage: dart tool/fake_web_app.dart [port]

import 'dart:convert';
import 'dart:io';

const int defaultPort = 8898;

Future<void> main(List<String> args) async {
  final int port = args.isEmpty ? defaultPort : int.parse(args.first);
  final HttpServer server =
      await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('fake Web App listening on http://localhost:$port');

  await for (final HttpRequest request in server) {
    try {
      await _route(request);
    } catch (error) {
      stderr.writeln('error handling ${request.uri}: $error');
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}

Future<void> _route(HttpRequest request) async {
  final String path = request.uri.path;
  stdout.writeln('${request.method} $path');

  // Same-origin control endpoint, so a test can read back what it sent.
  if (path == '/received') {
    return _json(request, <String, Object?>{'ok': true});
  }

  // A plain JSON asset: loading this as a script cannot call our callback,
  // which is the failure the transport has to surface instead of hanging.
  if (path == '/not_jsonp') {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{"ok": true, "message": "halo"}');
    return request.response.close();
  }

  final Map<String, Object?> payload = _payload(request.uri);

  if (payload['action'] == 'ping') {
    return _json(request, <String, Object?>{
      'ok': true,
      'message': 'TrackFin siap menerima data.',
    });
  }

  if (payload['action'] == 'push') {
    return _json(request, <String, Object?>{
      'ok': true,
      'expenses': const <String>[],
      'wallets': const <String>[],
      // Echo the deletions so the test can prove the batch survived the trip.
      'deletedExpenses': payload['deleteExpenses'] ?? const <String>[],
      'deletedWallets': payload['deleteWallets'] ?? const <String>[],
      'message': 'OK',
    });
  }

  request.response.statusCode = HttpStatus.notFound;
  return request.response.close();
}

/// Mirrors Code.gs: a callback turns the reply into executable JavaScript.
Future<void> _json(HttpRequest request, Map<String, Object?> body) async {
  final String encoded = jsonEncode(body);
  final String? callback = request.uri.queryParameters['callback'];

  if (callback == null || callback.isEmpty) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(encoded);
    return request.response.close();
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType =
        ContentType('application', 'javascript', charset: 'utf-8')
    // The leading comment neutralises any "Warning:" banner the host prepends,
    // which would otherwise be a JavaScript syntax error.
    ..write('/**/ $callback($encoded);');
  return request.response.close();
}

Map<String, Object?> _payload(Uri uri) {
  final Map<String, Object?> merged = <String, Object?>{
    'action': uri.queryParameters['action'],
  };
  final String? raw = uri.queryParameters['payload'];
  if (raw != null && raw.isNotEmpty) {
    merged.addAll(jsonDecode(raw) as Map<String, Object?>);
  }
  return merged;
}
