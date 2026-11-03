-- A complete recorder run with observational Roblox APIs; no native game execution.
-- RECORDER_SOURCE
local checks = 0
local function check(value, message)
    checks += 1
    assert(value, message)
end
local Vec = {}
Vec.__index = function(v, k)
    if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
    if k == "Unit" then return v / v.Magnitude end
    return Vec[k]
end
function Vec.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec) end
function Vec:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
Vec.__add = function(a, b) return Vec.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vec.__sub = function(a, b) return Vec.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vec.__mul = function(a, n) return Vec.new(a.X * n, a.Y * n, a.Z * n) end
Vec.__div = function(a, n) return Vec.new(a.X / n, a.Y / n, a.Z / n) end
Vec.__unm = function(a) return a * -1 end
local function signal()
    local s = { listeners = {} }
    function s:Connect(callback)
        local conn = { Connected = true }
        function conn:Disconnect() self.Connected = false end
        self.listeners[#self.listeners + 1] = { conn = conn, callback = callback }
        return conn
    end
    function s:Fire(...)
        local snapshot = table.clone(self.listeners)
        for _, entry in ipairs(snapshot) do
            if entry.conn.Connected then entry.callback(...) end
        end
    end
    return s
end
local Enum = setmetatable({}, {
    __index = function(t, category)
        local group = setmetatable({}, {
            __index = function(g, key)
                local value = { Name = key }
                rawset(g, key, value)
                return value
            end,
        })
        rawset(t, category, group)
        return group
    end,
})
local nodes = {}
local Methods = {}
function Methods:IsA(class)
    if class == "ValueBase" then return self.ClassName:sub(-5) == "Value" end
    if class == "BasePart" then return self.ClassName == "Part" end
    if class == "GuiObject" then
        return self.ClassName == "Frame" or self.ClassName:sub(1, 4) == "Text" or self.ClassName == "ScrollingFrame"
    end
    return self.ClassName == class
end
function Methods:GetChildren()
    local children = {}
    for _, item in ipairs(nodes) do
        if item.Parent == self then children[#children + 1] = item end
    end
    return children
end
function Methods:FindFirstChild(name, recursive)
    for _, child in ipairs(self:GetChildren()) do
        if child.Name == name then return child end
    end
    if recursive then
        for _, child in ipairs(self:GetChildren()) do
            local found = child:FindFirstChild(name, true)
            if found then return found end
        end
    end
end
function Methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self:GetChildren()) do
        if child:IsA(class) then return child end
    end
end
function Methods:WaitForChild(name) return self:FindFirstChild(name) end
function Methods:IsDescendantOf(parent)
    local node = self.Parent
    while node do
        if node == parent then return true end
        node = node.Parent
    end
    return false
end
function Methods:GetPivot() return { Position = self.Position or Vec.new() } end
function Methods:GetState() return self.State or Enum.HumanoidStateType.Running end
function Methods:CaptureFocus() self.Focused = true end
local function node(class, name, parent)
    local item = setmetatable({
        ClassName = class,
        Name = name or class,
        Parent = parent,
        Visible = true,
        Text = "",
        AbsoluteSize = Vec.new(800, 600),
        Position = Vec.new(),
        Size = Vec.new(2, 2, 1),
        CanCollide = true,
        CFrame = { LookVector = Vec.new(1, 0, 0), UpVector = Vec.new(0, 1, 0) },
        Material = Enum.Material.Plastic,
        Color = { R = 0.5, G = 0.5, B = 0.5 },
        Transparency = 0,
        AssemblyLinearVelocity = Vec.new(),
        Activated = signal(),
        InputBegan = signal(),
        DescendantAdded = signal(),
        StateChanged = signal(),
    }, { __index = Methods })
    nodes[#nodes + 1] = item
    return item
end
local UDim2 =
    { new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end }
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
local now, rays, forbidden, writes = 0, 0, 0, {}
local blockLOS = false
local lowOnly, voidAhead = false, false
local World = node("Workspace", "Workspace")
local Storage = node("Folder", "ReplicatedStorage")
local map1 = node("Model", "Facility", World)
local map2 = node("Model", "School", World)
local current = node("ObjectValue", "CurrentMap", Storage)
current.Value = map1
local player = node("Player", "SecretPlayerName")
node("PlayerGui", "PlayerGui", player)
local folder = node("Folder", "TempPlayerStatsModule", player)
local typing = node("BoolValue", "IsTyping", folder)
typing.Value = false
local action = node("ObjectValue", "ActionEvent", folder)
local function avatar(owner)
    local char = node("Model", "SecretPlayerName", World)
    local hum = node("Humanoid", "Humanoid", char)
    hum.Health, hum.WalkSpeed, hum.JumpPower, hum.JumpHeight, hum.UseJumpPower, hum.HipHeight =
        100, 16, 50, 7.2, true, 2
    hum.MoveDirection, hum.FloorMaterial = Vec.new(1, 0, 0), Enum.Material.Plastic
    local root = node("Part", "HumanoidRootPart", char)
    root.Position = Vec.new(0, 3, 0)
    owner.Character = char
    return char, hum, root
end
local char, hum, root = avatar(player)
local other = node("Player", "SecretPlayerNameOther")
local otherChar, otherHum, otherRoot = avatar(other)
otherRoot.Position = Vec.new(8, 3, 0)
local otherStats = node("Folder", "TempPlayerStatsModule", other)
local beast = node("BoolValue", "IsBeast", otherStats)
beast.Value = true
local pc = node("Part", "ComputerTrigger1", map1)
pc.Position = Vec.new(8, 3, 0)
local pod = node("Part", "PodTrigger", map1)
pod.Position = Vec.new(5, 3, 0)
local torso = node("ObjectValue", "CapturedTorso", pod)
torso.Value = otherRoot
local stair = node("Part", "Stair", map1)
stair.Position = Vec.new(3, 0.2, 0)
local wall = node("Part", "WindowSill", map1)
local floor = node("Part", "Floor", map1)
local Run = { Heartbeat = signal() }
local Input = { JumpRequest = signal(), InputBegan = signal(), InputChanged = signal(), InputEnded = signal() }
function Input:GetFocusedTextBox() return self.Focus end
function World:Raycast(origin, direction, params)
    rays += 1
    check(#params.FilterDescendantsInstances == 2, "rays must exclude both avatars")
    if direction.Y < 0 then
        if voidAhead and origin.X > 4 then return nil end
        return {
            Instance = floor,
            Position = Vec.new(origin.X, 0, origin.Z),
            Normal = Vec.new(0, 1, 0),
            Distance = origin.Y,
        }
    elseif lowOnly and origin.Y == 2 and direction.Y == 0 then
        return nil
    elseif origin.Y == 3 and direction.Y == 0 and not blockLOS then
        return nil -- Unobstructed root-to-Beast line, independent of the low obstacle probes.
    elseif direction.X > 0 and direction.Y == 0 then
        return { Instance = wall, Position = origin + direction.Unit * 2, Normal = Vec.new(-1, 0, 0), Distance = 2 }
    end
end
local encoded = {}
local function escape(s)
    return '"'
        .. s:gsub('[%z\1-\31\\"]', function(c)
            if c == "\\" then return "\\\\" end
            if c == '"' then return '\\"' end
            return string.format("\\u%04x", string.byte(c))
        end)
        .. '"'
end
local function json(value)
    if type(value) == "string" then return escape(value) end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    if type(value) ~= "table" then error("unsupported JSON value") end
    local parts = {}
    if #value > 0 then
        for _, v in ipairs(value) do
            parts[#parts + 1] = json(v)
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        parts[#parts + 1] = escape(k) .. ":" .. json(value[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
local Http = {}
function Http:JSONEncode(value)
    local line = json(value)
    encoded[line] = value
    return line
end
local services = {
    Players = { LocalPlayer = player, GetPlayers = function() return { player, other } end },
    Workspace = World,
    ReplicatedStorage = Storage,
    RunService = Run,
    UserInputService = Input,
    HttpService = Http,
}
local game = { PlaceId = 893973440 }
function game:GetService(name)
    check(services[name] ~= nil, "recorder requested forbidden service: " .. name)
    return services[name]
end
local shared = {}
local environment = setmetatable({
    game = game,
    getgenv = function() return shared end,
    _G = shared,
    Enum = Enum,
    Vector3 = { new = Vec.new },
    Instance = { new = node },
    UDim2 = UDim2,
    UDim = { new = function(a, b) return { Scale = a, Offset = b } end },
    Color3 = { new = Vec.new, fromRGB = Vec.new },
    RaycastParams = { new = function() return {} end },
    os = { clock = function() return now end, date = os.date },
    writefile = function(path, data) writes[path] = data end,
    warn = function() end,
}, { __index = getfenv() })
for _, name in ipairs({ "keypress", "keyrelease", "firetouchinterest", "fireproximityprompt", "request" }) do
    environment[name] = function()
        forbidden += 1
        error("recorder attempted control/network: " .. name)
    end
end
local function execute()
    local chunk = assert(loadstring(SOURCE))
    setfenv(chunk, environment)
    chunk()
end
execute()
local api = assert(shared.FTFMovementRecorder)
local function click(text)
    for _, item in ipairs(nodes) do
        if item.ClassName == "TextButton" and item.Text == text then
            item.Activated:Fire()
            return
        end
    end
    error("missing button: " .. text)
end
local function advance(dt)
    now += dt
    root.Position += hum.MoveDirection * (hum.WalkSpeed * dt)
    Run.Heartbeat:Fire(dt)
end
local function records(payload)
    local list = {}
    for line in payload:gmatch("[^\n]+") do
        list[#list + 1] = assert(encoded[line], "non-JSONL export")
    end
    return list
end
local function collect(list, kind)
    local result = {}
    for _, item in ipairs(list) do
        if item.k == kind then result[#result + 1] = item end
    end
    return result
end
for _ = 1, 10 do
    advance(0.1)
end
check(rays == 0 and next(writes) == nil, "idle recorder must not scan or write")
root.Position = Vec.new(0, 3, 0)
click("Ghi")
for _ = 1, 20 do
    advance(0.1)
end
check(rays > 0 and rays <= 45, "context should use nine rays at at most 2 Hz, not per frame")
Input.JumpRequest:Fire()
hum.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping)
Input.JumpRequest:Fire() -- Holding the touch jump button must be coalesced.
advance(0.1)
Input.JumpRequest:Fire()
hum.State, hum.FloorMaterial, root.AssemblyLinearVelocity =
    Enum.HumanoidStateType.Freefall, Enum.Material.Air, Vec.new(16, -4, 0)
advance(0.1)
root.AssemblyLinearVelocity = Vec.new(16, 35, 0)
advance(0.1)
typing.Value = true
action.Value = pc
advance(0.1)
Input.Focus = {}
Input.InputBegan:Fire({ KeyCode = { Name = "E" } }, false)
Input.Focus = nil
Input.InputBegan:Fire({ KeyCode = { Name = "LeftShift" } }, false)
Input.InputEnded:Fire({ KeyCode = { Name = "LeftShift" } }, false)
local mark
for _, n in ipairs(nodes) do
    if n.ClassName == "TextBox" and n.PlaceholderText then mark = n end
end
mark.Text = "Cứu pod qua cửa sổ; beast ở phía sau"
click("Đánh dấu")
for _ = 1, 8 do
    advance(0.1)
end
advance(0.6)
typing.Value = false
action.Value = nil
current.Value = map2
advance(0.6)
char, hum, root = avatar(player)
advance(0.6)
player.Character = nil
advance(0.6)
player.Character = char
advance(0.6)
click("Dừng")
local rayAtStop = rays
advance(10)
check(rays == rayAtStop, "paused recorder continued querying geometry")
local path = api.Export()
check(path and writes[path], "file API must receive an explicit local export")
local first = records(writes[path])
local frames, segments, events, contexts =
    collect(first, "frame"), collect(first, "segment"), collect(first, "event"), collect(first, "context")
check(first[1].schema == "ftf-movement-observation", "missing versioned header")
check(frames[1].for_mode == "autohelp", "approaching occupied pod must automatically label AutoHelp")
check(frames[#frames].for_mode == "autohide", "near Beast must automatically label AutoHide")
local sawAutomaticFarm = false
for _, f in ipairs(frames) do
    if f.for_mode == "autofarm" then sawAutomaticFarm = true end
end
check(sawAutomaticFarm, "actual hacking must automatically label AutoFarm")
check(
    first[1].mode_labels == "inferred_from_observations_not_actual_bot_toggles",
    "inference must not claim actual bot-toggle knowledge"
)
check(#segments >= 5 and segments[1].map == "Facility", "map and respawn boundaries not segmented")
local sawSchool, sawUnavailable, sawJump, sawUpward, sawTyping, sawTarget, sawNote, shiftCount =
    false, false, 0, false, false, false, false, 0
for _, s in ipairs(segments) do
    if s.map == "School" then sawSchool = true end
end
for _, e in ipairs(events) do
    if e.name == "jump_request" then
        sawJump += 1
    end
    if e.name == "airborne_upward_change" then sawUpward = true end
    if e.name == "character_unavailable" then sawUnavailable = true end
    if e.name == "note" and e.data.text:find("Cứu", 1, true) then sawNote = true end
    if e.name == "key" then
        check(e.data.key ~= "E", "chat-focused key leaked")
        shiftCount += 1
    end
end
for _, f in ipairs(frames) do
    sawTyping = sawTyping or f.stats.IsTyping == true
    sawTarget = sawTarget or f.target ~= nil
    check(f.speed == 16 and f.jump_power == 50, "recorder changed or misreported movement properties")
end
check(sawSchool and sawUnavailable, "map/life transitions not recorded")
check(sawJump == 2 and sawUpward, "jump requests versus actual airborne impulse must stay distinguishable")
check(sawTyping and sawTarget and sawNote and shiftCount == 2, "interaction, notes or crawl-key evidence missing")
local sawPod, sawBeast = false, false
for _, c in ipairs(contexts) do
    for _, t in ipairs(c.nearby) do
        if t.kind == "pod" and t.occupied then sawPod = true end
    end
    for _, p in ipairs(c.others) do
        if p.beast then sawBeast = true end
    end
end
check(sawPod and sawBeast, "rescue/evade reference context missing")
local before = #Run.Heartbeat.listeners
execute()
check(#Run.Heartbeat.listeners == before, "re-executing duplicated recorders/listeners")
api.Start()
advance(0.1)
api.Stop()
local samePath = api.Export()
check(samePath == path and #writes[path] > #table.concat({}, ""), "resume/export lost session")
check(#collect(records(writes[path]), "frame") > #frames, "resumed samples missing from refreshed export")
for line in writes[path]:gmatch("[^\n]+") do
    print("EXPORT " .. line)
end
-- Unsupported file APIs keep the recording and present bounded, lossless text pages.
environment.writefile = function() return false end
api.Export()
local dataBox
for _, n in ipairs(nodes) do
    if n.Name == "Data" then dataBox = n end
end
check(dataBox and #dataBox.Text > 0 and #dataBox.Text <= 12000, "fallback text preview not bounded")
local copied
environment.setclipboard = function(s) copied = s end
click("Chép trang")
check(copied == dataBox.Text, "copy must use exactly the displayed text page")
click("×")
-- New session requires two explicit taps before discarding unexported data.
click("Phiên mới")
api.Export()
check(#dataBox.Text > 0, "first reset tap discarded data")
click("Phiên mới")
environment.writefile = function(path2, data) writes[path2] = data end
current.Value = nil
api.Start()
advance(0.1)
api.Stop()
local unknownPath = api.Export()
check(collect(records(writes[unknownPath]), "segment")[1].map_source == "unknown", "unknown map guessed from geometry")
-- A long suspended frame produces one sample, rather than hundreds of queued frames.
click("Phiên mới")
click("Phiên mới")
api.Start()
advance(30)
api.Stop()
local gapPath = api.Export()
check(#collect(records(writes[gapPath]), "frame") == 1, "slow frame caused catch-up burst")
-- A ten-minute reference remains bounded and auto-stops; no export occurs implicitly.
click("Phiên mới")
click("Phiên mới")
current.Value = map1
api.Start()
for _ = 1, 6200 do
    advance(0.101)
end
local limited = api.Export()
local limitRows = records(writes[limited])
check(#collect(limitRows, "frame") == 6000, "sample limit not enforced")
check(limitRows[#limitRows].reason == "limit", "full session did not stop automatically")
check(#writes[limited] <= 4 * 1024 * 1024, "byte limit exceeded")
-- Inference is automatic, evidence-based, and can retain overlapping contexts.
local scenarios = 0
local captured = node("BoolValue", "Captured", folder)
local selfBeast = node("BoolValue", "IsBeast", folder)
local inputFlag = node("BoolValue", "ActionInput", folder)
local function fresh()
    click("Phiên mới")
    click("Phiên mới")
    captured.Value, selfBeast.Value, typing.Value, inputFlag.Value, action.Value = false, false, false, false, nil
    current.Value = node("Model", "InferenceMap", World)
    hum.MoveDirection, hum.State, hum.FloorMaterial =
        Vec.new(1, 0, 0), Enum.HumanoidStateType.Running, Enum.Material.Plastic
    root.Position, root.AssemblyLinearVelocity = Vec.new(0, 3, 0), Vec.new(16, 0, 0)
    otherRoot.Position, otherRoot.AssemblyLinearVelocity, blockLOS = Vec.new(1000, 3, 0), Vec.new(), false
    lowOnly, voidAhead = false, false
    return current.Value
end
local function testPod(map, x, occupied)
    local t = node("Part", "PodTrigger", map)
    t.Position = Vec.new(x, 3, 0)
    local v = node("ObjectValue", "CapturedTorso", t)
    v.Value = occupied and otherRoot or nil
    return t
end
local function testComputer(map, x, done)
    local model = node("Model", "ComputerTable", map)
    local t = node("Part", "ComputerTrigger1", model)
    t.Position = Vec.new(x, 3, 0)
    local s = node("Part", "Screen", model)
    s.Position = t.Position
    s.Transparency, s.Color = 0, { R = 0.1, G = done and 0.9 or 0.1, B = 0.2 }
    return t
end
local function result(expected, label)
    api.Start()
    advance(0.1)
    api.Stop()
    local p = api.Export()
    local contexts2 = collect(records(writes[p]), "context")
    local inference = contexts2[#contexts2].inference
    check(inference.primary == expected, label .. ": got " .. inference.primary)
    scenarios += 1
    return inference
end
local m = fresh()
testPod(m, 20, false)
result("general", "empty pod is not a rescue")
m = fresh()
testPod(m, 200, true)
result("general", "distant captive alone does not prove intent")
m = fresh()
testPod(m, 35, true)
otherRoot.Position = Vec.new(8, 3, 0)
local overlapping = result("autohelp", "rescue approach under Beast threat")
check(
    #overlapping.candidates == 2 and overlapping.confidence == "overlapping_situations",
    "overlapping rescue/evade evidence was discarded"
)
m = fresh()
testPod(m, 35, true)
otherRoot.Position = Vec.new(8, 3, 0)
typing.Value = true
result("autofarm", "actual typing overrides guessed rescue direction")
m = fresh()
local pt = testPod(m, 12, true)
action.Value, inputFlag.Value = pt, true
result("autohelp", "native pod action observed")
m = fresh()
testPod(m, 120, true)
testComputer(m, 8, false)
result("autofarm", "close PC before distant captive")
m = fresh()
testComputer(m, 8, true)
result("general", "finished green-screen computer is not a farming target")
fresh()
otherRoot.Position = Vec.new(8, 30, 0)
result("general", "Beast on another floor is not automatically a chase")
fresh()
otherRoot.Position = Vec.new(8, 3, 0)
captured.Value = true
local trapped = result("general", "captured player is not demonstrating active evasion")
check(table.find(trapped.tags, "self_captured"), "captured context tag absent")
fresh()
otherRoot.Position = Vec.new(8, 3, 0)
selfBeast.Value = true
result("general", "playing Beast is not a survivor rescue/evade demonstration")
fresh()
otherRoot.Position = Vec.new(18, 3, 0)
otherRoot.AssemblyLinearVelocity = Vec.new(-8, 0, 0)
result("autohide", "closing Beast trajectory recognized")
m = fresh()
local exit = node("Part", "ExitDoorTrigger", m)
exit.Position = Vec.new(6, 3, 0)
action.Value, inputFlag.Value = exit, true
result("autofarm", "native exit opening observed")
fresh()
otherRoot.Position = Vec.new(8, 3, 0)
hum.MoveDirection = Vec.new()
api.Start()
for _ = 1, 83 do
    advance(0.51)
end
api.Stop()
local stationary = records(writes[api.Export()])
local lastContext = collect(stationary, "context")
local lastInference = lastContext[#lastContext].inference
check(
    lastInference.primary == "general" and table.find(lastInference.tags, "beast_stationary_40s"),
    "observed AFK Beast still labelled chase forever"
)
advance(10) -- No observation while paused; this must not count towards AFK evidence.
api.Start()
advance(0.1)
api.Stop()
stationary = records(writes[api.Export()])
lastContext = collect(stationary, "context")
check(
    lastContext[#lastContext].inference.primary == "autohide",
    "pause gap incorrectly preserved unobserved AFK evidence"
)
-- Paged export must preserve every JSON line, including UTF-8 notes.
environment.writefile = function() error("file API unavailable") end
api.Export()
local joined, previousPage = {}, nil
for _ = 1, 1000 do
    if dataBox.Text == previousPage then break end
    joined[#joined + 1], previousPage = dataBox.Text, dataBox.Text
    click("Sau")
end
check(#joined > 1, "fallback test did not exercise multiple pages")
local reconstructed = table.concat(joined)
check(#records(reconstructed) == #stationary, "paged fallback dropped or duplicated JSON lines")
environment.writefile = function(path2, data) writes[path2] = data end
fresh()
api.Start()
advance(0.1)
for _ = 1, 15000 do
    mark.Text = string.rep("界", 120)
    click("Đánh dấu")
end
local byteLimited = api.Export()
local byteRows = records(writes[byteLimited])
check(
    byteRows[#byteRows].reason == "limit" and #writes[byteLimited] <= 4 * 1024 * 1024,
    "UTF-8 note burst exceeded byte budget"
)
-- Detailed situations are observations, not a claim that the player or bot made a mistake.
local function stationaryStep(dt)
    now += dt
    Run.Heartbeat:Fire(dt)
end
fresh()
api.Start()
for _ = 1, 5 do
    stationaryStep(0.51)
end
advance(0.6)
api.Stop()
local stalledRows = records(writes[api.Export()])
local suspected, resumed = false, false
for _, e in ipairs(collect(stalledRows, "event")) do
    suspected = suspected or e.name == "possible_stall"
    resumed = resumed or e.name == "progress_resumed"
end
check(suspected and resumed, "before/after low-progress situation lost")
fresh()
typing.Value = true
api.Start()
for _ = 1, 5 do
    stationaryStep(0.51)
end
api.Stop()
for _, e in ipairs(collect(records(writes[api.Export()]), "event")) do
    check(e.name ~= "possible_stall", "legitimate stationary hacking falsely flagged as stalled movement")
end
m = fresh()
local upperPod = testPod(m, 8, true)
upperPod.Position = Vec.new(8, 22, 0)
testPod(m, 80, true)
result("autohelp", "rescue target on upper floor")
local heightContexts = collect(records(writes[api.Export()]), "context")
local heightContext = heightContexts[#heightContexts]
check(
    table.find(heightContext.scene.tags, "pod_above") and #heightContext.rescue_targets == 2,
    "different-floor target or farther captive omitted from scene context"
)
fresh()
blockLOS = true
otherRoot.Position = Vec.new(8, 3, 0)
local hiddenBeast = result("general", "stationary Beast behind geometry is not proof of chase")
check(
    hiddenBeast.beast_line_of_sight == false and table.find(hiddenBeast.tags, "beast_behind_geometry"),
    "occlusion evidence missing"
)
fresh()
lowOnly, voidAhead = true, true
result("general", "terrain evidence does not fabricate a gameplay goal")
local terrainContexts = collect(records(writes[api.Export()]), "context")
local terrainScene = terrainContexts[#terrainContexts].scene
check(
    table.find(terrainScene.tags, "low_obstacle_ahead")
        and table.find(terrainScene.tags, "no_ground_within_ahead_probe"),
    "flat low prop or unseen lower floor not recorded"
)
fresh()
api.Start()
advance(0.1)
hum.MoveDirection = Vec.new(-1, 0, 0)
advance(0.6)
api.Stop()
local turnRows = records(writes[api.Export()])
local turned = false
for _, e in ipairs(collect(turnRows, "event")) do
    turned = turned or e.name == "direction_reversal"
end
check(turned, "turn-back event not retained with raw movement")
check(forbidden == 0 and hum.WalkSpeed == 16 and hum.JumpPower == 50, "recorder touched controls")
print(
    "PASS: recorder lifecycle, maps, context, export, privacy, touch observations, limits; "
        .. scenarios
        .. " targeted inference scenarios ("
        .. checks
        .. " checks)"
)
