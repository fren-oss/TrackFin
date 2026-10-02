#!/usr/bin/env bash
#
# Build command for Vercel.
#
# Vercel's default build image does not ship Flutter, and an anonymous
# `vercel --temporary` build runs with a bare `sh` that has no Flutter either.
# This script uses the SDK when it is already present and only downloads it when
# it is not, so local test deploys stay fast.
#
# Requires FAILED_BUILD or SKIP_FLUTTER_INSTALL to opt out entirely.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.5}"
INSTALL_DIR="${FLUTTER_INSTALL_DIR:-$HOME/flutter}"

# Prefer an SDK already on PATH so repeated deploys do not re-download.
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
elif [ -x "$INSTALL_DIR/bin/flutter" ]; then
  FLUTTER_BIN="$INSTALL_DIR/bin/flutter"
else
  echo "Flutter $FLUTTER_VERSION not found, downloading..."
  ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$ARCHIVE"

  curl -fsSL "$URL" -o "/tmp/$ARCHIVE"
  tar -xf "/tmp/$ARCHIVE" -C "$(dirname "$INSTALL_DIR")"
  rm -f "/tmp/$ARCHIVE"

  FLUTTER_BIN="$INSTALL_DIR/bin/flutter"
fi

export PATH="$(dirname "$FLUTTER_BIN"):$PATH"

echo "Using $("$FLUTTER_BIN" --version | head -1)"

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build web --release

# The CanvasKit folder is fetched from our own origin rather than gstatic, so
# the deployed PWA does not need a CDN at runtime.
test -f build/web/canvaskit/canvaskit.js || {
  echo "ERROR: canvaskit.js missing from the build output" >&2
  exit 1
}

echo "Build complete: $(du -sh build/web | cut -f1)"