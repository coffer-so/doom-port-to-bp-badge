-- SPDX-License-Identifier: GPL-2.0-or-later
local root=arg[1] or '.'
package.path=root..'/?.lua;'..package.path
local Sprites,Art=require('sprites'),require('art')
local checks,loads=0,0
local function check(value,why) checks=checks+1;assert(value,why) end
ui={load=function(rows,opts)
  loads=loads+1
  local w=#rows[1]
  for _,row in ipairs(rows) do assert(#row==w,'ragged image') end
  return {rows=rows,palette=opts.palette,w=w,h=#rows}
end}
local canvas={}
function canvas:image(image,x,y)
  assert(math.type(x)=='integer' and math.type(y)=='integer')
  assert(x>=0 and y>=0 and x+image.w<=160 and y+image.h<=92)
  self.last={image=image,x=x,y=y}
end
local cache=Sprites.new(Art,160,92)
local z={};for x=1,160 do z[x]=99 end
-- Independent inverse projection checks every visible pixel, including alpha,
-- sub-texel downsampling, extreme closeups and all four viewport boundaries.
for _,kind in ipairs({'enemy','chest','solana_coin','coffer_coin'}) do
  local src=Art[kind]
  local palette=Art.palettes[kind] or Art.palette
  for _,size in ipairs({{1,2},{3,7},{12,18},{24,36},{47,71},{160,92},{299,448}}) do
    local w,h=table.unpack(size)
    for _,position in ipairs({{0,0},{73,22},{-w//2,-h//2},{159,91}}) do
      local left,top=table.unpack(position)
      if left+w>0 and top+h>0 then
        cache:beginFrame()
        check(cache:draw(canvas,kind,left,top,w,h,1,z),'valid projection failed')
        local got=canvas.last
        for y=0,got.image.h-1 do for x=0,got.image.w-1 do
          local sx=math.ceil((got.x+x-left+1)*#src[1]/w)
          local sy=math.ceil((got.y+y-top+1)*#src/h)
          local symbol=src[sy]:sub(sx,sx)
          local expected=palette[symbol] or nil
          local stamped=got.image.rows[y+1]:sub(x+1,x+1)
          local actual=stamped~='.' and got.image.palette[stamped] or nil
          check(actual==expected,'pixel/alpha projection changed for '..kind)
        end end
        check(cache.count<=Sprites.LIMIT and cache.bytes<=Sprites.MAX_BYTES,'unbounded cache')
      end
    end
  end
end
cache=Sprites.new(Art,160,92);cache:beginFrame()
check(cache:draw(canvas,'enemy',20,0,24,36,1,z),'initial build')
local before=loads
check(cache:draw(canvas,'enemy',40,10,24,36,1,z),'translation should hit')
check(loads==before,'absolute position leaked into cache key')
check(not cache:draw(canvas,'enemy',20,0,25,37,1,z),'build budget exceeded')
z[30]=0.5
check(not cache:draw(canvas,'enemy',20,0,24,36,1,z),'stamp crossed a nearer wall')
z[30]=99
local alternate={};for k,v in pairs(Art.palette) do alternate[k]=v end
alternate.A=0xFF0000
cache:beginFrame()
check(cache:draw(canvas,'enemy',20,0,24,36,1,z,alternate),'alternate palette failed')
check(canvas.last.image.palette.A==0xFF0000,'stale palette image reused')
cache:beginFrame()
local original=ui.load;ui.load=function() error('out of memory') end
check(not cache:draw(canvas,'enemy',20,0,26,39,1,z),'load failure must fall back')
ui.load=original
cache:beginFrame()
check(cache:draw(canvas,'enemy',20,0,26,39,1,z),'failed build poisoned cache')
ui.load=nil
check(not cache:draw(canvas,'enemy',20,0,26,39,1,z),'missing image API must fall back')
print('sprites_spec: '..checks..' exact pixel/alpha/crop, occlusion, cache/budget and failure checks passed')
