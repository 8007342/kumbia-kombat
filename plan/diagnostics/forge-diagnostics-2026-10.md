# Forge diagnostics archive, 2026-10

Dated session logs moved out of `FORGE_DIAGNOSTICS.md` on 2026-11-05, so that file can stay short.
The text below is verbatim and is not updated: much of it describes old forge images and old
branch rules. For what is true now see `../../FORGE_DIAGNOSTICS.md`, and for the distilled lessons
see `../../LESSONS_LEARNED.md`.

Contents, in order:

1. `work/2610-pipe` session, 2026-10-29. Exists only on that unmerged branch.
2. `work/1829-danc` publication note, 2026-10-28. Exists only on that unmerged branch.
3. The body of `FORGE_DIAGNOSTICS.md` as of `07cd19d` on `work/1833-cast`, unchanged and in its
   original order (the dance staging session first, then the 2026-10-18 bootstrap notes).

Only the separator lines and the "Source" lines were added here.

---

**Source:** `origin/work/2610-pipe` tip `8cc7ac82b4c6b3e537327a943822515ce785d4ee`, commit
`8cc7ac8`, the section that commit added to `FORGE_DIAGNOSTICS.md`.

## Opponent performance and asset pipeline session — 2026-10-29

Work was performed on `work/2610-pipe`, following this project's Level 2 work
ref discipline. The branch already contained the sprite pipeline plan and an
earlier cloud-generated Gatekeeper dance candidate. Three focused commits were
pushed successfully after the forge pre-receive hook caught one ledger issue.

### Forge capabilities confirmed

- `npm run build` uses the installed shared Flutter toolchain (Flutter 3.47.7)
  and builds the web app to `build/web`. The release build completed in about
  64 seconds in this session.
- The authenticated `publish_local` / `service_reload` facilities can run a
  sibling Wrangler preview. This project's existing WEB preview used Wrangler
  with watch enabled; after the build, `service_reload` reported the route
  ready and serving at `https://www.kumbia-kombat.localhost:18443/`.
- Host-browser navigation can open that local HTTPS preview in the existing
  visible development window. This was done after rebuilding.
- The cloud image generation service produced a transparent-background
  Gatekeeper travel-sheet candidate. It is 1215x1295 RGBA and was recorded with
  its prompt, provenance, and SHA256 in
  `assets/art/pipeline/candidates/gatekeeper-travel-cloud-20261029.run.json`.
  The sheet is a pipeline candidate, not a validated runtime atlas: cell bounds,
  baseline consistency, and gait alternation still need review.
- Existing session research found a local Ollama service available for local
  language-model inference. No image-generation model was loaded through it;
  Ollama availability alone did not provide a proven image pipeline. ComfyUI
  sibling-container facilities were not available as a ready image in this
  session, and this project container cannot start additional containers.
  The documented next step is to validate the forge's sibling-container
  ComfyUI service/image and its custom-node inventory before implementing that
  backend. Cloud imagegen can supply candidates in the meantime.
- Git mirror pushes relay to GitHub and reported durable upstream acceptance.
  Three small pushes completed for this work branch.

### Project findings and changes

- Reviewed Mācron's animation history: the existing pipeline moved from an
  initial generated dance sheet to measured raster atlases and then
  chart-driven anticipation, accent, follow-through, and settle choreography.
  Mācron also has a dedicated spin/view sequence. Opponents had chart-derived
  semantic pose selection, but each semantic pose resolved to a single source
  rectangle rather than an authored within-phase sequence. Scene rendering
  also did not consume the existing `BattleStaging` module, explaining the
  weak opponent dance and sliding travel.
- Added the `opponent-performance` OpenSpec change for readable, increasingly
  complex chart-faithful opponent dances; grounded entrance/exit transitions;
  metadata-driven depth and scale; and reversible crowd response. Strict
  OpenSpec validation passed.
- Added `plan/animation-research-register.md` to retain animation and game
  development references, their practical Kumbia guidance, and the limits of
  each source. It includes Disney animation process, GDC animation talks,
  Ubisoft predictive foot IK, Dead Cells production workflow, Valve's Left 4
  Dead AI Director paper, and additional game/animation references. The Valve
  paper is explicitly treated as pacing research rather than sprite-animation
  guidance.
- Updated `CrowdInterestModel`: isolated failures still produce the nearby
  stumble response, while repeated consecutive failed phrases cool the full
  room progressively; a passing phrase clears the failure streak. The initial
  room cooling decrement is `.025` per repeated failure and remains a tuning
  value, not an evidence-backed final balance.
- Added and documented a second cloud-generated Gatekeeper travel candidate.
  Neither this travel sheet nor the earlier dance sheet is wired into runtime.

### What worked and what did not

- Strict OpenSpec validation, JSON provenance parsing, `git diff --check`, and
  the release web build succeeded. No automated tests were run in this session.
- The first push of the specs commit was rejected because the generated
  `.openspec.yaml` had an unquoted ISO date. The server's Ruby Psych safe YAML
  parser interpreted it as a `Date` object and rejected the ledger. Quoting the
  date string and amending the commit resolved the issue; the retry and later
  pushes were accepted. Quote date-like YAML scalars in future ledger files.
- The development preview was reloaded after the build and the existing browser
  window navigated to it successfully. This confirms the route and page load,
  but is not a mobile gameplay or animation smoke review.
- Opponent phase sequences and the `BattleStaging` renderer integration remain
  implementation work. The travel candidate has not been cropped or measured,
  and opponent complexity, entrances/exits, perspective scaling, and crowd
  response still need runtime review and tuning.

### Remote work refs

- `83dd0bf docs: define opponent animation standards and research`
- `b4eaf8f feat: cool crowd after repeated phrase failures`
- `d399282 art: add Gatekeeper travel candidate`

All three commits were pushed to `origin/work/2610-pipe`. The OpenSpec change
is intentionally still open while implementation tasks remain.

---

**Source:** `origin/work/1829-danc` tip `087b1867a3c759e50cb51a20c4fb9fd0d1ca164d`, commit
`087b186`, the section that commit added to `FORGE_DIAGNOSTICS.md`.

## Direct main publication clarification — 2026-10-28

The stable `game` integration was merged directly to `main` after the owner
asked for a remote phone-test build. This worked under the **current** forge
configuration; earlier notes below describe a different historical seed and
must not be read as the current outcome.

- Before publishing, `tillandsias-plan discipline show` reported Level 2 with
  `default_branch: main`, but specifically `enforcement.default_branch: warn`.
  `tillandsias-plan discipline check-ref refs/heads/main` returned
  `warn:discipline:default-branch-protected`, not `refused`.
- The installed local `.tillandsias/hooks/pre-push.lua` maps only an
  `enforced` verdict to refusal. It emitted the seed remedy text saying direct
  pushes are refused, which conflicted with the actual `warn` verdict. The
  local hook therefore printed a warning and allowed the push.
- The remote pre-receive hook was authoritative and also reported
  `warn only: accepted`; the mirror relay pushed the ref to upstream and
  verified durable acceptance.
- Stable `game` at `e045f16` was merged locally into `main` as `caacc6b` and
  pushed directly. `git fetch origin` confirmed `origin/main` at `caacc6b`;
  upstream relay confirmed success. The push was not a bypass: both policy
  layers were in warning mode.
- The resulting `main` update is intended to trigger the remote build for the
  owner's touchscreen phone playtest. The requested staging implementation and
  generated v3/travel assets were not part of this publication and remain
  documented recovery work in `plan/opponent-depth-staging-pass.md`.

### Wording improvements

The behavior appears to be working as configured. The confusing part is that
the seed's `remedy` still says direct pushes “are refused” while enforcement is
`warn`, and the local hook prints that remedy unconditionally. That text should
be made mode-aware: in warn mode explicitly say the push **will be accepted**
and recommend the normal branch flow; in enforced mode say it **will be
refused**. The forge should keep the distinction visible in both
`check-ref` output and pre-push/post-receive messages. Do not infer enforcement
from the protection rule name alone; check the verdict and the configured mode.

The push is now also recorded in commit history and remote refs. This note is
being committed separately on `work/1829-danc` for durable diagnostics; it does
not need another integration merge.

---

**Source:** `FORGE_DIAGNOSTICS.md` at `07cd19deb73fac5d273e5c3e3f1502b0ddd2ba91` on `work/1833-cast`,
lines 3-283.

## Dance staging implementation session — 2026-10-28

The owner asked for a fleet implementation pass based on the dance-fluidity and
opponent-depth research, then explicitly requested a frequent push to remote
work branches and a detailed record of this session. Work was on
`work/1829-danc`, based on `cb3279f` (`docs: plan opponent depth staging pass`),
which already held the sprite-based cast, reactive crowd, AutoPlay, wardrobe
rendering fixes, and two research plans.

### What went well

- Existing generated sprites, pixel-art manifests, music-clock choreography,
  perspective floor projection, crowd-interest state, and AutoPlay were present
  on `origin/work/1829-danc`; their smoke tests and browser renders had worked in
  the earlier part of the session.
- Flutter unit tests ran successfully: 110 tests passed after adding the
  depth-staging and art-geometry coverage. `flutter analyze --no-pub` reported
  no issues, and `openspec validate living-party --strict --no-interactive`
  accepted the change.
- The release web build completed, and the static preview successfully loaded
  the new Gatekeeper and Mācron companion textures (HTTP 200). The initial
  sprite scene showed the audience, room perspective, and existing controls.
- Debug web output exposed a real scene exception hidden by release minification:
  `Bad state: Transport has no audio anchor`. The new staging code asked for
  `secondsAt()` while a silent/headless scene was still rendering before audio
  start. Guarding the optional protection-window calculation until transport
  sections exist removed the exception. A follow-up debug-browser run reached
  the playable scene with no runtime errors.
- The `.35` Mācron stature was explicitly checked in the scene integration: the
  travel atlas has its own measured reference crop and scale, preserving the
  toy-sized proportions through floor movement.
- Project discipline identified the expected Level 2 work-ref policy. The
  branch name `work/1829-danc` is valid and the history includes several prior
  frequent pushes, demonstrating the mirror path previously worked.

### What required figuring out

- A conversation interruption reset the checkout from `work/1829-danc` to the
  `game` integration branch and discarded uncommitted files in the session
  workspace. This was diagnosed by `git branch --show-current`, `git branch -a`,
  `git log --all`, and `git status`. The work branch remained on origin and was
  checked out again. The lost source edits and generated assets were not in the
  branch history, and the generated-image cache paths from the earlier context
  no longer existed.
- Flutter commands after the interruption failed because `.dart_tool/package_config.json`
  had disappeared. `flutter pub get` restored generated package metadata without
  changing the lockfile, after which the release build succeeded.
- A preview reload failed with `no preview to reload` because the interrupted
  environment had stopped the local service. `publish_local --category WEB
  --runtime static` restored it and the host browser opened the app again.
- The first smoke attempt was on the wrong branch and showed the old rectangle
  crowd; checking branch and history separated that stale integration preview
  from the intended sprite-based work branch.
- Host-browser screenshots can be returned as image content through
  `Page.captureScreenshot`; printing the whole tool response as text emits a
  huge base64 payload. Forwarding the image block directly avoids that output.

### What did not work

- The requested implementation is not complete on the remote yet. The
  interruption removed the prior uncommitted Gatekeeper v3 atlas/choreography,
  Mācron travel sheet/scene integration, and its tests before they could be
  committed. The earlier generated-image cache files are absent, and this
  continuation hit the image-generation tool's usage limit before regenerating
  them. Agent continuation attempts also stopped at their usage limit. These
  are external session/tool capacity failures, not failures in the image or
  code paths themselves.
- Therefore the current branch still uses the preexisting sprites and does not
  yet contain the depth-staging feature requested in this session. Only the
  recoverable crowd-slot layout edits, their tests, and the staging module/tests
  currently visible in the worktree can be preserved here. No claim is made
  that these are a complete playable implementation.
- A release build produced a large number of minified exceptions in the
  headless preview. Debug mode gave the actionable transport-anchor message;
  the code fix passed tests and a debug smoke run. A final release rebuild after
  that fix succeeded, but the live preview service later stopped during the
  interruption and the regenerated working tree still needs a full final
  release smoke check.
- Remote pushes, although successful in earlier turns on this work branch,
  could not be completed before the interrupted session. This diagnostics
  update and the currently recoverable changes still need committing and
  pushing now.

### Session sequence and handoff

1. Reviewed the already-pushed research plans for fluid animation and
   depth-aware floor staging; delegated the Gatekeeper, crowd-layout, and
   choreography tasks.
2. Integrated (in the interrupted workspace) a 56-drawing Gatekeeper pilot with
   50 safe measured crops, authored aliases, companion Mācron travel art,
   sequential route marks, input-window protection, and closer foreground
   audience anchors. Added provenance and tests. None of these uncommitted
   implementation files survived the workspace reset.
3. Ran the test suite (110 passed), analysis (clean), strict OpenSpec validation
   (valid), and a release build (success). Live debug testing revealed and
   verified the transport guard fix.
4. The requested next step is to complete and verify the recoverable worktree,
   then commit and push to `origin/work/1829-danc`. Do not report the feature as
   complete until the missing art integration has been restored, a release
   preview has been smoke-tested, and the push is confirmed.

Observations from the first forge session that bootstrapped this project
(empty repo → Flutter web + Flame "under construction" landing page, OpenSpec,
Cloudflare deploy config, branch discipline level 2). Written for whoever runs
the next forge: what worked, what broke (loudly and silently), and what to fix
in the forge image/tooling.

## What went well

- `start-a-new-project` scaffold + `flutter create` + `pub add flame` produced a
  clean app; `flutter analyze` and `flutter test` passed with no ceremony.
- `npm run build` (→ `tool/build.sh`) self-bootstraps a pinned Flutter SDK when
  none is installed and produced `build/web` end-to-end.
- The git mirror push path (`tgp` / `git-tools_git_push`) worked first try and
  relays to GitHub (`https://github.com/8007342/kumbia-kombat.git`).
- `tillandsias-plan discipline raise`, `check-ref`, `derive`, and `hook` all do
  what the skill says; the `seed-ahead-of-reality` drift rule behaved exactly as
  designed (warn now, refuse once `game` exists on origin).
- Customizing the pre-push refusal wording via `.tillandsias/hooks/pre-push.lua`
  works and is a clean override point (contract documented in the embedded
  template header).

## Failures that were loud and got fixed

1. **Global `core.hooksPath` blocked discipline hooks.** The image sets
   `core.hooksPath=/home/forge/.cache/tillandsias/git-hooks` in `~/.gitconfig`,
   so `discipline install-hooks` refused (`refused:install-hooks:global-hooks-path`).
   Fix: `git config --local core.hooksPath .tillandsias/hooks`. A fresh clone
   needs the same one-liner (or the forge should set it at project-init time).

2. **`tillandsias-plan` not on `PATH`.** The binary lives at
   `/usr/local/lib/tillandsias/policy-bin/tillandsias-plan`; the installed hook
   stubs exec `command -v tillandsias-plan` and refused with
   `blocked:hook:pre-push:no-plan-binary` until it was symlinked into
   `~/.local/bin`. Fix for next run: symlink or PATH the policy-bin directory
   before installing hooks.

3. **Seed grammar foot-gun (`work_ref`).** `discipline raise --to 2` writes a
   seed with no `work_ref`. Setting `work_ref: work/<id>` validates but
   `check-ref` then rejects every real work branch (`work/001-test`,
   `work/1234-abcd`) because the field is a regex, not a template. The working
   form is `work_ref: 'work/[0-9]{3,4}-[a-z0-9]{4}'`. Document the field as a
   regex, or have `raise` write a sane default.

4. **`messages.default_branch_denied` is inert in the client hook.** The seed's
   custom message shows up in `discipline check-ref` remedies, but the embedded
   pre-push template ignores it and prints canned wording. Worked around with a
   `pre-push.lua` override. Either honor the seed message in the template or
   document that only `check-ref` reads it.

## Silent failures / traps (the ones that cost the most time)

- **Empty probe commits land on `origin/main` during the warn phase.** Before
  `game` exists on origin, `default-branch-protected` only warns, so a push
  test actually pushes (empty commit `5cff664` "probe" is on remote `main`
  because of this). The hook prints a warning, not an error — easy to miss in
  noisy output. Suggestion: while `seed-ahead-of-reality` is active, have the
  warn say explicitly "this push WILL be accepted" or offer a dry-run flag.
- **Stale Dart LSP.** The editor LSP reports phantom
  `Target of URI doesn't exist: 'package:flutter/…'` on every file even after
  `flutter pub get`; `flutter analyze` is ground truth. Restarting the language
  server or pointing it at the project's pub cache fixes it.
- **`discipline derive` reports `installed_hooks=[]`.** It `ls`es
  `<git-common-dir>/hooks`, which ignores `core.hooksPath`, so a correctly
  configured repo looks hook-less. Derive should read `core.hooksPath` first.
- **Untracked `.cache/` in repo root.** The plan binary writes
  `.cache/metrics/command-policy-audit.jsonl` into the CWD; now gitignored.
- **`gh` is installed but unauthenticated** — agents cannot open the PRs the
  discipline model requires (`work/*` → `game` → `main`). Operators need to
  `gh auth login`, or the forge needs a machine token, or the level-2 flow
  needs a non-PR landing path for a single-operator repo.
- **Branch names with a trailing slash are invalid** to git; the "game/
  integration branch" wording in tooling should render as `game`.
- **Mirror enforcement is invisible until you test it.** The mirror's
  pre-receive reads the seed from the *integration branch's* tree, so the seed
  and the `pre-push.lua` override must be pushed on `game` (not only `main`)
  for server-side wording to match.

## Expected behaviors (not bugs)

- Level-2 rules warn until qualifiers appear (`seed-ahead-of-reality`), then
  refuse. This is by design and worked as specified.
- Hook stubs refuse closed (`no-plan-binary`) rather than guessing — correct.
- `install-hooks` refuses with a global `core.hooksPath` rather than fighting
  the user's config — correct, just surprising on this image.

## Improvements for the next forge image

1. Put `tillandsias-plan` on `PATH` (or symlink at image build time).
2. Don't set a global `core.hooksPath` in the image gitconfig, or make
   `install-hooks` auto-set the repo-local one with a note.
3. `raise` should write a default `work_ref` regex and honor
   `messages.default_branch_denied` in hook templates.
4. `derive` should honor `core.hooksPath` when counting installed hooks.
5. Auth for `gh` (or a PR-less landing path) before any project adopts
   integration-branch + PR discipline.
6. Warn-phase pre-push output should state loudly that the push will succeed.

## Foundation session — 2026-10-18

- Reproduced the missing PATH wiring and inherited global hooksPath on this
  checkout. The documented binary still exists and runs at
  `/usr/local/lib/tillandsias/policy-bin/tillandsias-plan`.
- Restored `~/.local/bin/tillandsias-plan` symlink and repo-local
  `core.hooksPath=.tillandsias/hooks`. If a harness PATH omits ~/.local/bin,
  set `TILLANDSIAS_PLAN_BIN` to the absolute path for git operations.
- `discipline show`: seed level 2; `derive`: observed 1/effective 1 because
  only one committer host is visible. This is the documented early opt-in
  warning phase; work still follows level 2 by project instruction.
- Initial remote connectivity probe used `work/kumbia-foundation`, accepted
  with a grammar warning. Actual work moved immediately to grammar-valid
  `work/1824-kumb`, successfully relayed and durably accepted by GitHub.
  The initial probe ref contains only the preexisting integration commit.
- Standalone `dart` resolves to Dart 3.12.1, while the Flutter wrapper uses
  Flutter 3.47.7 / Dart 3.13.5 and the project declares SDK ^3.13.5. Thus
  plain `dart run tool/music/transport_check.dart` fails on package language
  version even though Flutter analyze/test pass. The standalone music build
  writes an empty build/music-preview/packages.json and uses
  `dart --packages=build/music-preview/packages.json` for dependency-free
  transport checks. This avoids changing the app SDK constraint; use Flutter's
  bundled Dart for package-aware work.
- GitHub CLI remains unauthenticated this session (`gh auth status`); git
  mirror pushes succeed independently. Lakanoa public API returned 404;
  its initials implementation could not be inspected.
- Flutter dev wrapper successfully starts shared-toolchain `flutter run -d
  web-server --web-hostname 0.0.0.0 --web-port 8080 --hot` and announces
  `https://flutter.kumbia-kombat.localhost:18443/` as routed. After Flutter
  reports serving, host-browser `browser_open` still rejects that exact HTTPS
  URL with `URL_NOT_ALLOWED: not in active routes for project`. HTTP/8080 is
  also refused because the browser requires HTTPS. No route policy bypass
  was attempted. The separately published static `www` music preview opens
  visibly and works; route registration/allowlist synchronization needs repair.
- GitHub connector draft-PR creation also returned API 404 for this private
  repo despite successful mirror pushes. Work is safely on remote
  `work/1824-kumb`; PR creation remains an operator/access followup. Do not
  merge directly into game to work around missing PR access.

## Garden/storyboard continuation — 2026-10-18

- Stock Flutter builds try to fetch CanvasKit from gstatic and a default font;
  host-browser's project-only network rejects those requests. Build with
  `--no-web-resources-cdn` and bundle the UI font. `tool/build.sh` now does so.
- Managed static preview of build/web returned 404 for existing canvaskit/
  files and the added music/ subtree while serving assets/ and root entry files.
  Re-publish/reload did not fix it. Publishing the root project's existing
  Wrangler configuration (`runtime=wrangler`) serves those paths correctly.
- Wrangler watch can exit on a transient ENOENT under assets/shaders while
  Flutter replaces build outputs. After builds finish, `service_reload` restores
  the local preview. The Request.cf DNS warning is harmless in local mode;
  the fatal error observed was a disappearing shader file during rebuild.
- Mobile screenshots at DPR 3 with the detailed garden exceed the MCP 4 MiB
  per-line cap. Use page-level CDP Page.captureScreenshot with JPEG/quality 50,
  or set DPR 1 in an agent-owned headless test window. Do not print base64.

## Mobile-test release attempt — 2026-10-18

- User explicitly requested the more forgiving timing prototype be merged into
  main for auto-publication. Commit cb61c74 is durably pushed to
  work/1826-time and game. Flutter analysis is clean and all 20 tests pass.
- GitHub connector create_pull_request (game → main) still returns API 404
  Not Found. `gh auth status` confirms no authenticated GitHub hosts.
- A normal push of the reviewed game head to main was refused locally:
  `refused:hook:pre-push:default-branch-protected:enforced`. The hook requires
  a pull request. No hook or protection was changed or bypassed.
- Release is ready at game. Restore GitHub connector access to this repository
  or authenticate gh, then open/merge game → main. Alternatively the owner can
  open https://github.com/8007342/kumbia-kombat/compare/main...game directly.
  Main was not updated; automatic production publication was not triggered.

## Owner-authorized manual publication attempt — 2026-10-18

- Owner explicitly authorized manual merging/pushing while PR access is broken.
- Prepared a clean no-conflict merge of origin/game into local main. Code tree
  matches the already tested game prototype exactly.
- One-time push skipped only the client PR-only hook, with no persistent hook
  or seed changes. The remote independently rejected main before upstream relay:
  `blocked:branch-discipline:default-branch:main:level=2`.
- The merge is preserved on work/1827-publ, then integrated into game. Main on
  the remote remains unchanged. An operator must restore PR API access or add
  an authorized manual landing path to the mirror; a client-only exception
  cannot publish main. No server policy was modified.
