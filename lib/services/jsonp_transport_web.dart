import 'dart:async';
import 'dart:js_interop';
// Gives JSObject its getProperty/setProperty/delete/callMethod members.
// ignore: depend_on_referenced_packages
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'jsonp_transport.dart' show JsonpTransportError;

/// Browsers block cross-origin XHR/fetch responses that lack CORS headers, and
/// Apps Script never sends any. JSONP sidesteps this: a `<script>` tag is not
/// subject to CORS, so the script's response can call a global function we
/// install first. The cost is that the payload travels in the URL, which is why
/// native keeps using POST.
const bool useJsonp = true;

/// GETs [uri] with [params] plus a `callback` parameter, resolving once the
/// script invokes that callback.
Future<String> jsonpRequest(Uri uri, Map<String, String> params) {
  final Completer<String> completer = Completer<String>();

  // Random suffix avoids colliding with anything else on the page.
  final String callbackName =
      '__trackfinJsonp_${DateTime.now().microsecondsSinceEpoch}';

  void resolve(JSAny? payload) {
    if (completer.isCompleted) return;
    completer.complete(_stringify(payload));
  }

  _global.setProperty(callbackName.toJS, resolve.toJS);

  /// Script-level cleanup: remove the tag and the global even on failure.
  void cleanup() {
    final web.Element? tag = web.document.getElementById(callbackName);
    tag?.remove();
    _global.delete(callbackName.toJS);
  }

  final web.HTMLScriptElement script =
      web.document.createElement('script') as web.HTMLScriptElement
        ..id = callbackName
        ..type = 'application/javascript'
        ..charset = 'utf-8'
        ..src = _withCallback(uri, params, callbackName).toString();

  script.onLoad.listen((_) {
    // Reaching onLoad without the callback firing means the script replied with
    // something that never called us (a login page, most likely).
    if (!completer.isCompleted) {
      cleanup();
      completer.completeError(
        const JsonpTransportError(
          'Server tidak mengirim balasan yang valid. Web App mungkin belum '
          'di-deploy, atau deployment-nya masih meminta login.',
        ),
      );
    }
  });

  script.onError.listen((_) {
    if (!completer.isCompleted) {
      cleanup();
      completer.completeError(
        const JsonpTransportError(
          'Gagal memuat URL Apps Script. Periksa URL, koneksi internet, dan '
          'status deployment.',
        ),
      );
    }
  });

  web.document.head!.appendChild(script);

  // Hard stop in case neither event fires.
  return completer.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () {
      cleanup();
      throw const JsonpTransportError(
        'Waktu habis saat menghubungi server.',
      );
    },
  ).whenComplete(cleanup);
}

final JSObject _global = globalContext;

/// The script hands us an object; the rest of the app wants raw JSON text.
String _stringify(JSAny? value) {
  final JSAny? json = _global.getProperty<JSAny?>('JSON'.toJS);
  if (json == null || !json.isA<JSObject>()) return '{}';
  final JSAny? result = (json as JSObject).callMethod('stringify'.toJS, value);
  return (result as JSString?)?.toDart ?? '{}';
}

Uri _withCallback(
  Uri base,
  Map<String, String> params,
  String callback,
) {
  return base.replace(
    queryParameters: <String, String>{...params, 'callback': callback},
  );
}
