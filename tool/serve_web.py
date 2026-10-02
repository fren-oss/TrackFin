#!/usr/bin/env python3
"""Serves build/web for local testing with caching disabled.

The default http.server lets Chrome keep a stale main.dart.js, which makes code
changes look like they had no effect. During development that is worse than
useless, so every response is marked no-store.
"""

import functools
import http.server
import os
import socketserver
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(HERE), 'build', 'web')
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def send_header(self, keyword, value):
        # SimpleHTTPRequestHandler sets Last-Modified; it makes the browser
        # revalidate against a 304 and we would rather it not cache at all.
        if keyword == 'Last-Modified':
            return
        super().send_header(keyword, value)

    def log_message(self, fmt, *args):
        sys.stderr.write('%s - %s\n' % (self.address_string(), fmt % args))


if not os.path.isdir(ROOT):
    sys.exit('build/web not found. Run: flutter build web --release')

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(
    ('', PORT),
    functools.partial(NoCacheHandler, directory=ROOT),
) as httpd:
    print('TrackFin dev server on http://localhost:%d (caching disabled)' % PORT)
    httpd.serve_forever()