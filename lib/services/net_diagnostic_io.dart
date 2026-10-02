import 'dart:io';

String describeNetworkError(Object error) {
  if (error is SocketException) {
    return 'Tidak ada koneksi ke server. '
        'Detail: ${error.osError?.message ?? error.message}';
  }
  if (error is HandshakeException) {
    return 'Gagal koneksi aman (TLS). Detail: ${error.message}. '
        'Cek jam dan tanggal perangkat.';
  }
  return 'Gagal menghubungi server. Detail: $error';
}
