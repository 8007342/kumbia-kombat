# Gatekeeper dance research (2026-11-02)

Two research passes commissioned for the Gatekeeper v3 64-drawing re-key and the
generation pipeline. Operator approved the proposed changes on 2026-11-02.
Machine-readable principles derived from this file and the Mācron passes live
in `tool/art/references/animation-principles.json`; the pipeline cites them in
every frame's provenance.

- Part 1: cumbia vocabulary mapped to the 64 drawings
- Part 2: animation craft, rig critique and SDXL control stack

Web sources were thin in places (noted inline); verify poses against real dance
footage at review.

---

# Part 1 — Cumbia vocabulary


Inputs read: `origin/work/1830-pipe:tool/art/rig/poses.py`, `plan/opponent-depth-staging-pass.md` (Opponent production target, turn timing, constraints), `plan/dance-battle-choreography.md`, `plan/storyboard.md` G01, and `assets/art/ensemble/gatekeeper-v2.png`. The web sources are thin: mostly dance-school blogs and encyclopedia mirrors, and WebFetch failed, so everything below comes from search excerpts. Nothing here is ethnography. Validate the poses on video and at in-game size.

## 1. Vocabulary that fits a confident older man

| Move | Where it comes from | Rhythm and weight |
|---|---|---|
| **Paso básico (back-break)** | Pan-regional social cumbia (Mexican, Tejano, Colombian social). | 4 counts: step back on a diagonal (1), replace weight on the front foot (2), close the feet (3), pause/hold (4), then the other side. Many guides teach the man starting with his right foot back. In 2/4 terms: back on beat 1, replace on "&", close on 2, rest on "&". Weight stays mostly over the front (support) foot. The back foot takes the step on its ball. Knees are softly bent the whole time. |
| **Paso lateral** | Basic side step: step out, close, repeat. Knees soft, hips sway as a result of the steps. | Same 4-count frame. The hip sway follows the support leg and is never pushed on purpose. |
| **Short planted steps, raised heel** | Traditional Colombian men's role: "the man marks the rhythm with his feet; his steps are short; one sole flat, the other heel raised." | Low, grounded, almost in place. This fits the 1.1-art-pixel root-motion limit very well. |
| **Arrastre (dragged foot)** | Shuffling, sliding procession steps in traditional cumbia. The return slide is common in social dancing. | The foot comes back sliding on the floor instead of lifting. This is the "return" drawing of a step. |
| **Hat in hand, other hand behind back** | Traditional Colombian men's role: hat or handkerchief in one hand, the other hand behind the back, hat on and off, courting with no contact. | A natural source for brim touches, hat-tip finishes and the hands-behind-back "watch". |
| **Rebajada / sonidera feel** | Slowed cumbia with low, short steps, expressive turns and hand gestures (sonidera also has animated step variations and turn patterns). | Supports a deeper knee drop and a looser, laid-back upper body. Skip gang hand signs: they belong to real Kolombia groups. |
| **Circular arm styling, loose shoulders** | Social-cumbia guides: shoulders never tense; smooth arm circles start at the shoulder and run out through the wrist. Shoulder shimmy is an optional flourish. | Use it in follow-through drawings (wrist roll, shoulder settle). |
| **Turns** | Social partner turns and solo turns. | The rig has only ±30° yaw for Gatekeeper, so suggest a turn with a heel pivot and an open arm. Never fake a turn by flipping the image. |

**Not found in the sources:** named Salvadoran, chicha or villera steps. Wikipedia notes that chicha *dance* is distinct from cumbia dance. Do not invent "regional" step names. For the "uncle at the wedding" swagger, use universal party-dancer signals that suit his costume: a hand on the belt or hip (akimbo), chest out, a chin-up smile, a brim touch, a slow nod on the downbeat.

**Count mapping for the groove:** `down` = beat 1, the back-step and deepest knee. `pass` = 2, replace. `up` = 3, close and rise. `pass2` = 4, the hold, where the hip and shoulder accent lives. Gatekeeper's style lives in the pause.

## 2. Shared poses (in the rig's own units, as starting values)

- **AKIMBO** (hand on hip, as in v2 art cells 1 and 6): arm `(50,-15)`, fore `(-40,0)`. This is already `CHALLENGE.proud`. Use it as the default "other hand" during calls.
- **HIP DROP**: `pelvis_y` −0.02…−0.04, with both knees flexed (thigh flex +12–20, shin −10…−16). The pelvis shifts toward the support foot, and the shoulders counter-twist 6–10° against it.
- **BALL-STEP BACK**: free thigh `(6,-14)`, shin `(6,-30)`, with the heel raised.
- **ARRASTRE**: free thigh `(5,4)`, shin `(5,-6)`. Toe on the floor, beside the support foot.

## 3. Proposals by clip group

### Groove (8)
| Drawing | Current | Proposal |
|---|---|---|
| down_l/r | Side "down" over the support leg | Make it a **back-break**. Support stays on the planted foot with the knee bent. Free foot does BALL-STEP BACK on a 30–45° diagonal. Add HIP DROP, `twist` +8 toward the back foot, `lean` +3, opposite arm swings forward loosely. Head level, facing the player. |
| pass_l/r | Weight through centre | Replace weight forward: `pelvis_y` back up a little, twist 3. |
| up_l/r | Rise | Close the feet with ARRASTRE, both feet planted, `pelvis_y` +0.01 (small rise), `head_nod` −3 (chin up). |
| pass_l2/r2 | Pass | **The hold accent**: hip pop toward the new support (`pelvis_x` ±0.05), `side_bend` ∓5, shoulder dip, forearm wrist roll. This is where the hat or shoulders settle. |
Keep the arms below the shoulders throughout, so the groove can never be mistaken for a hand call.

### Hand calls, LH and RH (16)
| Phase | Proposal |
|---|---|
| prep (≤¼ beat) | A **scoop**: knees dip (HIP DROP), the active elbow drops and the hand passes low near the hip, the head glances toward the hand. The other hand goes to AKIMBO. Weight is on the *opposite* foot (`support` = opposite side, not "both"). |
| peak | Keep the high arm (`(155,10)/(165,10)`) but **lengthen the line of action**. Pelvis pushed away from the arm (`pelvis_x` ∓0.07), `side_bend` toward the arm about 10, so one diagonal runs from the planted foot to the raised palm. The free foot is on its ball with the knee turned in (a cumbia "hip drop" on the active side). Open palm or one finger up ("¡wepa!"). Chin up. The other hand stays on the hip. |
| follow | A wrist circle (fore 195→ next arm curl) plus a shoulder shimmy. The hat stays still (settling is described as hat and shoulders, so a slight lag is fine). |
| return | The hand sweeps down in an arc to the belt, landing on AKIMBO or on the groove arm. Feet return to the groove pose. |
**Do not** use a hat-tip as a hand call. The hand at head height reads weaker than a full reach, it covers his face, and LH vs RH would read less clearly. Keep LH and RH as exact rig mirrors. The art keeps the anatomical side (no image mirroring).

### Foot calls, LF and RF (16)
| Phase | Proposal |
|---|---|
| prep | Knee lifts and turns slightly in, on the ball of the foot. Support knee bent, HIP DROP. **Arms go to AKIMBO or belt height.** The current arms (abd 45–55) are close to "hand" territory. |
| peak | A **heel dig (taconazo)** on the forward diagonal: thigh about `(25,30)`, shin about `(28,35)`, toe up, the leg almost straight so it reads as one long diagonal. Torso leans back a little (`lean` −5) with the chest proud. Head turned toward the foot. A lifted knee-kick (v2 row 2) reads at small size too; pick whichever has the clearer silhouette at 360×640. |
| follow | A hip pop over the support foot plus a shoulder shrug. The heel stays down, still within the bounded root motion. |
| return | **ARRASTRE**: the foot slides back to close. This is the authentic dragged foot and needs no root travel. |

### Enter forward / retreat backward / yield side (6 each)
| Clip | Proposal |
|---|---|
| enter_forward | A "paseo" swagger: each contact lands on the beat with a soft knee drop (`down` frame gets HIP DROP), shoulders counter-rotate 6–8°, one hand AKIMBO or both arms loose. Small chin-up head bob. **Flag:** G01 wants the walk to end on an "open stopping palm". That pose is not in the 64-drawing vocabulary. Reuse `reassurance.open_hand` or `challenge.offer`, or authorize a replacement. |
| retreat_backward | Do it as **chained cumbia back-steps** while he keeps facing the player. This is the most authentic locomotion clip available. Arms stay low so the clip never resembles a call. |
| yield_side | A paso lateral (step-close with an ARRASTRE close) and an open-palm gesture on the final contact, which hands the floor over. The root travel belongs to the separate yield parameter, so it stays within that rule. |

### Watch (4)
Current: yaw 35, arms folded. Proposal: **hands clasped behind his back** (from the traditional Colombian men's posture), a gentle back-break rock that only shifts weight (no step), a small nod on beat 1. That is low amplitude, clearly not a demonstration, and different in silhouette from both clap and hand cues. Alternative: thumbs in the belt. Must not compete while Mācron answers.

### Clap (4)
Keep it chest-height and symmetric, with the contact frame on the music. Make it more cumbia with a **knee dip on contact** (`pelvis_y` −0.02), elbows out, head nod, and the body turned slightly toward the player. **Flags:** no overhead or side-raised claps (they would read as a hand call), and no one-sided lean (it would read as directional).

### Challenge (4)
load: back-break dip, hands going to the hips. proud: AKIMBO on both sides, chest out, chin up, a heel set forward with the toe up (the classic "señor" stance). offer: the current palm-up sweep toward the floor is good; add a small bow of the head. A **brim touch** may replace `load` → `proud` as a courteous "after you" (from the traditional hat gesture). Keep the hat on its head so its shape stays consistent. **Flag:** boasting only at protected phrase boundaries. Never trigger proud/finish on a player miss.

### Approval (3)
load: small inhale with the chin up. nod: **right palm to the chest** (a heart or "me" tap; this matches G01's chest tap), a deep nod, a knee dip. release: an open palm toward the player, or the G01 "point toward door" at clearance. **Flag:** pointing is not in the vocabulary. Either reuse `challenge.offer` with the arm aimed at the door, or treat it as a replacement drawing.

### Reassurance (3)
notice: head tilt with a soft smile. open_hand: both palms up in a small shrug with the knees bent, as if to say "otra vez". settle: a back-break groove step on the spot, inviting the player to rejoin the rhythm. Warm, never a sigh or a face-palm.

### Finish / turn (4)
finish_a: the **remate**. Hand reaches for the brim with the heel forward and toe up, other hand AKIMBO. finish_b: brim touched with a head dip and chest proud. This replaces the current arm-up finish, which can look like an LH call at the phrase end. turn_in/out: yaw ±30 with a heel pivot, a lean into the turn and the leading arm open at hip height. **Flag:** the finish must stay inside the 1.5-beat rest (beats 6.5 to 8). The brim touch must not cover the face too long, and the hat may not leave the head.

## 4. Constraint checklist

- Prep is at most a quarter beat, and the accent lands on the exact note beat. That fits a scoop or knee-lift prep.
- Root motion is bounded to 1.1 px for foot steps. Back-steps and drags are in place, so they are fine. Do not author travelling side-steps inside call clips.
- The "other hand" must never rise during a call. AKIMBO enforces that.
- The count stays at exactly 64 drawings. Every proposal above is a substitution, apart from the flagged G01 stop-palm, chest-tap and point.
- Reduced motion keeps the accents and the hip drop, and drops the walk bounce.

## 5. Cultural respect

- Make him a *skilled* dancer with dignity. Avoid the Speedy Gonzales or bandit tropes (mustache twirl, sombrero-bandit, "ándale" shouts), drunkenness and laziness.
- The hip movement comes from bent knees and weight transfer, not from pelvic thrusts.
- Don't mix iconography from different countries. A guayabera and Panama hat are coastal or Caribbean party wear, so don't add a vueltiao hat or charro elements.
- Don't use Kolombia or gang hand signs.
- Don't present the "shackles" origin of the dragged foot as fact; it is folk etymology.
- Feedback stays warm, never mocking.

## Sources

- Texas Monthly, How to dance cumbia: https://www.texasmonthly.com/the-culture/how-to-dance-cumbia/
- Back-break basic, counts: https://godsballroom.com/misc/how-to-dance-cumbia-basic-steps.html ; https://citydance.org/?p=203
- Partner back-steps and turns: https://rabbitroar.pages.dev/posts/how-to-dance-the-traditional-cumbia-colombiana-a-tutorial
- Arm circles and loose shoulders: https://cumbia.fm/en/blog/how-to-dance-cumbia-rhythms-steps-and-soul/
- Traditional cumbia (hat, no contact, candles, dragged feet): https://en.wikipedia.org/wiki/Cumbia_(Colombia) ; https://cumbiaexhibition.blogspot.com/2008/09/dance.html
- Men's short steps, raised heel (Spanish class document): https://es.scribd.com/document/96401539/Fandango
- Hat in one hand, other hand behind back: https://theculturetrip.com/south-america/colombia/articles/traditional-colombian-dances-you-should-know-about/
- UC Riverside side-to-side 4-count shuffle: https://gluckprogram.ucr.edu/media/4001/download
- Cumbia rebajada and Kolombia (low short steps, spins, hand signs): https://en.wikipedia.org/wiki/Cumbia_rebajada ; https://en.wikipedia.org/wiki/Kolombia_(subculture) ; https://mexiconewsdaily.com/culture/cumbia-rebajada-monterreys-accidental-music-genre
- Cumbia sonidera: https://theculturetrip.com/north-america/mexico/articles/cumbia-sonidera-an-introduction-to-mexican-cumbia-and-its-culture ; https://indyweek.com/music/sonidero-night-disco-rodeo/
- Peruvian cumbia and chicha dance being distinct: https://en.wikipedia.org/wiki/Peruvian_cumbia
- Argentine cumbia and villera: https://en.wikipedia.org/wiki/Argentine_cumbia ; https://en.wikipedia.org/wiki/Cumbia_villera
- Salvadoran cumbia (music only): https://www.cumbia.fm/en/blog/cumbia-in-el-salvador-rhythms-of-identity/
- Meter, 2/4 and offbeat llamador: https://orphiq.com/resources/what-is-cumbia ; https://en.wikipedia.org/wiki/Cumbia_(Panama)


---

# Part 2 — Animation craft and control stack


Scope: posing craft, a critique of `origin/work/1830-pipe:tool/art/rig/poses.py` and `standin.py`, and the per-pose ControlNet stack. These topics are already covered elsewhere and are not repeated: beat timing and smears (`plan/dance-fluidity-pass.md`), the clip vocabulary and the Cartwright and Disney principles (`plan/animation-research-register.md`), and model licences (`plan/generative-animation-research.md` §3.1).

## 1. Craft: what makes a dance key read as "epic" at 64–128 px

- **One line of action per key.** Draw one C- or S-curve from the planted foot, through the spine, out to the accent limb. A straight vertical spine reads as stiff. If the line strays too far from the support, the pose looks unbalanced ([CSP tips](https://tips.clip-studio.com/en-us/articles/7847); [UW posing notes](https://courses.cs.washington.edu/courses/cse459/10wi/reading/posing.pdf)).
- **Contrapposto.** The hip line and the shoulder line tilt in opposite directions. The hip rises on the support side. This bilateral opposition is what gives a pose weight ([Fonseca, BU](https://eprints.bournemouth.ac.uk/25588/1/Jose%20Fonseca_Poster_BU_OpenAcess.pdf)).
- **No twinning.** Mirror-symmetric arms, legs or shoulders read as amateur. The fixes are to twist the hips against the shoulders, tilt the hip and shoulder lines, offset one arm or leg, or move off a straight-on view ([Animator Island, Twinning 102](https://www.animatorisland.com/?p=2053); [Animation Mentor](https://www.animationmentor.com/?p=4836); [Illusion of Life notes](https://animationapprentice.blogspot.com/2025/08/why-animators-choose-asymmetrical-poses.html)).
- **Contrast between keys.** Williams' "look for the contrast" and his head and hand "accents" ([Animator's Survival Kit](https://www.harvard.com/book/9780865478978)): a peak only reads as big if the key before it is compact and low. The prep should crouch and gather (limbs in, body down 5–8 % of height). The peak should open and extend. The settle should land between the two.
- **Silhouette first.** Fill the sprite with solid black. The accent limb must stand out against empty background, not overlap the torso ([freegamesprites silhouette test](https://freegamesprites.com/es/news/sprite-silhouette-test-character-readability); [Wayline pixel lesson](https://www.wayline.io/learn/pixel-art/4)). Fighting-game spriters keep the startup and recovery keys the clearest, and many draw over 3D models for consistency ([Tiny Warrior Games](https://tinywarriorgames.com/?p=969)).
- **Cumbia flavour.** Knees stay soft, the hips follow the stepping foot, the shoulders are loose and accented, and the arms are open with elbows slightly bent, not flailing ([cumbia.fm](https://cumbia.fm/en/blog/how-to-dance-cumbia-rhythms-steps-and-soul/)). So the groove's "epic" comes from the hips and knees and the angle between them. Save big arms for the accent keys.
- **Pixel budget (my arithmetic, not from a source).** At about 110 px for 1.8 m, 1 px is about 1.6 cm. A 27 cm forearm turned by 5° moves the wrist about 1.5 px, and a 3° head tilt moves less than 1 px. **A change below about 10° on a limb, or 5° on the torso, cannot be seen in the sprite.** Most groove deltas today are 2–6°.
- **Overlapping action.** The hat brim and shirt hem should trail the head and hips by one drawing: tilt the brim against the last head motion, then let it settle on the next drawing. This is secondary action. It must never cover the accent limb or the face (fluidity-pass rule).

## 2. Critique of the vocabulary, and rig-level changes

Observed in `contact.png`: every groove, walk, watch and social frame is a near-vertical, front-on, straight-legged figure. The arms hang against the torso with blue and red merging, and the hips are always level.

### Structural causes in `standin.py` (fix these first)

1. **The pelvis never tilts.** Hips get only `rot(Z, twist*0.3)`, so the hip line is always horizontal, and `side_bend` only rolls the torso above the pelvis. Contrapposto is impossible. **Add `pelvis_roll`**, applied to the hip offsets as `rot(Y, pelvis_roll)` and passed to the torso as well. Then let `side_bend` be the counter-tilt of the shoulders (opposite sign, about 0.6–0.8 of `pelvis_roll`). Also add a small `shoulder_roll`, or derive it from `side_bend`.
2. **Knee bends point at the camera.** Flex is toward the viewer, so under the orthographic front camera `l_thigh=(2,14)`, `l_shin=(2,-8)` reads as a straight leg. That is why "down" doesn't read as down. Either:
   - put part of the bend into abd: knees open outward, plié style, with thigh abd +15…+25 and shin abd −5…+5 so the shin returns under the knee; or
   - cheat the body to `yaw` ±15–25° so the flex projects.
3. **The weight shift slides the feet.** `plant()` corrects only z, and `pelvis_x` moves both legs with the pelvis, so the support foot is not under the centre of mass. Fix it in one of two ways:
   - plant x on the support ankle too, by translating so that ankle stays at the clip's pivot, then let `pelvis_x` read as a hip push; or
   - give the support thigh abd of −6…−10, toward the midline, so the ankle sits under the pelvis while the free leg goes out.
   This also strengthens the support-foot grounding the manifest relies on.

### Pose-level changes (rough ranges; all assume the fixes above)

| Clip | Problem | Change |
|---|---|---|
| groove down_* | Level hips, straight legs, ±3° head, arms at 18–22° | `pelvis_roll` 8–12 (high on the support side), `side_bend` −6…−9 counter, `twist` 10–15 toward the free leg, `yaw` ±15 alternating per side. Support knee bent 20–30° in the visible plane. Free leg toe-touch out with thigh abd 15–20. Drop the body 5–7 %. Arms open to abd 35–50 with forearm bent 60–80°, one high and one low (wrists ≥20° apart in height). `head_side` 8–12 opposite the shoulder tilt. |
| groove up_* / pass | The same pose at lower amplitude | Keep it as the contrast key: near level but still asymmetric (`pelvis_roll` 3–5, `twist` passing through 0). Don't zero everything; the pass should carry the twist across. |
| left/right_hand peak & follow | The arm is vertical beside the head (abd 155–168), passes the hat, and is a tangent. `support="both"`. `side_bend` only +6. | Support on the **opposite** foot. `pelvis_x` pushes the hip to the support side, with `pelvis_roll` 10. `side_bend` +12…+18 toward the raised hand, giving a long diagonal from the support foot to the hand. Upper arm abd 130–145, forearm 145–160 (a diagonal; the wrist clears the hat by more than one head radius). Free leg extended toe-touch (abd 15–25) to continue the diagonal. Head turned toward the hand and looking up (`head_turn` 20–25, `head_nod` −12…−15). Follow overshoots by +8–10° on the arm, not the 13° on the forearm alone. |
| left/right_hand prep | Not compact enough to contrast | Crouch: drop 6 %, the accent arm crosses low (abd −10…−20, forearm flex 40), `twist` −10 away from the coming accent, head down 6–8. Keep the wrist outside the torso silhouette; low in front of the hip is fine. |
| left/right_foot peak | The kick reads, but the torso is upright and the arms are symmetric (45/50) | Counter-lean: `side_bend` −12…−16 toward the support leg, `pelvis_roll` 10–14 (hip lifts on the kick side). The arm opposite the kick goes high (abd 100–120); the same-side arm is low and back. Turn the head toward the kicking foot. |
| watch / clap / approval / reassurance / challenge.proud | Mirror-twinned arms (identical tuples) | Never use identical arm tuples. **Clap:** clap off-centre at chin height on the side the head turns to, `yaw` 20, the near arm long and the far arm short, wrists meeting outside the torso. **Proud:** one fist on the hip, the other arm pointing or beckoning (abd 70–90), chin up 10, weight on one leg with `pelvis_roll` 10. **Reassurance open_hand:** one palm higher (abd 70 vs 40), head tilted 10–12. **Watch:** `pelvis_roll` 8 hip-cock, arms crossed only if the wrists stay inside the torso outline. Otherwise put one hand on the hip, so OpenPose isn't asked to resolve crossing forearms. |
| finish_turn finish_a/b | Already the best poses | Push `side_bend` to 14–18, add `pelvis_roll` and hat-brim lag on finish_b. |
| walks | Acceptable | Add `pelvis_roll` ±5 that follows the support leg, and a ±6 head bob. |

### Guardrails that keep these changes safe

- **Grounding:** the support ankle stays fixed in x and z across a clip, and the free foot never goes below `groundY`. Add an assert to `plant()`.
- **Limb identity:** keep the accent limb on the near or open side. Cap `yaw` at ±35° outside turn clips, and don't flip the yaw sign inside a clip, so left and right never swap depth order between drawings.
- **OpenPose readability:**
  - Keep every wrist at least 1.2 head radii from the nose and ear points.
  - Don't let a forearm segment cross another limb segment in 2D. Check this programmatically from `rig.json`, warn on it, and re-pose.
  - Keep foreshortened segments at ≥60 % of their projected rest length.
- **Frame-to-frame identity:** shoulder width in 2D varies by no more than 25 % within a non-turn clip. Torso length and head size are constant (already true).

## 3. Control stack per pose type (SDXL)

Models: [xinsir controlnet-openpose-sdxl-1.0](https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0) and [xinsir controlnet-union-sdxl-1.0 / ProMax](https://huggingface.co/xinsir/controlnet-union-sdxl-1.0) for depth and lineart (both Apache-2.0, PENDING/PROPOSE in project docs). The xinsir card notes:
- the model expects **thick skeleton lines** and gives a replacement `draw_bodypose`; thin lines give unstable output;
- the bucket size is about 1024²;
- other bases need the fp16-fix VAE.

The union model fuses conditions without extra hyperparameters, but publishes no recommended scales. ComfyUI's Apply ControlNet takes strength (recommended 0.5–1.5) and a start/end percent window ([docs.comfy.org](https://docs.comfy.org/built-in-nodes/ControlNetApply)). The community starting point for chaining is openpose 1.0, end 0.7 plus depth about 0.6, end 0.6 ([eastondev guide](https://eastondev.com/blog/en/posts/ai/20260719-comfyui-controlnet-guide/)).

Everything below is a **starting value to sweep**, not a verified result.

| Pose type | OpenPose (str, start–end) | Depth | Lineart | Init / other |
|---|---|---|---|---|
| Groove, walks (moderate) | 0.9, 0–0.75 | 0.4, 0–0.5 | 0.3, 0–0.6 | Flat region render as img2img at denoise 0.6–0.7 |
| Exaggerated peaks (overhead arm, kick, deep lean) | 1.0–1.1, 0–0.9 | 0.6, 0–0.6 | 0.5, 0–0.7 | Region init at denoise 0.5–0.6. This anti-collapse step matters most, because the extended limb is already painted, so the sampler can't fold it back into the body. |
| Overlap poses (clap, hand on hip, crossed) | 0.8, 0–0.7 | 0.7, 0–0.7 (carries front/back order) | 0.5, 0–0.7 | Region init. Prompt the hands only lightly. |
| Turns, rear and profile views | 0.4–0.5, 0–0.5 (or off) | 0.7, 0–0.7 | 0.6, 0–0.8 | Region init. Mācron: no OpenPose at all (doc §3.3). |

Practical notes:

- **Lightning 4-step quantises the windows.** At 4 steps, end 0.5 means 2 steps, so an end percent can't be tuned finer than 0.25. Sweep end ∈ {0.5, 0.75, 1.0} on Lightning, or tune on SDXL base at 25 steps first (this is still the doc's open question 1).
- **Keep the summed strength around 2.0 or below.** Stacked strong controls overcook edges and fight the IP-Adapter (heuristic).
- **Every control image must come from the same render and the same pixels.** Misaligned depth and pose make the controls fight each other.
- **Don't feed `regions.png` to the union "segment" type.** It was trained on ADE20K-style semantic colours, not our palette (inference from the card; untested). Use regions as the init and as masks for regional prompting or post-checks.

Known failure modes and mitigations:

- **Front-facing feet.** COCO-18 stops at the ankles, so OpenPose carries no foot direction, which lets feet splay or point backward. Let depth and lineart carry the feet (keep both on through about 0.6), and keep `toe_out` 10–15 so the feet show some width.
- **Hands.** COCO-18 has no hand keypoints, so hands get invented. Keep hands as simple mitts in the lineart, prompt "simple hands, closed fist / open palm", and paint hands on in the pixel finish if needed. Don't add hand skeletons; xinsir's own example runs with `hand_and_face=False`.
- **Foreshortened limbs.** A short projected bone gives a stubby or missing limb. Avoid limbs pointing straight at the camera (use the yaw cheat), and raise depth to 0.6–0.7 on those keys.
- **Limbs crossing the head or torso.** The generator merges the arm into the hat or body. The guardrail is the ≥1.2 head-radius wrist clearance. Omit occluded keypoints rather than drawing them behind the body.
- **Left/right swap in rear or near-profile views.** This is a known OpenPose limb-switching weakness ([Sensors 2021 appendix](https://pmc.ncbi.nlm.nih.gov/articles/PMC8074772/figure/sensors-21-02889-f0A4)). Lower OpenPose and lean on depth, and check limb identity against `rig.json` in review.
- **Thin default skeleton.** Use xinsir's thick `draw_bodypose`, scaled to the canvas.

Never use flux.1-dev, sd3.5, sdxl-turbo, RMBG or InsightFace. The stack above needs none of them.
