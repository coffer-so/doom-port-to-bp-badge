-- SPDX-License-Identifier: GPL-2.0-or-later
local root=arg[1] or '.'
local Surfaces=dofile(root..'/surfaces.lua')
local Textures=dofile(root..'/textures.lua')
local checks,loads=0,0
local function check(value,why) checks=checks+1;assert(value,why) end
local function integer(n) assert(math.type(n)=='integer','native coordinate must be integer') end
ui={load=function(rows,opts)
  loads=loads+1
  local image={rows={},palette=opts.palette,w=#rows[1],h=#rows}
  for i=1,#rows do image.rows[i]=rows[i] end
  return image
end}
local canvas={}
function canvas:image(image,x,y)
  integer(x);integer(y)
  assert(x>=0 and y>=0 and x+image.w<=160 and y+image.h<=92,'native strip off canvas')
  self.last={image=image,x=x,y=y}
end
local function reference(material,shade,texX,top,height,y0,y1)
  local out={}
  local runs=Textures[material][shade][texX]
  for i=1,#runs,3 do
    local a=math.max(0,y0,top,top+math.floor(runs[i]*height/8))
    local b=math.min(92,y1,top+height,top+math.floor(runs[i+1]*height/8))
    for y=a,b-1 do out[y]=runs[i+2] end
  end
  return out
end
local cache=Surfaces.new(Textures,160,92)
-- Include sub-texel walls and tall walls cropped through their middle.
for _,height in ipairs({1,2,3,7,8,9,17,46,91,92,93,127,184,251,1150}) do
  for material=1,3 do for shade=1,5 do for texX=1,16 do
    local top=(92-height)//2
    local y0,y1=math.max(0,top),math.min(92,top+height)
    cache:beginFrame()
    check(cache:draw(canvas,158,y0,y1,top,height,material,shade,texX,2),'native draw failed')
    local image=canvas.last.image
    local expected=reference(material,shade,texX,top,height,y0,y1)
    for y=1,#image.rows do
      check(#image.rows[y]==2,'strip width changed')
      for x=1,2 do
        local color=image.palette[image.rows[y]:sub(x,x)]
        check(color==expected[y0+y-1],'RLE projection/crop color mismatch')
      end
    end
    check(cache.count<=Surfaces.LIMIT,'cache is unbounded')
  end end end
end
-- Four-pixel wall rays preserve the exact RLE colors, including one/three-pixel
-- edge crops. The compact key must distinguish every width and height pair.
cache=Surfaces.new(Textures,160,92)
for _,width in ipairs({1,2,3,4}) do
  for _,height in ipairs({1,8,20,21,92,93,184,1150}) do
    for _,x in ipairs({0,156,158,159,-1,-3}) do
      if x+width>0 then
        local top=(92-height)//2
        local y0,y1=math.max(0,top),math.min(92,top+height)
        cache:beginFrame()
        check(cache:draw(canvas,x,y0,y1,top,height,2,3,5,width),'wide strip/crop failed')
        local got=canvas.last
        local actualWidth=math.min(160,x+width)-math.max(0,x)
        check(got.x==math.max(0,x) and got.image.w==actualWidth,'wrong horizontal crop')
        local expected=reference(2,3,5,top,height,y0,y1)
        for y=1,got.image.h do
          check(#got.image.rows[y]==actualWidth,'wide strip row length changed')
          for px=1,actualWidth do
            check(got.image.palette[got.image.rows[y]:sub(px,px)]==expected[y0+y-1],
              'wide strip pixel changed')
          end
        end
        check(cache.count<=Surfaces.LIMIT,'wide cache exceeded entry cap')
      end
    end
  end
end
cache=Surfaces.new(Textures,160,92)
cache:beginFrame()
check(cache:draw(canvas,0,0,20,0,20,1,1,1,4),'four-wide compact key failed')
local keyLoads=loads
check(cache:draw(canvas,0,0,21,0,21,1,1,1,2),'two-wide compact key failed')
check(loads==keyLoads+1 and canvas.last.image.w==2 and canvas.last.image.h==21,
  'compact keys collide between height/width combinations')
cache=Surfaces.new(Textures,160,92)
for i=1,Surfaces.LIMIT+17 do
  local height=1000+i
  cache:beginFrame()
  check(cache:draw(canvas,0,0,92,(92-height)//2,height,1,1,1,4),'eviction fill failed')
  check(cache.count<=Surfaces.LIMIT,'eviction did not bound four-wide entries')
end
keyLoads=loads;cache:beginFrame()
check(cache:draw(canvas,0,0,92,(92-1001)//2,1001,1,1,1,4),'evicted strip rebuild failed')
check(loads==keyLoads+1,'oldest strip survived bounded clock eviction')
cache=Surfaces.new(Textures,160,92)
local start=loads
cache:beginFrame()
for texX=1,Surfaces.BUILDS_PER_FRAME do
  check(cache:draw(canvas,0,0,92,0,92+texX,1,1,texX,2),'allowed build failed')
end
check(not cache:draw(canvas,0,0,92,0,200,1,1,16,2),'build budget exceeded')
check(loads-start==Surfaces.BUILDS_PER_FRAME,'native load budget exceeded')
check(cache:draw(canvas,4,0,92,0,93,1,1,1,2),'hit must work after build budget exhausted')
check(loads-start==Surfaces.BUILDS_PER_FRAME,'hit rebuilt native image')
cache:beginFrame()
check(cache:draw(canvas,4,2,92,2,92,1,1,1,2),'translated visible geometry failed')
check(cache:draw(canvas,8,0,90,0,92,1,1,1,2),'new visible height failed')
local before=loads
check(cache:draw(canvas,10,2,92,2,92,1,1,1,2),'translation cache hit failed')
check(loads==before,'absolute screen position incorrectly part of cache key')
cache:beginFrame()
check(cache:draw(canvas,0,0,80,0,80,1,2,2,2),'canonical source initial draw failed')
before=loads
check(cache:draw(canvas,2,0,80,0,80,1,2,3,2),'identical source pattern lookup failed')
check(loads==before,'identical RLE patterns should share native strips')
cache:beginFrame()
check(cache:draw(canvas,-1,0,92,0,92,1,1,1,2),'left clipping failed')
check(canvas.last.x==0 and canvas.last.image.w==1,'left clipping dimensions')
check(cache:draw(canvas,159,0,92,0,92,1,1,1,2),'right clipping failed')
check(canvas.last.x==159 and canvas.last.image.w==1,'right clipping dimensions')
check(not cache:draw(canvas,0.5,0,92,0,92,1,1,1,2),'fractional coordinate accepted')
check(not cache:draw(canvas,0,0,92,0,92.5,1,1,1,2),'fractional projection accepted')
check(not cache:draw(canvas,160,0,92,0,92,1,1,1,2),'fully offscreen accepted')
check(not cache:draw(canvas,0,0,92,0,92,1,1,1,5),'oversized strip accepted')
cache:beginFrame()
local original=ui.load
ui.load=function() error('not enough memory') end
check(not cache:draw(canvas,0,0,92,0,100,1,1,1,2),'ui.load failure did not fall back')
ui.load=original
cache:beginFrame()
check(cache:draw(canvas,0,0,92,0,100,1,1,1,2),'load failure poisoned cache')
ui.load=nil
check(not cache:draw(canvas,0,0,92,0,100,1,1,1,2),'missing native API did not fall back')
print('surfaces_spec: '..checks..' exact RLE/crop, budget, bounded eviction and fallback checks passed')
