# Proposal: ground rhythm in research

## Why

The owner, after the phone test: "the game combos are awesome, but they're not always
well aligned with the music … I think our 'late' taps are probably due to humans being
slow … We would like the game taps and combinations to match the music theme and the
dancing theme, they should all feel harmonious and being one and the same." They asked
that specs cite authorities on music, rhythm, gameplay and engagement, including the
"hard to measure" musical requirements.

The research (`plan/research/rhythm-music-engagement-2026-11-07.md`) finds three things.
Humans tap *early*, not late, so a late bias is device latency. Our windows are already
wide, so the fix is centering them. And the felt unity of tap, dance and music has
measured correlates: onset alignment, medium syncopation, limb-to-metric-level mapping,
phrase boundaries, and peaks at instrument entries.

## What Changes

- **rhythm-combat:** judgment uses the *heard* time: scheduled audio time corrected for
  output latency, input latency and a per-device calibration. Add a tap-along
  calibration, an early or late bias report, and a bounded automatic nudge. Windows keep
  their widths. Add chart-to-music alignment rules: taps on audible sharp-attack onsets,
  feet on beats, hands on subdivisions, phrase boundaries, a syncopation band per tier,
  and the cha-cha and clave figures. Add a difficulty-curve target with pass-rate bands,
  and a playtest protocol.
- **dynamic-music:** add the abstract musical requirements (seam smoothness, tension
  and release, peak placement, repetition and variety, groove) with their measurable
  proxies and references. Add dance-to-music accent agreement.
- Resolve a contradiction: the spec's 250 ms minimum interval "including across
  different limbs" disagrees with the code's per-grip limits (170 ms cross-thumb). Adopt
  the per-grip limits, which are above the human synchronization floor of about 100–125 ms.

Out of scope: changing window widths, new art, and re-rendering music. Implementation
belongs to the agents now working on timing (FEEL) and chart audit (ALIGN).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `rhythm-combat`: latency-corrected judgment and calibration, chart-to-music alignment,
  per-grip spacing, and the difficulty curve.
- `dynamic-music`: measurable musical-quality requirements, and dance accent agreement.

## Impact

`lib/gameplay/rhythm.dart` and the session's audible-time source, the level JSON charts,
`tool/` chart audit scripts, and the music render and validation tools.

Spec notes: this change MODIFIES rhythm-combat's "Audio-clock timing and phrase success"
against the main spec's text. The unarchived `living-party` change modifies the same
requirement (with the 6-of-8 pass thresholds), so whoever archives second must merge the
two. The main rhythm-combat spec already fails `openspec validate`: "Moves are invited by
drawing them" has no scenario. That predates this change, which leaves it alone.
