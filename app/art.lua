-- SPDX-License-Identifier: GPL-2.0-or-later
-- Original fallback/pickup artwork; licensed Freedoom detail is loaded separately.
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
}

local detail = require("art_detail")
for symbol,color in pairs(detail.palette_additions) do art.palette[symbol]=color end
art.enemy,art.weapon=detail.enemy,detail.weapon
art.chest=detail.chest
local coins=require('coins')
art.palettes={}
for name,coin in pairs(coins) do art[name]=coin.rows;art.palettes[name]=coin.palette end
-- Original 24x24 supply pickups. Independent palettes are required because the
-- Freedoom detail module replaces symbols in the shared enemy/weapon palette.
art.medkit={
  '........................',
  '........................',
  '........kkkkkkkk........',
  '........kssssssk........',
  '........ks....sk........',
  '....kkkkkkkkkkkkkkk.....',
  '....kgggggggggggggk.....',
  '..kgwwwwwwwwwwwwwwwbss..',
  '..kgwwwwwwwwwwwwwwwbss..',
  '..kgwwwwwwwwwwwwwwwbss..',
  '..kgwwwwwwwwwwwwwwwbss..',
  '..kgwswwwwrrrdwwwswbss..',
  '..kgwwwwwwrrrdwwwwwbss..',
  '..kgwwwrrrrrrrrrdwwbss..',
  '..kgwwwrrrrrrrrrdwwbss..',
  '..kgwwwrrrrrrrrrdwwbss..',
  '..kgwwwdddrrrddddwwbss..',
  '..kgwwwwwwrrrdwwwwwbss..',
  '..kgwwwwwwddddwwwwwbss..',
  '..kgwwwwwwwwwwwwwwwbss..',
  '..kgsssssssssssssssgss..',
  '..kkkkkkkkkkkkkkkkkkkk..',
  '........................',
  '........................',
}
art.palettes.medkit={k=0x1D2224,s=0x69777A,g=0xB1BDB7,w=0xF0EEE3,
  h=0xFFFFFF,r=0xD83A34,d=0x8B2523,b=0x394548}
art.ammo={
  '........................',
  '........................',
  '.......k...k...k........',
  '......kyk.kyk.kyk.......',
  '......yyo.yyo.yyo.......',
  '......wyo.wyo.wyo.......',
  '......wyo.wyo.wyo.......',
  '....kkyyokyyokyyokkk....',
  '....kdooodooodoooddk....',
  '....kddddddddddddddk....',
  '..kllllllllllllllllllk..',
  '..kddddddddddddddddddk..',
  '..kggggggggggggggggdsk..',
  '..kggllgggggggggllgdsk..',
  '..kggllgggggggggllgdsk..',
  '..kggssggggyygggssgdsk..',
  '..kggssggggyygggssgdsk..',
  '..kggssggggyygggssgdsk..',
  '..kggssgggggggggssgdsk..',
  '..kggssgggggggggssgdsk..',
  '..kgdddddddddddddddddk..',
  '..kkkkkkkkkkkkkkkkkkkk..',
  '........................',
  '........................',
}
art.palettes.ammo={k=0x181C16,d=0x34422A,g=0x5B6B3D,l=0x94A064,
  s=0x434E43,y=0xE9C365,o=0xAD783D,w=0xF8E4A5}
return art
