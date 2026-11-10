#!/usr/bin/env bash
# The Rust ports of tool/music/layer/{measure,lag,room}.py against the Python's own
# outputs on two rooms (bar and salón), captured 2026-11-10 before the .py were deleted.
#
#   tool/music/mixrs/compare/layer_golden.sh [MIXRS]
#
# Exact, except one thing: the rendered .ogg files are decoded by ffmpeg here and were
# decoded by libsndfile in Python, so on those the click count (informational, not a
# gate) may differ by a few in ten thousand. Every file measured as decoded WAV matched
# to the last digit, the bar's high.ogg included. Files under the layered cache
# (~/.cache/…/layered-20261109) are skipped, and said so, when that cache is missing.
set -u
cd "$(dirname "$0")/../../../.."
here=tool/music/mixrs/compare/golden/layer
bin=${1:-${MIXRS:-${CARGO_TARGET_DIR:-$HOME/.cache/tillandsias-project/cargo/target}/release/mixrs}}
[ -x "$bin" ] || { echo "no mixrs at $bin: cargo build --release in tool/music/mixrs"; exit 2; }
cache=$HOME/.cache/tillandsias-project/kumbia-audio/layered-20261109
scratch=$(mktemp -d)
trap 'rm -r "$scratch"' EXIT
bad=0
ok() { echo "ok   $*"; }
no() { echo "FAIL $*"; bad=1; }

# measure: every field but the path, which the golden writes with ~.
while IFS= read -r want; do
  file=$(jq -r .file <<<"$want")
  path=${file/#\~/$HOME}
  [ -f "$path" ] || { echo "skip measure $file (missing)"; continue; }
  got=$("$bin" measure "$path")
  a=$(jq -cS 'del(.file)' <<<"$want"); b=$(jq -cS 'del(.file)' <<<"$got")
  if [ "$a" = "$b" ]; then ok "measure $file"; continue; fi
  if [[ $file == *.ogg ]] && [ "$(jq -cS 'del(.file,.clicks)' <<<"$want")" = "$(jq -cS 'del(.file,.clicks)' <<<"$got")" ]; then
    c1=$(jq .clicks <<<"$want"); c2=$(jq .clicks <<<"$got")
    if (( (c1 > c2 ? c1 - c2 : c2 - c1) * 1000 <= c1 )); then ok "measure $file (clicks $c1 vs $c2: decoder)"; continue; fi
  fi
  no "measure $file"; echo "  want $a"; echo "  got  $b"
done < "$here/measure.jsonl"

# lag: the ms each stretched tier sits from mid.
while read -r room tier ratio want; do
  [ -f "$cache/$room/mid.wav" ] || { echo "skip lag $room $tier (no cache)"; continue; }
  got=$("$bin" lag "$cache/$room/mid.wav" "$cache/$room/$tier.wav" "$ratio")
  [ "$got" = "$want" ] && ok "lag $room $tier $got ms" || no "lag $room $tier: want $want got $got"
done < "$here/lag.txt"

# room plan: tempos and ratios, read from the wired levels.json.
for room in bar salon; do
  want=$(grep "parent.flac\"}" "$here/plan.jsonl" | grep "chains/$room/" | jq -cS .)
  got=$("$bin" room plan "$room" --levels "$here/levels-after-wire.json" | jq -cS .)
  [ "$want" = "$got" ] && ok "room plan $room" || { no "room plan $room"; echo "  want $want"; echo "  got  $got"; }
done

# room wire: from the two rooms unwired, to Python's levels.json byte for byte. It copies
# the stretched files from the stage into the cache, so it needs both.
if [ -d /work/tmp/audio/layered/bar ] && [ -d "$cache/bar" ]; then
  cp "$here/levels-before-wire.json" "$scratch/levels.json"
  i=0
  for room in bar salon; do
    i=$((i + 1))
    got=$("$bin" room wire "$room" --levels "$scratch/levels.json" | jq -c .)
    want=$(sed -n "${i}p" "$here/wire.jsonl")
    [ "$want" = "$got" ] && ok "room wire $room" || { no "room wire $room"; echo "  want $want"; echo "  got  $got"; }
  done
  cmp -s "$scratch/levels.json" "$here/levels-after-wire.json" && ok "room wire: levels.json byte for byte" || no "room wire: levels.json differs"
else
  echo "skip room wire (no stage or cache)"
fi
exit $bad
