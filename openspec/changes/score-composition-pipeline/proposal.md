# Proposal

## Why

The owner wants real composition and orchestration that builds intensity, not a few
transposed beats, from a one-line prompt, while keeping tiny MIDI-style assets on the
web synth. Music is free to change, but it stays dominantly Latin with hints of other
styles, and each level follows its character: Gatekeeper reads salsa, Bartender reads
electronic. Level 4 will later build a chill country backdrop into heavy metal.
No available model can guarantee that: audio models don't produce notes, and symbolic
models produce uneven sketches. So composition needs a pipeline that uses models as
contributors and measures the result.

## What Changes

- Add a **score brief**: a prompt expanded into a reviewable structured plan covering
  form, harmony, groove, orchestration per tier, tempo and style layers.
- Add a **deterministic arranger** that turns a brief plus motifs into the existing
  score JSON and MIDI, including tier variants, success phrases, bridges and adornments.
- Add **motif sources** behind one interface: hand-authored, the planning LLM,
  Anticipatory Music Transformer variations, Text2midi sketches, and ACE-Step audio
  transcribed to MIDI. All outputs are candidates that are quantised and fitted to the brief.
- Add **measurable complexity gates**, so a score that is mostly transposed repeats
  fails before anyone listens.
- Add a **measured Latin identity gate**: every tier must contain recognised Latin
  rhythm patterns. It checks that the patterns are present, not how they feel.
- Add **style layers** that can change at safe phrase boundaries, and replay-tier
  scores for faster, more complex play.
- Extend the synth with voices that new styles need, with no samples or stems.

Out of scope: changing judgment, charts or tempo rules in this change. Replay mode
itself is out of scope, though scores are prepared for it.

## Capabilities

### New Capabilities

- `score-composition-pipeline`: producing complete validated interactive scores from a
  style brief, with models as optional motif contributors.

### Modified Capabilities

- `dynamic-music`: the rule that every score keeps audible cumbia percussion becomes a
  dominantly Latin rhythmic identity. The runtime contract otherwise holds: precomposed,
  deterministic note events and no recorded stems.

## Impact

- **Code:** `tool/music/` (brief compiler, arranger, gates, motif import); `lib/music`
  voice additions; `assets/music/` regenerated. Generated scores must stay within the
  current size order (about 150 KB JSON per full score before compression).
- **Dependencies:** a host music engine for AMT, Text2midi and ACE-Step
  (macuahuitl-fedora has it on the planner). Everything else works without it.
