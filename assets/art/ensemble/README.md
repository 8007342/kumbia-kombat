# Reusable audience, dance challengers and party life

Built-in imagegen sources, 2026-10-28. Exact prompts, identity references and
cleanup requests are in `provenance.json`. The runtime manifest contains **132
explicit measured source rectangles**, not equal-grid slicing:

- Three reusable people,24 poses each: seated idle2, notice2, seated rhythm2,
  stand-up4, standing idle2, step-touch4, clap2, cheer2, sit-down4.
- Garden gatekeeper20 and bartender20: preparation, four limb accents, follow-through,
  settling, finish, cede, invite, watching, approval, recovery and turns.
- Party life16: four umbrella/table poses, four hanging-plant poses, four candle
  flames and four waiter poses. The umbrella source includes table and drinks.
- Furniture4: two chair facings, a cafe table/drinks/votive, and closed umbrella.

The generated chairs disappeared during some dance poses. An imagegen edit
removed ALL chairs from the person sources; stable furniture is rendered behind
people using the shared floor anchor. Chair height/width/seat support are calibrated
against source art, never changed because a guest sits down. The man's initial
sheet had two touching frame pairs; a separate packing edit isolated all24 sprites.

`tool/art/inspect_alpha.py` reads PNG alpha and reports connected-component bounds
for review (`uv run --with pillow python tool/art/inspect_alpha.py <file>`). It does
not edit images. The final rectangles and anchors were inspected explicitly.
Plants anchor at the cord top; people, furniture and waiter use floor anchors.

Both generated challengers repeated the same leg for the right-foot accent. The
right-foot manifest entry explicitly mirrors its source drawing so the correct
anatomical leg is demonstrated. This is an original symmetric costume character;
Mācron's asymmetric cuff is not mirrored. All action tags must be reviewed again
when production art replaces these previews.

The dedicated plum/pink clothing ramp supports GPU palette variants. Palette-mask
review and tests preserve sampled skin/hair/wood and alpha; this is not a global
color filter. Skin tones and character proportions must never change as a result
of the outfit variant. Deep warm shadows intentionally remain unchanged.

These are integrated preview drawings, not finished native-grid pixel animation.
Some source poses still need anatomical/cloth continuity cleanup and more in-betweens.
All exported poses are kept at one source scale per character; no frame-by-frame
fit-to-box scaling is allowed. Seating proportion/hand contact needs visual review
against each room, and phone memory/frame-time acceptance remains open. Texture
memory is bounded by shared atlases, but full-resolution source sheets exceed the
old16MiB total-art hypothesis. No physical-device performance claim is made.
