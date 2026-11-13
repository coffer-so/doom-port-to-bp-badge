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
    check(#s.map==14 and s.width==14 and s.height==14,"compact map dimensions")
    for y=0,s.height-1 do
        check(#s.map[y+1]==s.width,"map row width")
        check(s:tile(0,y)~=0 and s:tile(s.width-1,y)~=0,"closed horizontal border")
    end
    for x=0,s.width-1 do
        check(s:tile(x,0)~=0 and s:tile(x,s.height-1)~=0,"closed vertical border")
    end
    check(s:tile(-1,1)==1 and s:tile(s.width,1)==1,"outside solid")
    check(s.hp==100 and s.ammo==99 and #s.enemies==6,"initial combat resources")
    check(#s.pickups==2 and s.pickups[1].kind=="solana_coin"
        and s.pickups[2].kind=="coffer_coin","exactly one coin of each kind")
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
    for y=1,3 do for x=1,9 do check(s:tile(x,y)==0,"wide starter room") end end
    check(path(s,1,1,2,10)~=nil and path(s,1,1,11,10)~=nil,
        "both coins reachable with every door closed")
    local reachable,floors=0,0
    for y=1,s.height-2 do for x=1,s.width-2 do
        if s:tile(x,y)==0 then
            floors=floors+1
            if path(s,1,1,x,y) then
                reachable=reachable+1
                local n=0
                for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                    if s:tile(x+d[1],y+d[2])==0 then n=n+1 end
                end
                check(n>=2,"main loop has no dead-end floor cells")
            end
        end
    end end
    check(reachable==108 and floors==112,"wide outer loop plus optional central passage")
    s.doorOpen,s.doors[2].open=true,true
    for y=1,s.height-2 do for x=1,s.width-2 do
        if s:tile(x,y)==0 then check(path(s,1,1,x,y)~=nil,"opened shortcut connects every floor cell") end
    end end
end

-- Physical walk-through of the entire objective; no position teleports.
do
    local s=fresh()
    local first=assert(path(s,1,1,2,10))
    check(#first==10,"spawn to Solana coin is ten grid steps")
    walk(s,first)
    check(s.coins.solana and not s.coins.coffer and s.collected==1,"walk collects Solana coin")
    check(not s.won and not s.delivered,"one coin does not complete game")
    local across=assert(path(s,2,10,11,10))
    check(#across==9,"coins share a direct nine-step floor")
    check(s:visible(2.5,10.5,11.5,10.5),"both coins visible along same open hall")
    walk(s,across)
    check(s.coins.solana and s.coins.coffer and s.collected==2,"walk collects Coffer coin")
    check(s.pickups[1].taken and s.pickups[2].taken,"both world coins disappear once collected")
    check(not s.won and not s.delivered,"two coins alone do not complete game")
    local back=assert(path(s,11,10,6,2))
    check(#back==13 and #first+#across+#back==32,"whole objective route is 32 grid steps")
    walk(s,back)
    check(not s.won,"returning to chest does not auto-deposit")
    check(not s.doors[1].open and not s.doors[2].open,"entire objective needs no door interaction")
    turn(s,math.pi)
    check(s:use()=="deposit" and s.delivered and s.won,"CANCEL interaction deliberately deposits both coins")
    check(s.collected==2,"deposit preserves exact collection count")
    local x,hp,ammo=s.x,s.hp,s.ammo
    s:update(0.1,{up=true})
    check(s.x==x and s.hp==hp and s.ammo==ammo and s:fire()==nil and s:use()==nil,
        "completed delivery freezes game and cannot duplicate deposit")
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

do
    local s=fresh()
    walk(s,assert(path(s,1,1,3,6)))
    turn(s,math.pi)
    check(s:use()==nil,"optional door requires facing it")
    turn(s,0)
    check(s:tile(4,6)==3 and not s:visible(3.5,6.5,5.5,6.5),"closed door blocks sight")
    check(s:use()=="door" and s:tile(4,6)==0,"optional door opens without key or coins")
    local version=s._doorsVersion
    walk(s,{{4,6},{5,6}})
    check(s._flowDoors==version,"opening door refreshes pursuit field")
    walk(s,{{6,6},{7,6},{8,6}})
    turn(s,0)
    check(s:use()=="door" and s.doors[2].open,"second door operates independently")
    walk(s,{{9,6},{10,6}})
    check(s:tile(4,6)==0 and s:tile(9,6)==0,"opening second preserves first door")
    check(s.collected==0,"opening doors does not fabricate coins")
end

do
    local s=fresh()
    s.x,s.y,s.angle=5.5,3.5,math.pi/2
    s.enemies={enemy(5.5,10.5)}
    check(not s:visible(s.x,s.y,5.5,10.5),"stone wall blocks sight")
    check(s:fire()=="shot" and s.enemies[1].hp==2,"stone wall blocks shots")
    s=fresh();s.x,s.y,s.angle=3.5,6.5,0
    s.enemies={enemy(5.5,6.5)}
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
    check(s.kills==6 and s.ammo==87,"starting ammo covers all six zombies with reserve")
    check(not s.won,"kills alone do not complete delivery objective")
end

do
    local s=fresh()
    s.angle=-math.pi/2
    for _=1,100 do s:update(0.1,{up=true}) end
    check(s.y>=1.18 and s.y<1.4,"wall collision stops player radius")
    s.x,s.y,s.angle=3.5,6.5,0
    for _=1,20 do s:update(0.1,{up=true}) end
    check(s.x<3.83,"closed door blocks movement")
    s:use()
    for _=1,10 do s:update(0.1,{up=true}) end
    check(s.x>5,"open door permits movement")
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
    check(s.hp==92,"long frame causes only one zombie attack")
    for _=1,11 do s:update(0.1) end
    check(s.hp==84,"attack cooldown limits damage")
    s.hp,s.enemies[1].attack=8,0
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
    s.x,s.y=3.5,7.5;s.enemies={enemy(5.5,10.5)};s.enemies[1].awake=true
    local e=s.enemies[1]
    check(not s:visible(e.x,e.y,s.x,s.y),"pursuit fixture has a corner")
    for _=1,300 do
        s:update(0.05)
        check(s:canStand(e.x,e.y,0.16),"zombie remains on floor")
        if s.hp<100 then break end
    end
    check(s.hp<100,"flowfield pursues player around wall")
    s=fresh();s.x,s.y=3.5,6.5;s.enemies={enemy(5.5,6.5)};s.enemies[1].awake=true
    for _=1,100 do s:update(0.05) end
    check(s.hp==100 and s.enemies[1].x>4.5,"zombie cannot cross or attack through closed door")
    s.angle=0;s:use()
    for _=1,100 do s:update(0.05) end
    check(s.hp<100 and s.enemies[1].x<4.5,"opening door refreshes zombie pursuit")
end

print("core_spec: "..checks.." checks passed")
