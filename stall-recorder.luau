-- FTF stall recorder (D companion). Standalone: run it alongside D.
-- The recorder only observes: it never moves the avatar, presses keys or
-- fires remotes. Records why/where the avatar stands still, paces back and
-- forth, or jitters, for long AFK sessions over many rounds.
--
-- AutoHop is a separate script (autohop.luau). The Stop button ends recording.
--
-- Output (executor Workspace root, no subfolder):
--   D_stall_<date>_<time>_p<part>.txt  — JSON Lines (one JSON object per line)
-- With appendfile the current part grows by appending; otherwise each part
-- is rewritten and a new part starts at ~3 MB. Total cap: MAX_TOTAL_MB.
-- If D (with its read-only snapshot hook) is running, its internal movement
-- state (owner, aim, route mode, refused moves...) is added to each sample.

local Players = game:GetService("Players")
local World = game:GetService("Workspace")
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer

local env = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end
if type(env.DStallRecorder) == "table" and type(env.DStallRecorder.Stop) == "function" then
    pcall(env.DStallRecorder.Stop)
end

local CFG = {
    SAMPLE = 0.1, -- seconds between samples
    HISTORY = 30, -- samples kept before an incident (3 s)
    STILL_SPEED = 0.8, -- studs/s counted as standing
    STILL_TIME = 1.2, -- seconds standing before an incident
    PACE_WINDOW = 8, -- seconds; pacing = long travel, little net displacement
    PACE_TRAVEL = 24,
    PACE_NET = 6,
    JITTER_WINDOW = 3, -- seconds; jitter = many reversals, tiny net motion
    JITTER_REVERSALS = 4,
    JITTER_NET = 3,
    PART_BYTES = 3 * 1024 * 1024,
    MAX_TOTAL_MB = 200,
    SUMMARY_EVERY = 60, -- seconds between summary lines
}

local R = {
    running = true,
    samples = {},
    track = {},
    part = 1,
    partBytes = 0,
    totalBytes = 0,
    buffer = {},
    incidents = 0,
    counts = { stall = 0, pacing = 0, jitter = 0 },
    lastSaveOk = nil,
    lastError = nil,
    connections = {},
}
env.DStallRecorder = R

local stamp = os.date("!%Y%m%d_%H%M%S")
local useAppend = type(appendfile) == "function"
local function fileName() return ("D_stall_%s_p%d.txt"):format(stamp, R.part) end

-- JSON-safe numbers: nil for NaN/inf, rounded otherwise.
local function num(v, digits)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    local m = 10 ^ (digits or 1)
    return math.floor(v * m + 0.5) / m
end
local function vec(v) return v and { num(v.X), num(v.Y), num(v.Z) } or nil end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function clean(value, depth)
    depth = depth or 0
    local kind = typeof(value)
    if kind == "number" then return num(value, 3) end
    if kind == "string" or kind == "boolean" then return value end
    if kind == "Vector3" then return vec(value) end
    if kind == "EnumItem" then return value.Name end
    if kind == "Instance" then return value.Name end
    if kind == "table" and depth < 5 then
        local out, isArray = {}, #value > 0
        for k, v in pairs(value) do
            local c = clean(v, depth + 1)
            if c ~= nil then
                if isArray and type(k) == "number" then out[k] = c else out[tostring(k)] = c end
            end
        end
        return out
    end
    return nil
end

local function encode(object)
    local ok, line = pcall(function() return Http:JSONEncode(clean(object)) end)
    if not ok then
        R.lastError = "encode: " .. tostring(line)
        return nil
    end
    return line .. "\n"
end
-- Straight to the file (only ever used for rounds we actually played).
local function writeRaw(line)
    if not line then return end
    if R.totalBytes + #line > CFG.MAX_TOTAL_MB * 1024 * 1024 then
        R.full = true
        return
    end
    R.totalBytes = R.totalBytes + #line
    if useAppend then
        if R.partBytes + #line > CFG.PART_BYTES * 8 then
            R.part, R.partBytes = R.part + 1, 0
        end
        local exists = R.partBytes > 0
        local saved, err = pcall(function()
            if exists then appendfile(fileName(), line) else writefile(fileName(), line) end
        end)
        R.lastSaveOk, R.lastError = saved, saved and R.lastError or tostring(err)
        if saved then R.partBytes = R.partBytes + #line end
    else
        if R.partBytes + #line > CFG.PART_BYTES then
            R.part, R.partBytes, R.buffer = R.part + 1, 0, {}
        end
        R.buffer[#R.buffer + 1] = line
        R.partBytes = R.partBytes + #line
        R.dirty = true
    end
end
-- Everything is first kept for the current round only. It reaches the file
-- when that round ends and we really played it (in the map from its start,
-- 30 s+ inside); otherwise (AFK hops, joined mid-round, lobby only) it is
-- dropped and no file is written at all.
R.pending = {}
local function writeLine(object)
    local line = encode(object)
    if not line then return end
    local pend = R.pending
    pend[#pend + 1] = line
    if #pend > 120000 then table.remove(pend, 1) end
end
local flush
local function commitPending(meta)
    if not R.headerWritten and R.headerObj then
        writeRaw(encode(R.headerObj))
        R.headerWritten = true
    end
    for _, line in ipairs(R.pending) do writeRaw(line) end
    if meta then writeRaw(encode(meta)) end
    R.pending = {}
    R.savedRounds = (R.savedRounds or 0) + 1
    flush()
end
local function dropPending() R.pending = {} end
flush = function()
    if useAppend or not R.dirty then return end
    if type(writefile) ~= "function" then
        R.lastSaveOk, R.lastError = false, "executor has no writefile"
        return
    end
    local saved, err = pcall(writefile, fileName(), table.concat(R.buffer))
    R.lastSaveOk, R.lastError = saved, saved and nil or tostring(err)
    if saved then R.dirty = false end
end

-- ---------- game state readers ----------
local function stats(target)
    return target and target:FindFirstChild("TempPlayerStatsModule")
end
local function flag(target, name)
    local s = stats(target)
    local v = s and s:FindFirstChild(name)
    return v ~= nil and v.Value == true
end
local function currentMap()
    local holder = game:GetService("ReplicatedStorage"):FindFirstChild("CurrentMap")
    local map = holder and holder:IsA("ObjectValue") and holder.Value
    return map
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() rayParams.RespectCanCollide = true end)
local function refreshFilter()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then list[#list + 1] = p.Character end
    end
    rayParams.FilterDescendantsInstances = list
end
local function ray(origin, direction)
    local hit = World:Raycast(origin, direction, rayParams)
    if not hit then return nil end
    local part = hit.Instance
    local name = part.Name
    pcall(function()
        if part.Parent and part.Parent ~= World then name = part.Parent.Name .. "." .. name end
    end)
    return {
        part = name,
        d = num(hit.Distance, 2),
        n = vec(hit.Normal),
        size = part:IsA("BasePart") and vec(part.Size) or nil,
        collide = part:IsA("BasePart") and part.CanCollide or nil,
        trans = part:IsA("BasePart") and num(part.Transparency, 2) or nil,
    }
end
local function probe(root, hum, aim)
    refreshFilter()
    local hip = hum.HipHeight > 0 and hum.HipHeight or 2
    local feetY = root.Position.Y - hip - root.Size.Y / 2
    local look = flat(root.CFrame.LookVector)
    local toward = aim and flat(aim - root.Position)
    local base = toward and toward.Magnitude > 0.3 and toward.Unit or (look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1))
    local rays = {}
    for i = 0, 7 do
        local a = i * math.pi / 4
        local dir = base * math.cos(a) + Vector3.new(-base.Z, 0, base.X) * math.sin(a)
        local entry = { deg = i * 45 }
        for _, h in ipairs({ 0.4, 1.2, 3 }) do
            entry["h" .. h] = ray(Vector3.new(root.Position.X, feetY + h, root.Position.Z), dir * 6)
        end
        rays[#rays + 1] = entry
    end
    return {
        rays = rays,
        ground = ray(root.Position, Vector3.new(0, -8, 0)),
        ceiling = ray(root.Position, Vector3.new(0, 6, 0)),
        toAim = aim and ray(Vector3.new(root.Position.X, feetY + 1.5, root.Position.Z), flat(aim - root.Position)) or nil,
        feetY = num(feetY, 2),
    }
end
local function pods(map, from)
    local list = {}
    if not map then return list end
    for _, o in ipairs(map:GetChildren()) do
        if o.Name == "FreezePod" then
            local trig = o:FindFirstChild("PodTrigger", true)
            local torso = trig and trig:FindFirstChild("CapturedTorso")
            if trig and torso and torso:IsA("ObjectValue") and torso.Value then
                list[#list + 1] = {
                    p = vec(trig.Position),
                    d = num((trig.Position - from).Magnitude),
                    dy = num(trig.Position.Y - from.Y),
                    flat = num(flat(trig.Position - from).Magnitude),
                }
            end
        end
    end
    return list
end
local function beast(from)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and flag(p, "IsBeast") then
            local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local to = flat(from - r.Position)
                local look = flat(r.CFrame.LookVector)
                return {
                    d = num((r.Position - from).Magnitude),
                    dy = num(r.Position.Y - from.Y),
                    facing = to.Magnitude > 0.1 and look.Magnitude > 0.1 and num(look.Unit:Dot(to.Unit), 2) or nil,
                    v = num(flat(r.AssemblyLinearVelocity).Magnitude),
                }
            end
        end
    end
    return nil
end
local function dState()
    local hook = env.D_Snapshot
    if type(hook) ~= "function" then return nil end
    local ok, snapshot = pcall(hook)
    return ok and snapshot or nil
end

local function sample(now)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return nil end
    local wtp = hum.WalkToPoint
    local hasWalk = hum.WalkToPart ~= nil or (wtp - Vector3.zero).Magnitude > 0.01
    local okState, state = pcall(function() return hum:GetState().Name end)
    return {
        t = num(now, 2),
        p = vec(root.Position),
        v = num(flat(root.AssemblyLinearVelocity).Magnitude, 2),
        vy = num(root.AssemblyLinearVelocity.Y),
        vel = flat(root.AssemblyLinearVelocity),
        st = okState and state or "?",
        fl = hum.FloorMaterial.Name,
        md = num(hum.MoveDirection.Magnitude, 2),
        mdir = vec(hum.MoveDirection),
        walkTo = hasWalk and num(flat(wtp - root.Position).Magnitude, 2) or nil,
        walkToDY = hasWalk and num(wtp.Y - root.Position.Y) or nil,
        ws = num(hum.WalkSpeed),
        sit = hum.Sit or nil,
        cap = flag(player, "Captured") or nil,
        rag = flag(player, "Ragdoll") or nil,
        crawl = flag(player, "IsCrawling") or nil,
        hack = flag(player, "ActionInput") or nil,
        esc = flag(player, "Escaped") or nil,
        beast = flag(player, "IsBeast") or nil,
        d = dState(),
    }, root, hum
end

-- ---------- incidents ----------
local function recordIncident(kind, now, root, hum, extra)
    R.incidents = R.incidents + 1
    R.counts[kind] = (R.counts[kind] or 0) + 1
    local history = {}
    for i = math.max(1, #R.samples - CFG.HISTORY + 1), #R.samples do
        local s = R.samples[i]
        local copy = table.clone(s)
        copy.vel = nil
        history[#history + 1] = copy
    end
    local d = R.samples[#R.samples] and R.samples[#R.samples].d
    local aimDistance = d and d.aimDist
    local aim
    if hum and hum.WalkToPoint and (hum.WalkToPoint - Vector3.zero).Magnitude > 0.01 then aim = hum.WalkToPoint end
    local map = currentMap()
    local incident = {
        k = "incident",
        n = R.incidents,
        kind = kind,
        t = num(now, 2),
        utc = os.date("!%H:%M:%S"),
        map = map and map.Name or "lobby",
        round = R.round,
        pos = vec(root.Position),
        dReason = d and d.reason or nil,
        aimDist = aimDistance,
        probe = probe(root, hum, aim),
        pods = pods(map, root.Position),
        beast = beast(root.Position),
        history = history,
    }
    for k, v in pairs(extra or {}) do incident[k] = v end
    writeLine(incident)
    flush()
    return incident
end

-- ---------- map shape ----------
local KEYWORDS = { "door", "exit", "computer", "freezepod", "pod", "window", "stair", "step", "ramp",
    "ladder", "truss", "vent", "rail", "fence", "barrier", "clip", "table", "desk", "shelf", "crate", "box" }
local function kindOf(o)
    if o:IsA("TrussPart") then return "truss" end
    if o:IsA("WedgePart") or o:IsA("CornerWedgePart") then return "wedge" end
    local a = o
    for _ = 1, 3 do
        if not a then break end
        local name = string.lower(a.Name)
        for _, w in ipairs(KEYWORDS) do
            if string.find(name, w, 1, true) then return w end
        end
        a = a.Parent
    end
    return nil
end
-- Once per round: every notable part of the map (doors, exits, computers,
-- pods, windows, stairs, ramps, ladders, vents, rails, props), with its
-- position, size and facing, so the layout can be rebuilt offline.
function R.MapScan(map, round)
    task.spawn(function()
        local list, n = {}, 0
        local all = map:GetDescendants()
        for i, o in ipairs(all) do
            if not R.running or R.round ~= round then return end
            if o:IsA("BasePart") then
                local kind = kindOf(o)
                if kind then
                    n = n + 1
                    local parent = o.Parent and o.Parent.Name or ""
                    list[#list + 1] = { kind, parent .. "." .. o.Name, o.ClassName, vec(o.Position), vec(o.Size),
                        vec(o.CFrame.LookVector), o.CanCollide and 1 or 0, num(o.Transparency, 2) }
                    if #list >= 400 then
                        writeLine({ k = "mapParts", round = round, parts = list })
                        list = {}
                    end
                    if n >= 6000 then break end
                end
            end
            if i % 600 == 0 then task.wait() end
        end
        if #list > 0 then writeLine({ k = "mapParts", round = round, parts = list }) end
        local ok, cf, size = pcall(function() return map:GetBoundingBox() end)
        writeLine({ k = "mapBox", round = round, center = ok and vec(cf.Position) or nil,
            size = ok and vec(size) or nil, count = n })
    end)
end
local CELL_DIRS = 16
local CELL_HEIGHTS = { 0.5, 1.8, 3.5, 5.5 }
function R.CellScan(root, hum)
    local pos = root.Position
    local hip = hum.HipHeight > 0 and hum.HipHeight or 2
    local feetY = pos.Y - hip - root.Size.Y / 2
    local key = math.floor(pos.X / 6) .. ":" .. math.floor(pos.Z / 6) .. ":" .. math.floor(feetY / 5)
    R.cells = R.cells or {}
    if R.cells[key] then return end
    R.cells[key] = true
    refreshFilter()
    local function short(hit)
        if not hit then return nil end
        local part = hit.Instance
        local name = part.Name
        if part.Parent and part.Parent ~= World then name = part.Parent.Name .. "." .. name end
        return { num(hit.Distance, 1), name, num(hit.Normal.Y, 2), part.ClassName,
            part:IsA("BasePart") and vec(part.Size) or nil, kindOf(part) }
    end
    local rays = {}
    for i = 0, CELL_DIRS - 1 do
        local a = i * 2 * math.pi / CELL_DIRS
        local dir = Vector3.new(math.cos(a), 0, math.sin(a))
        local ring = {}
        for j, h in ipairs(CELL_HEIGHTS) do
            ring[j] = short(World:Raycast(Vector3.new(pos.X, feetY + h, pos.Z), dir * 16, rayParams)) or 0
        end
        -- Floor 3 studs out in this direction (drop / step / stair below?).
        local out = Vector3.new(pos.X, feetY + 2, pos.Z) + dir * 3
        local floor = World:Raycast(out, Vector3.new(0, -14, 0), rayParams)
        ring[#ring + 1] = floor and num(floor.Position.Y - feetY, 1) or -99
        rays[i + 1] = ring
    end
    writeLine({
        k = "cell",
        at = vec(Vector3.new(pos.X, feetY, pos.Z)),
        floor = short(World:Raycast(pos, Vector3.new(0, -8, 0), rayParams)),
        ceil = short(World:Raycast(pos, Vector3.new(0, 20, 0), rayParams)),
        rays = rays,
    })
end

local stillSince, stillIncident
local lastPace, lastJitter = -math.huge, -math.huge
local lastSample, lastSummary, lastFlush = 0, os.clock(), os.clock()
local currentRound

local function step()
    if not R.running then return end
    local now = os.clock()
    if now - lastSample < CFG.SAMPLE then return end
    lastSample = now
    local s, root, hum = sample(now)
    if not s then return end
    R.samples[#R.samples + 1] = s
    if #R.samples > CFG.HISTORY * 3 then table.remove(R.samples, 1) end

    -- Round / map tracking.
    local map = currentMap()
    local mapName = map and map.Name or "lobby"
    if mapName ~= currentRound then
        -- Close the previous round: keep it only if we really played it.
        local play = R.play
        if play and play.map ~= "lobby" then
            if play.fromStart and play.inMap >= 30 then
                commitPending({ k = "roundEnd", n = R.round, map = play.map, inMap = num(play.inMap),
                    escaped = play.escaped or nil, caught = play.caught or nil, t = num(now, 2) })
            else
                dropPending()
            end
        end
        local fromStart = map ~= nil and currentRound == "lobby"
        currentRound = mapName
        R.round = (R.round or 0) + 1
        R.play = { map = mapName, startAt = now, fromStart = fromStart, inMap = 0, box = nil }
        R.cells = {}
        writeLine({ k = "round", n = R.round, map = mapName, t = num(now, 2), utc = os.date("!%H:%M:%S"),
            fromStart = fromStart })
        if map then R.MapScan(map, R.round) end
    end
    -- Time actually spent inside the map this round (not in the lobby).
    local play = R.play
    if play and map then
        if not play.box then
            local ok, cf, size = pcall(function() return map:GetBoundingBox() end)
            play.box = ok and { cf = cf, half = size / 2 + Vector3.new(30, 50, 30) } or false
        end
        local inside = true
        if play.box then
            local d = play.box.cf:PointToObjectSpace(root.Position)
            local h = play.box.half
            inside = math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
        end
        -- Must be inside within the first 40 s (not joined/teleported late).
        if inside then
            play.firstInside = play.firstInside or now
            if play.firstInside - play.startAt <= 40 then play.inMap = play.inMap + CFG.SAMPLE end
        end
        if s.esc then play.escaped = true end
        if s.cap then play.caught = true end
    end
    -- Continuous trail (every sample) so the whole movement can be replayed:
    -- position, speed, input direction, state, floor; D's state every 0.5 s.
    R.trailD = R.trailD or 0
    local withD = now - R.trailD >= 0.5
    if withD then R.trailD = now end
    writeLine({ k = "s", t = s.t, p = s.p, v = s.v, vy = s.vy, st = s.st, fl = s.fl, mdir = s.mdir,
        ws = s.ws, look = vec(flat(root.CFrame.LookVector)), cap = s.cap, esc = s.esc, hack = s.hack,
        crawl = s.crawl, d = withD and s.d or nil })
    -- Map shape around where we go: every new 6x6 stud cell (per floor) gets
    -- a ring of rays at 4 heights, floor and ceiling.
    if map then R.CellScan(root, hum) end

    -- Beast state changes (to identify perk signals such as Seer).
    if now - (R.beastScanAt or 0) >= 1 then
        R.beastScanAt = now
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and flag(p, "IsBeast") then
                    local parts = {}
                    local st = stats(p)
                    for _, v in ipairs(st and st:GetChildren() or {}) do
                        local ok, value = pcall(function() return v.Value end)
                        if ok and (type(value) ~= "userdata") then parts[#parts + 1] = v.Name .. "=" .. tostring(value) end
                    end
                    for name, value in pairs(p.Character and p.Character:GetAttributes() or {}) do
                        parts[#parts + 1] = "@" .. name .. "=" .. tostring(value)
                    end
                    table.sort(parts)
                    local sig = table.concat(parts, ";")
                    if sig ~= R.beastSig then
                        R.beastSig = sig
                        writeLine({ k = "beastState", t = num(now, 2), state = sig })
                    end
                end
            end
        end)
    end
    -- Lobby scan (once per lobby phase): where are the map vote spots/buttons?
    if not map and R.lobbyScanned ~= R.round then
        R.lobbyScanned = R.round
        pcall(function()
            local found = {}
            local words = { "shopping", "prison", "zoo", "arctic", "arcade", "nuclear", "spaceship",
                "facility", "library", "airport", "mansion", "homestead", "vote", "map" }
            local function interesting(text)
                local t = string.lower(text or "")
                for _, w in ipairs(words) do if string.find(t, w, 1, true) then return true end end
                return false
            end
            for _, top in ipairs(World:GetChildren()) do
                if not Players:GetPlayerFromCharacter(top) then
                    for _, o in ipairs(top:GetDescendants()) do
                        if #found >= 120 then break end
                        if (o:IsA("TextLabel") or o:IsA("TextButton")) and interesting(o.Text) then
                            local gui = o:FindFirstAncestorWhichIsA("SurfaceGui") or o:FindFirstAncestorWhichIsA("BillboardGui")
                            local part = gui and (gui.Adornee or gui.Parent)
                            found[#found + 1] = { text = o.Text, path = o:GetFullName(),
                                pos = part and part:IsA("BasePart") and vec(part.Position) or nil }
                        elseif o:IsA("BasePart") and interesting(o.Name) then
                            found[#found + 1] = { part = o:GetFullName(), pos = vec(o.Position), size = vec(o.Size) }
                        end
                    end
                end
            end
            local pg = player:FindFirstChildOfClass("PlayerGui")
            for _, o in ipairs(pg and pg:GetDescendants() or {}) do
                if #found >= 160 then break end
                if (o:IsA("TextLabel") or o:IsA("TextButton")) and interesting(o.Text) then
                    found[#found + 1] = { gui = o:GetFullName(), text = o.Text, visible = o.Visible }
                end
            end
            writeLine({ k = "lobbyScan", round = R.round, t = num(now, 2), me = vec(root.Position), found = found })
        end)
    end

    local active = not (s.cap or s.rag or s.esc or s.sit)
    -- 1) Standing still.
    if active and s.v < CFG.STILL_SPEED and math.abs(s.vy or 0) < 2 then
        stillSince = stillSince or now
        if not stillIncident and now - stillSince >= CFG.STILL_TIME then
            stillIncident = recordIncident("stall", now, root, hum, {
                wantsToMove = (s.md or 0) > 0.1 or (s.walkTo or 0) > 1 or nil,
            })
        end
    else
        if stillIncident then
            writeLine({
                k = "resume",
                n = stillIncident.n,
                duration = num(now - stillSince, 2),
                t = num(now, 2),
                d = s.d,
            })
        end
        stillSince, stillIncident = nil, nil
    end

    -- 2) Pacing back and forth and 3) jitter.
    R.track[#R.track + 1] = { t = now, p = root.Position, vel = s.vel }
    while #R.track > 0 and now - R.track[1].t > CFG.PACE_WINDOW do table.remove(R.track, 1) end
    if active and #R.track > 10 then
        local travel = 0
        for i = 2, #R.track do travel = travel + flat(R.track[i].p - R.track[i - 1].p).Magnitude end
        local net = flat(R.track[#R.track].p - R.track[1].p).Magnitude
        if now - R.track[1].t >= CFG.PACE_WINDOW - 0.5 and travel >= CFG.PACE_TRAVEL and net <= CFG.PACE_NET
            and now - lastPace > CFG.PACE_WINDOW then
            lastPace = now
            recordIncident("pacing", now, root, hum, { travel = num(travel), net = num(net) })
        end
        local reversals, first = 0, nil
        local previous
        for i = #R.track, 1, -1 do
            local entry = R.track[i]
            if now - entry.t > CFG.JITTER_WINDOW then break end
            first = entry
            if entry.vel.Magnitude > 2 then
                if previous and previous.Unit:Dot(entry.vel.Unit) < -0.5 then reversals = reversals + 1 end
                previous = entry.vel
            end
        end
        local jitterNet = first and flat(root.Position - first.p).Magnitude or math.huge
        if reversals >= CFG.JITTER_REVERSALS and jitterNet <= CFG.JITTER_NET and now - lastJitter > CFG.JITTER_WINDOW then
            lastJitter = now
            recordIncident("jitter", now, root, hum, { reversals = reversals, net = num(jitterNet) })
        end
    end

    if now - lastSummary >= CFG.SUMMARY_EVERY then
        lastSummary = now
        writeLine({ k = "summary", t = num(now, 2), utc = os.date("!%H:%M:%S"), counts = R.counts, bytes = R.totalBytes, d = s.d })
    end
    if now - lastFlush >= 10 then
        lastFlush = now
        flush()
    end
end

-- ---------- status panel ----------
local guiParent
pcall(function() if type(gethui) == "function" then guiParent = gethui() end end)
if not guiParent then pcall(function() guiParent = game:GetService("CoreGui") end) end
if not guiParent then guiParent = player:WaitForChild("PlayerGui") end
local gui = Instance.new("ScreenGui")
gui.Name = "DStallRecorder"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = guiParent end)
if not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end
-- Compact: just one small "Stop" button (drag to move).
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 56, 0, 26)
button.Position = UDim2.new(0, 8, 1, -120)
button.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
button.BackgroundTransparency = 0.15
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = "Stop"
button.Font = Enum.Font.GothamBold
button.TextSize = 13
button.Active = true
button.Draggable = true
button.Parent = gui
pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
end)

function R.Stop()
    if not R.running then return end
    R.running = false
    local play = R.play
    if play and play.map ~= "lobby" and play.fromStart and play.inMap >= 30 then
        commitPending({ k = "end", utc = os.date("!%H:%M:%S"), counts = R.counts, partial = true })
    else
        dropPending()
    end
    flush()
    for _, c in ipairs(R.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end
button.MouseButton1Click:Connect(function()
    R.Stop()
    gui:Destroy()
end)

-- Header: written in front of the first round we really play.
R.headerObj = ({
    k = "header",
    schema = "d-stall-recorder",
    version = 2,
    utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    place = game.PlaceId,
    append = useAppend,
    hasWritefile = type(writefile) == "function",
    dHook = type(env.D_Snapshot) == "function",
    cfg = CFG,
})
if type(writefile) ~= "function" then
    R.lastSaveOk, R.lastError = false, "executor has no writefile"
end
print(("[DStallRecorder] chi luu tran thuc su choi -> %s (appendfile=%s, D hook=%s)"):format(
    fileName(), tostring(useAppend), tostring(type(env.D_Snapshot) == "function")))

R.connections[#R.connections + 1] = Run.Heartbeat:Connect(function()
    local ok, err = pcall(step)
    if not ok then R.lastError = "step: " .. tostring(err) end
end)
