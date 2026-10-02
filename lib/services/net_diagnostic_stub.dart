/// Fallback for platforms that provide neither `dart:io` nor `dart:js_interop`.
String describeNetworkError(Object error) {
  return 'Gagal menghubungi server. Detail: $error';
}
