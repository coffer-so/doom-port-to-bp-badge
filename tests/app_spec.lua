-- SPDX-License-Identifier: GPL-2.0-or-later
-- UI contract checks and app VM work plus native canvas pixel charges.
local source = arg[1] or '.'
package.path = source .. '/?.lua;' .. package.path
local objects, held, costs, instructionCount, peak = {}, {}, 0, 0, 0
local canvasRects,canvasImages,mockNow,mockRenderMs = 0,0,0,0
local observedColors
local lastWeapon,orangePixels,yellowPixels=nil,0,0
local function integer(n) assert(math.type(n)=='integer', 'canvas coordinate is not an integer: '..tostring(n)) end
local function pixelCost(w,h) costs=costs+math.max(0,w)*math.max(0,h)//16 end
local function clippedCost(o,x,y,w,h)
  local a,b=math.max(0,x),math.max(0,y)
  local c,d=math.min(o.w,x+w),math.min(o.h,y+h)
  if c>a and d>b then pixelCost(c-a,d-b) end
end
local object={}
function object:text(s) assert(#s<=200);self.value=s end
function object:show(_) end
function object:remove() end
function object:pos(x,y) integer(x);integer(y) end
function object:size(w,h) integer(w);integer(h) end
function object:clear(_) pixelCost(self.w,self.h);mockNow=mockNow+mockRenderMs end
function object:image(img,x,y)
  integer(x);integer(y);canvasImages=canvasImages+1
  if img.w==32 and img.h==24 then lastWeapon={image=img,x=x,y=y} end
  if observedColors and img.palette then
    for _,row in ipairs(img.rows or {}) do for i=1,#row do
      local color=img.palette[row:sub(i,i)]
      if color then observedColors[color]=true end
    end end
  end
  clippedCost(self,x,y,img.w,img.h)
end
function object:pixel(x,y,_) integer(x);integer(y) end
function object:rect(x,y,w,h,color)
  integer(x);integer(y);integer(w);integer(h)
  assert(w>=0 and h>=0)
  canvasRects=canvasRects+1
  if color==0xF7761B then orangePixels=orangePixels+w*h end
  if color==0xFFD43B then yellowPixels=yellowPixels+w*h end
  if observedColors then observedColors[color]=true end
  clippedCost(self,x,y,w,h)
end
local function make(o) objects[#objects+1]=o;return setmetatable(o,{__index=object}) end
ui={W=320,H=218}
function ui.bg(_) end
function ui.load(rows,opts)
  assert(#rows>0 and #rows<=1024 and #rows[1]>0 and #rows[1]<=1024,'invalid native image size')
  for _,row in ipairs(rows) do assert(type(row)=='string' and #row==#rows[1],'ragged native image') end
  pixelCost(#rows[1],#rows)
  return {w=#rows[1],h=#rows,rows=rows,palette=opts and opts.palette}
end
function ui.clear() objects={} end
function ui.label(x,y,text,opts) assert(#text<=200);return make({kind='label',x=x,y=y,value=text,opts=opts}) end
function ui.rect(x,y,w,h,opts) return make({kind='rect',w=w,h=h}) end
function ui.image(x,y,path,opts)
  if type(path)=='table' then
    local image=path.w and path or ui.load(path,opts)
    local scale=opts and opts.scale or 1
    assert(x>=0 and y>=0 and x+image.w*scale<=ui.W and y+image.h*scale<=ui.H,
      'UI image exceeds screen')
  end
  return make({kind='image',source=path,opts=opts})
end
function ui.canvas(x,y,w,h,opts)
  assert(opts.scale*w<=ui.W and opts.scale*h<=ui.H)
  return make({kind='canvas',w=w,h=h})
end
sys={keys=function() return held end,millis=function() return mockNow end}
local mockSource=debug.getinfo(object.rect,'S').source
local function budget(fn,...)
  costs,instructionCount=0,0
  local inApp=false
  debug.sethook(function(event)
    if event=='count' then
      if inApp then instructionCount=instructionCount+1 end
    else
      local info=debug.getinfo(event=='return' and 3 or 2,'S')
      inApp=info~=nil and info.source~=mockSource and info.what~='C'
    end
  end,'cr',1)
  local ok,err=pcall(fn,...)
  debug.sethook()
  assert(ok,err)
  local estimate=instructionCount+costs
  peak=math.max(peak,estimate)
  assert(estimate<200000,'callback exceeds budget: '..estimate)
  assert(#objects<=64,'UI object budget exceeded')
  return estimate
end
local function upvalue(fn,name)
  for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end
  error('missing test upvalue: '..name)
end
local function setvalue(fn,name,value)
  for i=1,100 do
    local n=debug.getupvalue(fn,i)
    if not n then break end
    if n==name then debug.setupvalue(fn,i,value);return end
  end
  error('missing test upvalue: '..name)
end
local function checkPromotion()
  local rows={}
  local stats,replay=false,false
  for _,o in ipairs(objects) do
    if o.kind=='label' then
      if o.y>=128 then
        rows[#rows+1]=o.value
        assert(o.y==128+(#rows-1)*18 and o.opts.size==12 and o.opts.w==320,
          'promotion layout does not fit the five reserved rows')
        assert(o.y+o.opts.size<=ui.H and #o.value<=42,'promotion exceeds display bounds')
      end
      stats=stats or (o.value:match('^Coins ') and o.y==78 and o.opts.size==14)
      replay=replay or (o.value=='SELECT play again   CANCEL title' and o.y==102 and o.opts.size==12)
    end
  end
  assert(stats and replay and #rows==5,'end-screen statistics, controls or five promotion lines missing')
  assert(table.concat(rows,' ')==
    'Yield on RWA baskets comes from swaps between the tokens in each basket. '..
    'We created a completely new AMM primitive on Solana. Before Coffer, we built an $87M DeFi protocol.',
    'end-screen promotion differs from requested copy')
end
local manifestFile=assert(io.open(source..'/app.json','r'))
local manifest=manifestFile:read('a');manifestFile:close()
assert(manifest:match('"name"%s*:%s*"([^"]*)"')=='DOOM','App Store name must be DOOM')
assert(manifest:match('"summary"%s*:%s*"([^"]*)"')=='the iconic game ported by @coffer_so team',
  'App Store summary differs from requested copy')
budget(assert(loadfile(source..'/main.lua')))
local sawPlay,sawCredit,sawBrand,sawDoom,sawCoffer,sawTwitter,sawStart=false,false,false,false,false,false,false
for _,o in ipairs(objects) do
  sawPlay=sawPlay or o.value=='Play the game'
  sawCredit=sawCredit or (o.value=='Made by coffer team' and o.x==122 and o.y==128)
  sawBrand=sawBrand or o.value=='yield on RWA baskets here coffer.so'
  sawTwitter=sawTwitter or o.value=='twitter: @coffer_so'
  sawStart=sawStart or o.value=='click "select" btn to start the game'
  sawDoom=sawDoom or (o.kind=='image' and o.source=='art/doom.png')
  sawCoffer=sawCoffer or (o.kind=='image' and o.source=='art/coffer.png' and o.opts.scale==2)
end
assert(not sawPlay and sawCredit and sawBrand and sawDoom and sawCoffer and sawTwitter and sawStart,
  'exact title content/logo paths missing')
budget(on_key,'right',true)
assert(upvalue(on_tick,'mode')=='title','repeated RIGHT must not open mission screen')
budget(on_key,'right',false)
assert(upvalue(on_tick,'mode')=='mission','RIGHT did not open mission screen')
local Art=require('art')
local sawMission,sawSolana,sawChest,sawCofferCoin,sawAmmoRule,sawSuppliesRule=false,false,false,false,false,false
for _,o in ipairs(objects) do
  sawMission=sawMission or o.value=='1 Solana + 1 Coffer -> chest'
  sawAmmoRule=sawAmmoRule or o.value=='Find both coins. Start with 17 shots.'
  sawSuppliesRule=sawSuppliesRule or o.value=='Walk into coins, ammo and medkits.'
  sawSolana=sawSolana or (o.source==Art.solana_coin and o.opts.palette==Art.palettes.solana_coin)
  sawChest=sawChest or o.source==Art.chest
  sawCofferCoin=sawCofferCoin or (o.source==Art.coffer_coin and o.opts.palette==Art.palettes.coffer_coin)
end
assert(sawMission and sawSolana and sawChest and sawCofferCoin and sawAmmoRule and sawSuppliesRule,
  'mission objective, supplies guidance or native illustrations missing')
budget(on_key,'back',false)
assert(upvalue(on_tick,'mode')=='title','mission CANCEL did not return to title')
held={select=true}
budget(on_key,'select',false)
assert(upvalue(on_tick,'mode')=='mission' and upvalue(on_tick,'state')==nil,
  'title SELECT bypassed mandatory rules')
for _=1,6 do
  budget(on_key,'select',true)
  budget(on_tick,80)
end
assert(upvalue(on_tick,'mode')=='mission' and upvalue(on_tick,'state')==nil,
  'held title SELECT skipped rules or created a game')
held={};budget(on_tick,50)
held={select=true};budget(on_key,'select',false)
local state=upvalue(on_tick,'state')
assert(upvalue(on_tick,'mode')=='play','fresh SELECT on rules did not start game')
for _=1,6 do budget(on_tick,80) end
assert(state.ammo==17,'held SELECT from rules must not fire')
held={};budget(on_tick,50)
local start=state.x
held={up=true};budget(on_tick,80);held={}
assert(state.x>start,'held direction does not move')
budget(on_key,'select',false)
assert(state.ammo==16,'fire did not consume ammo')
held={back=true}
for _=1,9 do budget(on_tick,80) end
held={}
assert(upvalue(on_tick,'mode')=='pause','hold CANCEL does not pause')
for _,o in ipairs(objects) do assert(o.value~='Yield on RWA baskets comes from swaps','pause screen contains end-screen promotion') end
held={select=true}
budget(on_key,'select',false)
assert(upvalue(on_tick,'mode')=='play','resume failed')
for _=1,6 do budget(on_tick,80) end
assert(state.ammo==16,'held SELECT from pause must not fire')
held={};budget(on_tick,50)
held={select=true};budget(on_tick,50)
assert(state.ammo==15,'SELECT must fire after release and re-press')
held={};budget(on_tick,50)
local render=upvalue(on_tick,'render')
local sprite=upvalue(render,'sprite')
local depths=upvalue(sprite,'z')
-- Match the real CANCEL interaction, including a near diagonal hidden by a
-- wall corner. These first-door poses are shared with the core contract tests.
local hud=upvalue(render,'hud')
local info=upvalue(hud,'infoLabel')
local savedHint,savedHintTime=upvalue(hud,'currentHint'),upvalue(hud,'hintTime')
local doorScene=require('game').new()
assert(doorScene.doors[1].x==18 and doorScene.doors[1].y==3
  and doorScene:canStand(17.5,3.5) and doorScene:canStand(17.5,2.5)
  and doorScene:tile(18,2)~=0,'first-door HUD fixture no longer matches the real map')
doorScene.x,doorScene.y,doorScene.angle=17.5,3.5,0
doorScene.message,doorScene.messageTime='STATE MESSAGE',3
setvalue(on_tick,'state',doorScene)
setvalue(hud,'currentHint','TRANSIENT MESSAGE');setvalue(hud,'hintTime',1)
budget(hud)
assert(info.value=='cancel to open the door','eligible door prompt lost priority over transient/state messages')
budget(on_key,'back',false);budget(hud)
assert(doorScene.doors[1].open and info.value=='DOOR OPEN','opened door retained its open-door prompt')
doorScene.doors[1].open,doorScene.doorOpen=false,false
doorScene.messageTime=0;setvalue(hud,'hintTime',0)
doorScene.angle=math.pi;budget(hud)
assert(info.value~='cancel to open the door','door prompt remained while facing away')
doorScene.x,doorScene.y,doorScene.angle=17.5,2.5,math.pi/4;budget(hud)
assert(info.value~='cancel to open the door','door prompt leaked through the adjacent wall corner')
doorScene.x,doorScene.y,doorScene.angle=16.5,3.5,0;budget(hud)
assert(info.value~='cancel to open the door','distant door displayed an interaction prompt')
doorScene.x,doorScene.y,doorScene.angle=17.5,3.5,0
doorScene.collected=2;budget(hud)
assert(info.value=='cancel to open the door','eligible door did not override generic chest-return guidance')
doorScene.x,doorScene.y,doorScene.angle=doorScene.chest.x-1,doorScene.chest.y,0;budget(hud)
assert(info.value=='RETURN TO CHEST. CANCEL deposit','door guidance removed the chest deposit hint')
setvalue(on_tick,'state',state)
setvalue(hud,'currentHint',savedHint);setvalue(hud,'hintTime',savedHintTime)
budget(hud)
-- Walking over actual supply entities must refresh both HUD counters while
-- leaving the two-coin mission unchanged.
local supplies=require('game').new()
for _,enemy in ipairs(supplies.enemies) do enemy.alive=false end
local supplyAt={}
for _,pickup in ipairs(supplies.pickups) do
  if (pickup.kind=='medkit' or pickup.kind=='ammo') and not supplyAt[pickup.kind] then
    supplyAt[pickup.kind]=pickup
  end
end
assert(supplyAt.medkit and supplyAt.ammo,'real level must contain health and ammunition supplies')
supplies.hp,supplies.ammo=50,5
setvalue(on_tick,'state',supplies);budget(hud)
local hpLabel,roundsLabel=upvalue(hud,'health'),upvalue(hud,'ammoLabel')
assert(hpLabel.value=='HP 50%' and roundsLabel.value=='COINS 0/2  AMMO 5','HUD supply baseline differs')
supplies.x,supplies.y=supplyAt.medkit.x,supplyAt.medkit.y
budget(supplies.update,supplies,0.01,{});budget(hud)
assert(supplyAt.medkit.taken and hpLabel.value=='HP 75%','medkit collection did not refresh HUD health')
supplies.x,supplies.y=supplyAt.ammo.x,supplyAt.ammo.y
budget(supplies.update,supplies,0.01,{});budget(hud)
assert(supplyAt.ammo.taken and roundsLabel.value=='COINS 0/2  AMMO 13',
  'ammo collection did not refresh HUD ammunition')
assert(supplies.collected==0 and not supplies.coins.solana and not supplies.coins.coffer,
  'ordinary supplies changed the two-coin mission counter')
setvalue(on_tick,'state',state);budget(hud)
-- A diagonal across a large open room crosses more than 36 grid edges.
-- Stopping early would invent a nearer wall and wrongly occlude actors.
local longScene={}
for key,value in pairs(state) do longScene[key]=value end
setmetatable(longScene,getmetatable(state))
longScene.width,longScene.height=36,36
longScene.map={string.rep('1',36)}
for y=2,35 do longScene.map[y]='1'..string.rep('0',34)..'1' end
longScene.map[36]=string.rep('1',36)
longScene.x,longScene.y,longScene.angle=1.5,1.5,math.pi/4
longScene.enemies,longScene.pickups,longScene.props={},{},{}
setvalue(on_tick,'state',longScene)
budget(render)
local camera=2*(80+2)/160-1
local expectedDepth=(35-1.5)/(math.sqrt(0.5)*(1+0.66*camera))
assert(math.abs(depths[81]-expectedDepth)<0.001,'long ray stopped before the real map boundary')
setvalue(on_tick,'state',state)
for i=1,160 do depths[i]=99 end
for _,depth in ipairs({0.25,0.20,0.19,0.17}) do
  canvasRects,canvasImages=0,0
  budget(sprite,{kind='enemy'},depth,0,1,0,0,0.66)
  assert(canvasRects+canvasImages>0,'close enemy vanished at depth '..depth)
end
assert(Art.palettes.medkit and Art.palettes.ammo,'supply sprites need independent palettes')
local Sprites=require('sprites')
local savedSpriteCache=upvalue(sprite,'spriteCache')
for _,kind in ipairs({'solana_coin','coffer_coin','chest','medkit','ammo'}) do
  for _,native in ipairs({false,true}) do
    setvalue(sprite,'spriteCache',native and Sprites.new(Art,160,92) or {draw=function() return false end})
    observedColors={}
    canvasRects,canvasImages=0,0
    budget(sprite,{kind=kind},2,0,1,0,0,0.66)
    assert(native and canvasImages==1 or (not native and canvasRects>0 and canvasImages==0),
      kind..' palette check did not exercise the requested native/RLE path')
    local allowed,count={},0
    for _,color in pairs(Art.palettes[kind] or Art.palette) do allowed[color]=true end
    for color in pairs(observedColors) do
      assert(allowed[color],kind..' used another asset palette')
      count=count+1
    end
    assert(count>=2,kind..' did not render its detailed colors')
    observedColors=nil
  end
end
setvalue(sprite,'spriteCache',savedSpriteCache)
-- Co-located monsters share identical opaque/transparent pixels. Drawing one
-- must preserve the image without dropping a second, distinct nearby actor.
state.x,state.y,state.angle=1.5,1.5,0
for i,e in ipairs(state.enemies) do e.x,e.y,e.alive=3.5,1.5,i==1 end
-- Warm wall surfaces before comparing draw counts: native/RLE transitions
-- otherwise change calls independently of the number of enemy billboards.
for _=1,48 do budget(render) end
canvasRects,canvasImages=0,0;budget(render)
local singleSpriteDraws=canvasRects+canvasImages
for _,e in ipairs(state.enemies) do e.alive=true end
canvasRects,canvasImages=0,0;budget(render)
assert(canvasRects+canvasImages==singleSpriteDraws,'co-located monsters were redundantly drawn')
for i,e in ipairs(state.enemies) do e.alive=i<=2 end
state.enemies[2].y=1.7
canvasRects,canvasImages=0,0;budget(render)
assert(canvasRects+canvasImages>singleSpriteDraws,'distinct visible monsters were dropped')
-- Three slow pictures yield one cheap tick; held input still updates on it.
for _,e in ipairs(state.enemies) do e.alive=false end
state.x,state.y,state.angle=1.5,1.5,0
while upvalue(render,'frames')%3~=0 do budget(render) end
held={up=true};mockRenderMs=40
setvalue(on_tick,'skipRenderTick',false)
local framesBefore=upvalue(render,'frames')
local xBefore=state.x
for picture=1,3 do
  budget(on_tick,50)
  assert(upvalue(render,'frames')==framesBefore+picture,'slow renderer yielded before three pictures')
  assert(upvalue(on_tick,'skipRenderTick')==(picture==3),'slow renderer did not yield after third picture')
  assert(state.x>xBefore,'slow callback stopped held movement')
  xBefore=state.x
end
budget(on_tick,50)
assert(upvalue(render,'frames')==framesBefore+3 and not upvalue(on_tick,'skipRenderTick'),
  'one deferred render must re-arm drawing')
assert(state.x>xBefore,'deferred frame stopped held movement')
mockRenderMs=0;held={}
budget(on_tick,50)
assert(upvalue(render,'frames')==framesBefore+4,'render did not resume after deferred frame')
-- A single shot must remain visible after 300ms of cheap/skipped ticks. This
-- reproduces the slow-LCD case where the former 120ms flash expired unseen.
for _=1,3 do budget(on_tick,100) end
local idleImage,idleY=lastWeapon.image,lastWeapon.y
local beforeShot=state.ammo
state.fireCooldown=0
budget(on_key,'select',false)
assert(state.ammo==beforeShot-1,'single SELECT did not shoot')
local beforeDeferred=upvalue(render,'frames')
orangePixels,yellowPixels=0,0
for _=1,3 do
  setvalue(on_tick,'skipRenderTick',true)
  budget(on_tick,100)
end
assert(upvalue(render,'frames')==beforeDeferred and orangePixels==0 and yellowPixels==0,
  'deferred visual test unexpectedly rendered')
setvalue(on_tick,'skipRenderTick',false)
budget(on_tick,100)
assert(orangePixels>=100 and yellowPixels>=100,'shot expired before its yellow/orange muzzle frame')
assert(lastWeapon.image~=idleImage and lastWeapon.y>idleY,'firing gun did not change frame and recoil')
local firingImage=lastWeapon.image
assert(firingImage.rows==Art.weapon and idleImage.rows==Art.weapon and firingImage.palette['.']==nil,
  'firing gun changed the source pixels or transparent background')
local litSymbols={}
for _,row in ipairs(Art.weapon) do for i=1,#row do
  local symbol=row:sub(i,i)
  if symbol~='.' and not litSymbols[symbol] then
    litSymbols[symbol]=true
    local base,lit=Art.palette[symbol],firingImage.palette[symbol]
    assert(base and idleImage.palette[symbol]==base and lit,'weapon color missing or idle palette changed')
    local r,g,b=base>>16,(base>>8)&255,base&255
    local lr,lg,lb=lit>>16,(lit>>8)&255,lit&255
    assert(lr>=r and lg>=g and lb>=b and lr+lg+lb>r+g+b,'weapon symbol was not lit: '..symbol)
    assert(lr>=lg and lg>=lb,'weapon flash palette is not warm: '..symbol)
  end
end end
for _=1,3 do budget(on_tick,100) end
orangePixels,yellowPixels=0,0
budget(on_tick,100)
assert(lastWeapon.image==idleImage and lastWeapon.y==idleY and orangePixels==0 and yellowPixels==0,
  'gun did not recover to idle after the shot')
local savedAmmo=state.ammo
state.ammo,state.fireCooldown=0,0
budget(on_key,'select',false);budget(on_tick,100)
assert(state.ammo==0 and lastWeapon.image==idleImage and orangePixels==0 and yellowPixels==0,
  'empty weapon generated a firing frame')
state.ammo,state.fireCooldown=savedAmmo,0
held={select=true}
local heldStart,firingFrames=state.ammo,0
for _=1,12 do
  budget(on_tick,100)
  if lastWeapon.image~=idleImage then firingFrames=firingFrames+1 end
end
assert(state.ammo<=heldStart-3 and firingFrames>=3,'held SELECT did not repeat firing animation')
held={};for _=1,3 do budget(on_tick,100) end
-- Render every walkable tile in four directions, including close walls/sprites.
local poses=0
for y=1,state.height-2 do
  for x=1,state.width-2 do
    if state:tile(x,y)==0 then
      state.x,state.y=x+0.5,y+0.5
      for angle=0,3 do state.angle=angle*math.pi/2;budget(render);poses=poses+1 end
    end
  end
end
state.x,state.y,state.angle=state.chest.x-1,state.chest.y,0
state.coins.solana,state.coins.coffer,state.collected=false,false,0
budget(on_key,'back',false)
assert(not state.won and not state.delivered,'chest accepted missing coins')
state.coins.solana,state.coins.coffer,state.collected=true,true,2
budget(on_tick,50)
assert(not state.won,'coins deposited automatically without CANCEL')
budget(on_key,'back',false)
assert(state.won and state.delivered,'CANCEL did not deposit both coins')
budget(on_tick,50)
assert(upvalue(on_tick,'mode')=='win','victory screen missing')
checkPromotion()
budget(on_key,'select',false)
state=upvalue(on_tick,'state')
state.hp=0;state.dead=true
budget(on_tick,80)
assert(upvalue(on_tick,'mode')=='dead','death screen missing')
checkPromotion()
budget(on_key,'back',false)
assert(upvalue(on_tick,'mode')=='title','return to title failed')
assert(on_key('back',false)==false,'CANCEL must exit from title')
budget(on_key,'right',false)
held={select=true};budget(on_key,'select',false)
state=upvalue(on_tick,'state')
for _=1,6 do budget(on_tick,80) end
assert(upvalue(on_tick,'mode')=='play' and state.ammo==17,'mission SELECT did not start with trigger unarmed')
held={back=true};for _=1,9 do budget(on_tick,80) end
held={};budget(on_key,'back',false)
assert(upvalue(on_tick,'mode')=='title','mission-started game could not return to title')
for _=1,20 do
  budget(on_key,'select',false)
  assert(upvalue(on_tick,'mode')=='mission','lifecycle title skipped rules')
  held={};budget(on_tick,50)
  held={select=true};budget(on_key,'select',false)
  assert(upvalue(on_tick,'mode')=='play','lifecycle rules did not start game')
  budget(on_key,'back',false)
  held={back=true};for _=1,9 do budget(on_tick,80) end
  held={};budget(on_key,'back',false)
end
assert(#objects==10 or #objects<=16,'scene objects leaked')
on_exit()
print('app_spec: '..poses..' viewpoints; title, movement, fire, pause, win/death, 20 lifecycle loops OK')
print('mandatory rules, title/logos, delayed muzzle/recoil, empty/held SELECT, deposit, slow-frame input, overlap deduplication OK')
print('app VM + native canvas callback peak: '..peak..' / 200000 instructions')
