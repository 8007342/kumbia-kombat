# Tasks

## 1. Data

- [x] 1.1 `tool/credits/build_credits.py` and `base.json`: Dart graph, Cargo.lock, Python imports and venvs, node, provenance, tool versions
- [x] 1.2 `assets/credits.json` committed, with degree on every item; `--check` for staleness

## 2. Page

- [x] 2.1 `lib/credits/credits_page.dart`: header, base, direct large, deeper in more columns and smaller
- [x] 2.2 Looping stand-in music through the console's `<audio>`, with a speaker button when sound is held back
- [x] 2.3 Close button; back to the end screen by itself after the end, or to `/` on its own page

## 3. Placement

- [x] 3.1 After the campaign's last end screen, 8 s
- [x] 3.2 `/credits/`, `?page=credits`, `#/credits`; `web/credits/index.html`
- [x] 3.3 The console's CREDITS link
- [ ] 3.4 Move the trigger to after the VIP's tacos when `vip` lands

## 4. Verification

- [x] 4.1 Data test: every pubspec.lock and Cargo.lock package is credited, with degrees
- [x] 4.2 Widget tests: sizes and columns by degree, scrolling, music, close, auto return, phone layout
- [x] 4.3 Campaign test: the credits follow the last end screen; console test: the link opens `/credits/`
- [ ] 4.4 On a phone: speed, sizes, reading the deepest column
- [ ] 4.5 Credits music made and swapped in for the stand-in
