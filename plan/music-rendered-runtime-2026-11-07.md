# Rendered music in the game: runtime notes, 2026-11-07

**Status: in progress. The runtime is written and passes its tests with a fake clock. It has not yet run in a browser, and no rendered music has been played by the game.** This note covers `plan/music-rebuild.md` stages 5 and 6 on branch `work/1855-rend`.

## What exists (fact)

- Each transport section can name a rendered clip. Where it does, the take replaces the song's synth notes; cues and accents still sound.
- Takes loop natively on their loop points. A file position is worked out from the beat, so pause, resume and replay need no stored audio position.
- The tempo comes from each take's loop points. Five game tiers map to three takes through `tierTakes` in the manifest, and nothing assumes tempo rises.
- If a take isn't decoded, the tier change waits and the clock stays with the music that's playing. If nothing is decoded, the synth plays at the takes' tempos, so chart times don't change.
- Buses: master, music, accents, rewards. The resume fade has its own gain, so a slider and a fade can't overwrite each other.
- `?mixer=1` shows the owner's mixer. Without the flag it isn't built.

## What went wrong

- `rsync` isn't installed in the forge, so the first preview sync didn't run. My command then deleted my own build, which cost one rebuild. The preview wasn't touched.
- A server inside the forge can't be reached from the browser: windows load https only, and the server saw no request. So a click-track fixture can't be measured in a browser, and browser checks have to use real assets through the preview.

## Not done yet

- Merging the real assets, browser runs, drift, fps, memory and chart measurements. Results go here.
