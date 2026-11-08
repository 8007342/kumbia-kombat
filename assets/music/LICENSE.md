# Music asset provenance

Two kinds of music live here: audio rendered by a local model, which the game plays, and the original
synth scores, which it uses for count-ins, cues and as a fallback.

## Rendered music: `rendered/`

Everything under `rendered/` (`.ogg`, `.m4a`, `manifest.json`) was generated for Kumbia Kombat in 2026-11 on
the project's own computer, then cut, mastered and encoded by repository code. The generation is recorded
in `tool/music/workflows/`, `tool/music/sheets/`, `plan/music-themes-2026-11-06.md` and
`plan/music-pipeline-design-2026-11-07.md`. Each take has a provenance file with its workflow hash and
model hashes beside its FLAC master, outside the repository, in `~/.cache/tillandsias-project/kumbia-audio/`.

| Component | File | Source | Licence recorded by the studio's pin table |
|---|---|---|---|
| ACE-Step 1.5 XL turbo, the generating model | `acestep_v1.5_xl_turbo_bf16.safetensors` | `Comfy-Org/ACE-Step-1.5`, revision `371bb16` | Apache-2.0 |
| Text encoders | `qwen_0.6b_ace15.safetensors`, `qwen_4b_ace15.safetensors` | same | Apache-2.0 |
| Audio VAE | `ace_1.5_vae.safetensors` | same | Apache-2.0 |
| ComfyUI, the runner | v0.40.0 | Comfy-Org | GPL-3.0, tool only: its code doesn't ship in the game |
| ffmpeg with libopus, native AAC encoder | | | Tool only: no part ships except the encoded files |

The upstream ACE-Step project's Hugging Face tags and README say MIT, where the Comfy-Org repackaging is
recorded as Apache-2.0 by the studio; both are permissive. The model card states: "You can strictly use the
generated music for commercial purposes". We checked that as of 2026-11-06. It is the authors' statement.

Inputs were genre words, instrument words, tempo, key and seeds. No artist or song name, reference recording,
sample library or third-party stem went in. No stem separator was used: none was found with clearly
permissive weights. Models under non-commercial licences (MusicGen, YuE2, MuLaCover, SheetSage2's weights)
weren't used, although some of their nodes exist in the studio.

**What this record doesn't claim:**

- It doesn't warrant that a generated melody avoids resembling an existing work: no licence does, and these
  takes haven't been compared against any database of tunes. The training data is "legally compliant" in the
  model authors' words, with no published list.
- It makes no claim about copyright in this audio. The US Copyright Office's 2025 report says protection needs
  human authorship, so raw generated audio may not be protected. Selection and arrangement of takes may be.
- This is a record, not legal advice.

The salon (`rendered/salon/`, 2026-11-07) was made the same way: 12 candidate takes from genre and instrument
words, tempo 116, key D minor and seeds 58000 to 58203, recorded in `tool/music/sheets/salon.candidates.json`; seed
58001 was chosen by measurement, and its low and high tiers were re-sampled from its latent in one workflow
(`tool/music/sheets/salon.chain.json`). The billiards bridge into the salon (`rendered/billiards/bridge.*`) is cut by
repository code from the billiards and salon takes. No other input went in.

The comedor (`rendered/comedor/`, 2026-11-08) was made the same way: 20 candidate takes from genre and instrument
words, tempo 128, key F major and seeds 59000 to 59303, recorded in `tool/music/sheets/comedor.candidates.json`; seed
59202 was chosen by measurement, and its low and high tiers were re-sampled from its latent in one workflow
(`tool/music/sheets/comedor.chain.json`). The billiards bridge (`rendered/billiards/bridge.*`) now leads into the
comedor and is cut by repository code from the billiards and comedor takes. No other input went in.

The repository currently supplies no public licence, and this record doesn't grant one.

## Original scores: `scores/`, `midi/`, `manifest.json`

All five room compositions, five success mini-themes, four connecting bridges,
note arrangements, MIDI exports, and four adornment motifs
per composition in this directory were created for Kumbia Kombat in this repository
on 2026-10-18 with AI assistance. The authoring source is
`tool/music/generate.mjs`; output is deterministic. No song, melody transcription,
recording, sample library, soundfont, downloaded MIDI, or artist recording was used
as a source. Cumbia and Latin rhythmic conventions inform the compositions;
these are original game instrumentals rather than claims of archival authenticity.

The pool lawn's room score, success phrase and bridge were added the same way on
2026-11-05. Swing conventions inform them: ride pattern, walking bass, the Charleston
rhythm and common chord movement, none of which quotes a song. The melodies were
written for this project and have not been compared against any database of tunes.

The runtime synth uses mathematical oscillators and deterministic noise generated
in memory. It includes no third-party recordings. General MIDI program and drum
numbers in exports are interoperability identifiers, not bundled instrument audio.

These are project-original assets with no third-party attribution requirements.
Their redistribution follows the project owner's selected license. The repository
currently supplies no public license; this provenance record does not grant a
separate public redistribution license or make claims about copyrightability of
AI-assisted output. The owner should choose the repository's publication license
before distributing source/assets under a named open license.

The salon's bolero-cha score `salon_bolero` ("Terciopelo"), its four-bar tag resolving to the relative
major, and the bridge `billiards_to_salon` were added the same way on 2026-11-07. Cha-cha-chá and bolero
conventions inform them: the güiro's long-long-long-short-short, the conga tumbao, a montuno figure and
common minor-key cadences, none of which quotes a song. `billiards_to_salon` was retired on 2026-11-08, when the
comedor came between the two rooms.

Act two of the mansion added three room scores the same way on 2026-11-08, each with a four-bar tag: the comedor's
norteño polka `comedor_polka` ("Sobremesa", F major), the gallery's Celtic reel `galeria_reel` ("Trébol", A Dorian)
and the terrace's samba batucada `terraza_samba` ("Purpurina", C major), with the bridges `billiards_to_comedor`,
`comedor_to_salon`, `salon_to_galeria` and `galeria_to_terraza`. Genre conventions inform them: the polka's oom-pah
and its trio in the subdominant; the reel's AABB form in eighths over a drone, the bodhrán and hard-shoe eighths;
the batucada's surdo on 2 and 4, caixa sixteenths, tamborim and agogô. None quotes a song, a traditional tune or any
stage show's music. The melodies were written for this project and have not been compared against any database of
tunes.

Inventory: `scores/*.json` (32 original event scores), `midi/*.mid` (72 original
Standard MIDI File type 1 arrangements), `manifest.json` (catalog).
