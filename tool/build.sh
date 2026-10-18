#!/usr/bin/env bash
# Build KumbiaKombat for the web. Uses the local Flutter SDK when present,
# otherwise downloads a pinned SDK so Cloudflare's default `npm run build`
# works on a builder that has no Flutter.
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER_VERSION="3.47.7"
CACHE_DIR="${FLUTTER_CACHE:-$HOME/.cache/kumbia-kombat/flutter}"

if command -v flutter >/dev/null 2>&1; then
  echo "Using system flutter: $(flutter --version 2>/dev/null | head -1)"
else
  echo "flutter not on PATH; installing pinned Flutter $FLUTTER_VERSION into $CACHE_DIR"
  mkdir -p "$CACHE_DIR"
  if [ ! -x "$CACHE_DIR/flutter/bin/flutter" ]; then
    curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C "$CACHE_DIR"
  fi
  export PATH="$CACHE_DIR/flutter/bin:$PATH"
  flutter config --no-analytics >/dev/null 2>&1 || true
fi

flutter pub get
flutter build web --release --no-web-resources-cdn
echo "ok:build:build/web"
