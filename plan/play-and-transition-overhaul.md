# Play, musical lift and leaving the party — 2026-10-28

User direction extends `party-overhaul.md`: optional adornments must matter to
expression, peak excitement must contain playable finish combinations, and a
completed room must settle naturally as Mācron travels onward. This pass builds
behavioral proofs with the existing procedural art; cleaned multi-frame atlases
and remaining room art are still future production work.

## Decisions for the eager pass

- Keep the one-thumb four-zone interface and anticipatory flowing cues. Score
  taps at press-down. Separate required accuracy from optional expression.
- Replace long cross-quadrant swipes with short relative-direction flicks from
  marked accepted taps. Different directions choose musical ornaments. Keep
  gesture ownership with the original pointer, preserve tap credit even if a
  flick fails, and offer gestures only in authored gaps before the next input.
- Preserve the ±180 ms tap window. Try phrase-level forgiveness rather than
  blindly increasing windows: garden build-up can pass with six of eight notes,
  bar and peak proof with seven of eight. These are playtest hypotheses.
- The full arrangement is a playable plateau, not a finish trigger. Keep the
  existing per-level final challenge counts, make the peak phrases visibly
  different, and show remaining finish combinations. Changes are demonstrated
  before the response; do not change a motif mid-phrase.
- Separate lasting guest recognition from transient style excitement. Required
  responses earn welcome; adornments make specific nearby guests clap, toast or
  react more vigorously. Declining adornments never blocks a room. Expert play
  has an expressive payoff throughout the run rather than a mandatory tax.
- A failed phrase may cause a short clumsy recovery step and a localized guest
  reaction. A single missed note does not cause a fall. No injury, humiliation,
  collision damage or loss of already-earned Pizazz. Physical prop/person contact
  requires authored contact poses and routes and is not represented as delivered.
- Richer music at tier zero means a complete quieter groove with harmonic and
  melodic identity. Escalation adds counterlines, percussion variation, fills
  and ensemble answers; it must not simply increase loudness or tap density.
- Keep the existing modest tier tempo progression for the first pass. Additional
  style tempo boosts need an opt-in, safe-boundary design and latency/playtest
  evidence. Never move already-previewed cue deadlines to reward a swipe.

Input, crowd and music research notes record primary sources and distinguish
source recommendations from our proposed numeric settings.

## Social arc by room

| Room | Peak social shape | Approval / warm-down | Travel |
| --- | --- | --- | --- |
| Garden | Most queue guests face Mācron; a few clap, others step in place | Gatekeeper approves; applause lingers in a few guests while others resume conversation | Walk into depth through the entrance, shrinking consistently with the floor |
| Bar | Nearby patrons rise/turn from the counter; a pair toast | Drink settles; patrons lower glasses and resume their counter activities in staggered order | Walk laterally around the counter end toward the next space |
| Cool crowd | Most guests join a shared groove with individual variations | Circle opens; a few echo the signature step while others re-form small groups | Diagonal walk through the opened circle |
| Restroom | Small nearby group approves; attendant supplies the main gesture | Key turn and door action take attention; bystanders settle | Angled approach, door interaction and occlusion; tasteful exit to hall |
| VIP | Progressively the whole audience stands, claps and cheers | Full standing ovation; existing high five and invitation take priority, then guests settle into the final tableau | Approach host, high five, turn toward seat; no next-room transition |

Full crowd support means shared attention and approval, not identical gestures.
The fraction standing grows by stage, reaching the entire audience only at VIP.
Production needs actual seated/standing/stand-up/sit-down, pointing, clapping,
toasting and return-to-activity clips; do not equate bobbing a static sprite with
those finished actions.

## Musical transition storyboard

1. **Finish proof:** full arrangement remains audible through the last required
   varied response. Only actual mastery authorizes the gate and freezes the final
   campaign timer, when this is the final stage.
2. **Reach the musical exit:** finish the current committed phrase; crowd support
   holds. No premature scene teardown or silence.
3. **Success, first bar:** challenger approval and localized applause. Preserve the
   room motif and tonic answer; no new required notes.
4. **Success, second bar:** orchestra thins into a warm coda. Guests finish their
   gestures at different moments, lower drinks or turn to companions. Some keep
   clapping toward the exit. A real seat return is authored, not a teleport.
5. **Bridge:** source crowd settles further; Mācron follows the room's route.
   Percussion carries continuity and destination pickup introduces the next
   motif. The new room has its own occupied guests and rich starting groove.
6. **Arrival:** restore stable framing before cues. Intro space invites the player
   back into the pulse. Touch targets never travel with the camera.

All presentation timing follows the conductor, including pause/resume of the
whole chain. Source-local music time may retire; never use that frozen clock or
wall-time `dt` to drive the rest of the transition. End-of-song is an authored
musical cadence reached after mastery, not unconditional score EOF. Looping
until mastery remains necessary for retries.

## Evidence required before calling this tuned

Replay clean taps-only, forgiving recovery, expert adornments and failed phrase
scripts. Verify different full-tier phrases, no clear on reaching peak, localized
style and stumble reactions, no duplicate replay awards, and identical judgments
with presentation effects enabled or disabled. Compare audio render boundaries,
validate generated MIDI/data and inspect pause during approval/bridge. Review
motion, thumb comfort, clue comprehension and ten-minute performance on physical
Android/iOS devices. Human listening must judge whether richer arrangements are
catchier and whether the coda feels welcoming; event-count tests cannot do that.

The first expressive chain rewards alternating accepted flick directions within
24 musical beats, up to four stages. Repeating a direction starts a fresh
chain. Higher chains spread and extend transient neighbor excitement; Pizazz
stays 100 per credited invitation and required mastery is unchanged. Pause
clears transient style and duplicate replay credit cannot grow the chain.
