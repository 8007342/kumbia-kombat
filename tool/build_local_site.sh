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
  # Candidate atlases under review, listed one per line. Local builds only.
  if [ -s tool/local_preview_candidates.txt ]; then
    mapfile -t CANDIDATES < tool/local_preview_candidates.txt
    python3 tool/art/pipeline/preview_candidate.py "${CANDIDATES[@]}"
  fi
fi
~/.cache/kumbia-art/bin/python tool/art/gallery/build_gallery.py --out build/web/gallery
