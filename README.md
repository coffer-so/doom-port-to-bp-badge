# Coffer Doom Badge

A project by **dvp2 & the Coffer team**.

[Coffer](https://coffer.so/) builds multi-token DEX pools and DeFi primitives on Solana, including custom token baskets and RWA indices. Liquidity providers can earn swap fees; returns are variable and not guaranteed.

[Website](https://coffer.so/) | [Coffer on X](https://x.com/coffer_so)

## Status: preparation only — not an installable port

This repository currently contains a pinned, unmodified snapshot of the public Doomgeneric engine source and the integration plan below. **The Solana OS application has not been implemented, compiled or tested. There is no badge firmware, game demo or installable application in this revision.**

The original Doom game was created by id Software. Doomgeneric and its upstream contributors retain their original authorship and copyright. Coffer attribution describes this adaptation project, not ownership or creation of Doom.

## Intended target

- Solana Breakpoint 2026 badge: ESP32-C5HR8, 8 MB PSRAM, ILI9341 320x240, six buttons and microSD.
- A separate native Doom entry in the existing Solana OS launcher, with a coffer.so footer and safe return to the OS.
- Movement, turning, fire, use/doors and menu controls; bindings are not implemented yet.
- Existing Solana OS functionality should be preserved; this is not a replacement Doom-only OS.

The intended native C integration requires a compatible custom Solana OS build. It is **not** a drop-in Lua App Store upload. Solana OS is referenced as an upstream dependency, not copied into this repository.

## Repository contents

- vendor/doomgeneric/: original upstream engine source, license and documentation.
- UPSTREAMS.json: exact upstream revisions used during preparation.
- NOTICE.md and LICENSE: provenance and licensing.

## Installation, launch and controls

There are currently **no validated badge installation or launch steps**. Do not flash this repository onto a badge. Build instructions, a tested artifact and the complete button map must accompany the implemented port, rather than speculative commands.

No retail or shareware WAD is bundled. A future build will require legally obtained compatible game data. Code licensing does not grant rights to Doom artwork, levels, music or commercial WAD files.

## License and upstream assets

The vendored Doomgeneric code retains its GNU GPL v2 license and file-level notices. This project's additions are offered under GPL-2.0-or-later. Upstream screenshot images are omitted; all tracked engine source is retained unchanged.

Solana OS has its own license and exceptions for fonts/logos. Those assets are not distributed here. See NOTICE.md and the upstream repository before redistributing any firmware incorporating them.
