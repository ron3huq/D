-- FTF AutoHop (standalone; D and the stall recorder do not need it).
-- On at load, active 10 s later. Changes server (a random public server
-- with room via the games API, else a plain rejoin) when
--   1) a round runs without us (joined mid-round, waiting in the lobby),
--   2) we were caught and are out while teammates are still playing,
--   3) we are the Beast.
-- After we escape, it waits while teammates are still in the round; it hops
-- only if every survivor left has stood still for over a minute.
-- Escaped players are not "out". Running it again restarts it;
-- getgenv().DAutoHop.Stop() stops it. A small on-screen button pauses /
-- resumes it (drag it anywhere); getgenv().DAutoHop.SetPaused(true/false)
-- does the same from code.

local Players = game:GetService("Players")
local World = game:GetService("Workspace")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer

local env = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end
if type(env.DAutoHop) == "table" and type(env.DAutoHop.Stop) == "function" then
    pcall(env.DAutoHop.Stop)
end

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
    return holder and holder:IsA("ObjectValue") and holder.Value or nil
end

local Hop = { active = true, paused = false, armedAt = os.clock() + 10, since = nil, nextTry = 0 }
local function lobbyBounds()
    local now = os.clock()
    if Hop.lobby and now - Hop.lobby.at < 5 then return Hop.lobby end
    local objects = World:FindFirstChild("LobbyInteractiveObjects")
    local lo, hi
    if objects then
        for _, part in ipairs(objects:GetDescendants()) do
            if part:IsA("BasePart") then
                local q = part.Position
                lo = lo and Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z)) or q
                hi = hi and Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z)) or q
            end
        end
    end
    Hop.lobby = { at = now, lo = lo, hi = hi }
    return Hop.lobby
end
local function inLobby(position)
    local b = lobbyBounds()
    if not b.lo then return false end
    local m = 180
    return position.X >= b.lo.X - m and position.X <= b.hi.X + m
        and position.Z >= b.lo.Z - m and position.Z <= b.hi.Z + m
        and position.Y >= b.lo.Y - 60 and position.Y <= b.hi.Y + 60
end
local function inRound(target, map)
    local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not root or inLobby(root.Position) then return false end
    local ok, cf, size = pcall(function() return map:GetBoundingBox() end)
    if not ok or not cf then return true end
    local d = root.Position - cf.Position
    local h = size / 2 + Vector3.new(40, 60, 40)
    return math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
end
-- Survivors still in the round, and how long each has stood still.
Hop.still = setmetatable({}, { __mode = "k" })
local function stillFor(p, root, now)
    local t = Hop.still[p]
    if not t or (root.Position - t.pos).Magnitude > 3 then
        t = { pos = root.Position, since = now }
        Hop.still[p] = t
    end
    return now - t.since
end
local function hopReason()
    local map = currentMap()
    if not map then return nil end
    if flag(player, "IsBeast") then return "beast" end
    if flag(player, "Escaped") then
        Hop.escapedMap = map
        return nil
    end
    if inRound(player, map) then return nil end
    local now = os.clock()
    -- We escaped this round: wait for teammates still in it (the round is
    -- nearly over). Only if every survivor left has stood still for over a
    -- minute (e.g. one player idling at the exit) do we hop.
    local escapedHere = Hop.escapedMap == map
    local left, idle = 0, 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and stats(p) and not flag(p, "IsBeast") and not flag(p, "Escaped") then
            local hp = stats(p):FindFirstChild("Health")
            local alive = not hp or type(hp.Value) ~= "number" or hp.Value > 0
            if alive and inRound(p, map) then
                if not escapedHere then return "round running without us" end
                left = left + 1
                local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if root and stillFor(p, root, now) > 60 then idle = idle + 1 end
            end
        end
    end
    if escapedHere and left > 0 and idle == left then return "teammates idle after our escape" end
    return nil
end
local function hopServers()
    local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
        .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
    local body
    pcall(function() body = game:HttpGet(url) end)
    if type(body) ~= "string" then
        local requester = (syn and syn.request) or (http and http.request) or http_request or request
        if type(requester) == "function" then
            pcall(function()
                local res = requester({ Url = url, Method = "GET" })
                body = res and res.Body
            end)
        end
    end
    local list = {}
    local ok, data = pcall(function() return Http:JSONDecode(body) end)
    if ok and type(data) == "table" and type(data.data) == "table" then
        for _, server in ipairs(data.data) do
            local playing, max = tonumber(server.playing), tonumber(server.maxPlayers)
            if server.id ~= game.JobId and playing and max and playing >= 2 and playing < max - 1 then
                list[#list + 1] = server.id
            end
        end
    end
    return list
end
local function hopGo(reason)
    local Teleport = game:GetService("TeleportService")
    print("[AutoHop] doi server: " .. tostring(reason))
    local servers = hopServers()
    if #servers > 0 then
        local id = servers[math.random(1, #servers)]
        if pcall(function() Teleport:TeleportToPlaceInstance(game.PlaceId, id, player) end) then return end
    end
    pcall(function() Teleport:Teleport(game.PlaceId, player) end)
end
task.spawn(function()
    while Hop.active do
        local now = os.clock()
        local ok, reason = pcall(hopReason)
        reason = ok and now >= Hop.armedAt and not Hop.paused and reason or nil
        if reason then
            Hop.since = Hop.since or now
            -- Held a moment so round start/end transitions do not trigger it.
            if now - Hop.since >= (reason == "beast" and 2 or 4) and now >= Hop.nextTry then
                Hop.nextTry = now + 10
                pcall(hopGo, reason)
            end
        else
            Hop.since = nil
        end
        task.wait(0.5)
    end
end)

-- Pause button: one small draggable button, green = running, grey = paused.
local function guiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then
        local test = Instance.new("Folder")
        if pcall(function() test.Parent = core end) then test:Destroy() return core end
        test:Destroy()
    end
    return player:WaitForChild("PlayerGui")
end
local gui = Instance.new("ScreenGui")
gui.Name = "DAutoHopGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
local button = Instance.new("TextButton")
button.Name = "Pause"
button.Size = UDim2.fromOffset(150, 34)
button.Position = UDim2.new(1, -170, 0, 120)
button.AutoButtonColor = true
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.TextColor3 = Color3.new(1, 1, 1)
button.Active = true
button.Draggable = true
button.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button
local function refresh()
    if Hop.paused then
        button.Text = "AutoHop: PAUSE"
        button.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
    else
        button.Text = "AutoHop: ON"
        button.BackgroundColor3 = Color3.fromRGB(40, 150, 70)
    end
end
function Hop.SetPaused(value)
    Hop.paused = value and true or false
    Hop.since = nil
    -- Resuming never hops at once: re-arm the short start delay.
    if not Hop.paused then Hop.armedAt = math.max(Hop.armedAt, os.clock() + 3) end
    refresh()
    print("[AutoHop] " .. (Hop.paused and "tam dung" or "chay lai"))
end
button.MouseButton1Click:Connect(function() Hop.SetPaused(not Hop.paused) end)
refresh()
pcall(function() gui.Parent = guiParent() end)
Hop.Gui = gui

function Hop.Stop()
    Hop.active = false
    pcall(function() gui:Destroy() end)
end
env.DAutoHop = Hop
print("[AutoHop] bat (hoat dong sau 10 giay)")
