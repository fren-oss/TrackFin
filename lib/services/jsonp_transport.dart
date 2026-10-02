import 'jsonp_transport_io.dart'
    if (dart.library.js_interop) 'jsonp_transport_web.dart' as impl;

/// Raised when the script never calls back, which almost always means the Web
/// App is not deployed or is not reachable by anonymous callers.
class JsonpTransportError implements Exception {
  const JsonpTransportError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Whether this platform must use JSONP instead of a plain POST.
///
/// Native clients can POST to Apps Script freely. Browsers cannot, because the
/// response carries no CORS headers, so `true` only on web.
bool get useJsonp => impl.useJsonp;

/// Sends [params] as a GET and resolves with the JSON body the script returned.
Future<String> jsonpRequest(Uri uri, Map<String, String> params) =>
    impl.jsonpRequest(uri, params);
