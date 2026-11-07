# Tasks

## 1. Routing

- [x] 1.1 `routeFor` reads the first path segment, `?page=` and the hash; path only on the web
- [x] 1.2 `web/console/index.html` and `web/qr/index.html` with a fixed base; test keeps them in step
- [x] 1.3 `lib/main.dart` opens the console, the share page, gesture capture or the game

## 2. Console

- [x] 2.1 Catalog of levels, takes, atlases, clips, layers and close-up art from the shipping files, with references and problems
- [x] 2.2 Levels tab: campaign, flawless, mixer, listening page, share; per level play, flawless, outro, mixer, tier 0-4
- [x] 2.3 `?tier=` review start in the game
- [x] 2.4 Music tab: one `<audio>` at a time, BPM, bars, length, seekable position
- [x] 2.5 Rooms tab: plate, animated layers, layer boxes, floor overlay
- [x] 2.6 Moves tab: atlases by role, clips at data timing, code-timed clips, hold/step/mirror, frame index
- [x] 2.7 Close-ups tab: `ExitShot.sample` preview, close-up drawings with their users
- [x] 2.8 Notes: per item, local storage, copy all, clear with confirmation

## 3. Share page

- [x] 3.1 QR for https://kumbias.tlatoani.net, level Q, quiet zone, whole-pixel modules
- [x] 3.2 Title, address, night background, dancing cast from the atlases

## 4. Verification

- [x] 4.1 Catalog tests against the shipping files, a probe level and a broken file
- [x] 4.2 Widget test: the console lists the bundle, links open, a note is kept and counted
- [x] 4.3 QR: drawn modules match the encoder; quiet zone light; zxing decodes as drawn, at 120 px and blurred
- [ ] 4.4 On a phone: open `/console` and `/qr` on production and the preview; scan the code from a second phone
- [ ] 4.5 Owner: listen to a take and play a clip, then send notes with "copy all"
