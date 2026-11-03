# Design

## Context

Motivation is in proposal.md. `tool/music/generate.mjs` composes five scores from two
motifs with a fixed arrangement recipe and no dependencies. Tiers 0–4 are authored by
`minTier`/`maxTier` note ranges. `validate.mjs` checks structure, not musical variety.
Full-score JSON is about 145 KB and all MIDI previews total 209 KB. The Web Audio
backend synthesises voices from oscillators and noise, with a 96-voice cap.

**What models can actually do (checked 2026-11-03):**

| Model | Output | Licence | Fit |
|---|---|---|---|
| ACE-Step 1.5 XL | Audio (tagged text-to-audio) | MIT | Style reference; notes only by transcription |
| Anticipatory Music Transformer | MIDI, infills/continues | Apache-2.0 | Motif variation (approved) |
| Text2midi | Multi-track MIDI from text | Apache-2.0 | Sketches; authors report a 40 s file in about 55 s |
| NotaGen | ABC-style symbolic score | MIT | Classical focus; not requested |
| ChatMusician | Single-line ABC | MIT card, LLaMA 2-based | Inherited terms unclear; not requested |
| MIDI-LLM | Multitrack MIDI | Llama community | Not free-software friendly; rejected |
| Basic Pitch | Audio to MIDI | Apache-2.0 | Transcribes ACE-Step stems, with cleanup |

None of these promises arranged, tiered, loop-safe scores, so none can be the whole path.

## Goals / Non-Goals

**Goals:** a one-line prompt can start the whole score; composition has real structure;
assets stay tiny; everything is reproducible.

**Non-Goals:** runtime generation; live tempo control; samples; automated judgment of
musical taste.

## Decisions

### D1. Plan with an LLM, arrange with code

Composing is split: the agent (or a local LLM) writes a brief as JSON, and a
deterministic arranger renders it.

```jsonc
{ "id": "bar_swag", "prompt": "…", "bpm": 92, "meter": "4/4",
  "keys": [{ "section": "A", "root": "D", "mode": "mixolydian" }],
  "form": [{ "section": "A", "bars": 8 }, { "section": "B", "bars": 8 }, ...],
  "harmony": { "A": ["I", "IV", "I", "V"], "B": ["vi", "IV", "I", "V"] },
  "groove": { "pattern": "train-beat", "swing": 0.12, "layers": ["cumbia-guacharaca"] },
  "voices": ["pedalSteel", "nylonPluck", "subDrone", "chugGuitar"],
  "tiers": [{ "adds": ["subDrone", "brushes"] }, { "adds": ["nylonPluck"] },
            { "adds": ["pedalSteel countermelody"] }, { "adds": ["lead"] },
            { "adds": ["chugGuitar on bar 4 of each phrase", "double-time kick"] }],
  "motifs": { "lead": "motifs/bar_swag.lead.json" } }
```

Why: LLMs handle structured musical plans well, and code guarantees loop seams, tier
ranges, boundaries and validity. Alternative: raw model MIDI into the game. Rejected:
no tier structure, no seam guarantees, and it would drift from the transport contract.

### D2. Arranger techniques

The arranger provides composition devices the brief selects: voice-led chord
inversions, bass lines from harmonic function, motif operations (rhythmic displacement,
inversion, fragmentation, sequence), counter-melody by species-style rules, fills at
phrase ends, call and response, and orchestration by register. It is what replaces
today's fixed recipe, and it is unit tested per device.

### D3. Complexity gates

Measured on note data, per score and tier:

- **Repetition:** share of bars that are exact or transposed copies of another bar, per voice.
- **Harmony:** distinct chord functions and harmonic rhythm per section.
- **Independence:** how far voices avoid moving in parallel rhythm.
- **Pitch and rhythm variety:** pitch-class entropy and rhythm pattern count per voice.
- **Build:** note density and active voices must rise between tiers, without relying on velocity.

Starting thresholds are calibrated against today's five scores, which should fail the
repetition gate, then tuned by listening. Gates catch bad patterns; only ears approve.

### D4. Motif source interface

`motif import <source>` outputs a common motif JSON with provenance: quantised to the
grid, fitted to key and range, and capped in length. AMT runs on existing motifs for
variations, Text2midi for sketches, and ACE-Step through stem separation and Basic Pitch
for ideas. Candidates are auditioned from a preview page, and accepted ones are committed.
Demucs's licence is not yet verified, and it is not requested until it is.

### D5. Style layers and replay scores

A score may carry named layers that are note sets gated like tiers. The conductor selects
them at phrase boundaries through the existing mechanism. Replay scores are separate
briefs that derive from the base one, sharing the room's hook, with their own richer
arrangement. Their tempo and chart interplay is left to the replay design.

### D6. Synth voices as small presets

New voices (`pedalSteel`, `chugGuitar` through a waveshaper, `subDrone`, and so on) are
oscillator-and-filter recipes within the existing backend and voice cap. No sound
fonts or samples. The cap and CPU are checked on phones, as heavy distortion can be costly.

## Risks / Trade-offs

- [Oscillator synthesis limits realism] → it is the game's chosen sound; style comes
  through writing and voice recipes. Listening review decides how far to push.
- [Style mashups may fight the game's identity] → awaiting the owner's cumbia decision.
- [Text2midi weights are pickle format] → the host converts or sandboxes them; never load raw.
- [Larger scores] → a size budget is enforced, and repeated material compresses well.
- [LMD-trained models may echo existing songs] → motifs stay short, are fitted and edited,
  and humans review them. This does not eliminate the risk, so provenance records the source.

## Open Questions

- Exact gate thresholds, set after calibration on current scores.
