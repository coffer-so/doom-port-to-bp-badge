-- SPDX-License-Identifier: GPL-2.0-or-later
-- Optional native RGB565 wall strips. Unsupported calls retain the RLE fallback.
local M = {LIMIT=256, BUILDS_PER_FRAME=4}
local Cache = {}
Cache.__index = Cache
local floor, min, max = math.floor, math.min, math.max
local kind, protected = type, pcall
local function integer(n) return kind(n)=='number' and n%1==0 end

function M.new(textures, width, height)
  assert(integer(width) and integer(height) and width>0 and height>0 and width<=1024 and height<=1024)
  local sources,patterns={},{}
  for _,shades in ipairs(textures) do for _,columns in ipairs(shades) do for _,runs in ipairs(columns) do
    local signature=table.concat(runs,':')
    local source=patterns[signature]
    if not source then source=runs;patterns[signature]=source end
    sources[runs]=source
  end end end
  return setmetatable({textures=textures,sources=sources,w=width,h=height,entries={},clock={},hand=1,
    count=0,builds=0,hits=0,misses=0,failures=0},Cache)
end

function Cache:beginFrame() self.builds=0 end

function Cache:draw(canvas,x,y0,y1,top,height,material,shade,texX,width)
  if not ui or kind(ui.load)~='function' or not canvas then return false end
  if kind(x)~='number' or kind(y0)~='number' or kind(y1)~='number' or kind(top)~='number'
    or kind(height)~='number' or kind(width)~='number' or height%1~=0 or width%1~=0
    or height<=0 or width<1 or width>4 then return false end
  local drawX=max(0,x)
  width=min(self.w,x+width)-drawX
  y0,y1=max(0,y0,top),min(self.h,y1,top+height)
  if width<=0 or y1<=y0 then return false end
  local offset,length=y0-top,y1-y0
  local shades=self.textures[material]
  local columns=shades and shades[shade]
  local runs=columns and columns[texX]
  if not runs then return false end
  runs=self.sources[runs] or runs
  -- The source RLE table identifies material/shade/texX without string hashing.
  -- Entire visible strips use a compact integer key, checked before arithmetic.
  local key=offset==0 and length==height and height<16384 and (height*4+width)
    or (width..':'..height..':'..offset..':'..length)
  local bucket=self.entries[runs]
  local entry=bucket and bucket[key]
  if entry then
    if x%1~=0 or y0%1~=0 then return false end
    entry.used=true;self.hits=self.hits+1
    canvas:image(entry.image,drawX,y0)
    return true
  end
  self.misses=self.misses+1
  if self.builds>=M.BUILDS_PER_FRAME then return false end
  if not (integer(x) and integer(y0) and integer(y1) and integer(top)) then return false end
  self.builds=self.builds+1
  local rows,palette,symbols={}, {}, {}
  local symbolCount=0
  for i=1,#runs,3 do
    local a=max(y0,top+floor(runs[i]*height/8))
    local b=min(y1,top+floor(runs[i+1]*height/8))
    if b>a then
      local color=runs[i+2]
      local row=symbols[color]
      if not row then
        symbolCount=symbolCount+1
        local symbol=string.char(96+symbolCount)
        row=string.rep(symbol,width)
        symbols[color],palette[symbol]=row,color
      end
      for y=a-y0+1,b-y0 do rows[y]=row end
    end
  end
  if #rows~=length then return false end
  local ok,image=protected(ui.load,rows,{palette=palette})
  if not ok or not image then self.failures=self.failures+1;return false end
  if not bucket then bucket={};self.entries[runs]=bucket end
  entry={key=key,bucket=bucket,image=image,used=true}
  if self.count<M.LIMIT then
    self.count=self.count+1;self.clock[self.count]=entry
  else
    -- Second-chance clock: bounded storage and amortized constant eviction.
    local index=self.hand
    while self.clock[index].used do
      self.clock[index].used=false;index=index%M.LIMIT+1
    end
    local old=self.clock[index]
    old.bucket[old.key]=nil
    self.clock[index]=entry;self.hand=index%M.LIMIT+1
  end
  bucket[key]=entry
  canvas:image(image,drawX,y0)
  return true
end

return M
