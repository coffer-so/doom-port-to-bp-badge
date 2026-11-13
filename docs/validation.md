# Validation

Tested 2026-11-13 on a Solana Breakpoint 2026 badge: ESP32-C5,
Solana OS 2.1.0, 8 MB PSRAM and microSD. The owner updated the OS;
our uploader changed only this application through the documented USB Lua console.

## Final device measurement

A separate 12-second gameplay run, with no screenshot transfer:

| Measurement | Result |
| --- | --- |
| Gameplay frame rate | 9 FPS reported (117 frames; approximately 10 FPS) |
| Render CPU, average / peak | 54 ms / 115 ms |
| Walls, average / peak | 36 ms / 49 ms |
| Sprites, average / peak | 16 ms / 70 ms |
| HUD and weapon, average / peak | 1 ms / 4 ms |
| Lua heap peak | 394,351 bytes of 6,291,456 |
| Callback instruction peak | 100,041 of 200,000 |
| Allocations left after close | 0 bytes |
| Lua task stack never used | 5,412 bytes |
| Last runtime error | none |
| Code mode | Source compiled on the badge |

The earlier OS 2.0.0 build measured 4 FPS. The final renderer uses 40 wall
rays, bounded native wall/sprite caches and a cheap input tick after three
expensive pictures. Sprite detail is retained; wall columns use lower detail.
The requested 30 FPS has not been achieved. Results vary by scene.
Store-compiled code has not been benchmarked.

All 14 installed files matched local sizes and SHA-256 hashes. The final
title, mandatory rules and gameplay screenshots were captured from this badge.
Screenshot transfer stalls execution, so those runs are excluded from FPS
measurements. No unrelated applications, badge settings or firmware were changed.

## Host validation

The exact repository package passed `tools/check.py --stress` using official
Lua 5.5.1 compiled with `-DLUA_32BITS=1`: 32-bit integers and floats,
`math.maxinteger` 2,147,483,647.

- 374 game checks, including the complete button-driven coin/chest route.
- 908 app viewpoints and 20 title/rules/game/pause lifecycle loops.
- Held SELECT, delayed muzzle flash, recoil, empty-ammo and input fairness.
- 562,421 exact native wall-cache, crop, eviction and fallback checks.
- 275,930 exact sprite pixels, transparency, occlusion, cache and fallback checks.
- 812 RGB effect, throttle and cleanup checks.
- 32,832 world renders plus 1,666 crowded full ticks with six zombies.
- Maximum conservative callback work: 114,560 / 200,000; no overruns.
- 16 Python packaging/guarded USB protocol tests.

The package excludes tests, private photographs, device logs, credentials, WAD
data and the legacy C engine. Version 1.0.0 was submitted to the Solana OS App Store under Games. The store
currently requires an organiser’s review; other users cannot find/install it
until a version is approved.
