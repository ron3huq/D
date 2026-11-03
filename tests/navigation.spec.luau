-- Native movement, collision and input admission are simulated independently
-- of the production helpers. Sending a remote/key is not game acknowledgment.
local Vec = {}
Vec.__index = function(v, k)
    if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
    if k == "Unit" then return v / v.Magnitude end
    return Vec[k]
end
function Vec.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec) end
function Vec:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
Vec.__add = function(a, b) return Vec.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vec.__sub = function(a, b) return Vec.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vec.__mul = function(a, n)
    if type(a) == "number" then
        a, n = n, a
    end
    return Vec.new(a.X * n, a.Y * n, a.Z * n)
end
Vec.__div = function(a, n) return Vec.new(a.X / n, a.Y / n, a.Z / n) end
Vec.__unm = function(a) return a * -1 end
Vec.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
local Vector3 = { new = Vec.new, zero = Vec.new() }
local function Flat(v) return Vec.new(v.X, 0, v.Z) end
local CF = {}
CF.__index = CF
local function cf(p, dir)
    dir = dir or Vec.new(1, 0, 0)
    return setmetatable(
        { Position = p, LookVector = dir, UpVector = Vec.new(0, 1, 0), RightVector = Vec.new(-dir.Z, 0, dir.X) },
        CF
    )
end
function CF:PointToObjectSpace(p)
    local d = p - self.Position
    return Vec.new(d:Dot(self.RightVector), d.Y, -d:Dot(self.LookVector))
end
function CF:PointToWorldSpace(p)
    return self.Position + self.RightVector * p.X + self.UpVector * p.Y - self.LookVector * p.Z
end
local CFrame = {
    new = function(x, y, z) return cf(type(x) == "number" and Vec.new(x, y, z) or x) end,
    lookAt = function(p, q) return cf(p, Flat(q - p).Unit) end,
}
local Enum = {
    Material = { Air = "Air", Ground = "Ground" },
    KeyCode = { Space = "Space", E = "E", W = "W" },
    PathStatus = { Success = "Success", NoPath = "NoPath" },
    PathWaypointAction = { Walk = "Walk", Jump = "Jump" },
    HumanoidStateType = { Running = "Running", Jumping = "Jumping", Freefall = "Freefall" },
    RaycastFilterType = { Exclude = "Exclude" },
}
local function signal()
    local s = {}
    function s:Connect(f)
        return { Disconnect = function() end }
    end
    return s
end
local Node = {}
Node.__index = Node
local function node(name, class, parent)
    local n = setmetatable({ Name = name, ClassName = class or "Model", Parent = parent, children = {} }, Node)
    if parent then table.insert(parent.children, n) end
    return n
end
function Node:IsA(c)
    return self.ClassName == c
        or c == "BasePart" and self.ClassName == "Part"
        or c == "ValueBase" and self.ClassName:sub(-5) == "Value"
end
function Node:IsDescendantOf(p)
    local n = self.Parent
    while n do
        if n == p then return true end
        n = n.Parent
    end
    return false
end
function Node:GetChildren() return self.children end
function Node:GetDescendants()
    local a = {}
    for _, c in ipairs(self.children) do
        table.insert(a, c)
        for _, d in ipairs(c:GetDescendants()) do
            table.insert(a, d)
        end
    end
    return a
end
function Node:FindFirstChild(name)
    for _, c in ipairs(self.children) do
        if c.Name == name then return c end
    end
end
function Node:FindFirstAncestor(name)
    local p = self.Parent
    while p do
        if p.Name == name then return p end
        p = p.Parent
    end
end
function Node:GetPivot() return cf(self.Position or self.children[1].Position) end
local now = 100
local os = { clock = function() return now end }
local world, hum, root, torso, head, map, stats
local FH, Follow, AH, AR, TR, EM, Speed, Fly, Ctl = {}, {}, {}, {}, {}, {}, {}, {}, {}
local Workspace = { Gravity = 196.2 }
local PathfindingService = {}
local LocalPlayer = {}
local Players = {}
function Players:GetPlayers() return { LocalPlayer } end
local Computers = {}
local Doors, DoorFail, DoorTries = {}, {}, {}
local function IsInWorld(item) return item and item.Parent ~= nil end
local unloaded = false
local remoteHackActive, remoteHackEvent = false, nil
local rayParams = { FilterDescendantsInstances = {}, RespectCanCollide = true }
local rayFilterAt = 1
local RaycastParams = { new = function() return { FilterDescendantsInstances = {}, RespectCanCollide = true } end }
local VIM
local InvisBody = {}
local keypress, keyrelease
local task = {}
local scheduled = {}
local mainCoroutine = coroutine.running()
local step
local function resumeThread(co, ...)
    local ok, delay = coroutine.resume(co, ...)
    assert(ok, delay)
    if coroutine.status(co) ~= "dead" then
        table.insert(scheduled, { at = now + math.max(delay or 0.03, 0.001), co = co })
    end
end
function task.spawn(f, ...)
    local co = coroutine.create(f)
    resumeThread(co, ...)
    return co
end
function task.delay(dt, f) table.insert(scheduled, { at = now + dt, fn = f }) end
function task.wait(dt)
    dt = dt or 0.03
    if coroutine.running() ~= mainCoroutine then return coroutine.yield(dt) end
    local left = dt
    while left > 1e-7 do
        local d = math.min(left, 0.01)
        left -= d
        step(d)
    end
    return dt
end
local function runReady()
    for _ = 1, 1000 do
        local picked
        for i, j in ipairs(scheduled) do
            if j.at <= now + 1e-8 then
                picked = table.remove(scheduled, i)
                break
            end
        end
        if not picked then break end
        if picked.co then
            resumeThread(picked.co)
        else
            picked.fn()
        end
    end
end
local function GetHumanoid() return hum end
local function RootNow() return root end
local function GetCurrentMap() return map end
local function IsRealComputer(c, m)
    return c ~= nil and c.Name == "ComputerTable" and c.Parent ~= nil and c:IsDescendantOf(m)
end
local function TokOK(t) return FH.MotionValid(t) and FH.MotionAvailable(t) end
function FH.Stat(_, names)
    for _, n in ipairs(names) do
        if stats[n] then return stats[n] end
    end
end
function FH.True(p, names)
    local s = FH.Stat(p, names)
    return s and s.Value == true or false
end
function FH.Prio() return false end
function FH.RefreshFilter() end
function FH.NavigationFilter() return rayParams end
function FH.Done(c) return c.done == true end
function FH.ExitOpen() return false end
function FH.MatchOn() return true end
function FH.Grid() return nil, true end
function FH.DoorOf(part) return part.door end
function FH.DoorInfo(item) return item.geom end
function FH.DoorGeom(item) return item.geom end
function FH.DoorOnFloor(g, position) return math.abs(g.NearPos.Y - position.Y) < 4 end
function FH.DoorBlocked(g) return g.closed == true end
function FH.RescueDoorStand(g) return g.NearPos, g.NearTrig end
function FH.Unstick() end
function FH.AmBeast() return false end
function Ctl.On() return world.manual == true end
function Ctl.Gate() return world.manual == true end
local UserInputService = {}
function UserInputService:GetFocusedTextBox() return world.focus and {} or nil end
function UserInputService:IsKeyDown(k) return world.keys[k] == true end
function AH.Down() return not hum or hum.Health <= 0 or FH.True(LocalPlayer, FH.CAP) or FH.True(LocalPlayer, FH.RAG) end
function AH.ReleaseTap() end
function AH.Unsafe() return false end
function AH.Eval()
    return {
        danger = world.threat ~= nil,
        pos = world.threat,
        dist = world.threat and Flat(world.threat - root.Position).Magnitude or math.huge,
    }
end
function AR.Pending() return world.pending == true end
function AR.Release()
    AR.Held, AR.KeyDown = false, false
end
function TR.Release()
    TR.Held, TR.KeyDown = false, false
end
function Follow.ReleaseTap() end
function Follow.FindDoorRoute() return nil end
function Follow.TryDoor() return false end
function Follow.RescueDoorState() return nil end
function Follow.RescueDoorKind() return 0 end
function Follow.RescueRouteReturns() return false end
local FAST_H = { 0.7, 2.7, 4.7 }
local SLOW_H = { 0.7, 1.7, 2.7, 3.7, 4.7, 5.7, 6.7, 7.7, 8.7 }
local STAIR_H = { 1.1, 1.6, 2.3, 3.6, 4.25 }
local PATH_SPECS = { { 2.4, 5 }, { 1.2, 4 } }
local RemoteEvent = {}
function RemoteEvent:FireServer(...)
    world.remotes += 1
end
local function updateParts()
    root.CFrame = cf(root.Position, world.facing)
    torso.Position, torso.CFrame = root.Position, root.CFrame
    head.Position = root.Position + Vec.new(0, 1.5, 0)
    head.CFrame = cf(head.Position, world.facing)
end
local function part(name, p, size, parent, collide)
    local n = node(name, "Part", parent)
    n.Position, n.Size, n.CFrame = p, size, cf(p)
    n.CanCollide = collide ~= false
    n.AssemblyLinearVelocity = Vec.new()
    return n
end
local function box(name, lo, hi, parent)
    local p = part(name, (lo + hi) * 0.5, hi - lo, parent or map)
    table.insert(world.boxes, { lo = lo, hi = hi, part = p })
    return p
end
local function excluded(part, params)
    for _, n in ipairs(params and params.FilterDescendantsInstances or {}) do
        if part == n or part:IsDescendantOf(n) then return true end
    end
    return false
end
local function intersect(p, d, lo, hi, ignoreInside)
    local inside = p.X > lo.X + 1e-7
        and p.X < hi.X - 1e-7
        and p.Y > lo.Y + 1e-7
        and p.Y < hi.Y - 1e-7
        and p.Z > lo.Z + 1e-7
        and p.Z < hi.Z - 1e-7
    if inside and ignoreInside then return nil end
    local enter, leave, normal = 0, 1, Vec.new()
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        if math.abs(d[axis]) < 1e-9 then
            if p[axis] < lo[axis] or p[axis] > hi[axis] then return nil end
        else
            local a, b = (lo[axis] - p[axis]) / d[axis], (hi[axis] - p[axis]) / d[axis]
            local sign = -1
            if a > b then
                a, b = b, a
                sign = 1
            end
            if a > enter then
                enter = a
                normal = Vec.new(axis == "X" and sign or 0, axis == "Y" and sign or 0, axis == "Z" and sign or 0)
            end
            leave = math.min(leave, b)
            if enter > leave then return nil end
        end
    end
    if enter < 0 or enter > 1 then return nil end
    return enter, normal
end
function Workspace:Raycast(p, d, params)
    world.rays += 1
    local best, normal, instance
    if d.Y < 0 and p.Y >= 0 then
        local t = -p.Y / d.Y
        local at = p + d * t
        if t >= 0 and t <= 1 and (not world.void or not world.void(at.X, at.Z)) then
            best, normal, instance = t, Vec.new(0, 1, 0), world.floor
        end
    end
    for _, b in ipairs(world.boxes) do
        if b.part.CanCollide and not excluded(b.part, params) then
            local t, n = intersect(p, d, b.lo, b.hi, true)
            if t and (not best or t < best) then
                best, normal, instance = t, n, b.part
            end
        end
    end
    if best then
        return { Instance = instance, Position = p + d * best, Normal = normal, Distance = d.Magnitude * best }
    end
end
function Workspace:Blockcast(frame, size, movement, params)
    world.sweeps += 1
    local side = frame.RightVector
    local dir = frame.LookVector
    local hx = math.abs(side.X) * size.X * 0.5 + math.abs(dir.X) * size.Z * 0.5
    local hz = math.abs(side.Z) * size.X * 0.5 + math.abs(dir.Z) * size.Z * 0.5
    local extent = Vec.new(hx, size.Y * 0.5, hz)
    local best, normal, instance
    for _, b in ipairs(world.boxes) do
        if b.part.CanCollide and not excluded(b.part, params) then
            local t, n = intersect(frame.Position, movement, b.lo - extent, b.hi + extent, true)
            if t and (not best or t < best) then
                best, normal, instance = t, n, b.part
            end
        end
    end
    if best then
        return {
            Instance = instance,
            Position = frame.Position + movement * best,
            Normal = normal,
            Distance = movement.Magnitude * best,
        }
    end
end
function PathfindingService:CreatePath(spec)
    table.insert(world.pathSpecs, spec)
    local p = { Status = Enum.PathStatus.Success, Blocked = signal() }
    function p:ComputeAsync(from, to)
        task.wait(world.planDelay)
        self.wps = world.route and world.route(from, to, spec)
            or { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" }, { Position = to, Action = "Walk" } }
        if not self.wps then
            self.Status = Enum.PathStatus.NoPath
            self.wps = {}
        end
    end
    function p:GetWaypoints() return self.wps end
    function p:Destroy() end
    return p
end
local function nativeKey(code, down)
    local key = code == 0x20 and "Space" or code == 0x45 and "E" or code == 0x57 and "W" or code
    if world.keys[key] == down then return end
    world.keys[key] = down
    table.insert(world.inputs, { key = key, down = down, at = now, p = root.Position })
    if not down then return end
    if key == "Space" then
        if hum.FloorMaterial ~= "Air" then
            world.launch = true
        elseif world.firstAt and now - world.firstAt >= 0.195 and not world.doubleUsed and world.allowDouble then
            world.second = true
            world.doubleUsed = true
        end
    elseif key == "E" then
        if world.ignoreE > 0 then
            world.ignoreE -= 1
            return
        end
        if
            world.pc
            and Flat(root.Position - world.trigger.Position).Magnitude <= world.pcRange
            and not world.pc.done
        then
            world.engaged = true
            stats.ActionEvent.Value = world.event
            if world.alignPC then
                root.Position = world.trigger.Position
                updateParts()
            end
        elseif world.pod then
            local p = world.pod.CFrame:PointToObjectSpace(root.Position)
            local half = world.pod.Size * 0.5
            local gap = math.sqrt(math.max(0, math.abs(p.X) - half.X) ^ 2 + math.max(0, math.abs(p.Z) - half.Z) ^ 2)
            if gap <= 1.3 then world.rescueAt = now end
        end
    end
end
step = function(dt)
    now += dt
    runReady()
    if world.launch then
        world.launch = false
        world.firstAt = now
        world.doubleUsed = false
        world.vy = hum.JumpPower
        hum.FloorMaterial = "Air"
        world.jumps += 1
    end
    if world.second then
        world.second = false
        world.vy = hum.JumpPower
        world.doubles += 1
    end
    if world.engaged then
        stats.ActionProgress.Value += dt * 0.02
        if stats.ActionProgress.Value >= world.completeAt then
            world.pc.done = true
            world.engaged = false
        end
    end
    if world.rescueAt and now - world.rescueAt >= world.rescueDelay then world.captive.Value = nil end
    hum.nativeDir = Vec.new() -- Roblox's own no-input update, before our render controller.
    if FH.NoteNormalTakeoff then FH.NoteNormalTakeoff() end
    if FH.Tick then FH.Tick(hum, root) end
    if FH.JumpMoveStep then FH.JumpMoveStep() end
    if FH.GroundMoveStep then FH.GroundMoveStep() end
    local before = root.Position
    local direction = hum.nativeDir or Vec.new()
    if direction.Magnitude > 0.1 then world.facing = direction.Unit end
    local candidate = before + direction * hum.WalkSpeed * dt
    local feet = before.Y - 3
    local nextFeet = feet
    if hum.FloorMaterial == "Air" then
        nextFeet += world.vy * dt - 0.5 * Workspace.Gravity * dt * dt
        world.vy -= Workspace.Gravity * dt
    end
    local floor = 0
    if world.void and world.void(candidate.X, candidate.Z) then floor = -100 end
    for _, b in ipairs(world.boxes) do
        if
            candidate.X >= b.lo.X
            and candidate.X <= b.hi.X
            and candidate.Z >= b.lo.Z
            and candidate.Z <= b.hi.Z
            and b.hi.Y <= math.max(feet, nextFeet) + 1.05
        then
            floor = math.max(floor, b.hi.Y)
        end
    end
    if hum.FloorMaterial ~= "Air" then nextFeet = floor end
    if hum.FloorMaterial == "Air" and world.vy <= 0 and nextFeet <= floor then
        nextFeet = floor
        world.vy = 0
        hum.FloorMaterial = "Ground"
    end
    local blocked = false
    for _, b in ipairs(world.boxes) do
        if
            b.part.CanCollide
            and candidate.X + 1 > b.lo.X + 1e-5
            and candidate.X - 1 < b.hi.X - 1e-5
            and candidate.Z + 1 > b.lo.Z + 1e-5
            and candidate.Z - 1 < b.hi.Z - 1e-5
            and nextFeet + 2 < b.hi.Y - 1e-5
            and nextFeet + (head.CanCollide and 5 or 4) > b.lo.Y + 1e-5
        then
            blocked = true
            break
        end
    end
    if blocked and not world.engaged then
        -- Side contact blocks horizontal motion, not the native jump's rise.
        -- Resolve the vertical axis separately (e.g. a real ceiling).
        candidate = before
        world.blocked += 1
        for _, b in ipairs(world.boxes) do
            if
                b.part.CanCollide
                and before.X + 1 > b.lo.X + 1e-5
                and before.X - 1 < b.hi.X - 1e-5
                and before.Z + 1 > b.lo.Z + 1e-5
                and before.Z - 1 < b.hi.Z - 1e-5
                and nextFeet + 2 < b.hi.Y - 1e-5
                and nextFeet + (head.CanCollide and 5 or 4) > b.lo.Y + 1e-5
            then
                nextFeet = feet
                world.vy = 0
                break
            end
        end
    end
    if hum.FloorMaterial ~= "Air" and floor < feet - 0.85 then
        hum.FloorMaterial = "Air"
        world.vy = 0
        nextFeet = feet
    end
    root.Position = Vec.new(candidate.X, nextFeet + 3, candidate.Z)
    root.AssemblyLinearVelocity =
        Vec.new((root.Position.X - before.X) / dt, world.vy, (root.Position.Z - before.Z) / dt)
    hum.State = hum.FloorMaterial == "Air" and (world.vy > 0 and "Jumping" or "Freefall") or "Running"
    if world.trigger and not world.engaged then
        stats.ActionEvent.Value = Flat(root.Position - world.trigger.Position).Magnitude <= world.selectRange
                and world.event
            or nil
    end
    updateParts()
    if world.cancelAt and now >= world.cancelAt then world.manual = true end
end
local function reset()
    now = 100
    scheduled = {}
    world = {
        boxes = {},
        keys = {},
        inputs = {},
        pathSpecs = {},
        rays = 0,
        sweeps = 0,
        remotes = 0,
        manual = false,
        focus = false,
        planDelay = 0.05,
        ignoreE = 0,
        pcRange = 2.1,
        selectRange = 2.5,
        alignPC = true,
        completeAt = 0.025,
        allowDouble = true,
        jumps = 0,
        doubles = 0,
        vy = 0,
        blocked = 0,
        facing = Vec.new(1, 0, 0),
        rescueDelay = 0.08,
    }
    map = node("UnseenTestMap", "Model", node("Workspace", "Workspace"))
    LocalPlayer.Character = node("Character", "Model", map.Parent)
    LocalPlayer.Parent = Players
    root = part("HumanoidRootPart", Vec.new(0, 3, 0), Vec.new(2, 2, 1), LocalPlayer.Character, false)
    torso = part("Torso", root.Position, Vec.new(2, 2, 1), LocalPlayer.Character, true)
    head = part("Head", root.Position + Vec.new(0, 1.5, 0), Vec.new(2, 1, 1), LocalPlayer.Character, false)
    hum = {
        RootPart = root,
        Parent = LocalPlayer.Character,
        Health = 100,
        WalkSpeed = 16,
        JumpPower = 36,
        JumpHeight = 7.2,
        UseJumpPower = true,
        HipHeight = 0,
        FloorMaterial = "Ground",
        State = "Running",
        MaxSlopeAngle = 75,
        MoveDirection = Vec.new(),
    }
    function hum:GetState() return self.State end
    function hum:Move(d) self.nativeDir = d end
    function hum:MoveTo(goal) self.destination = goal end
    function hum:ChangeState(state)
        assert(self.FloorMaterial ~= "Air", "script forced an airborne jump state")
        if state == "Jumping" then world.launch = true end
    end
    stats = { ActionInput = { Value = false }, ActionEvent = {}, ActionProgress = { Value = 0 } }
    local keep = {}
    for k, v in pairs(FH) do
        if type(v) == "function" then keep[k] = v end
    end
    table.clear(FH)
    for k, v in pairs(keep) do
        FH[k] = v
    end
    FH.Motion = { token = nil, priority = 0, untilAt = 0, sentAt = 0 }
    FH.Bad = {}
    FH.LastJump = -10
    FH.BanDirect = 0
    FH.GridBan = 0
    FH.HackFail = 0
    FH.CompTrigCache = {}
    FH.PodRayCache = {}
    FH.CAP = { "Captured" }
    FH.RAG = { "Ragdoll" }
    FH.HP = { "Health" }
    FH.ESC = { "Escaped" }
    FH.HACK_INPUT = { "ActionInput" }
    FH.HACK_EVENT = { "ActionEvent" }
    FH.HACK_PROGRESS = { "ActionProgress" }
    FH.HACK_TYPING = { "IsTyping" }
    FH.BEASTN = { "IsBeast" }
    FH.Nav = nil
    for k in pairs(Follow) do
        if type(Follow[k]) ~= "function" then Follow[k] = nil end
    end
    Follow.Token = 7
    Follow.AutoFarm = true
    Follow.PauseUntil = 0
    Follow.JumpH1 = 4.6
    Follow.JumpH2 = 8.4
    Follow.BodyH = 4.4
    Follow.DoubleFrom = 0.9
    Follow.MaxDrop = 12
    Follow.MaxDY = 5
    Follow.HackMax = 5
    Follow.HackSendResult = true
    Follow.HelpDist = 3.6
    Follow.InAt = 0
    Follow.Beat = now
    Follow.Debug = false
    AH.BusyFlag = false
    AH.Active = false
    AH.JukeRange = 26
    AH.ScanSegs = 5
    AH.SegLen = 3
    AR.Active = false
    AR.BusyFlag = false
    AR.KeyDown = false
    AR.Held = nil
    AR.Pick = nil
    AR.PendingPick = nil
    TR.BusyFlag = false
    TR.Held = nil
    TR.KeyDown = false
    EM.ComboState = nil
    Fly.Active = false
    Ctl.Down = {}
    Computers = {}
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
    rayFilterAt += 1
    Doors, DoorFail, DoorTries = {}, {}, {}
    world.floor = part("Floor", Vec.new(0, 0, 0), Vec.new(1000, 0.01, 1000), map)
    keypress = function(code) nativeKey(code, true) end
    keyrelease = function(code) nativeKey(code, false) end
    VIM = { SendKeyEvent = function(_, down, key) nativeKey(key, down) end }
    updateParts()
end
-- SOURCE_FUNCTIONS
local checks, scenarios, failures = 0, 0, {}
local function check(value, message)
    checks += 1
    assert(value, message)
end
local function scenario(name, fn)
    reset()
    scenarios += 1
    local ok, problem = xpcall(fn, debug.traceback)
    print(
        name,
        ok and "PASS" or "FAIL",
        math.round((now - 100) * 100) / 100,
        "seconds",
        world.blocked,
        "blocked",
        world.jumps,
        world.doubles
    )
    if not ok then table.insert(failures, name .. ": " .. tostring(problem)) end
end
local function computer(distance)
    world.pc = node("ComputerTable", "Model", map)
    world.trigger = part("ComputerTrigger1", Vec.new(distance, 3, 0), Vec.new(1, 1, 0.6), world.pc, false)
    world.event = node("Event", "RemoteEvent", world.trigger)
    box("Desk", Vec.new(distance + 0.4, 0, -2), Vec.new(distance + 3, 1.9, 2), world.pc)
    Computers = { world.pc }
    return world.pc, world.trigger
end
local function pod(distance)
    local model = node("FreezePod", "Model", map)
    world.pod = part("PodTrigger", Vec.new(distance, 1.5, 0), Vec.new(8, 3, 8), model, false)
    world.podEvent = node("Event", "RemoteEvent", world.pod)
    world.captive = node("CapturedTorso", "ObjectValue", world.pod)
    world.captive.Value = {}
    box("Capsule", Vec.new(distance - 2.5, 0, -2.5), Vec.new(distance + 2.5, 6, 2.5), model)
    return { trig = world.pod, ev = world.podEvent, occupant = world.captive.Value }
end
local function rescueToken()
    return { owner = "rescue", priority = 90, ok = function() return not world.manual end }
end
scenario("native PC approach and game alignment, ActionInput stays false", function()
    local comp = computer(10)
    Follow.TestMainContact(7, LocalPlayer)(comp)
    check(comp.done, "real game never completed PC")
    check(world.jumps == 0, "PC contact generated an obstacle jump")
    check(now - 100 < 4, "smooth approach/ack unnecessarily stalled")
    check(not Follow.KeyDown and Follow.Held == nil, "PC release left E held")
end)
scenario("selected trigger before actual key admission still advances closer", function()
    world.selectRange = 3.1
    local comp = computer(10)
    Follow.TestMainContact(7, LocalPlayer)(comp)
    check(comp.done, "ignored early E was retried forever without advancing")
    check(world.jumps == 0, "ignored E jumped onto desk")
end)
scenario("short demonstrator hack is not computer completion", function()
    local comp = computer(4)
    world.completeAt = 10
    world.cancelAt = 101
    Follow.TestMainContact(7, LocalPlayer)(comp)
    check(not comp.done and stats.ActionProgress.Value < 1, "partial progress marked PC complete")
    check(now - 100 < 1.2 and not Follow.KeyDown, "manual takeover did not release PC input")
end)
scenario("ignored first E edge retries without losing computer", function()
    world.ignoreE = 1
    local comp = computer(7)
    Follow.TestMainContact(7, LocalPlayer)(comp)
    check(comp.done, "missed native input abandoned reachable PC")
end)
for _, owner in ipairs({ "follow", "rescue" }) do
    scenario("moving through ten-second planning delay " .. owner, function()
        local token = owner == "follow" and 7 or rescueToken()
        world.planDelay = 10
        FH.BanDirect = now + 30
        local goal = Vec.new(180, 3, 0)
        local result = Follow.WalkTo(token, function() return goal end, 0.8, nil, { noDoor = true, maxTime = 14 })
        check(result == "arrived", "planner age aborted a genuinely progressing route: " .. tostring(result))
        check(root.Position.X > 178 and world.blocked == 0, "live controller stopped despite clear path")
        check(hum.WalkSpeed == 16 and hum.JumpPower == 36, "movement parameters changed")
    end)
end
scenario("native path uses actual avatar width", function()
    local route = FH.Path(Vec.new(0, 0, 0), Vec.new(10, 0, 0), 2.4, 5)
    check(route and world.pathSpecs[1].AgentRadius <= 1.05, "planner padded a two-stud avatar to nearly five studs")
end)
scenario("side decoration outside body remains a clear walking lane", function()
    box("Decoration", Vec.new(0, 0, 1.04), Vec.new(8, 2.5, 1.3))
    local safe, kind = FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true)
    check(safe and kind == nil, "side-only proximity cancelled movement")
end)
scenario("small flat decoration stays ordinary walking", function()
    box("FloorTrim", Vec.new(2, 0, -2), Vec.new(2.5, 0.2, 2))
    local safe, kind = FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true)
    check(safe and kind == nil, "walkable flat trim was treated as wall/jump")
end)
scenario("solid front wall requires another route", function()
    box("Wall", Vec.new(2, 0, -10), Vec.new(3, 12, 10))
    local safe = FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true)
    check(safe == false, "jump authorized through a full wall")
end)
scenario("closed door is an interaction, not a jump", function()
    local door = box("Door", Vec.new(2, 0, -2), Vec.new(3, 8, 2))
    door.door = {}
    check(FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true) == false, "closed door bypassed by jump proof")
end)
scenario("ordinary ground shortcut cannot cross an unproved cliff", function()
    world.void = function(x) return x > 2 end
    check(FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true) == false, "unsupported shortcut accepted")
end)
scenario("stair treads support ordinary native walking", function()
    for i = 1, 12 do
        box("Step", Vec.new(i * 0.5, 0, -3), Vec.new(i * 0.5 + 0.5, i * 0.35, 3))
    end
    local safe, kind = FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true)
    check(safe and kind == "stairs", "supported staircase rejected")
end)
scenario("native double Space preserves jump power and forward direction", function()
    FH.Move(7, hum, Vec.new(30, 3, 0))
    check(FH.Jump(hum, true, 7), "first natural jump denied")
    for _ = 1, 35 do
        FH.Move(7, hum, Vec.new(30, 3, 0))
        task.wait(0.01)
    end
    check(world.jumps == 1 and world.doubles == 1, "game never accepted both distinct Space presses")
    check(root.Position.X > 4 and hum.JumpPower == 36, "jump stopped horizontal motion or boosted power")
end)
scenario("pod interaction begins outside capsule, not at its centre", function()
    local info = pod(16)
    local token = rescueToken()
    FH.RescuePod(
        token,
        function() return not world.manual end,
        info,
        nil,
        function() nativeKey(0x45, true) end,
        function() nativeKey(0x45, false) end,
        nil,
        5.2
    )
    check(world.captive.Value == nil, "valid capsule-side interaction did not free captive")
    check(world.blocked == 0 and world.jumps == 0, "pod approach rammed/jumped into capsule")
    check(now - 100 < 2, "short rescue route stopped before interaction")
end)
scenario("pod on other floor is not in contact through ceiling", function()
    local info = pod(0)
    world.pod.Position = Vec.new(0, 19.5, 0)
    world.pod.CFrame = cf(world.pod.Position)
    box("UpperFloor", Vec.new(-10, 17.8, -10), Vec.new(10, 18, 10))
    if FH.PodContactReady then
        check(not FH.PodContactReady(world.pod, hum, root), "other-floor pod passed contact proof")
    end
end)
scenario("rescue keeps priority over a distant red warning", function()
    AH.Active = true
    world.threat = Vec.new(10, 3, 0)
    check(not AR.ThreatPreempts(), "red alert abandoned rescue outside immediate reach")
end)
scenario("ready pod gets its rescue action before evading", function()
    AH.Active = true
    local info = pod(4.8)
    AR.Pick = info
    world.threat = Vec.new(2, 3, 0)
    check(not AR.ThreatPreempts(), "standing in real pod contact turned away instead of rescuing")
end)
scenario("immediate visible Beast can interrupt unsafe travel", function()
    AH.Active = true
    world.threat = Vec.new(3, 3, 0)
    check(AR.ThreatPreempts(), "immediate exposed strike range was ignored")
end)
scenario("manual control revokes live movement", function()
    FH.Move(7, hum, Vec.new(30, 3, 0))
    task.wait(0.1)
    world.manual = true
    local p = root.Position
    task.wait(0.3)
    check(Flat(root.Position - p).Magnitude < 0.01, "stale owner kept moving after manual takeover")
end)
scenario("native planner and controller traverse a 2.08-stud gap", function()
    box("LeftWall", Vec.new(-5, 0, -3), Vec.new(30, 7, -1.04))
    box("RightWall", Vec.new(-5, 0, 1.04), Vec.new(30, 7, 3))
    world.route = function(from, to, spec)
        if spec.AgentRadius * 2 > 2.08 then return nil end
        return { { Position = Vec.new(from.X, 0, 0), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    FH.BanDirect = now + 20
    local result = Follow.WalkTo(7, function() return Vec.new(24, 3, 0) end, 0.8, nil, { noDoor = true, maxTime = 6 })
    check(
        result == "arrived" and world.jumps == 0 and world.blocked == 0,
        "usable narrow corridor was abandoned or scraped"
    )
end)
scenario("noncolliding visual head cannot manufacture a low ceiling", function()
    head.Size = Vec.new(2, 8, 1)
    box("Ceiling", Vec.new(-5, 5, -5), Vec.new(15, 5.3, 5))
    local safe = FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true)
    check(safe == true, "noncolliding cosmetic geometry rejected real body clearance")
end)
scenario("colliding head still requires genuine clearance", function()
    head.CanCollide = true
    head.Size = Vec.new(2, 3, 1)
    box("CeilingBeam", Vec.new(2, 5, -5), Vec.new(15, 20, 5))
    check(
        FH.TraversalLane(7, hum, root, Vec.new(6, 3, 0), 0, 6, true) == false,
        "real head collider passed through ceiling"
    )
end)
scenario("native walk over flat trim never invokes Space", function()
    box("FloorTrim", Vec.new(2, 0, -3), Vec.new(2.5, 0.2, 3))
    local result = Follow.WalkTo(7, function() return Vec.new(12, 3, 0) end, 0.8, nil, { noDoor = true, maxTime = 3 })
    check(result == "arrived" and world.jumps == 0 and world.blocked == 0, "flat floor trim interrupted smooth walking")
end)
scenario("low window uses a single native jump while retaining direction", function()
    box("WindowSill", Vec.new(3, 0, -3), Vec.new(3.5, 2.7, 3))
    FH.Move(7, hum, Vec.new(12, 3, 0))
    for _ = 1, 100 do
        FH.Move(7, hum, Vec.new(12, 3, 0))
        task.wait(0.01)
    end
    check(root.Position.X > 10 and world.jumps >= 1, "native body failed to clear jumpable window sill")
    check(world.doubles == 0 and hum.JumpPower == 36, "small window unnecessarily double-jumped or boosted power")
end)
scenario("high obstacle uses a real second input instead of jump-height edits", function()
    box("TallObstacle", Vec.new(3, 0, -3), Vec.new(3.5, 5.4, 3))
    FH.Move(7, hum, Vec.new(12, 3, 0))
    for _ = 1, 110 do
        FH.Move(7, hum, Vec.new(12, 3, 0))
        task.wait(0.01)
    end
    check(
        world.doubles >= 1 and root.Position.X > 8,
        "required double jump was not delivered to native game controller"
    )
    check(hum.JumpPower == 36 and hum.JumpHeight == 7.2, "double jump altered configured jump properties")
end)
scenario("ignored native PC inputs never count as work or completion", function()
    world.pcRange = 0.1
    local comp = computer(6)
    Follow.TestMainContact(7, LocalPlayer)(comp)
    check(not comp.done and stats.ActionProgress.Value == 0, "transport success fabricated completed work")
    check(not FH.IsWorking(7) and not Follow.KeyDown, "unacknowledged input left a work lock")
end)
scenario("movement owner change cancels an airborne second press", function()
    FH.Move(7, hum, Vec.new(20, 3, 0))
    FH.Jump(hum, true, 7)
    task.wait(0.1)
    Follow.Token = 8
    task.wait(0.25)
    check(world.doubles == 0, "stale flight injected second jump after task cancellation")
end)
scenario("held E cancels steering during a jump", function()
    FH.Move(7, hum, Vec.new(20, 3, 0))
    FH.Jump(hum, true, 7)
    task.wait(0.1)
    AR.KeyDown = true
    local p = root.Position
    task.wait(0.15)
    check(
        Flat(root.Position - p).Magnitude < 0.01 and world.doubles == 0,
        "native flight fought an active rescue interaction"
    )
end)
scenario("zero progress while planner waits still times out", function()
    world.planDelay = 10
    box("UpperFloor", Vec.new(-20, 17.8, -20), Vec.new(20, 18, 20))
    local result = Follow.WalkTo(7, function() return Vec.new(0, 21, 0) end, 0.8, nil, { noDoor = true, maxTime = 15 })
    check(result == "timeout" and now - 100 < 8.2, "progress timeout became unbounded while stationary")
    check(Flat(root.Position).Magnitude < 0.01 and world.jumps == 0, "jumped repeatedly below an upstairs target")
end)
scenario("foreign progress cannot acknowledge this computer", function()
    if not FH.InteractionAck then return end
    local comp, trig = computer(6)
    local other = part("ComputerTrigger2", Vec.new(8, 3, 0), Vec.new(1, 1, 0.6), comp, false)
    stats.ActionEvent.Value = other
    stats.ActionInput.Value = true
    stats.ActionProgress.Value = 0.4
    check(not FH.InteractionAck(trig, {}), "another keyboard action acknowledged selected target")
end)
scenario("terminal exception revokes across maps and walls", function()
    if not FH.ContactApproachValid then return end
    local comp, trig = computer(4)
    local goal = FH.ContactGoal(trig, root.Position, 0.6)
    FH.SetContactApproach(7, hum, root, trig, comp, goal, "computer")
    check(FH.ContactApproachValid(7, hum, root, goal), "clear supported terminal exception rejected")
    map = node("ReplacementMap", "Model", map.Parent)
    check(not FH.ContactApproachValid(7, hum, root, goal), "stale map retained interaction bypass")
end)
scenario("Beast behind a wall does not interrupt a valid rescue route", function()
    AH.Active = true
    world.threat = Vec.new(3, 3, 0)
    box("Cover", Vec.new(1, 0, -3), Vec.new(1.5, 8, 3))
    check(not AR.ThreatPreempts(), "occluded Beast redirected rescue through unnecessary flee logic")
end)
scenario("scaled actual collider cannot be undercut by a narrow path request", function()
    root.Size = Vec.new(3, 2, 1)
    FH.Path(Vec.new(0, 0, 0), Vec.new(10, 0, 0), 1.2, 4)
    check(world.pathSpecs[1].AgentRadius >= 1.5, "narrow profile claimed clearance smaller than real body")
end)
scenario("native stair walking keeps moving all the way to its landing", function()
    for i = 1, 12 do
        box("Step", Vec.new(i * 0.5, 0, -3), Vec.new(i * 0.5 + 0.5, i * 0.35, 3))
    end
    box("Landing", Vec.new(6.5, 0, -3), Vec.new(12, 4.2, 3))
    local result = Follow.WalkTo(7, function() return Vec.new(10, 7.2, 0) end, 0.8, nil, { noDoor = true, maxTime = 5 })
    check(result == "arrived" and root.Position.Y > 7, "stopped midway through real stair ascent")
    check(world.blocked == 0 and world.jumps <= 1, "ordinary supported treads triggered repeated recovery hops")
end)
scenario("upstairs target uses a real connector away from its X/Z position", function()
    box("UpperWalkway", Vec.new(-2, 8.2, -2), Vec.new(22, 8.4, 2))
    for i = 1, 24 do
        box("Stair", Vec.new(8 + (i - 1) * 0.5, 0, 6), Vec.new(8 + i * 0.5, i * 0.35, 10))
    end
    box("UpperLanding", Vec.new(20, 8.2, -2), Vec.new(23, 8.4, 10))
    world.route = function()
        local points = { Vec.new(0, 0, 0), Vec.new(4, 0, 8), Vec.new(8, 0, 8) }
        for i = 4, 24, 4 do
            table.insert(points, Vec.new(8 + i * 0.5, i * 0.35, 8))
        end
        table.insert(points, Vec.new(21, 8.4, 0))
        table.insert(points, Vec.new(0, 8.4, 0))
        local result = {}
        for _, p in ipairs(points) do
            table.insert(result, { Position = p, Action = "Walk" })
        end
        return result
    end
    local result = Follow.WalkTo(
        7,
        function() return Vec.new(0, 11.4, 0) end,
        0.8,
        nil,
        { noDoor = true, maxTime = 12 }
    )
    check(
        result == "arrived" and root.Position.Y > 11,
        "failed to find/finish actual upstairs connector: " .. tostring(result)
    )
end)
scenario("clear goal replaces the stale path detour after passing a wall", function()
    box("Partition", Vec.new(5, 0, -4), Vec.new(6, 8, 4))
    FH.BanDirect = now + 20
    world.route = function(from, to)
        local positions = {
            Vec.new(from.X, 0, from.Z),
            Vec.new(0, 0, 6),
            Vec.new(8, 0, 6),
            Vec.new(8, 0, 25),
            Vec.new(30, 0, 25),
            Vec.new(30, 0, 0),
        }
        local result = {}
        for _, p in ipairs(positions) do
            table.insert(result, { Position = p, Action = "Walk" })
        end
        return result
    end
    local result = Follow.WalkTo(7, function() return Vec.new(30, 3, 0) end, 0.8, nil, { noDoor = true, maxTime = 4 })
    check(result == "arrived" and now - 100 < 3.5, "followed a long old circuit despite a newly clear goal")
end)
scenario("rescue portal ranking prefers opening a short door over an open detour", function()
    local short = node("ShortDoor", "Model", map)
    local far = node("DistantOpenDoor", "Model", map)
    local trigger = part("DoorTrigger", Vec.new(2, 3, 0), Vec.new(8, 3, 6), short, false)
    short.geom = {
        Door = short,
        Center = Vec.new(5, 3, 0),
        NearPos = Vec.new(2, 3, 0),
        FarPos = Vec.new(8, 3, 0),
        NearTrig = trigger,
        closed = true,
    }
    far.geom = {
        Door = far,
        Center = Vec.new(-20, 3, 0),
        NearPos = Vec.new(-23, 3, 0),
        FarPos = Vec.new(-17, 3, 0),
        closed = false,
    }
    local panel = box("ClosedPanel", Vec.new(5, 0, -3), Vec.new(5.5, 8, 3), short)
    panel.door = short
    Doors = { short, far }
    world.route = function(from, to)
        if from.X < 0 and to.X > 5 then
            return {
                { Position = from, Action = "Walk" },
                { Position = Vec.new(from.X, 0, 10), Action = "Walk" },
                { Position = Vec.new(to.X, 0, 10), Action = "Walk" },
                { Position = to, Action = "Walk" },
            }
        end
        return { { Position = from, Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local result = Follow.FindDoorRoute(
        7,
        root.Position,
        Vec.new(12, 3, 0),
        nil,
        function() return true end,
        nil,
        nil,
        Vec.new(12, 3, 0),
        {},
        100,
        50
    )
    check(
        result and result.Door == short,
        "rescue preferred a much longer already-open route over opening a reachable door"
    )
end)
scenario("nearby pod contact never reaches through a different room wall", function()
    if not FH.PodContactReady then return end
    local info = pod(4.8)
    box("RoomWall", Vec.new(1.3, 0, -3), Vec.new(1.5, 8, 3))
    check(not FH.PodContactReady(info.trig, hum, root), "pod contact bypassed room boundary")
end)
for _, problem in ipairs(failures) do
    print(problem)
end
print("Navigation scenarios", scenarios, "checks", checks, "failures", #failures)
assert(#failures == 0, "navigation/native interaction regression")
