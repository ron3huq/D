-- FTF stall recorder (D companion). Standalone: run it alongside D.
-- Only observes. Never moves the avatar, presses keys, fires remotes or
-- uses HTTP. Records why/where the avatar stands still, paces back and
-- forth, or jitters, for long AFK sessions over many rounds.
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

local function writeLine(object)
    local ok, line = pcall(function() return Http:JSONEncode(clean(object)) end)
    if not ok then
        R.lastError = "encode: " .. tostring(line)
        return
    end
    line = line .. "\n"
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
local function flush()
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
        currentRound = mapName
        R.round = (R.round or 0) + 1
        writeLine({ k = "round", n = R.round, map = mapName, t = num(now, 2), utc = os.date("!%H:%M:%S") })
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
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 64)
frame.Position = UDim2.new(0, 8, 1, -150)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BackgroundTransparency = 0.25
frame.Active = true
frame.Draggable = true
frame.Parent = gui
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -60, 1, 0)
label.Position = UDim2.new(0, 6, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(235, 235, 235)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Center
label.TextWrapped = true
label.Font = Enum.Font.Code
label.TextSize = 11
label.Parent = frame
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 50, 0, 26)
button.Position = UDim2.new(1, -54, 0.5, -13)
button.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = "Stop"
button.Font = Enum.Font.GothamBold
button.TextSize = 12
button.Parent = frame

local function refreshLabel()
    local saved = R.lastSaveOk == nil and "..." or (R.lastSaveOk and "OK" or ("LOI: " .. tostring(R.lastError)))
    label.Text = ("REC %s  stall %d  pace %d  jitter %d\n%s  %.1f MB  luu: %s%s"):format(
        R.running and "ON" or "OFF",
        R.counts.stall or 0,
        R.counts.pacing or 0,
        R.counts.jitter or 0,
        fileName(),
        R.totalBytes / 1048576,
        saved,
        R.full and "  (DAY - het dung luong)" or ""
    )
end

function R.Stop()
    if not R.running then return end
    R.running = false
    writeLine({ k = "end", utc = os.date("!%H:%M:%S"), counts = R.counts })
    flush()
    for _, c in ipairs(R.connections) do pcall(function() c:Disconnect() end) end
    refreshLabel()
    button.Text = "Close"
end
button.MouseButton1Click:Connect(function()
    if R.running then R.Stop() else gui:Destroy() end
end)

-- Header + immediate save so the file exists right away.
writeLine({
    k = "header",
    schema = "d-stall-recorder",
    version = 1,
    utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    place = game.PlaceId,
    append = useAppend,
    hasWritefile = type(writefile) == "function",
    dHook = type(env.D_Snapshot) == "function",
    cfg = CFG,
})
flush()
if type(writefile) ~= "function" then
    R.lastSaveOk, R.lastError = false, "executor has no writefile"
end
print(("[DStallRecorder] ghi vao %s (appendfile=%s, D hook=%s)"):format(
    fileName(), tostring(useAppend), tostring(type(env.D_Snapshot) == "function")))

R.connections[#R.connections + 1] = Run.Heartbeat:Connect(function()
    local ok, err = pcall(step)
    if not ok then R.lastError = "step: " .. tostring(err) end
end)
task.spawn(function()
    while gui.Parent do
        pcall(refreshLabel)
        task.wait(0.5)
    end
end)
