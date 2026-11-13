-- SPDX-License-Identifier: GPL-2.0-or-later
local source=arg[1] or '.'
local function load() return assert(loadfile(source..'/rgb.lua'))() end
local checks=0
local function check(value,why) assert(value,why);checks=checks+1 end
timer=setmetatable({},{__index=function() error('RGB must not request timers') end})
led=nil
local absent=load()
check(absent.effect('title'),'missing LED API should be harmless')
absent.tick(100);absent.close()
local history,pixels={},{}
local function set(i,r,g,b)
  check(i>=1 and i<=8 and math.type(i)=='integer','bad LED index')
  for _,v in ipairs({r,g,b}) do check(math.type(v)=='integer' and v>=0 and v<=255,'bad RGB channel') end
  pixels[i]={r,g,b};history[#history+1]={i,r,g,b}
end
local function fill(r,g,b) for i=1,8 do set(i,r,g,b) end end
led={count=8,set=set,fill=fill,off=function() fill(0,0,0) end}
local rgb=load()
local function all(r,g,b)
  for i=1,8 do check(pixels[i][1]==r and pixels[i][2]==g and pixels[i][3]==b,'unexpected LED color') end
end
rgb.effect('title');all(56,48,34)
local n=#history
rgb.tick(99);rgb.tick(1);check(#history==n,'steady title must not redraw')
rgb.effect('play');all(0,0,0)
rgb.effect('hurt');all(255,12,4)
rgb.tick(199);all(255,12,4)
rgb.tick(1);all(0,0,0)
rgb.effect('solana')
n=#history;rgb.tick(99);check(#history==n,'animation must throttle below 100 ms')
rgb.tick(1);check(#history==n+8,'chase frame must update all LEDs')
local hasPurple,hasGreen=false,false
for i=1,8 do hasPurple=hasPurple or pixels[i][3]>pixels[i][2];hasGreen=hasGreen or pixels[i][2]>pixels[i][3] end
check(hasPurple and hasGreen,'Solana chase needs purple and green')
rgb.tick(500);all(0,0,0)
rgb.effect('solana');rgb.tick(400);rgb.effect('coffer')
rgb.tick(500);check(pixels[6][1]>pixels[6][2] and pixels[6][2]>pixels[6][3],'Coffer chase must be gold')
rgb.tick(100);all(0,0,0)
rgb.effect('title');rgb.effect('hurt');rgb.tick(200);all(56,48,34)
rgb.effect('win');rgb.tick(1200)
check(pixels[5][2]>pixels[5][1],'win second phase must be a green wave')
rgb.tick(800);all(16,120,48)
n=#history;rgb.tick(10000);check(#history==n,'steady victory must not redraw')
rgb.effect('dead');all(64,3,1)
rgb.effect('play');all(0,0,0)
check(not rgb.effect('unknown'),'unknown effect must be ignored')
rgb.effect('solana');rgb.close();all(0,0,0)
n=#history
rgb.tick(10000);rgb.close();check(not rgb.effect('hurt'),'closed controller must stay closed')
check(#history==n,'closed controller must not relight LEDs')
led={count=8,set=function() error('permission denied') end,fill=function() error('permission denied') end}
local denied=load()
check(denied.effect('win'),'denied LED permission must not stop effects')
denied.tick(100);denied.close()
print('rgb_spec: '..checks..' checks; effects, throttle, reset, teardown, missing/denied API OK')
