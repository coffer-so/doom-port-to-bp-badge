# Validation — 1.0.4

Tested 2026-11-13 on the owner's Solana Breakpoint 2026 badge: ESP32-C5,
Solana OS 2.1.0, 8 MB PSRAM and microSD. The owner updated the OS; the
uploader changed only this application through the documented USB Lua console.

## Device measurement

A 12-second gameplay sample without screenshot transfer. The owner used the
physical movement and shooting buttons during the sample. This is not an
identical-camera comparison with earlier versions; scene costs vary.

| Measurement | Result |
| --- | --- |
| Gameplay frame rate | 8 FPS reported; 111 frames during the sample |
| Render CPU, average / peak | 56 ms / 118 ms |
| Walls, average / peak | 41 ms / 52 ms |
| Sprites, average / peak | 13 ms / 75 ms |
| HUD and weapon, average / peak | 1 ms / 6 ms |
| Lua heap peak | 413,818 bytes of 6,291,456 |
| Callback instruction peak | 99,193 of 200,000 |
| Allocations left after close | 0 bytes |
| Lua task stack never used | 5,412 bytes |
| Last runtime error | none |
| Code mode | Source compiled on the badge |

The owner tested and accepted this performance for publication; further work toward 30 FPS is not part of this release. Version 1.0.1 reported about 8.5 FPS during movement
and version 1.0.0 about 10 FPS in another scene. The renderer uses 40 wall rays, bounded native
wall/sprite caches and a cheap input tick after three expensive pictures.
Freedoom derivatives retain the previous sprite dimensions; their wall RLE
count is 540 instead of 546, and the edited demon is capped at 279 runs. Runtime
cost still varies with visibility, movement and cache misses. Store-compiled
code has not been benchmarked separately.

All 14 installed files matched local sizes and SHA-256 hashes. Title, mission and startup gameplay screenshots were freshly captured from
the same badge running this exact release. The top-down map was regenerated from
the 1.0.4 level data.
Screenshot transfer stalls execution, so it is excluded from the FPS sample.
No unrelated applications, badge settings or firmware were changed.

## Host validation

The exact upload package passed the checks using official Lua 5.5.1 compiled
with `-DLUA_32BITS=1`: 32-bit integers and floats, `math.maxinteger` 2,147,483,647.

- 1,680 game checks, including a complete button-driven coin/chest route.
- 31×31 map; 534 connected floor cells, 17 broad rooms and a one-cell winding
  zone with three dead ends. The Solana coin is inside one dead end; the full
  two-coin-and-return route takes 116 grid steps without opening a door.
- 2,136 app viewpoints and 20 title/rules/game/pause lifecycle loops.
- Held SELECT, delayed muzzle flash, warm weapon frame, recoil, empty ammo and input fairness.
- Door prompt matches CANCEL eligibility: exact text, priority, opening, distance,
  direction and wall/corner occlusion; chest guidance stays available.
- Button-driven traversal of all narrow branches and enemy pursuit through bends.
- Exact five-line end-screen copy, with the removed DeFi sentence absent.
- 17 starting rounds; 15 HP per enemy hit; three medkits (+25 HP, cap 100)
  and three ammunition cases (+8 rounds, cap 99). Full-resource supplies remain
  available, and pickups never change the two-coin objective.
- Actual medkit/ammo colours and transparency through native and RLE sprite paths.
- 562,427 native wall-cache, crop, deduplication, eviction and fallback checks.
- 275,930 exact sprite pixels, transparency, occlusion, cache and fallback checks.
- 812 RGB effect, throttle and cleanup checks.
- 77,248 world renders plus 4,206 crowded full ticks with six zombies.
- Maximum conservative callback work: 143,444 / 200,000; no overruns.
- 19 Python packaging/guarded USB protocol tests and five actual-Lua map/export/PNG tests.
- Freedoom source sizes, Git blob hashes and SHA-256 verified; 10 generated outputs rebuild byte for byte.

The ZIP contains exactly 14 allowlisted files. It excludes tests, private
photographs, device logs, credentials, WAD data and the legacy C engine.
Both current and historical Freedoom BSD notices are included in `credits.txt`; see [assets.md](assets.md).

## Publication

DOOM uses permanent ID `doom-by-coffer`, category Games, LED-only permissions,
no network hosts and no price. Version 1.0.4 was submitted and the listing confirms it is waiting for an
organiser to review it. The public Store and badge downloads still serve 1.0.2
until approval. The owner's USB installation is already 1.0.4.
