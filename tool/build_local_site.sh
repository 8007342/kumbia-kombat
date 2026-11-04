#!/usr/bin/env bash
# Local preview site: the game at /, the sprite review gallery at /gallery/.
# The production build (tool/build.sh) never includes the gallery.
# Publish with preview.publish {category:"WEB", app_dir:"build/web", runtime:"static"}.
set -euo pipefail
cd "$(dirname "$0")/.."
GALLERY_ONLY=0
[ "${1:-}" = "--gallery-only" ] && GALLERY_ONLY=1
if [ "$GALLERY_ONLY" = 0 ]; then
  bash tool/build.sh
fi
~/.cache/kumbia-art/bin/python tool/art/gallery/build_gallery.py --out build/web/gallery
