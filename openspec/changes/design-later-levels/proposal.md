# Proposal: design the campaign's last three levels

## Why

The owner's brief of 2026-11-08 (verbatim in `plan/levels/mansion-act-two-2026-11-08.md`) sets the
campaign's end: a restroom boss rush whose music runs "from slow country ... into metal themes, and
turn into something like the Sabre Dance", then "a difficult Tango level to be the last", then "the
VIP section with the Tlatoāni, where all the previous opponents shall come back again and share a
massive tray of steaming tacos al pastor", then the credits. The owner believed the Sabre Dance
"is likely royalty free now". Research says it isn't: Khachaturian died in 1978, so it's protected
until the end of 2048 in the EU and Armenia, 2037 or later in the US (URAA restoration), and 2078
in Mexico (life plus 100). `plan/levels/later-levels-2026-11-08.md` has the research and designs.

## What Changes

- **storyboard:** three level designs as requirements: `restroom` (the boss queue of every earlier
  opponent's hardest combo, the music arc, Mācron's rising and tasteful urgency, the stall-and-eyes
  outro), `tango` (the hardest fight, by precision rather than speed), and `vip` (the rueda of returning
  opponents, Tlatoāni's last call, the tacos al pastor, then the credits). The VIP conclusion requirement
  gains the tacos and the credits.
- **dynamic-music:** the frenzy is original and made from style words only. No protected work is named,
  quoted, fed to a model or arranged.

Out of scope: building any of the three levels, art, music renders. The storyboard spec's outdated
"five continuous social challenges" requirement (Garden, Bar, Cool Crowd, Restroom, VIP) predates the
current twelve-level campaign; this change leaves it for a campaign-order change to replace.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `storyboard`: the last three levels and the VIP conclusion.
- `dynamic-music`: no protected works in generated music.

## Impact

Later: `levels/restroom.json`, `levels/tango.json`, `levels/vip.json`, a level kind that reads other
levels' `hardestCombo`, new opponent and Mācron clips, the scores and bridges, and moving the credits
trigger (`add-credits-roll`).
