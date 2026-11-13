-- SPDX-License-Identifier: GPL-2.0-or-later
-- Original, asset-free Doom-style simulation for the Solana badge Lua runtime.
-- Coordinates are zero-based world units; map rows are immutable strings.
local floor, sqrt, abs = math.floor, math.sqrt, math.abs
local sin, cos, min, max = math.sin, math.cos, math.min, math.max
local PI2 = math.pi * 2
local WIDTH, HEIGHT = 31, 31
-- Handcrafted room network: 17 broad chambers and two-cell corridors, plus a
-- central-west one-cell maze with three dead ends. Doors remain optional.
-- West wing uses stone; the east wing and central galleries use tech panels.
local MAP = {
    "1111111111111111111111111111111",
    "1000001000001000002000002222221",
    "1000001000001000002000002222221",
    "1000000000000000003000000000221",
    "1000000000000000002000000222221",
    "1000001000001000002000002222221",
    "1110011111111110022220022222221",
    "1000001000001110222000002000001",
    "1000001000001110222000002000001",
    "1000000000000000222000000000001",
    "1000000000000111222000000000001",
    "1000001000001111222000002000001",
    "1220022220222022222220022220021",
    "1000002020000022222000002000001",
    "1000002022222022222000002000001",
    "1000000020000002000000000000001",
    "1000002020222222022000000000001",
    "1000002000000000022000002000001",
    "1220022222222220222222222220021",
    "1110111000001000002222222000001",
    "1110111000001000002222222000001",
    "1110000000003000002220000000001",
    "1111110000001000002220220000001",
    "1111111000001000002220222000001",
    "1111111110011111222220022220021",
    "1111111000001111222000002000001",
    "1111111000001111222000002000001",
    "1110000000000000000000000000001",
    "1111110000000111220000000000001",
    "1111111000001111222000002000001",
    "1111111111111111111111111111111",
}
-- Keyed by flat map index. Lookup runs only on the two door cells.
local DOOR_AT = {[3 * WIDTH + 18 + 1]=1, [21 * WIDTH + 12 + 1]=2}
local State = {}
State.__index = State

-- 0 floor, 1 stone, 2 tech wall, 3 closed door; out-of-bounds is solid.
function State:tile(tx, ty)
    if tx < 0 or ty < 0 or tx >= WIDTH or ty >= HEIGHT then return 1 end
    local t = string.byte(MAP[ty + 1], tx + 1) - 48
    if t == 3 then
        local id = DOOR_AT[ty * WIDTH + tx + 1]
        local door = self.doors[id]
        -- Compatibility flag for the first door; both doors are unlocked.
        if door.open or (id == 1 and self.doorOpen) then return 0 end
    end
    return t
end

function State:canStand(x, y, radius)
    radius = radius or 0.18
    local l, r, t, b = floor(x - radius), floor(x + radius),
        floor(y - radius), floor(y + radius)
    return self:tile(l, t) == 0 and self:tile(r, t) == 0
        and self:tile(l, b) == 0 and self:tile(r, b) == 0
end

-- Exact grid DDA. Only door interaction may terminate on its closed door cell;
-- every intervening wall and corner still blocks the trace.
local function trace(self, x0, y0, x1, y1, targetDoor)
    local tx, ty, ex, ey = floor(x0), floor(y0), floor(x1), floor(y1)
    if self:tile(tx, ty) ~= 0 then return false end
    if self:tile(ex, ey) ~= 0 and not (targetDoor and targetDoor.x == ex
        and targetDoor.y == ey and self:tile(ex, ey) == 3) then return false end
    local dx, dy = x1 - x0, y1 - y0
    local sx, sy = dx < 0 and -1 or 1, dy < 0 and -1 or 1
    local ddx, ddy = dx == 0 and 1e30 or abs(1 / dx),
        dy == 0 and 1e30 or abs(1 / dy)
    local mx = (dx < 0 and x0 - tx or tx + 1 - x0) * ddx
    local my = (dy < 0 and y0 - ty or ty + 1 - y0) * ddy
    for _ = 1, WIDTH + HEIGHT do
        if tx == ex and ty == ey then return true end
        -- At a corner both adjacent cells must be open. This agrees with
        -- collision, which prevents both bullets and actors clipping corners.
        if abs(mx - my) < 1e-9 then
            if self:tile(tx + sx, ty) ~= 0 or self:tile(tx, ty + sy) ~= 0 then
                return false
            end
            tx, ty, mx, my = tx + sx, ty + sy, mx + ddx, my + ddy
        elseif mx < my then
            tx, mx = tx + sx, mx + ddx
        else
            ty, my = ty + sy, my + ddy
        end
        if (tx ~= ex or ty ~= ey) and self:tile(tx, ty) ~= 0 then return false end
    end
    return false
end

function State:visible(x0, y0, x1, y1)
    return trace(self, x0, y0, x1, y1)
end

local function move(self, actor, dx, dy, radius)
    local nx = actor.x + dx
    if self:canStand(nx, actor.y, radius) then actor.x = nx end
    local ny = actor.y + dy
    if self:canStand(actor.x, ny, radius) then actor.y = ny end
end

local function say(self, text)
    self.message, self.messageTime = text, 2
end

-- One reusable breadth-first flow field, shared by all monsters. No per-frame
-- path tables, random numbers, file I/O or original Doom assets are required.
local function rebuildFlow(self, px, py)
    local dist, queue = self._dist, self._queue
    for i = 1, WIDTH * HEIGHT do dist[i] = -1 end
    local start = py * WIDTH + px + 1
    local head, tail = 1, 1
    queue[1], dist[start] = start, 0
    while head <= tail do
        local idx = queue[head]
        head = head + 1
        local tx, ty = (idx - 1) % WIDTH, floor((idx - 1) / WIDTH)
        local nd = dist[idx] + 1
        if tx > 0 and dist[idx - 1] < 0 and self:tile(tx - 1, ty) == 0 then
            tail = tail + 1; queue[tail], dist[idx - 1] = idx - 1, nd
        end
        if tx < WIDTH - 1 and dist[idx + 1] < 0 and self:tile(tx + 1, ty) == 0 then
            tail = tail + 1; queue[tail], dist[idx + 1] = idx + 1, nd
        end
        if ty > 0 and dist[idx - WIDTH] < 0 and self:tile(tx, ty - 1) == 0 then
            tail = tail + 1; queue[tail], dist[idx - WIDTH] = idx - WIDTH, nd
        end
        if ty < HEIGHT - 1 and dist[idx + WIDTH] < 0 and self:tile(tx, ty + 1) == 0 then
            tail = tail + 1; queue[tail], dist[idx + WIDTH] = idx + WIDTH, nd
        end
    end
    self._flowX, self._flowY, self._flowDoor = px, py, self.doorOpen
    self._flowDoors = self._doorsVersion
end

function State:fire()
    if self.dead or self.won or self.fireCooldown > 0 then return nil end
    self.fireCooldown = 0.32
    if self.ammo <= 0 then say(self, "NO AMMO"); return "empty" end
    self.ammo, self.flash = self.ammo - 1, 0.1
    local ca, sa, nearest, best = cos(self.angle), sin(self.angle), nil, 144
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            local dx, dy = enemy.x - self.x, enemy.y - self.y
            local d2 = dx * dx + dy * dy
            local depth, side = dx * ca + dy * sa, abs(dy * ca - dx * sa)
            if depth > 0 and d2 < best and side <= 0.12 * depth + 0.16
                and self:visible(self.x, self.y, enemy.x, enemy.y) then
                nearest, best = enemy, d2
            end
        end
    end
    if nearest then
        nearest.hp, nearest.awake, nearest.hurt = nearest.hp - 1, true, 0.18
        if nearest.hp <= 0 then
            nearest.alive = false
            self.kills = self.kills + 1
            return "kill"
        end
        return "hit"
    end
    return "shot"
end

-- Shared by the HUD prompt and CANCEL; inspection never opens a door.
function State:interactableDoor()
    if self.dead or self.won then return nil end
    local nearest, best = nil, 2.56
    local ca, sa = cos(self.angle), sin(self.angle)
    for i = 1, #self.doors do
        local door = self.doors[i]
        if not door.open and not (i == 1 and self.doorOpen) then
            local dx, dy = door.x + 0.5 - self.x, door.y + 0.5 - self.y
            local d2 = dx * dx + dy * dy
            if d2 < best and dx * ca + dy * sa > 0.2
                and trace(self, self.x, self.y, door.x + 0.5, door.y + 0.5, door) then
                nearest, best = door, d2
            end
        end
    end
    return nearest
end

function State:use()
    if self.dead or self.won then return nil end
    local nearest = self:interactableDoor()
    if nearest then
        nearest.open = true
        if nearest == self.doors[1] then self.doorOpen = true end
        self._doorsVersion = self._doorsVersion + 1
        say(self, "DOOR OPEN")
        return "door"
    end
    local ca, sa = cos(self.angle), sin(self.angle)
    local dx, dy = self.chest.x - self.x, self.chest.y - self.y
    if dx * dx + dy * dy < 2.56 and dx * ca + dy * sa > 0.2
        and self:visible(self.x, self.y, self.chest.x, self.chest.y) then
        if not self.coins.solana or not self.coins.coffer then
            say(self, "FIND BOTH COINS")
            return "missing"
        end
        self.delivered, self.won = true, true
        say(self, "COINS DEPOSITED")
        return "deposit"
    end
    return nil
end

function State:update(dt, keys)
    if self.dead or self.won or type(dt) ~= "number" or dt ~= dt or dt <= 0 then return end
    dt = min(dt, 0.1) -- Suspended apps must not return to an instant death.
    keys = keys or self._noKeys
    self.time = self.time + dt
    self.fireCooldown = max(0, self.fireCooldown - dt)
    self.flash, self.damageFlash = max(0, self.flash - dt), max(0, self.damageFlash - dt)
    self.messageTime = max(0, self.messageTime - dt)
    local turn = (keys.right and 1 or 0) - (keys.left and 1 or 0)
    local walk = (keys.up and 1 or 0) - (keys.down and 1 or 0)
    self.angle = (self.angle + turn * dt * 2.4) % PI2
    if walk ~= 0 then
        local speed = walk * dt * 2.05
        move(self, self, cos(self.angle) * speed, sin(self.angle) * speed, 0.18)
    end
    for i = 1, #self.pickups do
        local pickup = self.pickups[i]
        if not pickup.taken then
            local dx, dy = pickup.x - self.x, pickup.y - self.y
            if dx * dx + dy * dy < 0.25 then
                if pickup.kind == "solana_coin" and not self.coins.solana then
                    self.coins.solana, pickup.taken = true, true
                    self.collected = self.collected + 1
                    say(self, "SOLANA COIN FOUND")
                elseif pickup.kind == "coffer_coin" and not self.coins.coffer then
                    self.coins.coffer, pickup.taken = true, true
                    self.collected = self.collected + 1
                    say(self, "COFFER COIN FOUND")
                elseif pickup.kind == "medkit" and self.hp < 100 then
                    local gain = min(25, 100 - self.hp)
                    self.hp, pickup.taken = self.hp + gain, true
                    say(self, "MEDKIT +" .. gain .. " HP")
                elseif pickup.kind == "ammo" and self.ammo < 99 then
                    local gain = min(8, 99 - self.ammo)
                    self.ammo, pickup.taken = self.ammo + gain, true
                    say(self, "AMMO +" .. gain)
                end
            end
        end
    end
    local px, py = floor(self.x), floor(self.y)
    if px ~= self._flowX or py ~= self._flowY or self.doorOpen ~= self._flowDoor
        or self._flowDoors ~= self._doorsVersion then
        rebuildFlow(self, px, py)
    end
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            enemy.hurt = max(0, enemy.hurt - dt)
            enemy.attack = max(0, enemy.attack - dt)
            local dx, dy = self.x - enemy.x, self.y - enemy.y
            local d2 = dx * dx + dy * dy
            local sight = d2 < 64 and self:visible(enemy.x, enemy.y, self.x, self.y)
            if sight then enemy.awake = true end
            if enemy.awake then
                if d2 < 0.49 and sight then
                    if enemy.attack == 0 then
                        enemy.attack = 1.0
                        self.hp, self.damageFlash = max(0, self.hp - 15), 0.18
                        if self.hp == 0 then self.dead = true; return end
                    end
                else
                    local tx, ty = floor(enemy.x), floor(enemy.y)
                    local idx = ty * WIDTH + tx + 1
                    local best, nx, ny = self._dist[idx], nil, nil
                    -- Aim at the next cell's center. Separate-axis collision
                    -- slides around a corner while keeping the body on floor.
                    if not sight and best and best > 0 then
                        if tx > 0 and self._dist[idx - 1] >= 0 and self._dist[idx - 1] < best then
                            best, nx, ny = self._dist[idx - 1], tx - 0.5, ty + 0.5
                        end
                        if tx < WIDTH - 1 and self._dist[idx + 1] >= 0 and self._dist[idx + 1] < best then
                            best, nx, ny = self._dist[idx + 1], tx + 1.5, ty + 0.5
                        end
                        if ty > 0 and self._dist[idx - WIDTH] >= 0 and self._dist[idx - WIDTH] < best then
                            best, nx, ny = self._dist[idx - WIDTH], tx + 0.5, ty - 0.5
                        end
                        if ty < HEIGHT - 1 and self._dist[idx + WIDTH] >= 0 and self._dist[idx + WIDTH] < best then
                            nx, ny = tx + 0.5, ty + 1.5
                        end
                        if nx then dx, dy = nx - enemy.x, ny - enemy.y else dx, dy = 0, 0 end
                    elseif not sight then
                        dx, dy = 0, 0
                    end
                    local length = sqrt(dx * dx + dy * dy)
                    if length > 0.01 then
                        local step = min(dt * 0.72, length) / length
                        move(self, enemy, dx * step, dy * step, 0.17)
                    end
                end
            end
        end
    end
end

local function new()
    local chest = {x=5.5, y=2.5, kind="chest"}
    return setmetatable({
        map = MAP, width = WIDTH, height = HEIGHT,
        x = 1.5, y = 1.5, angle = 0, hp = 100, ammo = 17,
        kills = 0, totalKills = 6, key = false, won = false, dead = false,
        doorX = 18, doorY = 3, doorOpen = false,
        coins = {solana=false, coffer=false}, collected = 0, delivered = false,
        chest = chest,
        doors = {
            {x=18, y=3, locked=false, open=false},
            {x=12, y=21, locked=false, open=false},
        },
        time = 0, fireCooldown = 0, flash = 0, damageFlash = 0,
        message = "FIND TWO COINS. RETURN TO CHEST.", messageTime = 3,
        enemies = {
            {x=9.5, y=3.5, hp=2, alive=true, attack=0, hurt=0, awake=false},
            {x=3.5, y=15.5, hp=2, alive=true, attack=0, hurt=0, awake=false},
            {x=9.5, y=26.5, hp=2, alive=true, attack=0, hurt=0, awake=false},
            {x=21.5, y=27.5, hp=2, alive=true, attack=0, hurt=0, awake=false},
            {x=27.5, y=15.5, hp=2, alive=true, attack=0, hurt=0, awake=false},
            {x=21.5, y=3.5, hp=2, alive=true, attack=0, hurt=0, awake=false},
        },
        pickups = {
            {x=14.5, y=15.5, kind="solana_coin", taken=false},
            {x=27.5, y=27.5, kind="coffer_coin", taken=false},
            {x=3.5, y=10.5, kind="medkit", taken=false},
            {x=10.5, y=20.5, kind="medkit", taken=false},
            {x=27.5, y=14.5, kind="medkit", taken=false},
            {x=9.5, y=4.5, kind="ammo", taken=false},
            {x=9.5, y=22.5, kind="ammo", taken=false},
            {x=26.5, y=21.5, kind="ammo", taken=false},
        },
        props = {chest},
        _dist = {}, _queue = {}, _noKeys = {},
        _flowX = -1, _flowY = -1, _flowDoor = false,
        _doorsVersion = 0, _flowDoors = -1,
    }, State)
end

return {new = new}
