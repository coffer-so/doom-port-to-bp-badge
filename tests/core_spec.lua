-- SPDX-License-Identifier: GPL-2.0-or-later
-- Run from the package root: lua5.5 tests/core_spec.lua
local game = dofile((arg[1] or ".") .. "/game.lua")
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function fresh()
    local s = game.new()
    for i = 1, #s.enemies do s.enemies[i].alive = false end
    return s
end
local function enemy(x, y, hp)
    return {x=x, y=y, hp=hp or 2, alive=true, attack=0, hurt=0, awake=false}
end
local function path(s, sx, sy, ex, ey)
    local q, parent = {{sx,sy}}, {}
    local start = sy * s.width + sx + 1
    parent[start] = start
    local head = 1
    while head <= #q do
        local p = q[head]; head = head + 1
        if p[1] == ex and p[2] == ey then
            local result, idx = {}, ey * s.width + ex + 1
            while idx ~= start do
                table.insert(result, 1, {(idx - 1) % s.width, math.floor((idx - 1) / s.width)})
                idx = parent[idx]
            end
            return result
        end
        for _, delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local x, y = p[1] + delta[1], p[2] + delta[2]
            local idx = y * s.width + x + 1
            if s:tile(x, y) == 0 and not parent[idx] then
                parent[idx] = p[2] * s.width + p[1] + 1
                q[#q + 1] = {x,y}
            end
        end
    end
end
local function flood(s, sx, sy)
    local q, seen = {{sx,sy}}, {[sy*s.width+sx+1]=true}
    local head = 1
    while q[head] do
        local p=q[head];head=head+1
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local x,y=p[1]+d[1],p[2]+d[2]
            local id=y*s.width+x+1
            if s:tile(x,y)==0 and not seen[id] then
                seen[id]=true;q[#q+1]={x,y}
            end
        end
    end
    return seen,#q
end
local function turn(s, angle)
    for _=1,40 do
        local delta=(angle-s.angle+math.pi)%(2*math.pi)-math.pi
        if math.abs(delta)<1e-5 then return end
        s:update(math.min(0.05,math.abs(delta)/2.4),{left=delta<0,right=delta>0})
    end
    error('button turn failed')
end
local function walk(s, route)
    for _, cell in ipairs(route) do
        local tx, ty = cell[1] + 0.5, cell[2] + 0.5
        for _ = 1, 20 do
            local dx, dy = tx - s.x, ty - s.y
            local d = math.sqrt(dx*dx + dy*dy)
            if d < 0.001 then break end
            turn(s,math.atan(dy,dx))
            s:update(math.min(0.05, d / 2.05), {up=true})
        end
        check(math.abs(s.x - tx) < 0.001 and math.abs(s.y - ty) < 0.001,
            "route blocked at " .. tx .. "," .. ty)
    end
end


do
    local s=game.new()
    check(#s.map==31 and s.width==31 and s.height==31,"compact maze dimensions")
    check(s.width*s.height<0.75*36*36,"map area shrinks by at least a quarter")
    for y=0,s.height-1 do
        check(#s.map[y+1]==s.width,"map row width")
        check(s:tile(0,y)~=0 and s:tile(s.width-1,y)~=0,"closed horizontal border")
    end
    for x=0,s.width-1 do
        check(s:tile(x,0)~=0 and s:tile(x,s.height-1)~=0,"closed vertical border")
    end
    check(s:tile(-1,1)==1 and s:tile(s.width,1)==1,"outside solid")
    check(s.hp==100 and s.ammo==17 and #s.enemies==6,"seventeen starting shots and six zombies")
    check(#s.pickups==8 and s.pickups[1].kind=="solana_coin"
        and s.pickups[2].kind=="coffer_coin","exactly one coin of each kind")
    local kinds={}
    for _,p in ipairs(s.pickups) do kinds[p.kind]=(kinds[p.kind] or 0)+1 end
    check(kinds.solana_coin==1 and kinds.coffer_coin==1 and kinds.medkit==3 and kinds.ammo==3,
        "two objective coins plus three medkits and three ammo cases")
    check(#s.props==1 and s.props[1]==s.chest and s.chest.kind=="chest",
        "only decorative object is the delivery chest")
    check(not s.coins.solana and not s.coins.coffer and s.collected==0
        and not s.delivered and not s.won,"objective starts empty")
    check(#s.doors==2,"only two remaining doors")
    for _,d in ipairs(s.doors) do check(not d.locked and not d.open,"doors start unlocked and closed") end
    check(s:visible(s.x,s.y,s.chest.x,s.chest.y),"chest visible from starter room")
    for _,e in ipairs(s.enemies) do check(s:canStand(e.x,e.y),"zombie starts on floor") end
    for _,p in ipairs(s.pickups) do check(s:canStand(p.x,p.y),"coin starts on floor") end
    check(s:canStand(s.chest.x,s.chest.y),"chest starts on floor")
    for y=1,5 do for x=1,5 do check(s:tile(x,y)==0,"wide starter room without initial door") end end
    check(path(s,1,1,14,15)~=nil and path(s,1,1,27,27)~=nil,
        "both coins reachable with every door closed")
    local seen,reachable=flood(s,1,1)
    local floors=0
    for y=1,s.height-2 do for x=1,s.width-2 do
        if s:tile(x,y)==0 then
            floors=floors+1
            check(seen[y*s.width+x+1],"every floor cell connects with doors closed")
        end
    end end
    check(reachable==534 and floors==534,"every compact-maze floor remains connected")
    local broadRooms=0
    for r=0,4 do for c=0,4 do
        local x,y=3+c*6,3+r*6
        local broad=true
        for yy=y-2,y+2 do for xx=x-2,x+2 do
            if s:tile(xx,yy)~=0 then broad=false end
        end end
        if broad then broadRooms=broadRooms+1 end
    end end
    check(broadRooms==17 and broadRooms<0.75*23,"seventeen broad rooms is approximately a quarter fewer")
    local deadEnds=0
    for y=12,18 do for x=6,18 do
        if s:tile(x,y)==0 then
            local exits=0
            for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                if s:tile(x+d[1],y+d[2])==0 then exits=exits+1 end
            end
            if exits==1 then deadEnds=deadEnds+1 end
        end
    end end
    check(deadEnds==3,"thin maze has three genuine dead ends")
    for _,p in ipairs({{9,12},{13,14},{7,14},{9,16},{16,16},{15,18}}) do
        check(s:tile(p[1],p[2])==0 and s:tile(p[1]-1,p[2])~=0
            and s:tile(p[1]+1,p[2])~=0,"winding maze corridor is exactly one cell wide")
    end
    s.doorOpen,s.doors[2].open=true,true
    local _,opened=flood(s,1,1)
    check(opened==floors+2,"both optional doors connect without isolated passages")
end

-- Physical walk-through of the entire objective; no position teleports.
do
    local s=fresh()
    local first=assert(path(s,1,1,14,15))
    check(#first==27,"spawn to Solana coin enters winding maze")
    walk(s,first)
    check(s.coins.solana and not s.coins.coffer and s.collected==1,"walk collects Solana coin")
    check(not s.won and not s.delivered,"one coin does not complete game")
    local across=assert(path(s,14,15,27,27))
    check(#across==39,"maze coin and southeast coin occupy separate wings")
    check(s:visible(3.5,27.5,27.5,27.5),"south gallery retains a long navigation sightline")
    walk(s,across)
    check(s.coins.solana and s.coins.coffer and s.collected==2,"walk collects Coffer coin")
    check(s.pickups[1].taken and s.pickups[2].taken,"both world coins disappear once collected")
    check(not s.won and not s.delivered,"two coins alone do not complete game")
    local back=assert(path(s,27,27,4,2))
    check(#back==50 and #first+#across+#back==116,"whole objective route is 116 grid steps")
    walk(s,back)
    check(not s.won,"returning to chest does not auto-deposit")
    check(not s.doors[1].open and not s.doors[2].open,"entire objective needs no door interaction")
    turn(s,0)
    check(s:use()=="deposit" and s.delivered and s.won,"CANCEL interaction deliberately deposits both coins")
    check(s.collected==2,"deposit preserves exact collection count")
    local x,hp,ammo=s.x,s.hp,s.ammo
    s:update(0.1,{up=true})
    check(s.x==x and s.hp==hp and s.ammo==ammo and s:fire()==nil and s:use()==nil,
        "completed delivery freezes game and cannot duplicate deposit")
end

-- Buttons navigate every winding section and visit each one-cell dead end.
do
    local s=fresh()
    walk(s,assert(path(s,1,1,9,12)))
    walk(s,{{9,13},{10,13},{11,13},{12,13},{13,13},{13,12}})
    walk(s,{{13,13},{13,14},{13,15},{14,15}})
    check(s.coins.solana,"Solana coin requires entering a narrow dead end")
    walk(s,{{13,15},{12,15},{11,15},{10,15},{9,15},{9,16},{9,17},
        {8,17},{7,17},{7,16},{7,15},{7,14},{7,13}})
    walk(s,{{7,14},{7,15},{6,15},{5,15}})
    check(s:canStand(s.x,s.y),"thin-maze branches allow a physical return to the broad rooms")
end

do
    local s=fresh()
    s.x,s.y,s.angle=4.5,2.5,0
    check(s:use()=="missing" and not s.delivered and not s.won,"empty inventory cannot deposit")
    for _,name in ipairs({"solana","coffer"}) do
        s.coins.solana,s.coins.coffer=name=="solana",name=="coffer"
        s.collected=1
        check(s:use()=="missing" and not s.won,"either missing coin prevents deposit")
    end
    s.coins.solana,s.coins.coffer,s.collected=true,true,2
    s.angle=math.pi
    check(s:use()==nil,"deposit requires facing chest")
    s.x,s.y,s.angle=1.5,1.5,0
    check(s:use()==nil,"deposit requires proximity")
    s.x,s.y,s.angle=4.5,2.5,0
    s:update(0.1)
    check(not s.won,"waiting near chest cannot deposit")
    s:fire()
    check(not s.won and not s.delivered,"SELECT fires instead of depositing")
end

do
    local s=fresh()
    s.hp,s.ammo=73,23
    s.x,s.y=s.pickups[1].x,s.pickups[1].y
    for _=1,20 do s:update(0.05) end
    check(s.collected==1 and s.coins.solana and s.pickups[1].taken,"coin cannot collect repeatedly")
    check(s.hp==73 and s.ammo==23,"coins do not heal or add ammunition")
    s.x,s.y=s.pickups[2].x,s.pickups[2].y
    s:update(0.05)
    s.x,s.y=s.pickups[1].x,s.pickups[1].y
    s:update(0.05)
    check(s.collected==2 and s.coins.coffer,"revisiting coin cannot exceed two")
end

-- Supplies replenish combat resources without changing the coin mission.
do
    local s=fresh()
    for _,p in ipairs(s.pickups) do
        if p.kind=="medkit" then
            s.x,s.y,s.hp=p.x,p.y,50
            local ammo=s.ammo
            s:update(0.05)
            check(p.taken and s.hp==75 and s.ammo==ammo,"each medkit restores twenty-five health only")
            check(s.message=="MEDKIT +25 HP","medkit reports the actual recovery")
        elseif p.kind=="ammo" then
            s.x,s.y,s.ammo=p.x,p.y,17
            local hp=s.hp
            s:update(0.05)
            check(p.taken and s.ammo==25 and s.hp==hp,"each ammo case restores eight rounds only")
            check(s.message=="AMMO +8","ammo case reports rounds collected")
        end
    end
    check(s.collected==0 and not s.coins.solana and not s.coins.coffer
        and not s.pickups[1].taken and not s.pickups[2].taken and not s.won,
        "all six supplies leave the two-coin objective untouched")
end

do
    local s=fresh();local p=s.pickups[3]
    check(p.kind=="medkit","health-cap fixture is a real medkit")
    s.x,s.y=p.x,p.y
    for _=1,10 do s:update(0.05) end
    check(s.hp==100 and not p.taken,"full health never wastes an unneeded medkit")
    s.hp=90;s:update(0.05)
    check(s.hp==100 and p.taken and s.message=="MEDKIT +10 HP","partial medkit gain caps at one hundred")
    s.hp=60;s:update(0.05)
    check(s.hp==60,"consumed medkit cannot heal twice")
    s=fresh();p=s.pickups[6]
    check(p.kind=="ammo","ammo-cap fixture is a real ammo case")
    s.x,s.y,s.ammo=p.x,p.y,99
    for _=1,10 do s:update(0.05) end
    check(s.ammo==99 and not p.taken,"full inventory never wastes an ammo case")
    s.ammo=97;s:update(0.05)
    check(s.ammo==99 and p.taken and s.message=="AMMO +2","partial ammo gain caps at ninety-nine")
    s.ammo=0;s:update(0.05)
    check(s.ammo==0,"consumed ammo case cannot refill twice")
    s=fresh();p=s.pickups[6]
    s.ammo=0
    check(s:fire()=="empty" and s.ammo==0,"empty firing cannot spend negative ammunition")
    s.x,s.y=p.x,p.y;s:update(0.05)
    check(s.ammo==8 and p.taken,"empty weapon can be refilled by walking into ammo")
    for _=1,4 do s:update(0.1) end
    check(s:fire()=="shot" and s.ammo==7,"refilled weapon can fire after its cooldown")
    s=fresh();p=s.pickups[3]
    s.x,s.y,s.hp,s.dead=p.x,p.y,0,true;s:update(0.1)
    check(s.hp==0 and not p.taken,"medkit cannot revive a dead player")
end

do
    local s=fresh();s.hp=50
    walk(s,assert(path(s,1,1,3,10)))
    check(s.hp==75 and s.pickups[3].taken,"physical movement collects a medkit automatically")
    walk(s,assert(path(s,3,10,9,4)))
    check(s.ammo==25 and s.pickups[6].taken,"physical movement collects an ammo case automatically")
    check(s.collected==0,"walking into supplies never fabricates a coin")
end

do
    local s=fresh()
    walk(s,assert(path(s,1,1,17,3)))
    turn(s,math.pi)
    check(s:use()==nil,"optional door requires facing it")
    turn(s,0)
    check(s:tile(18,3)==3 and not s:visible(17.5,3.5,19.5,3.5),"closed door blocks sight")
    check(s:use()=="door" and s:tile(18,3)==0,"optional door opens without key or coins")
    local version=s._doorsVersion
    walk(s,{{18,3},{19,3}})
    check(s._flowDoors==version,"opening door refreshes pursuit field")
    walk(s,assert(path(s,19,3,11,21)))
    turn(s,0)
    check(s:use()=="door" and s.doors[2].open,"second door operates independently")
    walk(s,{{12,21},{13,21}})
    check(s:tile(18,3)==0 and s:tile(12,21)==0,"opening second preserves first door")
    check(s.collected==0,"opening doors does not fabricate coins")
end

do
    local s=fresh();local door=s.doors[1]
    s.x,s.y,s.angle=17.5,3.5,0
    check(s:interactableDoor()==door,"door prompt identifies exact usable door")
    check(not door.open and s._doorsVersion==0,"door inspection has no side effects")
    check(not s:visible(s.x,s.y,18.5,3.5),"ordinary visibility still rejects closed-door target")
    s.angle=math.pi
    check(s:interactableDoor()==nil and s:use()==nil,"facing away disables prompt and opening")
    s.x,s.angle=16.89,0
    check(s:interactableDoor()==nil and s:use()==nil,"door outside 1.6-unit radius cannot open")
    s.x=16.91
    check(s:interactableDoor()==door,"door just inside interaction radius is eligible")
    s.x,s.y,s.angle=17.5,2.5,math.pi/4
    check(s:canStand(s.x,s.y),"occluded prompt fixture is a legal floor position")
    check(s:interactableDoor()==nil and s:use()==nil and not door.open,
        "corner wall blocks both prompt and opening")
    s.y,s.angle=2.4,math.atan(1.1,1)
    check(s:interactableDoor()==nil and s:use()==nil,"intervening adjacent wall blocks non-corner trace")
    s.x,s.y,s.angle=17.5,3.5,0
    s.dead=true
    check(s:interactableDoor()==nil,"dead player has no door interaction")
    s.dead,s.won=false,true
    check(s:interactableDoor()==nil,"won game has no door interaction")
    s.won=false
    check(s:use()=="door" and door.open,"eligible CANCEL actually opens same door")
    check(s:interactableDoor()==nil and s:use()==nil,"open door has neither prompt nor repeat interaction")
end

do
    local s=fresh()
    s.x,s.y,s.angle=5.5,2.5,0
    s.enemies={enemy(8.5,2.5)}
    check(not s:visible(s.x,s.y,8.5,2.5),"stone wall blocks sight")
    check(s:fire()=="shot" and s.enemies[1].hp==2,"stone wall blocks shots")
    s=fresh();s.x,s.y,s.angle=17.5,3.5,0
    s.enemies={enemy(19.5,3.5)}
    check(s:fire()=="shot","closed door blocks shots")
    s.fireCooldown=0;s:use()
    check(s:fire()=="hit" and s.enemies[1].hp==1,"open door allows shots")
    s=fresh();s.enemies={enemy(3.5,1.5),enemy(5.5,1.5)}
    check(s:fire()=="hit" and s.enemies[1].hp==1 and s.enemies[2].hp==2,
        "nearest visible zombie receives shot")
    local ammo=s.ammo
    check(s:fire()==nil and s.ammo==ammo,"cooldown prevents repeated shot")
    for _=1,4 do s:update(0.1) end
    check(s:fire()=="kill" and s.kills==1 and not s.enemies[1].alive,"second hit kills zombie")
    s.fireCooldown,s.ammo=0,0
    check(s:fire()=="empty" and s.ammo==0,"empty weapon never underflows")
end

do
    local s=fresh()
    for i=1,6 do
        s.enemies={enemy(3.5,1.5)}
        s.fireCooldown=0
        check(s:fire()=="hit","zombie takes first hit")
        for _=1,4 do s:update(0.1) end
        check(s:fire()=="kill","zombie can be killed")
    end
    check(s.kills==6 and s.ammo==5,"seventeen starting shots leave five after six clean kills")
    check(not s.won,"kills alone do not complete delivery objective")
end

do
    local s=fresh()
    s.angle=-math.pi/2
    for _=1,100 do s:update(0.1,{up=true}) end
    check(s.y>=1.18 and s.y<1.4,"wall collision stops player radius")
    s.x,s.y,s.angle=17.5,3.5,0
    for _=1,20 do s:update(0.1,{up=true}) end
    check(s.x<17.83,"closed door blocks movement")
    s:use()
    for _=1,10 do s:update(0.1,{up=true}) end
    check(s.x>19,"open door permits movement")
    s=fresh()
    local x,y,t=s.x,s.y,s.time
    for _,dt in ipairs({0,-1,0/0,-math.huge}) do s:update(dt,{up=true}) end
    s:update("bad",{up=true})
    check(s.x==x and s.y==y and s.time==t,"invalid dt does nothing")
    s:update(1000,{up=true})
    check(math.abs(s.x-x-0.205)<1e-5 and s.time==0.1,"long frame capped")
end

do
    local s=fresh();s.enemies={enemy(1.9,1.5)}
    s:update(1000)
    check(s.hp==85,"long frame causes only one fifteen-damage zombie attack")
    for _=1,11 do s:update(0.1) end
    check(s.hp==70,"attack cooldown limits fifteen-damage hits")
    s.hp,s.enemies[1].attack=15,0
    s:update(0.1)
    check(s.dead and s.hp==0,"zombie damage causes death")
    local x=s.x
    s.coins.solana,s.coins.coffer=true,true
    s.x,s.y,s.angle=4.5,2.5,0
    check(s:use()==nil and not s.delivered,"dead player cannot deposit")
    s:update(0.1,{up=true})
    check(s.x==4.5 and s:fire()==nil,"dead player cannot move or shoot")
end

do
    local s=fresh()
    s.x,s.y=3.5,5.5;s.enemies={enemy(8.5,10.5)};s.enemies[1].awake=true
    local e=s.enemies[1]
    check(not s:visible(e.x,e.y,s.x,s.y),"pursuit fixture has a corner")
    for _=1,500 do
        s:update(0.05)
        check(s:canStand(e.x,e.y,0.16),"zombie remains on floor")
        if s.hp<100 then break end
    end
    check(s.hp<100,"flowfield pursues player around wall")
    s=fresh();s.x,s.y=17.5,3.5;s.enemies={enemy(19.5,3.5)};s.enemies[1].awake=true
    for _=1,20 do s:update(0.05) end
    check(s.hp==100 and s.enemies[1].x>18.5,"zombie cannot cross or attack through closed door")
    s.angle=0;s:use()
    for _=1,200 do s:update(0.05) end
    check(s.hp<100 and s.enemies[1].x<18.5,"opening door refreshes zombie pursuit")
    s=fresh();s.x,s.y=14.5,15.5;s.enemies={enemy(6.5,15.5)}
    local mazeEnemy=s.enemies[1];mazeEnemy.awake=true
    check(not s:visible(mazeEnemy.x,mazeEnemy.y,s.x,s.y),"maze pursuit starts behind winding walls")
    for _=1,700 do
        s:update(0.05)
        check(s:canStand(mazeEnemy.x,mazeEnemy.y,0.16),"zombie stays inside thin winding corridor")
        if s.hp<100 then break end
    end
    check(s.hp<100,"zombie follows narrow maze bends into coin dead end")
end

-- Rebuilding the larger maze's field shares the callback with the renderer.
-- Sample every chamber with all six enemies active and both door states.
local flowPeak=0
do
    local s=game.new()
    for _,e in ipairs(s.enemies) do e.awake,e.attack=true,1000 end
    for _,open in ipairs({false,true}) do
        s.doorOpen=open;s.doors[2].open=open;s._doorsVersion=s._doorsVersion+1
        for r=0,4 do for c=0,4 do
            s.x,s.y=3.5+c*6,3.5+r*6
            if r==2 and c==2 then s.x=14.5 end
            s._flowX=-1
            local count=0
            debug.sethook(function()count=count+100 end,"",100)
            s:update(0.05)
            debug.sethook()
            flowPeak=math.max(flowPeak,count)
            check(count<75000,"fresh maze flow leaves at least 125k VM for rendering")
            check(s._dist[math.floor(s.y)*s.width+math.floor(s.x)+1]==0,"flow origin follows current room")
        end end
    end
end

print("core_spec: "..checks.." checks passed; fresh flow peak "..flowPeak.." / 75000 VM")
