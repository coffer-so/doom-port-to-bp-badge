-- SPDX-License-Identifier: GPL-2.0-or-later
-- Original 16x8 techbase panels, prelit and run-length encoded per column.
local base = {
  {0xB5B5A6,0x969B8D,0x798171,0x5C6858,0x424F42,0x2F3C30,0x202C23},
  {0xA1A183,0x818A6B,0x646F53,0x4B583F,0x354630,0x263625,0x1A281B},
  {0xB1946D,0x94764F,0x73583B,0x57412D,0x403123,0x2D251D,0x211D18},
}
local out={}
for material=1,3 do
  out[material]={}
  for shade=1,5 do
    local columns={};out[material][shade]=columns
    for x=0,15 do
      local runs,last,start={},nil,0
      for y=0,8 do
        local tone=shade
        if material==1 then
          -- Broad gray metal plates with recessed borders and paired rivets.
          if x==0 or x==15 then tone=shade+2
          elseif x==1 or x==2 then tone=shade-1
          elseif x==14 or y==0 or y==7 then tone=shade+1
          elseif (x==3 or x==13) and (y==1 or y==6) then tone=shade-1 end
        elseif material==2 then
          -- Olive ribbed steel: continuous grooves are cheap vertical runs.
          if x%4==0 then tone=shade+2
          elseif x%4==1 then tone=shade-1
          elseif y==0 or y==7 then tone=shade+1 end
        else
          -- Brown industrial door leaves, central seam, frame and hinges.
          if x==0 or x==7 or x==8 or x==15 then tone=shade+2
          elseif x==1 or x==9 then tone=shade-1
          elseif x==6 or x==14 or y==0 or y==7 then tone=shade+1
          elseif (x==4 or x==12) and (y==3 or y==4) then tone=shade+1 end
        end
        local color=y<8 and base[material][math.max(1,math.min(7,tone))] or -1
        if color~=last then
          if last then runs[#runs+1]=start;runs[#runs+1]=y;runs[#runs+1]=last end
          start,last=y,color
        end
      end
      columns[x+1]=runs
    end
  end
end
return out
