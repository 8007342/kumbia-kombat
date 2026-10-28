# Reusable ensemble and dance-battle pass — 2026-10-28

Branch: `work/1829-danc`. Continued from `d981a47`; frequent work-ref pushes:

- `61f8611`: sparse stage audiences, seated/standing transition model, actual-note
  challenger choreography, research and tests.
- `a41863c`: 132 measured raster poses, transparent furniture-separated people,
  perspective layout, outfit-mask shader, styleguide, real-source pixel tests.
- `e1a2b82`: twelve-guest scene, depth sorting, persistent chairs, animated opponents,
  Mācron floor handovers, party life and source-anchored light.
- `f621708`: separate shader/Paint state per texture and wardrobe variant to fix
  all-outfits-teal behavior seen in the CanvasKit browser.
- `37b66e3`: bind each texture sampler after its per-frame crop and destination
  floats, fixing CanvasKit's zero-area crowd draw.
- `b1f23bc`: retained per-pose shader pictures after the live sampler path could
  lose a crowd on some web renderers. This was superseded by ordinary rasterized
  wardrobe images; see `wardrobe-rendering-stability.md`.

## Delivered behavior

Guests begin occupied and seated. Each stage caps cumulative social participation
per twelve guests: garden 3/2/1/0, bar 5/4/2/1, cool crowd 8/7/5/3,
restroom 9/8/6/4, VIP 12/12/12/12 (interested/following/standing/cheering).
Only garden/bar are playable. Individual fractional-beat delays, interest thresholds
and non-interrupted transitions prevent synchronized crowd snaps. A future larger
cast scales budgets with count. Progression and input remain authoritative.

Three silhouettes have 24 drawings each; the renderer samples loops and one-shot
notice/stand/sit transitions. Chairs stay independently planted. Four wardrobe
variants recolor reserved clothing, preserving reviewed skin/hair/wood and alpha.
Both challengers have 20 poses tied to the actual active limb motif and audio beat.
No change in mandatory note density is claimed; limb coordination varies with the
existing chart tiers. Finish, cede, invite and watch occupy existing musical rests.
Mācron's existing beloved source art is retained and composed into floor handovers.

Background and world actors share an exact centered cover transform, a 180px logical
world width and manually inspected floor planes. Every pose scales from one standing
reference; seated people are not fitted to a taller box. Mācron is .35 adult height
at his own floor distance. Chair dimensions were fitted to the new high-back source,
with a stable floor anchor and seat support. Physical perspective still needs human
review against the rendered paintings; these are art-directed camera estimates.

Ambient source frames cover umbrellas/tables/drinks, hanging Tillandsias, votives
and a waiter. Their slow phases differ. Small measured light glows follow a frozen
foreground clock, independent of scoring. Reduced motion holds informative poses.

## Validation and limits

The original integration suite passed 81 tests with clean analysis. `flutter build web --release
--no-web-resources-cdn --no-pub` succeeds. A hard-reloaded CanvasKit preview showed
the twelve seated garden guests with independently visible teal, blue, coral and
gold wardrobes; later real-GPU reports still showed disappearing guests, so it is
not acceptance evidence for the superseded live shader path.
OpenSpec strict validation and diff checks pass.

Sources/prompts: `assets/art/ensemble/provenance.json`. The read-only alpha inspector
and actual-image tests verify explicit bounds and transparent cutouts. Generated
sources still need native-grid, cloth/anatomy continuity, seated contact and additional
in-between cleanup; they are runtime previews, not final hand-authored production
sheets. All textures are shared across guest instances, but the old 16MiB total-art
hypothesis is exceeded. Physical-phone frame time, memory, comfort and audio listening
remain unverified. The final VIP ovation is tested model behavior, not an implemented
VIP room or final cinematic.
