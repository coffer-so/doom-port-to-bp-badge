# Validation — 1.0.1

Tested 2026-11-13 on the owner's Solana Breakpoint 2026 badge: ESP32-C5,
Solana OS 2.1.0, 8 MB PSRAM and microSD. The owner updated the OS; the
uploader changed only this application through the documented USB Lua console.

## Device measurement

A 12-second gameplay run without screenshot transfer. Physical button input
was observed during the run, so this is a moving gameplay sample, not an
identical-camera comparison with version 1.0.0.

| Measurement | Result |
| --- | --- |
| Gameplay frame rate | 8 FPS reported, 102 frames (about 8.5 FPS) |
| Render CPU, average / peak | 72 ms / 128 ms |
| Walls, average / peak | 36 ms / 62 ms |
| Sprites, average / peak | 35 ms / 87 ms |
| HUD and weapon, average / peak | 1 ms / 4 ms |
| Lua heap peak | 550,603 bytes of 6,291,456 |
| Callback instruction peak | 99,204 of 200,000 |
| Allocations left after close | 0 bytes |
| Lua task stack never used | 5,188 bytes |
| Last runtime error | none |
| Code mode | Source compiled on the badge |

The requested 30 FPS has not been achieved. Version 1.0.0 reported 9 FPS
(about 10) in a different scene. The renderer uses 40 wall rays, bounded native
wall/sprite caches and a cheap input tick after three expensive pictures.
Freedoom derivatives retain the previous sprite dimensions; their wall RLE
count is 540 instead of 546, and enemy runs are 238 instead of 279. Runtime
cost still varies with visibility, movement and cache misses. Store-compiled
code has not been benchmarked separately.

All 14 installed files matched local sizes and SHA-256 hashes. The title,
mandatory rules and gameplay screenshots are captured from the badge.
Screenshot transfer stalls execution, so it is excluded from the FPS sample.
No unrelated applications, badge settings or firmware were changed.

## Host validation

The exact upload package passed the checks using official Lua 5.5.1 compiled
with `-DLUA_32BITS=1`: 32-bit integers and floats, `math.maxinteger` 2,147,483,647.

- 565 game checks, including a complete button-driven coin/chest route.
- 14×14 map; 32 grid steps for both coins and return, formerly 80; no mandatory doors.
- 448 app viewpoints and 20 title/rules/game/pause lifecycle loops.
- Held SELECT, delayed muzzle flash, warm weapon frame, recoil, empty ammo and input fairness.
- Exact five-line end-screen copy, with the removed DeFi sentence absent.
- 562,427 native wall-cache, crop, deduplication, eviction and fallback checks.
- 275,930 exact sprite pixels, transparency, occlusion, cache and fallback checks.
- 812 RGB effect, throttle and cleanup checks.
- 16,272 world renders plus 2,188 crowded full ticks with six zombies.
- Maximum conservative callback work: 128,584 / 200,000; no overruns.
- 19 Python packaging/guarded USB protocol tests.
- Freedoom source sizes, Git blob hashes and SHA-256 verified; 10 generated outputs rebuild byte for byte.

The ZIP contains exactly 14 allowlisted files. It excludes tests, private
photographs, device logs, credentials, WAD data and the legacy C engine.
Freedoom's full BSD license is included in `credits.txt`; see [assets.md](assets.md).

## Publication

DOOM uses permanent ID `doom-by-coffer`, category Games, LED-only permissions,
no network hosts and no price. Version 1.0.1 passed the automatic check and is published/listed. The listing
shows version 1.0.1 under Games; installation is available through the badge
App Store by searching DOOM.
