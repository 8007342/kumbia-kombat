# Design

## Context

Motivation is in proposal.md. This builds on `character-sprite-pipeline` (its design
D1, D4, D5, D6, D13). Existing rules: music transport owns time; `cam.detail` is a
brief closeup that never obscures cues; reduced motion uses fixed cuts; text lives in
UI (`plan/storyboard.md`, `storyboard` and `art-direction` specs).
`RoomDeparture` already drives bridge routes from transport beats. The E01–E05 ending
table is the established shot format, and the transition storyboard gives approval a
two-bar success phrase followed by a bridge.

## Goals / Non-Goals

**Goals:** one definition of each character across dance and story; shots are cheap
enough to iterate; a beat budget the validator enforces.

**Non-Goals:** full motion video; lip sync; a timeline editor; new runtime work
before art passes review.

## Decisions

### D1. Shot file

```jsonc
// tool/art/shots/bar.pour.close.json
{ "id": "bar.pour.close", "sequence": "bar.outro", "beats": 1.5,
  "background": { "source": "assets/art/bar/bar-interior.png", "crop": "counter", "treatment": "defocus-free flat" },
  "camera": { "kind": "closeup", "target": "bartender.hands", "viewport": [0, 0.35, 1, 0.6], "native": [180, 120] },
  "cast": [{ "character": "bartender", "drawings": [
     { "id": "tilt", "pose": "pour.tilt", "holdBeats": 0.5 },
     { "id": "pour", "pose": "pour.flow", "holdBeats": 0.75 },
     { "id": "lift", "pose": "pour.lift", "holdBeats": 0.25 } ] }],
  "props": [{ "id": "oil-glass", "state": "filling" }, { "id": "oil-bottle", "hand": "right" }] }
```

Sequences list shots and name the bridge they must fit. Durations are beats because
"sub-second" depends on tempo: at the bar's 100 BPM one beat is 0.6 s.

Why not free-form prompts per shot: without a rig there is no mask, so a shot could
not be recoloured, scored or updated by a hat edit.

### D2. Same stage graph, new target kind

A shot compiles to the family-spec style jobs and runs `rig → masks → references →
generate → colour → finish → ramp → pack`. Reference keys come from the character, so
an edit invalidates shots through ordinary hashing. The only additions are a camera
parameter on rig renders and per-shot native sizes.

### D3. Visibility decides impact

The planner reads `regionPixels` from the rig inside the viewport. If the edited
region has no pixels in frame the shot's key excludes that region, so it does not
change. Character keys are therefore computed per region, and a shot hashes only the
regions it can see.

Alternative: rebuild every shot featuring the character. Rejected: it would waste GPU
and throw out accepted shots.

### D4. Close-up detail

Closeups show more of the character than the 96×120 atlas, so they use their own
native size and a head or hand pass (same mask-based second pass as dance frames).
The rig needs detail shapes (fingers-as-mitten plus prop grip) and closeup cameras.
The style stays pixel art at the same pixel density ratio where possible, so cuts do
not change the look.

### D5. Slight animation by drawings, not interpolation

Doctrine forbids blur, crossfades and optical-flow inbetweens. Motion is 2–4 authored
drawings, with parallax of separate layers allowed, and small transform moves only
for the camera, disabled in reduced motion.

### D6. Pilot: `bar.outro`

Fits the bar's success phrase and start of `bar_to_crowd`:

| Shot | Beats | View | Action |
|---|---|---|---|
| `bar.nod` | 1 | Medium on Bartender | Defeated but delighted: nod, reaches for the bottle |
| `bar.pour.close` | 1.5 | Closeup on hands | Oil pours into the glass, with a hit on the musical accent |
| `bar.slide` | 1 | Counter level | Glass slides along the counter toward Mācron |
| `macron.gulp` | 2 | Closeup at robot height | Antenna perks; three drawings of a blissful gulp; cyan face smiles |
| `bar.exit` | 1 | Wide | Bartender opens the side passage; hand-off to the walk |

Total 6.5 beats, which is within the 8-beat success phrase. The bridge length gets a
real check when the sequence validates against `assets/music/manifest.json`.

## Risks / Trade-offs

- [Closeups expose rig and generator weakness] → the pilot is reviewed before more
  sequences; `edit` backends can repair a single drawing.
- [Mācron closeups need his definition, which is non-humanoid] → port only what these
  shots need; his existing dance art stays untouched.
- [Atlas memory for shots] → load per sequence, release after; budget checked at pack.
- [Transitions may delay flow] → the sequence must fit the existing bridge, so it adds
  no time, and it is skippable.

## Open Questions

- Motor oil's look (dark amber vs near-black) is settled at pilot review.
