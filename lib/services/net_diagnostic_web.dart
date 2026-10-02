/// Web has no `dart:io`: the browser's fetch layer raises its own error types
/// that are not worth pattern-matching here. Surfacing the message is enough.
String describeNetworkError(Object error) {
  return 'Gagal menghubungi server. Detail: $error';
}
