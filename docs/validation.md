# Validation — 1.0.2

Tested 2026-11-13 on the owner's Solana Breakpoint 2026 badge: ESP32-C5,
Solana OS 2.1.0, 8 MB PSRAM and microSD. The owner updated the OS; the
uploader changed only this application through the documented USB Lua console.

## Device measurement

A 12-second startup gameplay sample without screenshot transfer or physical
movement. This measures the initial view; combat and movement can cost more.
Earlier versions were measured in different scenes and are not direct comparisons.

| Measurement | Result |
| --- | --- |
| Gameplay frame rate | 11 FPS reported, 144 frames (about 12 FPS) |
| Render CPU, average / peak | 36 ms / 110 ms |
| Walls, average / peak | 32 ms / 43 ms |
| Sprites, average / peak | 2 ms / 70 ms |
| HUD and weapon, average / peak | 0 ms / 3 ms |
| Lua heap peak | 299,187 bytes of 6,291,456 |
| Callback instruction peak | 82,214 of 200,000 |
| Allocations left after close | 0 bytes |
| Lua task stack never used | 5,252 bytes |
| Last runtime error | none |
| Code mode | Source compiled on the badge |

The requested 30 FPS has not been achieved. Version 1.0.1 reported about 8.5 FPS during movement
and version 1.0.0 about 10 FPS in another scene. The renderer uses 40 wall rays, bounded native
wall/sprite caches and a cheap input tick after three expensive pictures.
Freedoom derivatives retain the previous sprite dimensions; their wall RLE
count is 540 instead of 546, and the edited demon is capped at 279 runs. Runtime
cost still varies with visibility, movement and cache misses. Store-compiled
code has not been benchmarked separately.

All 14 installed files matched local sizes and SHA-256 hashes. The title,
mandatory rules and gameplay screenshots are captured from the badge.
Screenshot transfer stalls execution, so it is excluded from the FPS sample.
No unrelated applications, badge settings or firmware were changed.

## Host validation

The exact upload package passed the checks using official Lua 5.5.1 compiled
with `-DLUA_32BITS=1`: 32-bit integers and floats, `math.maxinteger` 2,147,483,647.

- 1,506 game checks, including a complete button-driven coin/chest route.
- 36×36 map; 741 walkable cells, 25 rooms, six loops and 130 grid steps for
  both coins and return; no mandatory doors. Over 6.6 times the previous
  14×14 map area and walkable cells.
- 2,964 app viewpoints and 20 title/rules/game/pause lifecycle loops.
- Held SELECT, delayed muzzle flash, warm weapon frame, recoil, empty ammo and input fairness.
- Exact five-line end-screen copy, with the removed DeFi sentence absent.
- 562,427 native wall-cache, crop, deduplication, eviction and fallback checks.
- 275,930 exact sprite pixels, transparency, occlusion, cache and fallback checks.
- 812 RGB effect, throttle and cleanup checks.
- 107,056 world renders plus 2,430 crowded full ticks with six zombies.
- Maximum conservative callback work: 154,318 / 200,000; no overruns.
- 19 Python packaging/guarded USB protocol tests.
- Freedoom source sizes, Git blob hashes and SHA-256 verified; 10 generated outputs rebuild byte for byte.

The ZIP contains exactly 14 allowlisted files. It excludes tests, private
photographs, device logs, credentials, WAD data and the legacy C engine.
Both current and historical Freedoom BSD notices are included in `credits.txt`; see [assets.md](assets.md).

## Publication

DOOM uses permanent ID `doom-by-coffer`, category Games, LED-only permissions,
no network hosts and no price. Version 1.0.2 passed the automatic check and is published/listed. The listing
shows version 1.0.2 under Games; installation is available through the badge
App Store by searching DOOM.
