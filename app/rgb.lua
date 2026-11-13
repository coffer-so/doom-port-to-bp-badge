-- SPDX-License-Identifier: GPL-2.0-or-later
-- Tick-driven badge LEDs. Nominal RGB values are scaled by the OS brightness cap.
local M = {}
local api = type(led)=='table' and led or nil
local count = math.max(0,math.min(8,math.floor(api and tonumber(api.count) or 8)))
local kind,base,age,wait,stamp,closed = 'play','play',0,0,nil,false
local duration = {hurt=200,solana=600,coffer=600}
local rainbow = {{255,40,20},{255,160,24},{80,240,40},{20,220,140},{40,90,255},{170,40,255}}
local allowed = {title=true,play=true,hurt=true,solana=true,coffer=true,win=true,dead=true}
local function call(name,...)
  if not api or type(api[name])~='function' then return false end
  local ok=pcall(api[name],...)
  if not ok then api=nil end -- Missing permission must never stop the game.
  return ok
end
local function fill(r,g,b)
  if api and type(api.fill)=='function' then call('fill',r,g,b)
  else for i=1,count do call('set',i,r,g,b) end end
end
local function off()
  if api and type(api.off)=='function' then call('off') else fill(0,0,0) end
end
local function draw()
  local step=math.floor(age/100)
  if kind=='win' and age>=2000 then step=20
  elseif kind=='title' or kind=='play' or kind=='dead' or kind=='hurt' then step=0 end
  local key=kind..':'..step
  if key==stamp then return end
  stamp=key
  if kind=='title' then fill(56,48,34)
  elseif kind=='play' then off()
  elseif kind=='hurt' then fill(255,12,4)
  elseif kind=='dead' then fill(64,3,1)
  elseif kind=='win' and age>=2000 then fill(16,120,48)
  else
    for i=1,count do
      local r,g,b
      if kind=='win' and age<1200 then
        local color=rainbow[(i+step-1)%#rainbow+1]
        r,g,b=color[1],color[2],color[3]
      else
        local distance=(i-1-step)%count
        local gain=distance==0 and 1 or (distance==1 and 0.45 or (distance==2 and 0.15 or 0.035))
        if kind=='solana' then
          if (i+step)%2==0 then r,g,b=153,69,255 else r,g,b=20,241,149 end
        elseif kind=='coffer' then r,g,b=255,190,74
        else r,g,b=30,240,96 end
        r,g,b=math.floor(r*gain),math.floor(g*gain),math.floor(b*gain)
      end
      call('set',i,r,g,b)
    end
  end
end
function M.effect(nextKind)
  if closed or not allowed[nextKind] then return false end
  if not duration[nextKind] then base=nextKind end
  kind,age,wait,stamp=nextKind,0,0,nil
  draw()
  return true
end
function M.tick(ms)
  if closed or type(ms)~='number' or ms~=ms or ms<=0 then return end
  ms=math.min(ms,60000)
  age,wait=age+ms,wait+ms
  if duration[kind] and age>=duration[kind] then
    kind,age,wait,stamp=base,0,100,nil
  end
  if wait<100 then return end
  wait=wait%100
  draw()
end
function M.close()
  if closed then return end
  closed=true
  kind,base,age,wait,stamp='play','play',0,0,nil
  off()
end
return M
