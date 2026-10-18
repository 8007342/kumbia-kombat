# FORGE_DIAGNOSTICS

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
