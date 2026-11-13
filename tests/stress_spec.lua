-- SPDX-License-Identifier: GPL-2.0-or-later
-- Desktop stress harness. World sweeps retain conservative Lua UI mock costs;
-- crowd ticks count app VM only, plus the exact native canvas pixel charges.
local source = arg[1] or '.'
package.path = source .. '/?.lua;' .. package.path
local held, objects, native, instructions = {}, {}, 0, 0
local peak, peakLabel, over, frames = 0, '', 0, 0
local profileAppOnly=false
local function integer(n) assert(math.type(n)=='integer', 'non-integer canvas coordinate') end
local function charge(o,x,y,w,h)
    local x0,y0=math.max(0,x),math.max(0,y)
    local x1,y1=math.min(o.w,x+w),math.min(o.h,y+h)
    if x1>x0 and y1>y0 then native=native+(x1-x0)*(y1-y0)//16 end
end
local obj={}
function obj:text(s) assert(type(s)=='string' and #s<=200);self.value=s end
function obj:clear(_) charge(self,0,0,self.w,self.h) end
function obj:rect(x,y,w,h,color)
    integer(x);integer(y);integer(w);integer(h)
    assert(w>=0 and h>=0 and type(color)=='number')
    charge(self,x,y,w,h)
end
function obj:pixel(x,y,color) integer(x);integer(y);assert(type(color)=='number') end
function obj:image(img,x,y) integer(x);integer(y);charge(self,x,y,img.w,img.h) end
local function make(o) objects[#objects+1]=o;return setmetatable(o,{__index=obj}) end
ui={W=320,H=218}
function ui.bg(_) end
function ui.load(rows,_)
    assert(#rows>0 and #rows<=1024 and #rows[1]>0 and #rows[1]<=1024,'invalid native image size')
    for _,row in ipairs(rows) do assert(type(row)=='string' and #row==#rows[1],'ragged native image') end
    native=native+#rows[1]*#rows//16
    return {w=#rows[1],h=#rows}
end
function ui.clear() objects={} end
function ui.label(_,_,s,opts) return make({kind='label',value=s,opts=opts}) end
function ui.rect(_,_,w,h,_) return make({kind='rect',w=w,h=h}) end
function ui.image(_,_,path,_) return make({kind='image',path=path}) end
function ui.canvas(_,_,w,h,opts)
    assert(w*opts.scale<=ui.W and h*opts.scale<=ui.H)
    return make({kind='canvas',w=w,h=h})
end
sys={keys=function() return held end,millis=function() return 0 end}
local function upvalue(fn,name)
    for i=1,100 do
        local n,v=debug.getupvalue(fn,i)
        if not n then break end
        if n==name then return v end
    end
    error('missing upvalue '..name)
end
local function setvalue(fn,name,value)
    for i=1,100 do
        local n=debug.getupvalue(fn,i)
        if not n then break end
        if n==name then debug.setupvalue(fn,i,value);return end
    end
    error('missing upvalue '..name)
end
local function budget(label,fn,...)
    native,instructions=0,0
    if profileAppOnly then
        local inApp=false
        local mockSource=debug.getinfo(obj.rect,'S').source
        debug.sethook(function(event)
            if event=='count' then
                if inApp then instructions=instructions+1 end
            else
                local info=debug.getinfo(event=='return' and 3 or 2,'S')
                inApp=info~=nil and info.source~=mockSource and info.what~='C'
            end
        end,'cr',1)
    else
        debug.sethook(function() instructions=instructions+100 end,'',100)
    end
    local ok,err=pcall(fn,...)
    debug.sethook()
    assert(ok,label..': '..tostring(err))
    local total=instructions+native
    frames=frames+1
    if total>peak then peak,peakLabel=total,label end
    if total>=200000 then over=over+1 end
    assert(#objects<=64,'UI object count')
    return total
end
budget('load',assert(loadfile(source..'/main.lua')))
budget('rules',on_key,'select',false)
assert(upvalue(on_tick,'mode')=='mission','title SELECT must show rules before stress gameplay')
budget('start',on_key,'select',false)
local state=upvalue(on_tick,'state')
local render=upvalue(on_tick,'render')
local spawnX,spawnY=state.x,state.y
state.doorOpen=true
assert(#state.pickups==2 and #state.props==1 and state.props[1]==state.chest,
    'stress must use final two-coin/chest objective')
-- Every legal tile at sixteen angles, plus all legal near-wall/corner offsets.
local worldFrames=0
for y=1,state.height-2 do
    for x=1,state.width-2 do
        if state:tile(x,y)==0 then
            for _,ox in ipairs({0.19,0.5,0.81}) do
                for _,oy in ipairs({0.19,0.5,0.81}) do
                    state.x,state.y=x+ox,y+oy
                    if state:canStand(state.x,state.y) then
                        for a=0,15 do
                            state.angle=a*math.pi/8
                            budget(('world %.2f %.2f a%d'):format(state.x,state.y,a),render)
                            worldFrames=worldFrames+1
                        end
                    end
                end
            end
        end
    end
end
print('world stress: '..worldFrames..' renders; peak '..peak..' ('..peakLabel..')')
assert(over==0,'world sweep exceeds conservative budget')
local worldPeak=peak
peak,peakLabel,over=0,'',0
profileAppOnly=true
local poses={{spawnX,spawnY},{state.chest.x-1,state.chest.y}}
for _,coin in ipairs(state.pickups) do poses[#poses+1]={coin.x,coin.y} end
for _,enemy in ipairs(state.enemies) do poses[#poses+1]={enemy.x,enemy.y} end
local crowdedFrames=0
for _,p in ipairs(poses) do
    assert(state:canStand(p[1],p[2]),'stress pose must be a walkable point in current map')
    for a=0,15 do
        local angle=a*math.pi/8
        for _,depth in ipairs({0.17,0.20,0.25,0.4,0.6,1.0,1.5,2.0}) do
            state.x,state.y,state.angle=p[1],p[2],angle
            local ex,ey=state.x+depth*math.cos(angle),state.y+depth*math.sin(angle)
            if state:canStand(ex,ey,0.17) then
              for cluster=0,1 do
                -- Monsters have no mutual collision: this cluster can occur.
                for i,e in ipairs(state.enemies) do
                    local side=cluster==1 and (i-3.5)*0.035 or 0
                    local forward=cluster==1 and (i-1)*0.01 or 0
                    e.x=ex-side*math.sin(angle)+forward*math.cos(angle)
                    e.y=ey+side*math.cos(angle)+forward*math.sin(angle)
                    e.alive,e.hp,e.awake,e.attack=true,2,true,1000
                end
                state.hp,state.dead,state.won,state.ammo=100,false,false,99
                state.delivered,state.collected=false,0
                state.coins.solana,state.coins.coffer=false,false
                for _,coin in ipairs(state.pickups) do coin.taken=false end
                state._flowX=-1 -- Include an entire fresh pathfield this frame.
                state.flash,state.damageFlash,state.fireCooldown=0.1,0.2,0
                setvalue(on_tick,'fireFlash',0.2)
                setvalue(on_tick,'hurtFlash',0.2)
                setvalue(on_tick,'skipRenderTick',false)
                budget(('crowd %.2f %.2f a%d d%.2f c%d'):format(state.x,state.y,a,depth,cluster),on_tick,100)
                crowdedFrames=crowdedFrames+1
              end
            end
        end
    end
end
print('crowd stress: '..crowdedFrames..' full ticks incl fresh flow + 6 overlapping/staggered enemies')
print('crowd app VM + native canvas peak: '..peak..' / 200000 ('..peakLabel..'); frames over: '..over)
print('maximum bounded callback cost: '..math.max(worldPeak,peak)..' / 200000')
assert(over==0,'app callback exceeds 200000-instruction budget')
