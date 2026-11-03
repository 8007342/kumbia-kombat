# Tasks

## 1. Measure first

- [x] 1.1 Implement complexity gates over existing score JSON with fixtures; verify a synthetic transposed-repeat score fails and report today's five scores as the baseline
- [x] 1.2 Write the brief and motif schemas; verify a valid brief passes and an unknown voice or section is refused by name

## 2. Arranger

- [x] 2.1 Implement harmony, bass and voice-led accompaniment devices; verify unit tests, plus byte-identical rebuilds
- [x] 2.2 Implement motif operations, counter-melody and fills; verify tests and that seams stay on form boundaries
- [x] 2.3 Implement tier, success-phrase, bridge and adornment output; verify `tool/music/validate.mjs` and `transport_check.dart` pass on one new score
- [x] 2.4 Enforce the size budget; verify an over-budget fixture fails

## 3. Synth voices

- [ ] 3.1 Add new voice recipes in `lib/music` within the voice cap; verify `flutter analyze` and the preview page plays each

## 4. Prompt-to-score proof

- [ ] 4.1 Write a brief from the owner's sample prompt and build a complete score set; verify all gates pass, and deliver the preview page for listening
- [ ] 4.2 Redesign the bar score through the pipeline; verify gates and deliver it for owner listening before promotion
- [ ] 4.3 Document the flow in `tool/music/README.md` and verify its commands run

## 5. Models

- [ ] 5.1 Implement motif import with provenance from MIDI files; verify quantise and key-fit tests
- [ ] 5.2 Once the host engine exists, generate AMT variations of existing motifs; verify provenance records model and licence, and deliver them for audition
- [ ] 5.3 Once available, add Text2midi and ACE-Step transcription sources; verify only note data enters a score

## 6. Styles

- [ ] 6.1 Add style layers to the score format and conductor; verify cue deadlines are unchanged by layer changes
- [ ] 6.2 Build one replay score from a derived brief; verify gates and owner listening

## Workflow follow-up

- Update `dynamic-music` if the owner changes the cumbia requirement.
