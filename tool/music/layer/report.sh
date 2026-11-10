#!/usr/bin/env bash
# Measures every rendered .ogg of the named levels, one line each, with gate failures.
#   tool/music/layer/report.sh bar cool-crowd
# The measures are `mixrs measure` (tool/music/mixrs/src/layer.rs), built if it isn't.
set -u
cd "$(dirname "$0")/../../.."
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$HOME/.cache/tillandsias-project/cargo/target}
cargo build --release --quiet -j 4 --manifest-path tool/music/mixrs/Cargo.toml || exit 2
files=()
for l in "$@"; do files+=(assets/music/rendered/$l/*.ogg); done
"$CARGO_TARGET_DIR/release/mixrs" measure "${files[@]}" | jq -r '
  "\(.file | split("/")[-2:] | join("/") | . + " " * (30 - length)) corr \(.corr) neg \(.negWindows * 100 | round)% clip \(.clipRuns) drop \(.dropouts) cent \(.centroidHz) bass \(.bassDb) on/s \(.onsetsPerS) lufs \(.lufs) \(.fails | join("; "))"'
exit "${PIPESTATUS[0]}"
