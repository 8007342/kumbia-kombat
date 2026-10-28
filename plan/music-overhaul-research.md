# Party music and departures — 2026-10-28

The owner's direction is a party already worth entering: a recognizable musical
baseline, progressively richer orchestration, a musical warm-down after approval,
and guests returning to their own activities as Mācron leaves. Optional skill may
eventually earn a modest tempo lift. The first implementation changes authored
notes and departure presentation data; it does not change judgment or add a live
tempo controller. Human listening and physical-phone acceptance remain open.

## Primary research and application

- [FMOD Studio: Authoring Events](https://www.fmod.com/docs/2.04/studio/authoring-events.html),
  sections on quantization and transition timelines, accessed 2026-10-28.
  Tempo markers establish musical quantization; transition timelines provide
  authored connecting material. Application here: retain a scheduled phrase exit,
  success phrase and composed bridge rather than start the next song from a
  visual callback. The project uses its existing Dart/Web Audio implementation,
  not FMOD. Search-index text was readable; a direct page fetch timed out.
- [FMOD support: tempo-synced transitions](https://qa.fmod.com/t/best-practices-for-tempo-sync-beatmatched-timing-across-events/20836/2),
  Jeff_FMOD, 2023-11-06. Describes conditions evaluated on musical quantization
  points. This supports aligning reactive orchestration and travel accents to
  musical boundaries; the exact eight-beat form remains a project decision.
- [Audiokinetic: The Wwise Project Adventure](https://www.audiokinetic.com/download/documents/WwiseProjectAdventure_en.pdf),
  “Adventures in Music,” especially transition behavior around pp. 160–161.
  Describes selectable source exits, entry cues, transition segments and tails.
  Application: let the current phrase finish, retain its releases, and resolve
  with this room's own melody before introducing the destination. This is an
  established composition pattern, not a reason to migrate audio middleware.
- [W3C Web Audio API 1.0](https://www.w3.org/TR/webaudio-1.0/#dom-baseaudiocontext-currenttime),
  Recommendation, 2021-06-17. Scheduled audio uses the context timeline, which is
  distinct from other system clocks. Application: music, guest settling and travel
  sample transport beats; rendering does not advance the song. Output latency
  and physical input calibration remain separate work.

These sources support timing structure. Whether these particular arrangements
sound inviting, danceable and culturally convincing remains a listening question.

## Implemented first pass

`tool/music/generate.mjs` now gives every room's tier 0 its own restrained melodic
hook, sparse offbeat harmonic dyads, bass and cumbia percussion. Tier 1 adds bass
movement and percussion; tier 2 replaces dyads with fuller accompaniment and adds
an alternating countermelody; tier 3 replaces the restrained hook with the complete
lead phrase; tier 4 adds the intervening response, brass and fills. Added parts
use restrained velocities; higher intensity is not simply a master gain increase.

All five eight-beat approval phrases retain their quoted motif and tonic answer.
The second bar removes percussion subdivisions, reduces accompaniment density
and softens attacks while retaining bass, beat and the melodic answer. This is an
authored warm-down, not a tempo ramp or a fade to silence. Existing bridge notes,
segment lengths, two-bar boundaries, +3 BPM tier steps and required charts remain
unchanged. The generated catalog has 7,544 note events and 34 MIDI exports.

`lib/gameplay/room_departure.dart` supplies pure bridge-progress routes, normalized
foot anchors and explicit rear/front/side-right view changes. Garden is the only
route with an implemented next room; the other entries are future storyboard data.
The model cannot alter musical time, clearance, input geometry or judgment. Correct
sprite facings and genuine doorway layers still need production artwork.

## Departure choreography

All timing below refers to the active segment's musical beats, not accumulated
frame delta or a stale cleared-session clock. Existing segments are reused, so no
extra cutscene bars are added.

| Segment | Music | Crowd | Mācron / environment |
|---|---|---|---|
| Remaining source phrase | Finish current phrase at its committed tempo | Hold earned attention; no premature mass dispersal | Challenger acknowledges; controls finish any final optional window |
| Success beats 0–4 | Room motif receives approval answer | Brief staggered approval; two guests clap | Gate action becomes the focus; Mācron turns toward the route |
| Success beats 4–8 | Thinner, softer second bar, tonic answer retained | Guests peel off one at a time toward conversation, drinks or seats; clappers remain | Open passage becomes visually clear |
| Bridge beats 0–4 | Existing percussion pivot at destination base tempo | Remaining clappers finish; distant guests resume established loops | Travel begins through this room's distinct threshold |
| Bridge beats 4–8 | Destination harmony and motif pickup | Source guests remain in source room; no crowd teleport | Doorframe/foreground occlusion introduces the next room |
| Next-room intro | New room's already musical baseline | New guests pursue their own activities | Establish rear view before the next required phrase |

| Departure | View / route | Visible social conclusion |
|---|---|---|
| Garden → bar | Short right-facing step, turn rear, recede diagonally into copper door | Queue parts; one pair chats again, two clap the exit |
| Bar → crowd | Side-right walk along counter, turn into end passage | Bartender completes drink slide; patrons turn back to drinks, one keeps time |
| Crowd → restroom | Brief front-facing acknowledgment, turn rear, walk through opened circle | Lead dancer repeats signature step; circle reforms behind Mācron |
| Restroom → VIP | Side-right passage behind doorframe, then rear approach toward stair | Key settles; waiting guest resumes foot tap, attendant gives small nod |
| VIP → ending | Rope opens, rear approach, authored closeup at robot height | Lounge settles into attentive smiles; high five and invitation own focus |

Guests need distinct home anchors and authored return clips. Walking toward a
chair should precede sitting; a generic bounce stopping is not a seating animation.
Use at most one newly prominent departure gesture per beat, with two designated
clappers. Reduced motion holds an informative departure view and adopts the next
room at the same musical boundary. Pausing freezes actors and travel together;
resume uses the conductor's live re-anchored segment handles.

## Next score revision and optional tempo boundaries

1. Audition all five baselines and adjacent tier pairs on speakers and headphones;
   compare whether the hook stays memorable and additions leave cue accents clear.
   Revise room-specific instrumentation, bass movement and phrase answers from
   listening, rather than add arbitrary notes to satisfy density counts.
2. Measure peak levels, simultaneous voices, dropped voices and device scheduling
   headroom before adding more tracks. The existing oscillator backend has a
   96-voice ceiling and still needs priority-aware stealing. MIDI program hints
   are not a substitute for the actual Web Audio timbres.
3. Give scheduled segments their own timbre identity. Currently the backend has a
   shared mutable `leadShape`; changing it only on visual room adoption cannot
   author every bridge/queued voice's intended sound.
4. Treat any skill-driven tempo lift as a separate opted-in rule. A conservative
   experiment would cap it at one +3 BPM lift, scheduled at an authored safe phrase
   boundary after all already-previewed cue deadlines and scheduled attacks.
   Never rescale currently visible notes or a built judge's millisecond targets.
   Coalesce repeated skill requests; reset the bonus at a room boundary; retain
   taps-only completion. Define leaderboard fairness and clean-run timing before
   enabling it. Optional swipes still affect only ornaments/Pizazz in this pass.
5. The current transport binds tier and BPM together. A future independent tempo
   intent requires a deliberate tempo-map change plus seconds↔beats round-trip,
   preview lead, pause/seek, retirement and retry tests. A scalar applied to scene
   motion or audio playback speed would violate the single-timeline contract.

## Evidence and remaining acceptance

`node tool/music/generate.mjs` and `node tool/music/validate.mjs` pass. Validation
checks every baseline phrase has hook/harmony/bass/percussion, increasing tier
event counts, unchanged tempo steps, quieter/sparser authored approval attacks,
retained approval downbeats, all notes within bounds, and balanced note-on/off
pairs in all 34 MIDI files. Attack velocity sums are structural checks, not a
measurement of loudness or clipping. `dart tool/music/transport_check.dart` and
`dart tool/music/transition_check.dart` pass. Four departure-model tests pass,
covering bounded routes/endpoints, facing changes at corners, reduced motion and
rejection of non-finite progress; targeted Flutter analysis reports no issues.
Parent integration tests must pass before this milestone is integrated.

Physical-phone listening, actual loudness/headroom measurement, smooth guest
departure, reliable doorway occlusion, frame/memory budgets and native-size art
review remain unverified. In particular, this score revision does not claim that
five rooms or production multi-view character animations are complete.
