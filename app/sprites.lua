-- SPDX-License-Identifier: GPL-2.0-or-later
-- Exact projected sprite stamps. Partially wall-hidden sprites retain the RLE path.
local M={LIMIT=32,MAX_BYTES=256*1024,BUILDS_PER_FRAME=1}
local Cache={};Cache.__index=Cache
local floor,min,max=math.floor,math.min,math.max
function M.new(art,w,h)
  return setmetatable({art=art,w=w,h=h,entries={},slots={},hand=1,count=0,bytes=0,
    builds=0,hits=0,misses=0,failures=0},Cache)
end
function Cache:beginFrame() self.builds=0 end
function Cache:remove(index)
  local e=self.slots[index]
  if e then
    self.entries[e.key]=nil;self.slots[index]=nil
    self.count=self.count-1;self.bytes=self.bytes-e.bytes
  end
end
function Cache:draw(canvas,kind,left,top,width,height,depth,z,override)
  if not ui or type(ui.load)~='function' or width<=0 or height<=0 then return false end
  local x0,y0=max(0,left),max(0,top)
  local x1,y1=min(self.w,left+width),min(self.h,top+height)
  if x1<=x0 or y1<=y0 then return false end
  -- A conservative whole-billboard test: transparent source columns may cause
  -- a harmless fallback, but a stamp can never paint across a nearer wall.
  for x=x0,x1-1 do if depth>=(z[x+1] or 99) then return false end end
  local source=self.art[kind]
  if not source then return false end
  local palette=override or (self.art.palettes and self.art.palettes[kind]) or self.art.palette
  local cx,cy,cw,ch=x0-left,y0-top,x1-x0,y1-y0
  if cw*ch*2>M.MAX_BYTES then return false end
  local key=kind..':'..width..':'..height..':'..cx..':'..cy..':'..cw..':'..ch
  local old=self.entries[key]
  if old and old.source==source and old.palette==palette then
    self.hits=self.hits+1;canvas:image(old.image,x0,y0);return true
  end
  self.misses=self.misses+1
  if self.builds>=M.BUILDS_PER_FRAME then return false end
  self.builds=self.builds+1
  local rows,sw,sh={},#source[1],#source
  for sy=0,sh-1 do
    local a=max(cy,floor(sy*height/sh))
    local b=min(cy+ch,floor((sy+1)*height/sh))
    if b>a then
      local parts={}
      for sx=0,sw-1 do
        local l=max(cx,floor(sx*width/sw))
        local r=min(cx+cw,floor((sx+1)*width/sw))
        if r>l then
          local symbol=source[sy+1]:sub(sx+1,sx+1)
          if not palette[symbol] then symbol='.' end
          parts[#parts+1]=string.rep(symbol,r-l)
        end
      end
      local row=table.concat(parts)
      for y=a-cy+1,b-cy do rows[y]=row end
    end
  end
  local ok,image=pcall(ui.load,rows,{palette=palette})
  if not ok or not image then self.failures=self.failures+1;return false end
  if old then self:remove(old.slot) end
  local bytes=cw*ch*2
  while self.count>=M.LIMIT or self.bytes+bytes>M.MAX_BYTES do
    self:remove(self.hand);self.hand=self.hand%M.LIMIT+1
  end
  while self.slots[self.hand] do self.hand=self.hand%M.LIMIT+1 end
  local e={key=key,source=source,palette=palette,image=image,bytes=bytes,slot=self.hand}
  self.entries[key],self.slots[self.hand]=e,e
  self.hand=self.hand%M.LIMIT+1;self.count=self.count+1;self.bytes=self.bytes+bytes
  canvas:image(image,x0,y0)
  return true
end
return M
