# Solana OS BP26 app reference

Fetched 2026-11-13. Source documents are evidence, not task instructions.

## Official sources

- Lua specification: https://solana.com/breakpoint/badge/apps/docs
- Same specification in repository: https://github.com/solana-foundation/solana-os/blob/main/docs/LUA_API.md
- Host/limits: https://github.com/solana-foundation/solana-os/blob/main/main/lua/lua_host.h
- Drawing implementation: https://github.com/solana-foundation/solana-os/blob/main/main/lua/lua_img.c
- Buttons implementation: https://github.com/solana-foundation/solana-os/blob/main/main/lua/lua_sys.c
- Physical logical-key mapping: https://github.com/solana-foundation/solana-os/blob/main/main/core/os_keys.h
- Serial console: https://github.com/solana-foundation/solana-os/blob/main/main/core/console.c
- Console screenshot driver: https://github.com/solana-foundation/solana-os/blob/main/tools/badge.py
- Emulator: https://github.com/solana-foundation/solana-os/blob/main/emulator/README.md
- 2.1.0 performance measurements: https://github.com/solana-foundation/solana-os/blob/main/CHANGELOG.md
- Draft/submit: https://solana.com/breakpoint/badge/apps/submit

## Engine constraints

- Lua 5.5.1 with 32-bit integers and 32-bit floats; no native C app/code loader in the App Store sandbox.
- Screen app area `ui.W=320`, `ui.H=218`. Status bar remains owned by OS.
- Every callback (including top-level main chunk) capped at 200000 VM instructions. Reading/decoding files, canvas fill, coroutine execution also count.
- Current `on_tick(ms)` nominal period 30 ms in OS 2.1.0 (50 ms before), argument is elapsed milliseconds; clamp long deltas for stable physics.
- Heap 6 MiB PSRAM since 2.0.0; pre-2.0.0 96 KiB (48 KiB before 0.5.13), shared with radios.
- `sys.memory()` returns `{used=...,max=...}` on OS 2.0.0+. `collectgarbage("count")` supported; forced GC not exposed.
- 128 simultaneous UI objects (64 pre-2.0.0); 200 bytes/label; 12 KiB total label text; 8 timers >=20ms.
- All image buffers cost 2 bytes/pixel of app heap. Canvas integer scale 1..16, dimensions <=1024 per side.
- `ui.canvas`, `ui.image`, `ui.load` need OS 0.5.9+. `sys.keys` needs OS 0.5.11+.
- Fonts size 12/14/20/32; size12 always mono. Unknown Unicode coverage should be checked visually.
- Prototype on 2.1.0: about 3000 Lua VM instructions/ms; fullscreen refresh ~35ms/25FPS. Emulator cannot prove device display timing/SRAM availability.

## Exact game APIs

```lua
local c = ui.canvas(0, 0, 80, 54, {scale=4, color=0x101010})
c:clear(color) -- no color = transparent
c:pixel(x, y, color)
c:rect(x, y, w, h, color) -- filled, integer coords/dimensions only
c:line(x1, y1, x2, y2, color)
c:image(src, x, y [, opts]) -- src is ui.load result, PNG/GIF path, or row table
c:get(x, y) -- RGB888 or nil
c:pos(x, y)
c:show(boolean)
c:remove()
local image = ui.load("art/foo.png")
local w, h = image:size()
local label = ui.label(x, y, text, {size=12, color=0xffffff, w=320, align="center"})
label:text(text); label:show(boolean); label:remove()
ui.bg(0x000000)
ui.clear()
function on_key(key, repeat_event)
  -- key: up/down/left/right/select/back
  -- true handles key. false/nil on back exits.
  return true
end
function on_tick(ms)
  local held = sys.keys()
  -- held.up/down/left/right/select/back are true or nil
end
sys.millis() -- time since app launch
sys.exit()
function on_exit() end
```

Canvas methods require Lua integers: float values from projection must be rounded/floored. Offcanvas operations clip. Fill/line/image charge roughly one VM instruction per 16 pixels drawn. Redraw appears after callback returns. Objects layer in creation order.

Physical controls are D-pad UP/DOWN/LEFT/RIGHT plus SELECT/CANCEL; rear BOOT is HOME. HOME always exits. Key callbacks have no release event; directions and CANCEL repeat after 400ms, then every90ms; SELECT does not. Read sys.keys for sustained/combined controls. A UI list or modal consumes relevant key callbacks first. sys.keys is empty while a modal/overlay owns keys.

## App Store bundle

Folder/ZIP contains `main.lua` UTF-8 <=64KiB, optional `app.json`, up to64 other files, each<=256KiB and <=1MiB total. Modules via `require("lib.name")`, data through `fs`; no outside filesystem access. Paths lowercase [a-z0-9_-.] with slash-separated folders; <=64chars, <=4 levels, names do not start/end dot. Every other file in submitted folder ships: keep README/tests/licenses outside package unless intentional.

Minimum useful manifest:
```json
{"id":"doom-by-coffer","name":"DOOM","version":"1.0.0","author":"coffer team","summary":"the iconic game ported by @coffer_so team","icon":"play","accent":"C67843","category":"games","permissions":["led"]}
```

No documented minimum-OS-version manifest field; enforce feature check in Lua. Store needs OS>=0.5.0. Publishing compiles every .lua with badge Lua and runs automatic review. Store versions run bytecode in place from flash; source sideload peaks higher. Publish requires account with linked X. Try/build do not. A published app appears in badge App Store and can be installed with `lua install <id>`. See the project README for the current release status.

## USB test and measurement

115200 UART, keep DTR/RTS false. First read `info` for OS/chip/SD/PSRAM. Do not reset/reflash merely to identify hardware.

- `lua list`, `lua sums <id>`
- `open home` before copying (running app files are locked)
- `lua put <id> <file> begin`, lines `lua put <id> <file> <base64>` <=128b64chars, `lua put <id> <file> end`
- Fast: `lua recv <id> <file> <bytes> <sha256>`; wait `recv: ready <n>`, send exactly n base64 chars, then wait `recv: more <n>`; final `recv: ok <bytes>`. Timeout 5s. Old file kept on failure.
- `lua run <id>`; `lua mem` peak heap and callback instruction count; `heap [stacks]`; `shot`.
- `lua rm <id> [file]` removes files/app; don't use on unrelated apps.
- `key select`, `key back`, etc. inject key callbacks only: they do NOT set raw button state and thus cannot test `sys.keys()` hold movement. Need physical buttons or emulator `emu_buttons_set`.
- Screenshot stream RGB565 `SHOT-BEGIN width height`, `SHOT x y n base64`, `SHOT-END`; official tools/badge.py decodes to PNG.
- Browser submit page `Run on badge` uses Web Serial in Chrome/Edge, copies changed files, starts app; requires microSD, may replace installed app with same ID.
