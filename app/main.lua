-- SPDX-License-Identifier: GPL-2.0-or-later
-- Solana OS Lua app. All input comes from the badge's physical logical keys.
local Game = require('game')
local Art = require('art')
local Textures = require('textures')
local Surfaces = require('surfaces')
local Sprites = require('sprites')
local RGB = require('rgb')
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local sin, cos = math.sin, math.cos
local W, H, SCALE = 160, 92, 2
local WALL_STEP=4
local view, health, ammoLabel, infoLabel, branding
local state, mode, elapsed, fireFlash, hurtFlash = nil, 'title', 0, 0, 0
local z, entities = {}, {}
local previousHp, backHeld, backUsed = 100, 0, false
local frames,renderLast=0,0
local currentHint, hintTime = '', 0
local oldHud = ''
local lastInfo
local triggerReady = false
local renderTotal,renderPeak,cadenceTotal=0,0,0
local wallsTotal,spritesTotal,overlayTotal=0,0,0
local wallsPeak,spritesPeak,overlayPeak=0,0,0
local skipRenderTick=false
local surfaceCache=Surfaces.new(Textures,W,H)
local spriteCache=Sprites.new(Art,W,H)
local gunImage,gunFireImage
local firePending,gunRecovery=false,0
local palette = Art.palette
local colors = {
  {0xB5B5A6, 0x969B8D, 0x798171, 0x5C6858, 0x424F42},
  {0xA1A183, 0x818A6B, 0x646F53, 0x4B583F, 0x354630},
  {0xB1946D, 0x94764F, 0x73583B, 0x57412D, 0x403123},
}
local function label(x,y,text,size,color,width)
  return ui.label(x,y,text,{size=size or 12,color=color or 0xDBCFAE,w=width or 320,align='center'})
end
local function rect(x,y,w,h,color)
  return ui.rect(x,y,w,h,{color=color,radius=0})
end
local function hint(text)
  currentHint, hintTime = text or '', 1.8
end
local function clear()
  ui.clear()
  view, health, ammoLabel, infoLabel, branding = nil,nil,nil,nil,nil
end
local function title()
  clear()
  mode, state = 'title', nil
  RGB.effect('title')
  local bg,ink=0x262724,0xFDF7DC
  ui.bg(bg)
  ui.image(70,0,'art/doom.png')
  ui.image(84,118,'art/coffer.png',{scale=2})
  ui.label(122,128,'Made by coffer team',{size=12,color=ink})
  label(0,164,'yield on RWA baskets here coffer.so',12,ink)
  label(0,180,'twitter: @coffer_so',12,ink)
  label(0,202,'click "select" btn to start the game',12,ink)
end
local function mission()
  clear();mode='mission'
  ui.bg(0x262724)
  label(0,8,'THE MISSION',20,0xFDF7DC)
  label(0,40,'Find both coins. Survive the zombies.',12,0xFDF7DC)
  ui.image(45,68,Art.solana_coin,{scale=2,palette=Art.palettes.solana_coin})
  ui.image(128,65,Art.chest,{scale=2,palette=palette})
  ui.image(227,68,Art.coffer_coin,{scale=2,palette=Art.palettes.coffer_coin})
  label(0,129,'1 Solana + 1 Coffer -> chest',12,0xFDF7DC)
  label(0,153,'Walk into coins to collect.',12,0xFDF7DC)
  label(0,171,'At the chest: CANCEL to deposit.',12,0xFDF7DC)
  label(0,200,'SELECT play   CANCEL back',12,0xFDF7DC)
end

local function makeHud()
  rect(0,184,320,34,0x171B1B)
  rect(0,184,320,2,0x705242)
  health = ui.label(8,189,'',{size=12,color=0xF0C689})
  ammoLabel = ui.label(111,189,'',{size=12,color=0xD3D0AC})
  infoLabel = ui.label(8,204,'',{size=12,color=0xAAA795,w=230})
  branding = ui.label(238,204,'coffer.so',{size=12,color=0xBAA77A,w=78,align='right'})
  oldHud,lastInfo='',nil
end
local function hud()
  local text = state.hp..':'..state.ammo..':'..state.kills..':'..state.collected
  if text ~= oldHud then
    health:text('HP '..state.hp..'%')
    ammoLabel:text('COINS '..state.collected..'/2  AMMO '..state.ammo)
    oldHud = text
  end
  local note = (hintTime > 0 and currentHint ~= '' and currentHint)
    or (state.messageTime > 0 and state.message)
    or (state.collected==2 and 'RETURN TO CHEST. CANCEL deposit' or 'FIND SOLANA + COFFER COINS')
  if note~=lastInfo then infoLabel:text(note);lastInfo=note end
end
-- Compile vertical color runs once; magnified sprite strips are drawn in C.
local spriteColumns={}
local function columnsFor(kind)
  if spriteColumns[kind] then return spriteColumns[kind] end
  local rows=Art[kind]
  if not rows then return nil end
  local pal=Art.palettes and Art.palettes[kind] or palette
  local columns={}
  for x=1,#rows[1] do
    local runs,last,start={},nil,0
    for y=0,#rows do
      local symbol=y<#rows and rows[y+1]:sub(x,x) or '.'
      if symbol~=last then
        if last and pal[last] then runs[#runs+1]=start;runs[#runs+1]=y;runs[#runs+1]=pal[last] end
        start,last=y,symbol
      end
    end
    columns[x]=runs
  end
  columns.height=#rows
  spriteColumns[kind]=columns
  return columns
end
local function sprite(e,dx,dy,dirX,dirY,planeX,planeY)
  local depth=dx*dirX+dy*dirY
  if depth<0.16 or depth>13 then return end
  local side=(dx*planeX+dy*planeY)/(planeX*planeX+planeY*planeY)
  local factor=e.kind=='enemy' and 0.78 or (e.kind=='chest' and 0.55 or 0.32)
  local height=floor(H/depth*factor)
  if height<2 then return end
  local columns=columnsFor(e.kind)
  if not columns then return end
  local sw,sh=#columns,columns.height
  local width=max(2,floor(height*sw/sh))
  local center=floor(W/2*(1+side/depth))
  local left=center-width//2
  local top=floor(H/2+H/(2*depth)-height)
  if e.kind=='solana_coin' or e.kind=='coffer_coin' then top=top-floor(H/(depth*3))+floor(sin(elapsed*3)*2) end
  if left+width<=0 or left>=W or top>=H or top+height<=0 then return end
  -- Reject wholly hidden billboards before visiting every source color run.
  local visible=false
  for x=max(0,left),min(W-1,left+width-1) do
    if depth<(z[x+1] or 99) then visible=true;break end
  end
  if not visible then return end
  if spriteCache:draw(view,e.kind,left,top,width,height,depth,z) then return end
  for sx=0,sw-1 do
    local x=max(0,left+floor(sx*width/sw))
    local last=min(W-1,left+floor((sx+1)*width/sw)-1)
    local runs=columns[sx+1]
    while x<=last do
      while x<=last and depth>=(z[x+1] or 99) do x=x+1 end
      local start=x
      while x<=last and depth<(z[x+1] or 99) do x=x+1 end
      if x>start then
        for i=1,#runs,3 do
          local y0=max(0,top+floor(runs[i]*height/sh))
          local y1=min(H,top+floor(runs[i+1]*height/sh))
          if y1>y0 then view:rect(start,y0,x-start,y1-y0,runs[i+2]) end
        end
      end
    end
  end
end
local function farther(a,b) return a.depth > b.depth end
local function render()
  if not state or not view then return end
  local clock=type(sys.millis)=='function' and sys.millis
  local started=clock and clock() or 0
  surfaceCache:beginFrame()
  spriteCache:beginFrame()
  local dirX,dirY=cos(state.angle),sin(state.angle)
  local planeX,planeY=-dirY*0.66,dirX*0.66
  view:clear(0x1B2427)
  view:rect(0,H//2,W,H-H//2,0x3C3530)
  view:rect(0,0,W,16,0x111A1F)
  view:rect(0,H-16,W,16,0x4D4136)
  for x=0,W-1,WALL_STEP do
    local camera=2*(x+WALL_STEP/2)/W-1
    local rx,ry=dirX+planeX*camera,dirY+planeY*camera
    local mx,my=floor(state.x),floor(state.y)
    local ddx,ddy=abs(1/(rx == 0 and 0.00001 or rx)),abs(1/(ry == 0 and 0.00001 or ry))
    local stepx,stepy=rx < 0 and -1 or 1,ry < 0 and -1 or 1
    local sdx=(rx < 0 and state.x-mx or mx+1-state.x)*ddx
    local sdy=(ry < 0 and state.y-my or my+1-state.y)*ddy
    local side,wall=0,0
    for _=1,36 do
      if sdx < sdy then sdx=sdx+ddx;mx=mx+stepx;side=0
      else sdy=sdy+ddy;my=my+stepy;side=1 end
      wall=string.byte(state.map[my+1],mx+1)-48
      if wall==3 then wall=state:tile(mx,my) end
      if wall > 0 then break end
    end
    local distance=max(0.08,side == 0 and sdx-ddx or sdy-ddy)
    for column=x+1,x+WALL_STEP do z[column]=distance end
    local height=floor(H/distance)
    local top=floor((H-height)/2)
    local y0,y1=max(0,top),min(H,top+height)
    local shade=min(5,1+floor(distance*0.55)+(side == 1 and 1 or 0))
    local col=colors[wall] or colors[1]
    if y1 > y0 then
      local hit=side == 0 and state.y+distance*ry or state.x+distance*rx
      local u=hit-floor(hit)
      if distance>9 then
        view:rect(x,y0,WALL_STEP,y1-y0,col[shade])
      else
        local tx=min(16,1+floor(u*16))
        local column=Textures[wall][shade][tx]
        if not surfaceCache:draw(view,x,y0,y1,top,height,wall,shade,tx,WALL_STEP) then
        for i=1,#column,3 do
          local a=max(y0,top+floor(column[i]*height/8))
          local b=min(y1,top+floor(column[i+1]*height/8))
          if b>a then view:rect(x,a,WALL_STEP,b-a,column[i+2]) end
        end
        end
      end
      if wall==2 and u>0.18 and u<0.8 then
        local a,b=max(y0,top+height//3),min(y1,top+height//3+max(1,height//14))
        if b>a then view:rect(x,a,WALL_STEP,b-a,shade<4 and 0x7AADA0 or 0x48685F) end
      elseif wall==3 and u>0.4 and u<0.6 then
        local a,b=max(y0,top+height//3),min(y1,top+2*height//3)
        if b>a then view:rect(x,a,WALL_STEP,b-a,state.key and 0x74AD79 or 0x85302A) end
      end
    end
  end
  local wallsDone=clock and clock() or 0
  -- Reuse sprite entries instead of allocating per-frame entity tables.
  local n=0
  for i=1,#state.enemies do
    local e=state.enemies[i]
    if e.alive then n=n+1;entities[n]=e;e.kind='enemy';e.depth=(e.x-state.x)*dirX+(e.y-state.y)*dirY end
  end
  for i=1,#state.pickups do
    local p=state.pickups[i]
    if not p.taken then n=n+1;entities[n]=p;p.depth=(p.x-state.x)*dirX+(p.y-state.y)*dirY end
  end
  for i=1,#(state.props or {}) do
    local p=state.props[i]
    n=n+1;entities[n]=p;p.depth=(p.x-state.x)*dirX+(p.y-state.y)*dirY
  end
  for i=#entities,n+1,-1 do entities[i]=nil end
  table.sort(entities,farther)
  -- Monsters can occupy exactly the same position. Their static billboard,
  -- projection and wall clipping are identical, so one draw preserves every
  -- visible pixel. Keep distinct positions and all gameplay actors intact.
  for i=n,1,-1 do
    local e=entities[i]
    e._spriteVisible=true
    for j=i+1,n do
      local near=entities[j]
      if near._spriteVisible and e.kind==near.kind and e.x==near.x and e.y==near.y then
        e._spriteVisible=false;break
      end
    end
  end
  for i=1,n do
    local e=entities[i]
    if e._spriteVisible then sprite(e,e.x-state.x,e.y-state.y,dirX,dirY,planeX,planeY) end
  end
  local spritesDone=clock and clock() or 0
  -- A successful shot stays pending until a picture actually shows it. Cheap
  -- skipped ticks must not consume the muzzle flash before the LCD sees it.
  local keys=sys.keys and sys.keys() or {}
  local bob=(keys.up or keys.down) and abs(sin(elapsed*9))*3 or 0
  local firing=firePending or fireFlash>0
  local kick=firing and 3 or (gunRecovery>0 and 1 or 0)
  local by=floor(H-24+bob)+kick
  local gx=W//2-16+(firing and 1 or 0)
  if firing then
    local cx=gx+16
    view:rect(cx-5,by-19,10,18,0xF7761B)
    view:rect(cx-12,by-12,24,7,0xF7761B)
    view:rect(cx-9,by-16,18,3,0xF7761B)
    view:rect(cx-7,by-14,14,12,0xFFD43B)
    view:rect(cx-4,by-17,8,17,0xFFD43B)
    view:rect(cx-2,by-13,4,13,0xFFF3B0)
  end
  local image=firing and gunFireImage or gunImage
  if image then view:image(image,gx,by) end
  view:pixel(W//2,H//2,0xE4D2AD)
  firePending=false
  if hurtFlash>0 then
    view:rect(0,0,W,1,0x9E332B);view:rect(0,H-1,W,1,0x9E332B)
    view:rect(0,0,1,H,0x9E332B);view:rect(W-1,0,1,H,0x9E332B)
  end
  hud()
  frames=frames+1
  if clock then
    local finished=clock()
    local cost=max(0,finished-started)
    local walls=max(0,wallsDone-started)
    local sprites=max(0,spritesDone-wallsDone)
    local overlay=max(0,finished-spritesDone)
    renderTotal=renderTotal+cost;renderPeak=max(renderPeak,cost)
    wallsTotal,spritesTotal,overlayTotal=wallsTotal+walls,spritesTotal+sprites,overlayTotal+overlay
    wallsPeak,spritesPeak,overlayPeak=max(wallsPeak,walls),max(spritesPeak,sprites),max(overlayPeak,overlay)
    renderLast=cost
  end
end
local function play()
  clear()
  state=Game.new()
  if not gunImage then gunImage=ui.load(Art.weapon,{palette=palette}) end
  if not gunFireImage then
    local lit={}
    for key,color in pairs(palette) do lit[key]=color end
    lit.J,lit.K,lit.L,lit.Q=0x493825,0xB98A45,0xFFE6A1,0xFFF2B8
    gunFireImage=ui.load(Art.weapon,{palette=lit})
  end
  mode,elapsed,fireFlash,hurtFlash='play',0,0,0
  firePending,gunRecovery=false,0
  RGB.effect('play')
  previousHp,backHeld,backUsed=100,0,false
  triggerReady=false
  currentHint,hintTime='',0
  frames,renderTotal,renderPeak,cadenceTotal=0,0,0,0
  wallsTotal,spritesTotal,overlayTotal=0,0,0
  wallsPeak,spritesPeak,overlayPeak=0,0,0
  skipRenderTick=true
  view=ui.canvas(0,0,W,H,{scale=SCALE,color=0x111A1F})
  makeHud()
  render()
end
local function overlay(kind)
  clear()
  mode=kind
  if kind=='win' then RGB.effect('win') elseif kind=='dead' then RGB.effect('dead') end
  ui.bg(0x111719)
  label(0,28,kind=='pause' and 'PAUSED' or (kind=='win' and 'COINS SECURED' or 'YOU DIED'),32,0xE1B16E)
  if kind=='pause' then
    label(0,80,'D-pad: move / turn',14)
    label(0,104,'SELECT fire   CANCEL interact',14)
    label(0,128,'2 coins -> chest. Hold CANCEL pause',12)
    label(0,163,'SELECT resume   CANCEL title',12)
    label(0,194,'coffer.so',12,0xBAA77A)
  else
    label(0,78,'Coins '..state.collected..'/2   Kills '..state.kills..'/'..state.totalKills,14)
    label(0,102,'SELECT play again   CANCEL title',12)
    label(0,128,'Coffer is a pure DeFi protocol.',12)
    label(0,143,'Yield on RWA baskets comes from swaps',12)
    label(0,158,'between the tokens in each basket.',12)
    label(0,173,'We created a completely new AMM primitive',12)
    label(0,188,'on Solana. Before Coffer, we built an',12)
    label(0,203,'$87M DeFi protocol.',12)
  end
end
local function resume()
  clear()
  mode='play'
  backHeld,backUsed=0,false
  triggerReady=false
  fireFlash,firePending,gunRecovery=0,false,0
  view=ui.canvas(0,0,W,H,{scale=SCALE,color=0x111A1F})
  makeHud();render()
end
local function shoot()
  local result=state:fire()
  if result=='shot' or result=='hit' or result=='kill' then
    fireFlash,gunRecovery,firePending=0.10,0.18,true
  elseif result=='empty' then hint('OUT OF AMMO') end
end
function on_key(key,rep)
  if mode=='title' then
    if key=='select' and not rep then mission()
    elseif key=='right' and not rep then mission()
    elseif key=='back' and not rep then return false end
  elseif mode=='mission' then
    if key=='select' and not rep then play()
    elseif key=='back' and not rep then title() end
  elseif mode=='play' then
    if key=='select' and not rep and triggerReady then shoot()
    elseif key=='back' and not rep then
      local result=state:use()
      if result=='missing' then hint('FIND BOTH COINS FIRST')
      elseif result=='door' then hint('DOOR OPEN') end
    end
  elseif mode=='pause' then
    if key=='select' and not rep then resume()
    elseif key=='back' and not rep then title() end
  else
    if key=='select' and not rep then play()
    elseif key=='back' and not rep then title() end
  end
  return true
end
function on_tick(ms)
  RGB.tick(ms or 0)
  if mode~='play' then return end
  local callbackStart=sys.millis and sys.millis() or 0
  cadenceTotal=cadenceTotal+max(0,ms or 0)
  local dt=max(0,min(100,ms or 0))/1000
  elapsed=elapsed+dt
  local keys=sys.keys and sys.keys() or {}
  if keys.back then
    backHeld=backHeld+dt
    if backHeld>=0.65 and not backUsed then backUsed=true;overlay('pause');return end
  else backHeld,backUsed=0,false end
  local hadSolana,hadCoffer=state.coins.solana,state.coins.coffer
  state:update(dt,keys)
  if state.coins.solana and not hadSolana then RGB.effect('solana') end
  if state.coins.coffer and not hadCoffer then RGB.effect('coffer') end
  if not keys.select then triggerReady=true end
  if keys.select and triggerReady then shoot() end
  hintTime=max(0,hintTime-dt)
  if not firePending then
    fireFlash=max(0,fireFlash-dt)
    gunRecovery=max(0,gunRecovery-dt)
  end
  hurtFlash=max(0,hurtFlash-dt)
  if state.hp<previousHp then hurtFlash=0.2;RGB.effect('hurt') end
  previousHp=state.hp
  if state.won then overlay('win');return end
  if state.dead then overlay('dead');return end
  if skipRenderTick then skipRenderTick=false;return end
  render()
  skipRenderTick=sys.millis and sys.millis()-callbackStart>=35 and frames%3==0 or false
end
function on_exit()
  RGB.close()
  if frames>0 and cadenceTotal>0 then
    print('render: '..frames..' frames, '..floor(frames*1000/cadenceTotal)..' fps; CPU avg '..floor(renderTotal/frames)..' ms, peak '..renderPeak..' ms')
    if type(sys.millis)=='function' then
      print('render phases avg/peak ms: walls '..floor(wallsTotal/frames)..'/'..wallsPeak..
        ', sprites '..floor(spritesTotal/frames)..'/'..spritesPeak..
        ', HUD/weapon '..floor(overlayTotal/frames)..'/'..overlayPeak)
    end
  end
  state,view,entities,z=nil,nil,nil,nil
end
if not ui.canvas or not sys.keys then
  ui.bg(0x111719)
  label(0,50,'Solana OS 0.5.11+ required',20)
  label(0,100,'Update from Settings to play.',14)
else title() end
