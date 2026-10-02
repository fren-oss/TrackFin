/// Native keeps the plain JSON POST, which is faster and avoids URL length
/// limits. See [jsonp_transport_web.dart] for why web cannot do this.
const bool useJsonp = false;

Future<String> jsonpRequest(Uri uri, Map<String, String> params) {
  throw StateError('JSONP is only available on the web build.');
}
