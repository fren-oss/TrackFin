import 'net_diagnostic_stub.dart'
    if (dart.library.io) 'net_diagnostic_io.dart'
    if (dart.library.js_interop) 'net_diagnostic_web.dart' as impl;

/// Turns a low-level transport failure into something a person can act on.
///
/// The concrete exception types differ per platform (`SocketException` only
/// exists on native, `XmlHttpRequest`-backed errors only on web), so the
/// classification lives behind conditional imports and web never has to
/// reference `dart:io`.
String describeNetworkError(Object error) => impl.describeNetworkError(error);
