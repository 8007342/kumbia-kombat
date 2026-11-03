# Tasks

## 1. Brief and plan

- [ ] 1.1 Write the level brief schema; verify valid files pass and unknown references, a missing Latin base and a non-palette variant are refused by name
- [ ] 1.2 Write briefs for garden and bar with owner-direction music; verify both validate, and deliver them for owner approval
- [ ] 1.3 Implement `level plan`, merging each pipeline's planner; verify with fixtures that a hat edit lists frames and in-frame shots and reports room and score unchanged, and that nothing changes on disk
- [ ] 1.4 Implement gate approvals by section hash; verify an unapproved brief is refused and a music edit invalidates only music approval

## 2. Charts and runtime data

- [ ] 2.1 Move `FightChart` data for garden and bar to files; verify `flutter test` shows identical charts and judgments
- [ ] 2.2 Add the chart rule validator; verify fixtures for cue lead, rests and form fail by name, and both current charts pass or their exceptions are recorded
- [ ] 2.3 Replace `partyRooms` and the hard-coded `garden_to_bar` with a level registry; verify a test registers a fake third room and transitions without per-room code

## 3. Audience and formations

- [ ] 3.1 Define guest silhouettes as `role: audience` characters with inverted gate checks; verify existing wardrobe fixtures in `test/outfit_palette_test.dart` still hold
- [ ] 3.2 Add formation files and the composed group check; verify a fixture covering a challenger fails by name
- [ ] 3.3 Add the bar counter formation; verify by a native-size contact sheet for owner review

## 4. Room art

- [ ] 4.1 Write the room schema and `bar` definition; verify refusals by name and that the floor plane matches `party_layout.dart`
- [ ] 4.2 Test `image.generate` `layout`/`mask` and studio inpaint for hidden-area fill on one bar layer; record which path to use
- [ ] 4.3 Implement stages for layers, fill and emissive; verify an edit rebuilds only its layer and that parallax shows no gaps at maximum offset
- [ ] 4.4 Generate the bar's layered background; deliver it at phone size for owner review
- [ ] 4.5 Add reserved-zone and calibration checks; verify an uncalibrated room is refused

## 5. Levels 1 and 2 end to end

- [ ] 5.1 Build garden and bar through `level build`; verify accepted work is reused, not regenerated
- [ ] 5.2 Play both levels in the preview, including `garden_to_bar`, `bar.outro` and `bar_to_crowd` entry; verify owner approval at phone size
- [ ] 5.3 Update `plan/level-3-readiness.md` with what the proof changed; verify every gap has a task or a recorded decision

## Workflow follow-up

- When the owner writes level 3's prompt, run it through this pipeline as a new change.
- Update `plan/roadmap.md` item 04 once levels 1–2 pass.
