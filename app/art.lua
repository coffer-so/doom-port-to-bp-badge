-- SPDX-License-Identifier: GPL-2.0-or-later
-- Original low-resolution artwork for this adaptation; no Doom game assets.
local art = {
  palette = {
    k=0x111316, s=0x393F43, g=0x537F3C, l=0xA3C868,
    r=0x8E2921, b=0x47201C, o=0xD65C32, y=0xF8C865,
    w=0xF1E3B2, t=0x278E82, c=0x66DDD0,
  },
  enemy = {
    '....rrrr....', '...rooor....', '..rrororr...', '..rwrrwrb...',
    '..rrbbrbb...', '...rwwrb....', '....rbb.....', '..ssrrss....',
    '.sggssggs...', 'sgglggglgs..', 'sgggsggggs..', '.gggsgggg...',
    '..ssrss.....', '..rrbrr.....', '..rrbrr.....', '..rb.br.....',
    '.ss...ss....', 'sss...sss...',
  },
  key = {'..yyy...', '.ywwwy..', '.yy.yy..', '..yyy...', '...y....', '...yyy..', '...y....', '...yy...'},
  ammo = {'.ssssss.', '.gyyyyg.', '.gyyyyg.', '.gyyyyg.', '.gggggg.', '.stttts.', '.ssssss.'},
  medkit = {'.wwwwww.', 'wwrrwwww', 'wwrrwwww', 'rrrrrrww', 'rrrrrrww', 'wwrrwwww', '.wrrwww.'},
}

local detail = require("art_detail")
for symbol,color in pairs(detail.palette_additions) do art.palette[symbol]=color end
art.enemy,art.weapon=detail.enemy,detail.weapon
art.chest=detail.chest
local coins=require('coins')
art.palettes={}
for name,coin in pairs(coins) do art[name]=coin.rows;art.palettes[name]=coin.palette end
return art
