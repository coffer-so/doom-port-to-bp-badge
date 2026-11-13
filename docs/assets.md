# Ready-made game artwork

The imp-style enemy, pistol and three wall materials are derivatives of existing
[Freedoom artwork](https://github.com/freedoom/freedoom), rather than newly drawn
approximations. Freedoom is a free Doom-compatible content replacement; these are
Freedoom designs, not the exact copyrighted id Software Doom game graphics.

Freedoom explicitly allows independent developers to reuse its artwork under the
[BSD license](https://freedoom.github.io/about.html). The engine release does not
release Doom's original game data: the [id Software source README](https://github.com/id-Software/DOOM/blob/master/README.TXT)
still requires a separately owned game copy. No original id monster, weapon, wall,
sound, music or WAD data is included here.

The pistol and wall source files are pinned to Freedoom commit
[`21d783c481af9233fa72305b40eb247fa966b49a`](https://github.com/freedoom/freedoom/tree/21d783c481af9233fa72305b40eb247fa966b49a).
The enemy uses Lokito's older humanoid demon at
[`56183b1e0689e53cbda9eb48025bf07b32837471`](https://github.com/freedoom/freedoom/tree/56183b1e0689e53cbda9eb48025bf07b32837471),
from `sprites/lokito/bossa1.gif`. Its author is identified in the original
[upstream import commit](https://github.com/freedoom/freedoom/commit/afac99005a36e7dcfa7e36e341da555c1be98f23).
The exact upstream paths, per-file historical revisions, Git blob hashes, SHA-256 hashes and byte sizes are in
[`assets/freedoom/SOURCES.json`](../assets/freedoom/SOURCES.json).
The complete unmodified current upstream license and contributor list are retained in
[`source/COPYING.adoc`](../assets/freedoom/source/COPYING.adoc) and
[`source/CREDITS`](../assets/freedoom/source/CREDITS). The older demon's original
notice and contributor list are retained separately in
[`source/old_COPYING`](../assets/freedoom/source/old_COPYING) and
[`source/old_CREDITS`](../assets/freedoom/source/old_CREDITS).
Both complete BSD notices are also included in the app's `credits.txt`, which is
already part of the upload package.

| Runtime artwork | Freedoom source | Badge output |
|---|---|---|
| Edited brown imp-style demon | historical `sprites/lokito/bossa1.gif` | 24 × 36, transparent |
| Pistol idle view | `sprites/pisga0.png` | 32 × 24, transparent |
| Brown/gray panels, STARTAN3 | `patches/sw19_2.png` + `sw19_1.png` | 16 × 8 |
| Green/gray panels, STARG3 | `patches/sw19_4.png` + `sw19_3.png` | 16 × 8 |
| Industrial door, BIGDOOR2 | `patches/door2_4.png` | 16 × 8 |

The panel composition and patch offsets follow upstream
[`lumps/textures/textures.cfg`](https://github.com/freedoom/freedoom/blob/21d783c481af9233fa72305b40eb247fa966b49a/lumps/textures/textures.cfg).
The source contact sheet contains extra candidates retained for comparison; only
the selected artwork above is compiled into the app.

The historical demon is converted from its original cyan color key to alpha,
resized to 24 × 34 and bottom-aligned in the 24 × 36 sprite. Its source body and
pose are retained, recolored brown, and edited with original red eyes, ivory
shoulder spines, fangs and claws. This is a modified Freedoom design rather than
an exact copy of Doom's imp. Freedoom's current `TROO` sprite is a serpent-like
creature and was inspected but not used for this humanoid design.

The enemy has a separate 12-entry palette. A deterministic least-error vertical
band merge caps it at 279 runs while preserving transparency, eyes and spines.
The pistol keeps the previous 24-color palette and exact visible RGB pixels;
the compiler asserts its unchanged PNG SHA-256 and the unchanged texture module
SHA-256. The original Coffer chest and its palette are preserved from
`assets/freedoom/project-overlay.json`; that file remains GPL-2.0-or-later and is
not part of the Freedoom import. Coffer/Solana coins and title branding are
unaffected.

Walls use box downsampling, eight representative colors per material and a
deterministic least-squares run allocation. Every wall remains 16 × 8 with five
precomputed light levels. The compiler enforces at most three vertical runs per
column and 36 per material, hence at most 540 runs across all shades. This bounds
fallback drawing cost instead of carrying high-resolution texture noise into the
Lua renderer. There is no runtime PNG decoding, WAD parser or new app dependency.

## Offline deterministic rebuild

Run from the repository root after installing the pinned development-only image
dependency; rebuilding itself does not access the network:

```sh
python3 -m venv .venv-art
.venv-art/bin/python -m pip install 'Pillow==13.0.0'
.venv-art/bin/python tools/compile_freedoom.py
.venv-art/bin/python tools/compile_freedoom.py --check
```

The compiler permits only the two pinned source revisions and verifies every retained upstream source against its size, SHA-256
and Git blob hash before generating `art_detail.lua`, `textures.lua`, reduced
PNG previews and `assets/freedoom/BUILD.json`. `--check` compares all generated
files byte for byte. The build report records output SHA-256 hashes and run
counts. Runtime source files retain the same API and dimensions expected by the
renderer and native caches.

Preview: [`badge-assets.png`](../assets/freedoom/previews/badge-assets.png).
Full-size composed textures: [`texture-sources.png`](../assets/freedoom/previews/texture-sources.png).
