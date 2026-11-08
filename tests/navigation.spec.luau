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
function Node:FindFirstChildOfClass(class)
    if class == "Humanoid" and self.hum then return self.hum end
    for _, child in ipairs(self.children) do if child:IsA(class) then return child end end
end
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
function Players:GetPlayers() return world and world.players or { LocalPlayer } end
local Computers = {}
local Doors, DoorFail, DoorTries, DoorOpenedAt, ExitDoors = {}, {}, {}, {}, {}
local function IsInWorld(item) return item and item.Parent ~= nil end
local warn = function(...) if world then world.warning = tostring(...) end end
local unloaded = false
local remoteHackActive, remoteHackEvent = false, nil
local REMOTE_HACK_RANGE = 20
local function IsComputerDone(comp) return comp.done == true end
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
    if world and world.frameStep then
        local started, deadline = now, now + dt
        while now < deadline - 1e-7 do step(world.frameStep) end
        return now - started
    end
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
function FH.Stat(player, names)
    if player ~= LocalPlayer then return player.stats and player.stats[names[1]] end
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
function FH.ExitOpen() return world.exitsEnabled == true end
function FH.InMatchPlayer(player) return player.Parent == Players and player.inRound ~= false end
function FH.ExitDoorOpen(door) return door.open == true end
function FH.ExitArea(door) return door.center, door.areaSize, door.area end
function FH.ExitLoiter() return false end
function AH.RescueContext() return world.rescueContext == true end
function AH.ThreatRange(value) return world.rescueContext and value / 3 or value end
function AH.SetState(value) AH.State = value end
function FH.MatchOn() return world.roundOn ~= false end
function FH.GameInfo() return world.gameInfo or {} end
function FH.ExitScreensDone() return false end
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
function Ctl.Gate()
    if world.blockingManualGate and world.manual then
        while world.manual do task.wait(0.03) end
        return true
    end
    return world.manual == true
end
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
function AR.SetBusy(value) AR.BusyFlag = value end
function AR.Pending() return world.pending == true end
function AR.Pods() return world.pods or {} end
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
    local args = { ... }
    if world.door and args[1] == "Input" and args[2] == "Action" and args[3] == true then
        world.doorStarted = world.doorStarted or now
        stats.ActionEvent.Value = world.doorEvent
    end
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
-- Convex wedge geometry: clip rays/swept boxes against six half-spaces.
-- This is a different support model from the axis-aligned tread fixtures.
local function wedge(x0, x1, z0, z1, height)
    local a = height / (x1 - x0)
    local item = { x0 = x0, x1 = x1, z0 = z0, z1 = z1, height = height, slope = a,
        part = part("RampWedge", Vec.new((x0+x1)/2, height/2, (z0+z1)/2), Vec.new(x1-x0,height,z1-z0), map) }
    item.planes = { {Vec.new(-1,0,0),-x0}, {Vec.new(1,0,0),x1}, {Vec.new(0,0,-1),-z0},
        {Vec.new(0,0,1),z1}, {Vec.new(0,-1,0),0.1}, {Vec.new(-a,1,0),-a*x0} }
    world.wedges = world.wedges or {}
    table.insert(world.wedges, item)
    return item
end
local function clipWedge(p, d, item, extent)
    extent = extent or Vec.new()
    local enter, leave, normal, inside = 0, 1, Vec.new(), true
    for _, plane in ipairs(item.planes) do
        local n = plane[1]
        local bound = plane[2] + math.abs(n.X)*extent.X + math.abs(n.Y)*extent.Y + math.abs(n.Z)*extent.Z
        local distance, speed = n:Dot(p)-bound, n:Dot(d)
        if distance >= -1e-7 then inside = false end
        if math.abs(speed) < 1e-9 then
            if distance > 0 then return nil end
        else
            local t = -distance/speed
            if speed < 0 then
                if t >= enter then enter, normal = t, n.Unit end
            else leave = math.min(leave, t) end
            if enter > leave then return nil end
        end
    end
    if inside or enter < 0 or enter > 1 then return nil end
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
    for _, item in ipairs(world.wedges or {}) do
        if item.part.CanCollide and not excluded(item.part, params) then
            local t, n = clipWedge(p, d, item)
            if t and (not best or t < best) then best, normal, instance = t, n, item.part end
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
    for _, item in ipairs(world.wedges or {}) do
        if item.part.CanCollide and not excluded(item.part, params) then
            local t, n = clipWedge(frame.Position, movement, item, extent)
            if t and (not best or t < best) then best, normal, instance = t, n, item.part end
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
    world.pathObjects = world.pathObjects or {}
    table.insert(world.pathObjects, p)
    function p:ComputeAsync(from, to)
        world.firstComputeAt = world.firstComputeAt or now
        task.wait(type(world.planDelay) == "function" and world.planDelay(#world.pathSpecs) or world.planDelay)
        if world.noNativePath then self.Status = Enum.PathStatus.NoPath; self.wps = {}; return end
        self.wps = world.route and world.route(from, to, spec)
            or { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" }, { Position = to, Action = "Walk" } }
        if not self.wps then
            self.Status = Enum.PathStatus.NoPath
            self.wps = {}
        end
    end
    function p:GetWaypoints()
        if world.pathYOffset and not self.offsetApplied then
            self.offsetApplied = true
            for _, waypoint in ipairs(self.wps) do waypoint.Position += Vec.new(0, world.pathYOffset, 0) end
        end
        return self.wps
    end
    function p:Destroy() self.destroyed = true end
    return p
end
local function nativeKey(code, down)
    local key = code == 0x20 and "Space" or code == 0x45 and "E" or code == 0x57 and "W" or code
    if world.keys[key] == down then return end
    world.keys[key] = down
    table.insert(world.inputs, { key = key, down = down, at = now, p = root.Position })
    if not down then return end
    if key == "Space" then
        if world.ignoreSpaceAfterX and root.Position.X >= world.ignoreSpaceAfterX and not world.ignoredSpace then
            world.ignoredSpace = true
            return -- Executor reports admission; the native controller sees no edge.
        end
        if (world.airReport and world.physicalMaterial or hum.FloorMaterial) ~= "Air" then
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
        elseif world.door and (root.Position - world.doorTrigger.Position).Magnitude <= 3.6 then
            world.doorStarted = world.doorStarted or now
            stats.ActionEvent.Value = world.doorEvent
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
    runReady() -- Client callbacks see reported state; physics retains its own state.
    if world.airReport and world.physicalMaterial then
        hum.FloorMaterial, hum.State = world.physicalMaterial, world.physicalState
    end
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
    if world.engaged and not world.freezeProgress then
        stats.ActionProgress.Value += dt * 0.02
        if stats.ActionProgress.Value >= world.completeAt then
            world.pc.done = true
            world.engaged = false
        end
    end
    if world.rescueAt and now - world.rescueAt >= world.rescueDelay then world.captive.Value = nil end
    if world.doorStarted then
        local elapsed = now - world.doorStarted
        stats.ActionInput.Value = elapsed < 0.1
        stats.ActionProgress.Value = math.min(elapsed / 1.8, 1)
        if elapsed >= 2.05 then
            world.door.closed = false
            world.doorPanel.CanCollide = false
        end
    end
    hum.nativeDir = Vec.new() -- Roblox's own no-input update, before our render controller.
    local actualFloor, actualState = hum.FloorMaterial, hum.State
    world.physicalMaterial, world.physicalState = actualFloor, actualState
    if world.airReport and root.Position.X >= (world.airReportX or -math.huge) then
        hum.FloorMaterial, hum.State = "Air", "Freefall"
    end
    if world.floorLag and world.firstAt and now - world.firstAt < world.floorLag then
        hum.FloorMaterial = "Ground"
        hum.State = world.vy > 0 and "Jumping" or "Freefall"
    end
    FH.MotionStep(dt)
    hum.FloorMaterial = actualFloor
    if world.airReport then hum.State = actualState end
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
    for _, item in ipairs(world.wedges or {}) do
        local y = (candidate.X-item.x0)*item.slope
        if candidate.X >= item.x0 and candidate.X <= item.x1 and candidate.Z >= item.z0 and candidate.Z <= item.z1
            and y <= math.max(feet,nextFeet)+1.05 then floor = math.max(floor,y) end
    end
    if hum.FloorMaterial ~= "Air" then nextFeet = floor end
    if hum.FloorMaterial == "Air" and world.vy <= 0 and nextFeet <= floor then
        nextFeet = floor
        world.vy = 0
        hum.FloorMaterial = "Ground"
    end
    local stepBlocked = hum.FloorMaterial ~= "Air" and world.stepHeight ~= nil and floor > feet + world.stepHeight
    local blocked = stepBlocked
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
        if stepBlocked then nextFeet = feet end
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
    local observedY = world.vy
    if hum.FloorMaterial ~= "Air" and world.wedges and #world.wedges > 0 then observedY = (root.Position.Y-before.Y)/dt end
    root.AssemblyLinearVelocity =
        Vec.new((root.Position.X - before.X) / dt, observedY, (root.Position.Z - before.Z) / dt)
    hum.State = hum.FloorMaterial == "Air" and (world.vy > 0 and "Jumping" or "Freefall") or "Running"
    if world.trigger and not world.engaged then
        stats.ActionEvent.Value = Flat(root.Position - world.trigger.Position).Magnitude <= world.selectRange
                and world.event
            or nil
    end
    updateParts()
    world.physicalMaterial, world.physicalState = hum.FloorMaterial, hum.State
    if world.airReport and root.Position.X >= (world.airReportX or -math.huge) then
        hum.FloorMaterial, hum.State = "Air", "Freefall"
    end
    if world.frameSample then world.frameSample(dt) end
    if world.cancelAt and now >= world.cancelAt then world.manual = true end
    if world.exitsEnabled then
        for _, exit in ipairs(ExitDoors) do
            if exit.open and (root.Position - exit.center).Magnitude < 1 then stats.Escaped.Value = true end
        end
    end
end
local function reset()
    now = 100
    scheduled = {}
    remoteHackActive, remoteHackEvent = false, nil
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
        assert((world.airReport and world.physicalMaterial or self.FloorMaterial) ~= "Air", "script forced an airborne jump state")
        if state == "Jumping" then world.launch = true; world.engineJumps = (world.engineJumps or 0) + 1 end
    end
    LocalPlayer.Character.hum = hum
    stats = { Health = { Value = 100 }, Escaped = { Value = false }, ActionInput = { Value = false }, ActionEvent = {}, ActionProgress = { Value = 0 } }
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
    FH.Endgame, FH.EndAt = { on = false }, 0
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
    -- EXIT_TEAM_RANGE
    Follow.InAt = 0
    Follow.Beat = now
    Follow.Debug = false
    AH.BusyFlag = false
    AH.Active = false
    AH.ExitState, AH.ThreatMap, AH.ThreatRound, AH.BeastMotion = nil, nil, nil, nil
    AH.EvalAt, AH.AfkCheckAt, AH.NearRange, AH.SeeRange = 0, math.huge, 32, 75
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
    Doors, DoorFail, DoorTries, DoorOpenedAt, ExitDoors = {}, {}, {}, {}, {}
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
scenario("static ActionInput cannot keep a non-progressing keyboard forever", function()
    local comp = computer(4)
    world.freezeProgress = true
    stats.ActionInput.Value = true
    local result = FH.ComputerContact(7, comp, world.trigger, function() return false end)
    check(result == "unconfirmed", "static input accepted as endless work: " .. tostring(result))
    check(not comp.done and not FH.IsWorking(7) and not Follow.KeyDown, "failed keyboard retained input/work")
end)
scenario("real PC progress outlives the inactivity limit", function()
    local comp = computer(4)
    world.completeAt = 0.14 -- seven seconds of real work; fixture HackMax is five.
    local result = FH.ComputerContact(7, comp, world.trigger, function() return false end)
    check(result == "done" and comp.done and now > 107, "active hack was abandoned by elapsed wall time")
end)
scenario("retained remote target does not freeze a walking farm", function()
    computer(4)
    remoteHackActive, remoteHackEvent = true, world.event
    FH.Move(7, hum, Vec.new(2, 3, 0))
    task.wait(0.08)
    check(root.Position.X > 0.8, "remote target proximity suppressed actual steering")
end)
scenario("released farm typing cannot freeze the new rescue owner", function()
    computer(4)
    stats.ActionInput.Value, stats.ActionEvent.Value = true, world.event
    stats.IsTyping = { Value = true }
    world.pending = true
    AH.Active, AR.Active, AH.BusyFlag = true, true, false
    local rescue = rescueToken()
    check(FH.MotionPriority(rescue) > FH.MotionPriority({ owner = "evade", priority = 80 }), "rescue lost arbitration")
    check(FH.Move(rescue, hum, Vec.new(-4, 3, 0)), "rescue could not claim movement")
    task.wait(0.1)
    check(root.Position.X < -1, "old farm acknowledgement froze rescue render input")
    check(not FH.Move(7, hum, Vec.new(4, 3, 0)), "farm overwrote rescue movement")
end)
scenario("selected PC slot does not also reserve the neighbouring keyboard", function()
    local comp, middle = computer(8)
    local left = part("ComputerTrigger2", Vec.new(8, 3, -3), Vec.new(1, 1, 0.6), comp, false)
    node("Event", "RemoteEvent", left)
    local other = { Character = node("Hacker", "Model", map.Parent), stats = {} }
    part("HumanoidRootPart", Vec.new(8, 3, -1.7), Vec.new(2, 2, 1), other.Character, false)
    other.stats.ActionEvent = { Value = middle:FindFirstChild("Event") }
    world.players = { LocalPlayer, other }
    check(FH.ComputerSlotTaken(comp, middle), "game-selected keyboard was not occupied")
    check(not FH.ComputerSlotTaken(comp, left), "one hacker incorrectly reserved two keyboards")
end)
scenario("real farm wrapper selects free neighbouring PC slot", function()
    local comp, middle = computer(4)
    local left = part("ComputerTrigger2", Vec.new(4, 3, -3), Vec.new(1, 1, 0.6), comp, false)
    local leftEvent = node("Event", "RemoteEvent", left)
    local other = { Character = node("Hacker", "Model", map.Parent), stats = {} }
    part("HumanoidRootPart", Vec.new(4, 3, -1.7), Vec.new(2, 2, 1), other.Character, false)
    other.stats.ActionEvent = { Value = middle:FindFirstChild("Event") }
    world.players = { LocalPlayer, other }
    root.Position = Vec.new(0, 3, -3)
    world.trigger, world.event, world.completeAt = left, leftEvent, 0.02
    Follow.TestMainContact(7, LocalPlayer)(comp)
    check(comp.done, "farm skipped an available keyboard beside an occupied one")
    check(now - 100 < 3, "farm delayed the free-slot handoff")
end)
scenario("farm rescue closes the last contact gap without a new path job", function()
    local info = pod(5.65)
    -- Capsule contact is 1.65 studs away, beyond rescue admission but visible.
    world.planDelay = 10
    local walkTo, calls = Follow.WalkTo, 0
    -- Model a completed path that stops 1.35 studs outside the trigger:
    -- 0.55 contact goal + 0.8 waypoint tolerance. Interaction physics stays real.
    Follow.WalkTo = function()
        calls += 1
        root.Position = Vec.new(0.3, 3, 0)
        return "arrived"
    end
    local firstPress
    local result = FH.RescuePod(7, function() return true end, info, nil,
        function() firstPress = firstPress or now; nativeKey(0x45, true) end,
        function() nativeKey(0x45, false) end)
    Follow.WalkTo = walkTo
    check(result == "done", "numeric farm owner did not start rescue from the final gap")
    check(calls == 0, "last metre unnecessarily restarted routing")
    check(firstPress and firstPress - 100 < 0.12, "waited for pathfinding before pressing rescue")
    check(world.blocked == 0, "contact advance rammed the capsule")
end)
scenario("three PC slots are checked independently and update during travel", function()
    if not FH.ComputerSlotTaken then return end -- Helper was introduced after the baseline.
    local comp, middle = computer(8)
    local left = part("ComputerTrigger2", Vec.new(8, 3, -3), Vec.new(1, 1, 0.6), comp, false)
    local right = part("ComputerTrigger3", Vec.new(8, 3, 3), Vec.new(1, 1, 0.6), comp, false)
    node("Event", "RemoteEvent", left)
    node("Event", "RemoteEvent", right)
    local other = { Character = node("Other", "Model", map.Parent), stats = {} }
    local r = part("HumanoidRootPart", Vec.new(6, 3, 0), Vec.new(2, 2, 1), other.Character, false)
    world.players = { LocalPlayer, other }
    check(FH.ComputerSlotTaken(comp, middle), "standing two studs from occupied keyboard was missed")
    check(not FH.ComputerSlotTaken(comp, left) and not FH.ComputerSlotTaken(comp, right), "one player occupied all three slots")
    other.stats.ActionEvent = { Value = left:FindFirstChild("Event") }
    r.Position = Vec.new(8, 3, -3)
    check(FH.ComputerSlotTaken(comp, left) and not FH.ComputerSlotTaken(comp, middle), "slot occupancy was cached after a player switched")
    r.Position = Vec.new(50, 3, 0)
    check(not FH.ComputerSlotTaken(comp, left), "freed keyboard stayed occupied")
end)
scenario("replanning keeps the verified leg toward an upstairs connector", function()
    box("UpperWalkway", Vec.new(-2, 8.2, -2), Vec.new(22, 8.4, 2))
    world.route = function(from, to)
        return {
            { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(0, 0, 30), Action = "Walk" },
            { Position = Vec.new(30, 0, 30), Action = "Walk" },
            { Position = to, Action = "Walk" },
        }
    end
    local before, after
    task.delay(0.2, function()
        before = root.Position
        world.planDelay = 1
        FH.Motion.replanToken = 7
        task.delay(0.6, function() after = root.Position end)
    end)
    Follow.WalkTo(7, function() return Vec.new(0, 11.4, 0) end, 0.8, nil, { noDoor = true, maxTime = 0.9 })
    check(before and after and Flat(after - before).Magnitude > 6, "replan discarded safe connector leg and stopped below the target")
end)
scenario("stationary intent against a solid wall never fabricates a jump", function()
    box("TallWall", Vec.new(1.5, 0, -10), Vec.new(2, 20, 10))
    FH.Move(7, hum, Vec.new(8, 3, 0))
    FH.StallIntent = { token = 7, hum = hum, root = root, anchor = root.Position, at = now - 1, seen = now, goal = Vec.new(8, 3, 0) }
    FH.StallJumpStep()
    task.wait(0.02)
    check(world.jumps == 0, "generic stall timer jumped at a proven full-height wall")
end)
scenario("unreleased pod stops retrying a silent contact and never claims completion", function()
    local info = pod(7)
    world.rescueDelay = 1000
    local tok = rescueToken()
    local result = FH.RescuePod(tok, tok.ok, info, nil,
        function() AR.KeyDown = true end,
        function() AR.KeyDown = false end, nil, 5.2)
    check(result == "unconfirmed" and world.captive.Value ~= nil, "pod timer was accepted as actual release")
    check(now < 106 and not AR.KeyDown, "silent rescue contact kept the player standing indefinitely")
end)
scenario("AutoHelp reaches an upstairs pod through the real stair connector", function()
    local info = pod(0)
    info.trig.Position += Vec.new(0, 8.4, 0)
    info.trig.CFrame = cf(info.trig.Position)
    for _, b in ipairs(world.boxes) do
        if b.part.Name == "Capsule" then
            b.lo += Vec.new(0, 8.4, 0)
            b.hi += Vec.new(0, 8.4, 0)
            b.part.Position += Vec.new(0, 8.4, 0)
        end
    end
    box("UpperWalkway", Vec.new(-2, 8.2, -2), Vec.new(22, 8.4, 2))
    for i = 1, 24 do
        box("Stair", Vec.new(8 + (i - 1) * 0.5, 0, 6), Vec.new(8 + i * 0.5, i * 0.35, 10))
    end
    box("UpperLanding", Vec.new(20, 8.2, -2), Vec.new(23, 8.4, 10))
    if FH.PodRouteGoal then
        local routeGoal = FH.PodRouteGoal(info.trig, root.Position)
        check(routeGoal.Y > 8, "pod route goal was projected onto the avatar's lower floor")
        check(FH.ContactDistance(info.trig, routeGoal) > 0.1, "route aimed inside the capsule footprint")
    end
    world.route = function(from, to)
        local points = { Vec.new(from.X, 0, from.Z), Vec.new(4, 0, 8), Vec.new(8, 0, 8) }
        for i = 4, 24, 4 do table.insert(points, Vec.new(8 + i * 0.5, i * 0.35, 8)) end
        table.insert(points, Vec.new(21, 8.4, 0))
        table.insert(points, to)
        local result = {}
        for _, p in ipairs(points) do table.insert(result, { Position = p, Action = "Walk" }) end
        return result
    end
    local tok = rescueToken()
    local realWalkTo, firstGoal = Follow.WalkTo, nil
    Follow.WalkTo = function(token, getGoal, ...)
        firstGoal = firstGoal or getGoal()
        return realWalkTo(token, getGoal, ...)
    end
    local result = FH.RescuePod(tok, tok.ok, info, nil,
        function() AR.KeyDown = true; nativeKey(0x45, true) end,
        function() AR.KeyDown = false; nativeKey(0x45, false) end, nil, 5.2)
    Follow.WalkTo = realWalkTo
    check(firstGoal and firstGoal.Y > 8, "first rescue route led underneath the upstairs pod")
    check(result == "done" and world.captive.Value == nil and root.Position.Y > 11,
        "rescue failed on actual upper floor: " .. tostring(result))
    check(now < 108, "rescue wasted time underneath the upper pod")
end)
scenario("AutoHelp ranks feasible route length rather than only pod distance", function()
    local nearPod = pod(8)
    local farPod = pod(-18)
    world.pods = { nearPod, farPod }
    box("Partition", Vec.new(4, 0, -10), Vec.new(5, 8, 10))
    AR.PodRoutes = {
        [nearPod.trig] = { from = root.Position, at = now, length = 60, occupant = nearPod.occupant, map = map },
    }
    local pick = AR.Nearest()
    check(pick == farPod, "nearby pod behind long detour beat the shorter reachable rescue")
    check(AR.Nearest() == farPod, "rescue changed targets without new route evidence")
end)
scenario("AutoHelp changes contact side after an unconfirmed rescue attempt", function()
    local info = pod(7)
    world.rescueDelay = 1000
    local tok = rescueToken()
    local first = FH.RescuePod(tok, tok.ok, info, nil,
        function() AR.KeyDown = true end, function() AR.KeyDown = false end, nil, 5.2)
    check(first == "unconfirmed", "fixture did not produce failed rescue contact")
    local failedPosition = root.Position
    world.rescueDelay = 0.08
    local result = FH.RescuePod(tok, tok.ok, info, nil,
        function() AR.KeyDown = true; nativeKey(0x45, true) end,
        function() AR.KeyDown = false; nativeKey(0x45, false) end, nil, 5.2)
    check(result == "done" and world.captive.Value == nil, "rescue did not recover from failed contact")
    check(Flat(root.Position - failedPosition).Magnitude > 1.5, "retried the exact same failed pod contact")
end)
scenario("a passing player cannot evict an actively progressing hack", function()
    local comp = computer(4)
    world.completeAt = 0.06
    local other = { Character = node("Visitor", "Model", map.Parent), stats = {} }
    local visitorRoot = part("HumanoidRootPart", Vec.new(40, 3, 0), Vec.new(2, 2, 1), other.Character, false)
    world.players = { LocalPlayer, other }
    task.delay(0.5, function() visitorRoot.Position = world.trigger.Position - Vec.new(2, 0, 0) end)
    local result = FH.ComputerContact(7, comp, world.trigger, function() return false end)
    check(result == "done" and comp.done, "slot proximity evicted a keyboard whose real progress was increasing")
end)
local function openingDoor()
    local model = node("SingleDoor", "Model", map)
    local trig = part("DoorTrigger", Vec.new(3, 3, 0), Vec.new(6, 3, 8), model, false)
    local event = node("Event", "RemoteEvent", trig)
    local panel = box("Panel", Vec.new(5.75, 0, -4), Vec.new(6.25, 8, 4), model)
    local geometry = { Door = model, Center = Vec.new(6, 3, 0), Dir = Vec.new(1, 0, 0),
        NearPos = trig.Position, NearTrig = trig, FarPos = Vec.new(10, 3, 0),
        Size = Vec.new(0.5, 6, 8), FloorY = 0, closed = true,
        ApproachStand = Vec.new(3, 3, 0), ApproachTrig = trig }
    panel.door = model
    model.geom = geometry
    world.door, world.doorPanel, world.doorTrigger, world.doorEvent = geometry, panel, trig, event
    return geometry, trig
end
scenario("door progress remains active after ActionInput becomes false", function()
    local _, trig = openingDoor()
    stats.ActionEvent.Value = world.doorEvent
    stats.ActionInput.Value = false
    local meter = {}
    stats.ActionProgress.Value = 0.1
    Follow.DoorOpening(trig, meter)
    task.wait(0.15)
    stats.ActionProgress.Value = 0.2
    check(Follow.DoorOpening(trig, meter) == true, "advancing native door action was mistaken for an ignored E")
    task.wait(0.9)
    check(Follow.DoorOpening(trig, meter) == false, "static door progress retained an unbounded opening proof")
end)
scenario("the actual door controller opens and crosses without repeated E edges", function()
    local geometry = openingDoor()
    local result = Follow.PassDoor(7, geometry)
    local presses = 0
    for _, e in ipairs(world.inputs) do if e.key == "E" and e.down then presses += 1 end end
    check(result == true and root.Position.X >= 8.8, "door controller never crossed its confirmed open portal")
    check(presses == 1, "the active door opening was interrupted by extra E edges: " .. tostring(presses))
    check(now < 103.5 and world.jumps == 0 and not Follow.KeyDown, "door added unnecessary waiting/jumps or retained E")
end)
scenario("manual input interrupts door opening without crossing or held E", function()
    local geometry = openingDoor()
    task.delay(0.5, function() world.manual = true end)
    local result = Follow.PassDoor(7, geometry)
    check(not result and root.Position.X < 5, "door crossing ignored manual takeover")
    check(not Follow.KeyDown and Follow.Held == nil, "manual cancellation left door input held")
end)
scenario("native jump state survives a delayed solid FloorMaterial report", function()
    world.floorLag = 0.18
    local goal = Vec.new(20, 3, 0)
    FH.Move(7, hum, goal)
    check(FH.Jump(hum, true, 7), "native first jump was rejected")
    task.wait(0.29)
    local spaces = {}
    for _, e in ipairs(world.inputs) do if e.key == "Space" and e.down then table.insert(spaces, e.at) end end
    check(world.doubles == 1 and #spaces == 2 and spaces[2] - spaces[1] <= 0.28,
        "second Space waited an extra airborne timer after delayed FloorMaterial")
    check(root.Position.X > 4 and hum.JumpPower == 36 and hum.JumpHeight == 7.2,
        "native window crossing lost forward travel or modified jump properties")
end)
scenario("a stale solid floor cannot authorize a fresh airborne first jump", function()
    hum.FloorMaterial, hum.State = "Ground", "Freefall"
    root.AssemblyLinearVelocity = Vec.new(16, 20, 0)
    check(not FH.TakeoffSupported(hum, root), "stale FloorMaterial manufactured grounded support during ascent")
end)
scenario("door progress cannot transfer to a newly selected trigger", function()
    local geometry, trig = openingDoor()
    local meter = {}
    stats.ActionEvent.Value, stats.ActionProgress.Value = world.doorEvent, 0.3
    Follow.DoorOpening(trig, meter)
    local other = part("DoorTrigger", Vec.new(3, 3, 8), Vec.new(6, 3, 8), geometry.Door, false)
    local event = node("Event", "RemoteEvent", other)
    stats.ActionEvent.Value, stats.ActionProgress.Value = event, 0
    check(not Follow.DoorOpening(other, meter), "old trigger progress was reused for a different selected interaction")
end)
scenario("a verified lower landing keeps native fall and forward steering", function()
    box("UpperPlatform", Vec.new(-10, 0, -5), Vec.new(3, 20, 5))
    root.Position = Vec.new(0, 23, 0)
    updateParts()
    local result = Follow.WalkTo(7, function() return Vec.new(5, 3, 0) end, 0.8, nil, { noDoor = true, maxTime = 3 })
    check(result == "arrived" and root.Position.Y < 3.2 and root.Position.X > 4,
        "verified descent stopped on the upper lip or steered back during the fall")
    check(world.jumps == 0 and hum.JumpPower == 36, "clear descent fabricated an unnecessary jump or boost")
end)
local function actor(name, position, beast, look, velocity)
    local player = { Parent = Players, Character = node(name, "Model", map.Parent),
        stats = { Health = { Value = 100 }, IsBeast = { Value = beast == true }, Escaped = { Value = false } } }
    player.Character.hum = { Health = 100 }
    local r = part("HumanoidRootPart", position, Vec.new(2, 2, 1), player.Character, false)
    r.CFrame, r.AssemblyLinearVelocity = cf(position, look or Vec.new(1, 0, 0)), velocity or Vec.new()
    return player, r
end
local function openExit(x)
    local exit = node("ExitDoor", "Model", map)
    exit.open, exit.center = true, Vec.new(x, 3, 0)
    local sign = x >= 0 and -1 or 1
    local trigger = part("ExitDoorTrigger", exit.center + Vec.new(sign * 3, 0, 0), Vec.new(3, 3, 3), exit, false)
    node("Event", "RemoteEvent", trigger)
    ExitDoors[#ExitDoors + 1] = exit
    world.exitsEnabled = true
    return exit
end
local function exitPlayers()
    local a = actor("TeammateA", Vec.new(80, 3, 0))
    local b = actor("TeammateB", Vec.new(100, 3, 0))
    local beast, br = actor("Beast", Vec.new(150, 3, 0), true, Vec.new(-1, 0, 0), Vec.new(-16, 0, 0))
    world.players = { LocalPlayer, a, b, beast }
    return a, b, beast, br
end
scenario("rescue adopts the forward segment after passing an old waypoint", function()
    root.Position = Vec.new(11, 3, 0); updateParts()
    local path = { { Position = Vec.new(0, 0, 0), Action = "Walk" },
        { Position = Vec.new(10, 0, 0), Action = "Walk" }, { Position = Vec.new(20, 0, 0), Action = "Walk" } }
    check(Follow.PathIndex(path, root.Position, 0, true) == 3, "delayed rescue plan pulled avatar back to its nearer old vertex")
end)
scenario("native stair route uses the floor rather than root-height waypoint Y", function()
    world.pathYOffset = 3
    for i = 1, 24 do box("Step", Vec.new(i * 0.5, 0, -3), Vec.new(i * 0.5 + 0.5, i * 0.35, 3)) end
    box("Landing", Vec.new(12.5, 0, -3), Vec.new(30, 8.4, 3))
    world.route = function(from, goal)
        local result = { { Position = Vec.new(0, 0, 0), Action = "Walk" } }
        for i = 4, 24, 4 do table.insert(result, { Position = Vec.new(i * 0.5, i * 0.35, 0), Action = "Walk" }) end
        table.insert(result, { Position = Vec.new(26, 8.4, 0), Action = "Walk" })
        return result
    end
    local result = Follow.WalkTo(7, function() return Vec.new(26, 11.4, 0) end, 0.8, nil, { noDoor = true, maxTime = 6 })
    check(result == "arrived" and root.Position.X > 25, "stair controller waited at a waypoint above the walking surface")
    check(world.jumps <= 3, "stair waypoint height mismatch caused repeated jumps")
end)
scenario("landing on a higher tread rearms a real next hop without a fixed pause", function()
    FH.Move(7, hum, Vec.new(16, 4.2, 0))
    box("RaisedTread", Vec.new(1, 0, -4), Vec.new(20, 1.2, 4))
    check(FH.NormalJump(hum), "first hop was refused")
    task.wait(0.4)
    check(hum.FloorMaterial ~= "Air" and FH.Feet(hum, root) > 1,
        "fixture did not land on higher support")
    check(FH.NormalJump(hum), "fixed cooldown stranded a progressed avatar on the next raised tread")
end)
scenario("two open exits still produce approach and stable waiting", function()
    local exit = openExit(30); openExit(-70)
    exitPlayers()
    local state = {}
    check(FH.ExitPriority(), "two open doors failed to activate exit controller")
    local result = FH.ExitRoute(7, state)
    check(result == "waiting" and root.Position.X > 17 and not stats.Escaped.Value,
        "bot froze in the room or escaped before the wait policy")
    local anchor = root.Position
    FH.ExitRoute(7, state); task.wait(0.1)
    check(state.door == exit and Flat(root.Position - anchor).Magnitude < 0.5, "waiting switched doors or retained a movement destination")
end)
scenario("exit waits for multiple far teammates then leaves when only one remains", function()
    openExit(20); openExit(-40)
    local a, b = exitPlayers()
    local state = {}
    check(FH.ExitRoute(7, state) == "waiting", "did not establish open-exit waiting state")
    b.stats.Escaped.Value = true
    local started = now
    local result = FH.ExitRoute(7, state)
    if result == "redirect" then task.wait(0.03); result = FH.ExitRoute(7, state) end
    check(result == "escaped" and stats.Escaped.Value and now - started < 1.5,
        "one remaining teammate did not trigger immediate native exit traversal")
end)
scenario("all surviving teammates within 15 studs authorize leaving", function()
    openExit(20)
    local a, b = exitPlayers()
    a.Character:FindFirstChild("HumanoidRootPart").Position = Vec.new(15, 3, 0)
    b.Character:FindFirstChild("HumanoidRootPart").Position = Vec.new(6, 3, 0)
    check(FH.ExitPolicy(Vec.new(20, 3, 0), Vec.new(11, 3, 0)), "nearby 14-stud teammate was rejected")
    b.Character:FindFirstChild("HumanoidRootPart").Position = Vec.new(4, 3, 0)
    check(not FH.ExitPolicy(Vec.new(20, 3, 0), Vec.new(11, 3, 0)), "16-stud teammate was counted as assembled")
end)
scenario("Beast near an open waiting exit triggers escape instead of repicking", function()
    local exit = openExit(20); openExit(-60)
    local _, _, _, br = exitPlayers()
    local state = {}
    check(FH.ExitRoute(7, state) == "waiting", "could not reach exit wait")
    br.Position = root.Position + Vec.new(-12, 0, 0)
    local result = FH.ExitRoute(7, state)
    if result == "redirect" then task.wait(0.03); result = FH.ExitRoute(7, state) end
    check(result == "escaped" and state.door == exit and stats.Escaped.Value,
        "threat cancelled the already-open selected exit instead of escaping")
end)
scenario("AutoHide alarms only on a facing, visible closing Beast", function()
    local beast, br = actor("Beast", Vec.new(20, 3, 0), true, Vec.new(-1, 0, 0), Vec.new(-16, 0, 0))
    world.players = { LocalPlayer, beast }
    check(AH.TestEval().danger, "facing and approaching Beast did not raise alarm")
    br.CFrame, br.AssemblyLinearVelocity = cf(br.Position, Vec.new(1, 0, 0)), Vec.new(16, 0, 0)
    task.wait(0.06)
    check(not AH.TestEval().danger, "retreating Beast kept the alarm active")
    br.CFrame, br.AssemblyLinearVelocity = cf(br.Position, Vec.new(0, 0, 1)), Vec.new(0, 0, 16)
    task.wait(0.06)
    check(not AH.TestEval().danger, "lateral passing Beast raised alarm")
    br.CFrame, br.AssemblyLinearVelocity = cf(br.Position, Vec.new(-1, 0, 0)), Vec.new()
    task.wait(0.06)
    check(not AH.TestEval().danger, "stationary facing Beast raised a movement alarm")
end)
scenario("wall and different floor suppress directional AutoHide alarm", function()
    local beast, br = actor("Beast", Vec.new(20, 3, 0), true, Vec.new(-1, 0, 0), Vec.new(-16, 0, 0))
    world.players = { LocalPlayer, beast }
    local wall = box("Wall", Vec.new(8, 0, -5), Vec.new(9, 10, 5))
    check(not AH.TestEval().danger, "directional alarm reached through wall")
    wall.CanCollide = false; br.Position += Vec.new(0, 12, 0); task.wait(0.06)
    check(not AH.TestEval().danger, "directional alarm confused floors")
end)
scenario("half of remaining survivors at one exit includes 2/3 and 2/4", function()
    local exit = openExit(20); openExit(-40)
    root.Position = Vec.new(11, 3, 0); updateParts()
    local a, b = exitPlayers()
    local ar = a.Character:FindFirstChild("HumanoidRootPart")
    ar.Position = Vec.new(19, 3, 0)
    check(FH.ExitPolicy(exit.center, Vec.new(11, 3, 0)), "two of three survivors at the same exit did not authorize leaving")
    local c = actor("TeammateC", Vec.new(120, 3, 0)); table.insert(world.players, c)
    check(FH.ExitPolicy(exit.center, Vec.new(11, 3, 0)), "two of four survivors at the same exit did not authorize leaving")
    ar.Position = Vec.new(-39, 3, 0)
    check(not FH.ExitPolicy(exit.center, Vec.new(11, 3, 0)), "survivors split across different exits were merged into one assembled group")
end)
scenario("confirmed exit unlock survives disappearing UI but resets for a new round", function()
    world.gameInfo = { computersLeft = 0 }
    check(FH.TestExitOpen(), "explicit unlock was ignored")
    world.gameInfo = {}; task.wait(0.6)
    check(FH.TestExitOpen(), "both-open stage lost unlock when UI no longer contained the message")
    world.gameInfo = { computersLeft = 2 }
    check(not FH.TestExitOpen(), "new-round computers inherited old unlock")
end)
scenario("directional threat uses observed motion if replicated velocity is zero", function()
    local beast, br = actor("Beast", Vec.new(20, 3, 0), true, Vec.new(-1, 0, 0), Vec.new())
    world.players = { LocalPlayer, beast }
    check(not AH.TestEval().danger, "stationary first observation raised movement alarm")
    task.wait(0.1); br.Position -= Vec.new(1.6, 0, 0)
    check(AH.TestEval().danger, "physically approaching Beast with missing velocity was ignored")
end)
scenario("all three modes hand movement to exit when waiting policy becomes ready", function()
    if not FH.ExitEscapePending then return end -- New helper absent from baseline.
    openExit(20)
    root.Position = Vec.new(11, 3, 0); updateParts()
    local a, b = exitPlayers()
    AR.Active, AR.BusyFlag, AH.Active, world.pending = true, true, true, true
    local rescue = rescueToken()
    check(FH.MotionValid(rescue), "ordinary rescue was cancelled before an exit condition existed")
    b.stats.Escaped.Value = true; task.wait(0.04)
    check(FH.ExitEscapePending(), "open-exit readiness did not request an immediate handoff")
    check(not FH.MotionValid(rescue) and not AH.PodsPending(), "rescue kept ownership over ready exit")
    check(FH.MotionValid(7) and FH.Move(7, hum, Vec.new(20, 3, 0)), "farm exit owner stayed blocked by stale rescue busy flag")
end)
scenario("rescue leaves a concave wall pocket while the native route is pending", function()
    box("FrontWall", Vec.new(2, 0, -3), Vec.new(3, 14, 3))
    box("LeftWall", Vec.new(-5, 0, -3), Vec.new(3, 14, -2))
    box("RightWall", Vec.new(-5, 0, 2), Vec.new(3, 14, 3))
    world.planDelay = 3
    local goal = Vec.new(20, 3, 0)
    local token, steering = rescueToken(), {}
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 0.65, rescueJuke = goal, rescueSteer = steering })
    check(root.Position.X < -5, "rescue waited/pressed into the wall instead of taking its only backward exit")
    check(world.jumps == 0, "solid wall pocket was treated as a jump obstacle")
end)
scenario("rescue steps down from a high object when its forward descent is walled", function()
    box("TallObject", Vec.new(-2, 0, -2), Vec.new(2, 10, 2))
    box("ForwardWall", Vec.new(2.2, 0, -3), Vec.new(2.5, 22, 3))
    root.Position = Vec.new(0, 13, 0); updateParts()
    world.planDelay = 2
    local goal = Vec.new(20, 3, 0)
    local token = rescueToken()
    local leftObject = false
    task.delay(0.7, function() leftObject = root.Position.Y < 5 and math.abs(root.Position.Z) > 2 end)
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 3, rescueJuke = goal })
    check(leftObject and result == "arrived" and root.Position.Y < 4,
        "rescue remained on the object because the direct down lane was blocked")
    check(world.blocked < 10, "object escape walked into the wall corner after dropping")
    check(world.jumps == 0 and hum.JumpPower == 36, "object escape used an unnecessary jump or boost")
end)
scenario("rescue keeps a verified window crossing through a short sill landing", function()
    local token = rescueToken()
    root.Position = Vec.new(3, 3, 0); updateParts()
    Follow.CrossingTraversal = { token = token, hum = hum, root = root,
        aim = Vec.new(8, 0, 0), origin = Vec.new(0, 3, 0), dir = Vec.new(1, 0, 0),
        t = now - 0.4, untilAt = now + 1.5, airborne = true, feetY = 0 }
    world.planDelay = 2
    local goal = Vec.new(-10, 3, 0)
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 0.24, rescueJuke = goal })
    check(root.Position.X > 5.5, "landing cancelled the forward crossing and pulled the avatar back across the window")
end)
scenario("manual reposition starts a fresh rescue route without consuming its timeout", function()
    local token, steering = { owner = "rescue", priority = 90, ok = function() return true end }, {}
    local goal = Vec.new(20, 3, 0)
    world.blockingManualGate = true
    task.delay(0.2, function()
        FH.RejectLane(token, hum, goal)
        world.manual = true
        steering.failedLanes = { { origin = root.Position, dir = Vec.new(1, 0, 0), untilAt = now + 20 } }
        steering.doors = { obsolete = true }
        task.delay(1, function()
            root.Position = Vec.new(6, 3, 0); updateParts()
            world.manual = false
        end)
    end)
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 1.5, rescueJuke = goal, rescueSteer = steering })
    check(result == "arrived", "manual input expired the old timeout or retained the stale blocked route")
    check(not steering.doors or not steering.doors.obsolete, "manual room change retained the old door-crossing history")
    local stale = false
    for _, lane in ipairs(FH.LiveLanes and FH.LiveLanes.lanes or {}) do if lane.token == token then stale = true end end
    check(not stale, "manual reposition retained the rescue owner's stale rejected corridors")
end)
scenario("native rescue route starts before a slow atlas scan", function()
    local atlasCalls = 0
    FH.Nav = { Map = map, QueueArea = function() end,
        Route = function() atlasCalls += 1; task.wait(1.5); return nil end }
    FH.BanDirect = now + 20
    local goal = Vec.new(30, 3, 0)
    local token = rescueToken()
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 2.5, rescueJuke = goal })
    check(world.firstComputeAt and world.firstComputeAt - 100 < 0.1,
        "rescue waited for the atlas before requesting native pathfinding")
    check(atlasCalls == 0, "geometrically minimum native route was delayed by unnecessary graph comparison")
end)
scenario("rescue chooses the shorter window route over a slightly longer open route", function()
    box("LowWindow", Vec.new(8.5, 0, -0.5), Vec.new(9.5, 1.6, 0.5))
    world.route = function(from, to, spec)
        if spec.AgentRadius > 1.01 then
            return { { Position = Vec.new(0, 0, 0), Action = "Walk" },
                { Position = Vec.new(8, 0, 1.6), Action = "Walk" },
                { Position = Vec.new(10, 0, 1.6), Action = "Walk" },
                { Position = Vec.new(18, 0, 0), Action = "Walk" } }
        end
        return { { Position = Vec.new(0, 0, 0), Action = "Walk" },
            { Position = Vec.new(9, 0, 0), Action = "Jump" },
            { Position = Vec.new(18, 0, 0), Action = "Walk" } }
    end
    local path, length, _, native = FH.PathAny(root.Position, Vec.new(18, 3, 0), 1, false, function() return true end, false, true, true)
    check(path and path[2].Action == "Jump" and length < 18.1,
        "rescue accepted the open detour without checking the shorter admissible window")
    check(FH.RouteCost(path, length, true) < 18.3, "jump penalty made the shorter window lose distance ranking")
    if native then native:Destroy() end
end)
scenario("six-stud AutoHide emergency does not require Beast to face toward us", function()
    local beast, br = actor("Beast", Vec.new(5.5, 3, 0), true, Vec.new(1, 0, 0), Vec.new(16, 0, 0))
    world.players = { LocalPlayer, beast }
    check(AH.TestEval().danger, "exposed Beast inside six studs did not trigger emergency")
    br.Position = Vec.new(6.5, 3, 0); task.wait(0.06)
    check(not AH.TestEval().danger, "six-stud exception broadened normal directional detection")
    br.Position = Vec.new(5.5, 3, 0)
    AH.BeastMotion[beast].anchor = br.Position
    AH.BeastMotion[beast].movedAt = now - 41
    task.wait(0.06)
    check(AH.TestEval().danger, "AFK exemption suppressed the six-stud emergency")
    box("SeparatingWall", Vec.new(2, 0, -5), Vec.new(3, 10, 5)); task.wait(0.06)
    check(not AH.TestEval().danger, "close-range emergency reached through a solid room wall")
end)
scenario("suspended wall contact recovers by a verified retreat and gravity drop", function()
    box("ThinShelfEdge", Vec.new(0.99, 8.2, -3), Vec.new(1.4, 8.4, 3))
    root.Position = Vec.new(0, 9.4, 0); updateParts()
    hum.FloorMaterial, hum.State = "Air", "Freefall"
    world.vy, world.planDelay = 0, 3
    local escapedShelf = false
    task.delay(0.85, function() escapedShelf = root.Position.Y < 4 and root.Position.X < -1 end)
    local goal, token = Vec.new(20, 3, 0), rescueToken()
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 1.3, rescueJuke = goal })
    check(escapedShelf, "Freefall with zero velocity against a shelf was treated as endless normal flight")
    check(world.jumps == 0 and hum.JumpPower == 36, "suspended escape forced an airborne first jump or boost")
end)
scenario("rescue juke cannot cancel a committed window or react to an idle nearby Beast", function()
    local beast = actor("Beast", Vec.new(0, 3, -10), true)
    world.players, world.threat = { LocalPlayer, beast }, Vec.new(0, 3, -10)
    local token, aim = rescueToken(), Vec.new(8, 3, 0)
    Follow.CrossingTraversal = { token = token, hum = hum, root = root, aim = aim, untilAt = now + 1 }
    check(FH.RescueJuke(token, root, aim, Vec.new(30, 3, 0), 0) == aim,
        "rescue dodge changed the committed window direction")
    Follow.CrossingTraversal, world.threat = nil, nil
    check(FH.RescueJuke(token, root, aim, Vec.new(30, 3, 0), 0) == aim,
        "a nearby Beast without a real threat caused unnecessary zigzags")
end)
scenario("an unreachable far pod returns a bounded route failure instead of waiting 75 seconds", function()
    local info = pod(60)
    box("FrontWall", Vec.new(2, 0, -3), Vec.new(3, 20, 3))
    box("BackWall", Vec.new(-3, 0, -3), Vec.new(-2, 20, 3))
    box("LeftWall", Vec.new(-3, 0, -3), Vec.new(3, 20, -2))
    box("RightWall", Vec.new(-3, 0, 2), Vec.new(3, 20, 3))
    world.noNativePath = true
    local token = rescueToken()
    local result = FH.RescuePod(token, token.ok, info, nil,
        function() AR.KeyDown = true end, function() AR.KeyDown = false end, nil, 5.2)
    check(result == "far" and now < 106, "failed far-pod route was retried stationary until the overall 75-second limit")
    check(world.captive.Value ~= nil and world.jumps == 0 and not AR.KeyDown,
        "unreachable route claimed rescue or jumped repeatedly into the room walls")
end)
scenario("window continuation retains ownership while its next native hop is cooling down", function()
    box("Sill", Vec.new(2, 0, -3), Vec.new(4, 3, 3))
    box("SecondLip", Vec.new(4.5, 0, -3), Vec.new(4.8, 4.4, 3))
    root.Position = Vec.new(3, 6, 0); updateParts()
    FH.LastJump = now - 0.1
    local token = rescueToken()
    local crossing = { token = token, hum = hum, root = root, aim = Vec.new(8, 0, 0),
        origin = Vec.new(0, 3, 0), dir = Vec.new(1, 0, 0), t = now - 0.4,
        untilAt = now + 1.5, airborne = true, feetY = 0 }
    Follow.CrossingTraversal = crossing
    local retained = false
    task.delay(0.1, function() retained = Follow.CrossingTraversal == crossing end)
    local goal = Vec.new(-10, 3, 0)
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 0.15, rescueJuke = goal })
    check(retained, "native hop cooldown was mistaken for failed traversal and cancelled the window commitment")
end)
-- These fixtures drive the full production render dispatcher, including
-- stair/stall recovery, instead of only Tick + Move. Terrain remains synthetic.
local function stairRescue(down, offset, diagonal, lowStep)
    local run, rise = 0.5, lowStep and 0.35 or 1
    local width = diagonal and 60 or 6
    for i = 1, 24 do
        box("Tread", Vec.new(2 + (i - 1) * run, 0, -width / 2), Vec.new(2 + i * run, i * rise, width / 2))
    end
    box("Landing", Vec.new(14, 0, -width / 2), Vec.new(24, 24 * rise, width / 2))
    if down then root.Position = Vec.new(18, 3 + 24 * rise, 0); updateParts() end
    world.stepHeight = lowStep and 0.2 or nil
    world.pathYOffset = offset
    FH.BanDirect = now + 20
    world.route = function(from, to)
        local w = { { Position = Vec.new(from.X, from.Y - 3, from.Z), Action = "Walk" } }
        if down then
            for i = 24, 2, -4 do
                table.insert(w, { Position = Vec.new(2 + (i - 0.5) * run, i * rise,
                    diagonal and (24 - i) * run or 0), Action = "Walk" })
            end
        else
            for i = 4, 24, 4 do
                table.insert(w, { Position = Vec.new(2 + (i - 0.5) * run, i * rise,
                    diagonal and i * run or 0), Action = "Walk" })
            end
        end
        table.insert(w, { Position = to, Action = "Walk" })
        return w
    end
    local z = diagonal and 12 or 0
    local goal = down and Vec.new(-4, 3, z) or Vec.new(22, 3 + 24 * rise, z)
    local result = Follow.WalkTo(rescueToken(), function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 5, rescueJuke = goal })
    check(result == "arrived", "stair rescue stalled: " .. tostring(result))
    check(world.doubles == 0 and world.jumps <= (down and 0 or lowStep and 4 or 2), "supported stairs became repeated window/double jumps")
    check(now < 103, "stair rescue spent most of its time recalculating or returning to old treads")
    check(not FH.MotionStepRetry, "the full render dispatcher hid a movement-helper error")
end
scenario("rescue climbs diagonal treads without repeated double jumps", function() stairRescue(false, nil, true, false) end)
scenario("rescue descends diagonal treads without jumping or pausing", function() stairRescue(true, nil, true, false) end)
scenario("rescue descends when navmesh waypoints lie below tread surfaces", function() stairRescue(true, -0.6, false, false) end)
scenario("rescue uses native takeoffs when simulated treads cannot be walked", function() stairRescue(false, nil, true, true) end)
scenario("rescue does not treat a wall or covered stairs as a supported ascent", function()
    local token = rescueToken()
    box("SolidWall", Vec.new(2, 0, -4), Vec.new(3, 20, 4))
    local goal = Vec.new(5, 12, 0)
    check(not Follow.RescueSurfaceLane or not Follow.RescueSurfaceLane(token, hum, root, goal, 0, 5),
        "a tall wall became an incline by looking at its top")
    world.boxes = {}
    for i = 1, 8 do box("Tread", Vec.new(i * 0.5, 0, -3), Vec.new((i + 1) * 0.5, i * 0.35, 3)) end
    box("LowCeiling", Vec.new(0, 3.8, -3), Vec.new(6, 4.1, 3))
    FH.RescueSurfaceProbe = nil
    check(not Follow.RescueSurfaceLane or not Follow.RescueSurfaceLane(token, hum, root, goal, 0, 5),
        "stair proof ignored actual body headroom")
end)
scenario("a slightly shorter window shortcut wins without a jump penalty", function()
    box("Sill", Vec.new(4.5, 0, -3), Vec.new(5.5, 1.8, 3))
    local points = { Vec.new(0, 0, 0), Vec.new(0, 0, 2), Vec.new(10, 0, 2), Vec.new(10, 0, 0) }
    local wps = {}
    for _, point in ipairs(points) do table.insert(wps, { Position = point, Action = "Walk" }) end
    local shortcut = Follow.RescueShortcut(root.Position, 0, wps, 2, nil, Vec.new(30, 3, 0))
    check(shortcut == 4 or shortcut == 3, "a verified shorter jump lost to the empty walking detour")
end)
scenario("rescue adopts the first native leg while the narrow profile still computes", function()
    box("Partition", Vec.new(2, 0, -10), Vec.new(3, 20, 10))
    FH.BanDirect = now + 20
    world.planDelay = function(index) return index == 1 and 0.05 or 1.5 end
    world.route = function(from, to)
        return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(0, 0, -12), Action = "Walk" },
            { Position = Vec.new(8, 0, -12), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local token, goal = rescueToken(), Vec.new(30, 3, 0)
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 0.4, rescueJuke = goal })
    check(root.Position.Z < -3, "usable native leg waited for the second ComputeAsync/atlas comparison")
    task.wait(1.7)
    for _, path in ipairs(world.pathObjects) do check(path.destroyed, "cancelled preview leaked a native Path") end
end)
scenario("rescue keeps walking its native leg during a slow optional door comparison", function()
    box("Partition", Vec.new(2, 0, -10), Vec.new(3, 20, 10))
    FH.BanDirect = now + 20
    world.route = function(from, to)
        return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(0, 0, -12), Action = "Walk" },
            { Position = Vec.new(8, 0, -12), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local original, searchAt = Follow.FindDoorRoute, nil
    Follow.FindDoorRoute = function() searchAt = now; task.wait(1.5); return nil end
    local token, goal = rescueToken(), Vec.new(30, 3, 0)
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { maxTime = 0.5, rescueJuke = goal })
    Follow.FindDoorRoute = original
    check(searchAt and root.Position.Z < -4, "optional door search replaced the usable route with stopped/local steering")
    task.wait(1.7)
    for _, path in ipairs(world.pathObjects) do check(path.destroyed, "cancelled door comparison leaked its fallback Path") end
end)
scenario("rescue finishes the doorway crossing before accepting a reverse provisional goal", function()
    local g = openingDoor()
    local token, goal = rescueToken(), Vec.new(30, 3, 0)
    local steering = { rescueTarget = {} }
    check(Follow.PassDoor(token, g, nil, nil, goal, steering), "rescue never opened/crossed the doorway")
    local exitX = root.Position.X
    local reverse = Vec.new(0, 3, 0)
    world.planDelay = 1.5
    Follow.WalkTo(token, function() return reverse end, 0.8, nil,
        { noDoor = true, maxTime = 0.06, rescueJuke = goal, rescueSteer = steering })
    check(root.Position.X > exitX + 0.5, "opening-to-route handoff returned to the old side before clearing the door")
    check(not Follow.KeyDown and not AR.KeyDown, "door continuation retained the interaction key")
end)
scenario("door continuation cancels on a new obstruction or movement owner", function()
    local token = rescueToken()
    root.Position = Vec.new(8.9, 3, 0); updateParts()
    Follow.DoorTraversal = { token = token, hum = hum, root = root, aim = Vec.new(11, 3, 0),
        dir = Vec.new(1, 0, 0), untilAt = now + 2 }
    box("NewObstruction", Vec.new(10, 0, -3), Vec.new(10.5, 12, 3))
    check(not Follow.ActiveDoor or not Follow.ActiveDoor(token, hum, root), "door commitment continued into a new wall")
    Follow.DoorTraversal = { token = token, hum = hum, root = root, aim = Vec.new(11, 3, 0),
        dir = Vec.new(1, 0, 0), untilAt = now + 2 }
    FH.ReleaseMotion(token, false)
    check(Follow.DoorTraversal == nil, "released rescue retained door ownership")
end)
scenario("landing above an old takeoff exits the prop instead of aiming at its own feet", function()
    box("WideProp", Vec.new(4, 0, -4), Vec.new(14, 3, 4))
    FH.BanDirect = now + 20
    world.route = function(from, to)
        return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(5, 0, 0), Action = "Jump" },
            { Position = Vec.new(15, 0, 0), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local landed, moved = false, false
    task.delay(0.24, function()
        root.Position = Vec.new(5, 6, 0); updateParts()
        hum.FloorMaterial, hum.State, world.vy = "Ground", "Running", 0
        FH.JumpFlight, FH.Jmp = nil, nil
        landed = true
        task.delay(0.7, function() moved = Flat(root.Position - Vec.new(5, 6, 0)).Magnitude > 4 end)
    end)
    local goal, token = Vec.new(30, 3, 0), rescueToken()
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 4, rescueJuke = goal })
    check(landed and moved and result == "arrived", "old takeoff below the prop stranded the rescue after landing")
    check(world.jumps <= 3 and world.doubles == 0, "prop escape depended on repeated jumps")
end)
scenario("AutoHelp opens a closed doorway and continues all the way to a confirmed pod release", function()
    local info = pod(30)
    local g = openingDoor()
    Doors = { g.Door }
    box("LeftDoorWall", Vec.new(5.75, 0, -30), Vec.new(6.25, 15, -4))
    box("RightDoorWall", Vec.new(5.75, 0, 4), Vec.new(6.25, 15, 30))
    local idle, longest, reversed, exited, previousX = 0, 0, false, false, 0
    world.frameSample = function(dt)
        if root.Position.X >= 8.8 then exited = true end
        if exited and root.Position.X < 23 then
            if root.Position.X < previousX - 0.02 then reversed = true end
            idle = Flat(root.AssemblyLinearVelocity).Magnitude < 0.1 and idle + dt or 0
            longest = math.max(longest, idle)
        end
        previousX = root.Position.X
    end
    local token = rescueToken()
    local result = FH.RescuePod(token, token.ok, info, nil,
        function() AR.KeyDown = true; nativeKey(0x45, true) end,
        function() AR.KeyDown = false; nativeKey(0x45, false) end, nil, 5.2)
    check(result == "done" and world.captive.Value == nil, "door-to-pod controller stopped before a real release")
    check(exited and not reversed and longest < 0.2, "rescue paused or returned through the door after crossing it")
    check(now < 106 and not Follow.KeyDown and not AR.KeyDown, "door-to-pod rescue exhausted its travel time or kept E")
end)
scenario("Follow-owned rescue uses the same supported stair proof", function()
    Follow.Rescuing = true
    for i = 1, 12 do box("Tread", Vec.new((i - 1) * 0.5, 0, -20), Vec.new(i * 0.5, i, 20)) end
    local safe, kind = FH.TraversalLane(7, hum, root, Vec.new(4, 8, 3), 0, 5, true)
    check(safe and kind == "stairs", "numeric Follow rescue owner lost the continuous stair admission")
end)
scenario("a delayed optional door cannot reverse a route after its saving has disappeared", function()
    box("Partition", Vec.new(2, 0, -10), Vec.new(3, 20, 10))
    FH.BanDirect = now + 20
    world.route = function(from, to)
        return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(0, 0, -12), Action = "Walk" },
            { Position = Vec.new(8, 0, -12), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local originalSearch, originalPass = Follow.FindDoorRoute, Follow.PassDoor
    local passed, searched = false, false
    Follow.FindDoorRoute = function(_, from)
        searched = true
        task.wait(0.4)
        return { Door = node("OptionalDoor", "Model", map), NearPos = Vec.new(0, 3, 3),
            RescueStand = Vec.new(0, 3, 3), RescueFrom = from, RescueTailCost = 32 }
    end
    Follow.PassDoor = function() passed = true; return false end
    local goal, token = Vec.new(30, 3, 0), rescueToken()
    Follow.WalkTo(token, function() return goal end, 0.8, nil, { maxTime = 0.65, rescueJuke = goal })
    Follow.FindDoorRoute, Follow.PassDoor = originalSearch, originalPass
    check(searched and not passed and root.Position.Z < -8,
        "an old-start door comparison replaced forward progress with a longer reverse leg")
end)
scenario("rescue continues when Freefall and Air stay reported on supported treads", function()
    for i = 1, 24 do box("Tread", Vec.new(2 + (i - 1) * 0.5, 0, -4), Vec.new(2 + i * 0.5, i * 0.35, 4)) end
    box("Landing", Vec.new(14, 0, -4), Vec.new(24, 8.4, 4))
    world.stepHeight, world.airReport, world.airReportX = 0.2, true, 6
    FH.BanDirect = now + 20
    world.route = function(from, to)
        local w = { { Position = Vec.new(from.X, from.Y - 3, from.Z), Action = "Walk" } }
        for i = 4, 24, 4 do table.insert(w, { Position = Vec.new(2 + (i - 0.5) * 0.5, i * 0.35, 0), Action = "Walk" }) end
        table.insert(w, { Position = to, Action = "Walk" }); return w
    end
    local goal, token = Vec.new(22, 11.4, 0), rescueToken()
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 4.5, rescueJuke = goal })
    check(result == "arrived" and now < 103.8, "reported airborne state stranded rescue on actual stair support")
    check(hum.JumpPower == 36 and hum.JumpHeight == 7.2, "support recovery changed native jump properties")
end)
scenario("rescue takes a supported uphill prefix before a delayed connector plan finishes", function()
    for i = 1, 16 do box("SteepTread", Vec.new(1 + (i - 1) * 0.5, 0, -4), Vec.new(1 + i * 0.5, i * 0.7, 4)) end
    box("UpperLanding", Vec.new(9, 0, -4), Vec.new(24, 11.2, 24))
    box("NorthWall", Vec.new(-5, 0, 2), Vec.new(9, 25, 3))
    box("SouthWall", Vec.new(-5, 0, -3), Vec.new(9, 25, -2))
    world.planDelay = 2
    local goal, token = Vec.new(20, 14.2, 20), rescueToken()
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 0.7, rescueJuke = goal })
    check(root.Position.X > 4 and root.Position.Y > 5.5,
        "safe upward treads were excluded from local exploration while native pathfinding yielded: " .. root.Position.X .. "," .. root.Position.Y .. "," .. root.Position.Z)
end)
scenario("a new rescue leg cannot inherit an old sideways recovery destination", function()
    local token, goal = rescueToken(), Vec.new(30, 3, 0)
    FH.Move(token, hum, goal)
    local watch = FH.MoveWatch
    watch.escape, watch.escapeUntil = Vec.new(-6, 3, 0), now + 1.8
    watch.escapeAnchor, watch.escapeAt = root.Position, now
    watch.escapeCheckAt, watch.escapeClear = now + 1, true
    watch.lastSide = 1
    Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 0.4, rescueJuke = goal })
    check(root.Position.X > 4, "the old recovery writer overrode the new rescue's forward route")
    check(Follow.RescueControl == nil, "finished rescue retained controller ownership")
end)
scenario("reported Freefall without real contact never authorizes a grounded rescue takeoff", function()
    local token = rescueToken()
    root.Position = Vec.new(0, 20, 0); updateParts()
    hum.FloorMaterial, hum.State = "Air", "Freefall"
    FH.Move(token, hum, Vec.new(10, 20, 0))
    if Follow.RescueGrounded then
        hum.FloorMaterial = "Ground"
        check(not Follow.RescueGrounded(hum, root, true), "stale solid material at an unsupported apex counted as contact progress")
        hum.FloorMaterial = "Air"
    end
    for _ = 1, 5 do
        if Follow.RescueGrounded then check(not Follow.RescueGrounded(hum, root), "unsupported body was classified as grounded") end
        check(not FH.TakeoffSupported(hum, root), "rescue manufactured a takeoff in free fall")
        task.wait(0.03)
    end
    check(world.jumps == 0 and world.doubles == 0, "unsupported contact check injected a jump")
end)
scenario("rescue can chain two ordinary takeoffs when the game refuses an airborne second jump", function()
    box("LowerPlatform", Vec.new(4, 0, -4), Vec.new(8, 2.8, 4))
    box("HigherPlatform", Vec.new(8, 0, -4), Vec.new(24, 5.6, 4))
    world.allowDouble = false
    FH.BanDirect = now + 20
    world.route = function(from, to)
        return { { Position = Vec.new(from.X, from.Y - 3, from.Z), Action = "Walk" },
            { Position = Vec.new(5.5, 2.8, 0), Action = "Jump" },
            { Position = Vec.new(10, 5.6, 0), Action = "Jump" }, { Position = to, Action = "Walk" } }
    end
    local goal, token = Vec.new(22, 8.6, 0), rescueToken()
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 4, rescueJuke = goal })
    check(result == "arrived" and world.jumps >= 2, "two ordinary native hops were replaced by a stalled/abandoned climb")
    check(world.doubles == 0 and hum.JumpPower == 36 and hum.JumpHeight == 7.2,
        "paired grounded hops relied on an airborne boost or changed jump properties")
end)
scenario("a local double-input window route beats a remote navmesh walking detour", function()
    box("HighWindow", Vec.new(3, 0, -20), Vec.new(3.5, 5.4, 20))
    FH.BanDirect = now + 20
    world.route = function(from, to)
        if from.X >= 5 then return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" }, { Position = to, Action = "Walk" } } end
        return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(0, 0, 22), Action = "Walk" },
            { Position = Vec.new(8, 0, 22), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local goal, token = Vec.new(50, 3, 0), rescueToken()
    local steering = { token = token, root = root, rescueGoal = goal, goal = goal,
        aim = Vec.new(0, 3, 6), dir = Vec.new(0, 0, 1), checkAt = now + 1,
        progressPos = root.Position, progressAt = now, trail = {} }
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 4, rescueJuke = goal, rescueSteer = steering })
    check(result == "arrived" and world.doubles >= 1, "native walking detour hid a shorter real two-input window crossing")
    check(now < 103.7 and hum.JumpPower == 36 and hum.JumpHeight == 7.2, "shorter window route modified jump strength or remained slow")
end)
scenario("a declined high-window crossing falls back to the walking route without buffs", function()
    box("HighWindow", Vec.new(3, 0, -20), Vec.new(3.5, 5.4, 20))
    world.allowDouble = false
    FH.BanDirect = now + 20
    world.route = function(from, to)
        if from.X >= 5 then return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" }, { Position = to, Action = "Walk" } } end
        return { { Position = Vec.new(from.X, 0, from.Z), Action = "Walk" },
            { Position = Vec.new(0, 0, 22), Action = "Walk" },
            { Position = Vec.new(8, 0, 22), Action = "Walk" }, { Position = to, Action = "Walk" } }
    end
    local goal, token = Vec.new(50, 3, 0), rescueToken()
    local steering = { token = token, root = root, rescueGoal = goal, goal = goal,
        aim = Vec.new(0, 3, 6), dir = Vec.new(0, 0, 1), checkAt = now + 1,
        progressPos = root.Position, progressAt = now, trail = {} }
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 9, rescueJuke = goal, rescueSteer = steering })
    check(result == "arrived" and world.doubles == 0, "failed window was retried instead of taking the usable walking route")
    check(world.jumps <= 4 and hum.JumpPower == 36 and hum.JumpHeight == 7.2, "failed native second input caused jump spam or a boost")
end)
local function wedgeRescue(angle, down, reportedAir)
    local length = 8 / math.tan(math.rad(angle))
    wedge(2, 2+length, -4, 4, 8)
    box("TopLanding", Vec.new(2+length,0,-4), Vec.new(12+length,8,4))
    if down then root.Position = Vec.new(8+length,11,0); updateParts() end
    world.airReport, world.airReportX = reportedAir, 3
    FH.BanDirect = now+20
    world.route = function(from,to)
        local w = { {Position=Vec.new(from.X,from.Y-3,from.Z),Action="Walk"} }
        if down then
            for i=4,0,-1 do table.insert(w,{Position=Vec.new(2+length*i/4,8*i/4,0),Action="Walk"}) end
        else
            for i=0,4 do table.insert(w,{Position=Vec.new(2+length*i/4,8*i/4,0),Action="Walk"}) end
        end
        table.insert(w,{Position=to,Action="Walk"});return w
    end
    local goal = down and Vec.new(0,3,0) or Vec.new(8+length,11,0)
    local result = Follow.WalkTo(rescueToken(),function()return goal end,0.8,nil,
        {noDoor=true,maxTime=3.5,rescueJuke=goal})
    check(result=="arrived", "convex ramp support was mistaken for a wall or an airborne stall")
    check(world.doubles==0 and hum.JumpPower==36, "ramp walking used double-jump spam or a boost")
end
scenario("rescue climbs a convex wedge ramp",function()wedgeRescue(35,false,false)end)
scenario("rescue descends a convex wedge ramp",function()wedgeRescue(35,true,false)end)
scenario("rescue climbs a steep supported wedge with reported Air",function()wedgeRescue(60,false,true)end)
scenario("rescue descends a steep supported wedge with reported Air",function()wedgeRescue(60,true,true)end)
scenario("rescue keeps climbing through a stair landing and a reversing second flight", function()
    root.Position = Vec.new(0,3,-2.5); updateParts()
    for i=1,12 do
        box("FirstFlight", Vec.new(2+(i-1)*0.5,0,-4), Vec.new(2+i*0.5,i*0.35,-1))
        box("SecondFlight", Vec.new(2+(i-1)*0.5,0,1), Vec.new(2+i*0.5,4.2+(13-i)*0.35,4))
    end
    box("TurnLanding",Vec.new(8,0,-4),Vec.new(12,4.2,4))
    box("UpperLanding",Vec.new(-3,0,1),Vec.new(2,8.4,4))
    box("CentralWall",Vec.new(-4,0,-1),Vec.new(8,22,1))
    world.airReport, world.airReportX = true, 4
    world.route = function(from,to)
        local points={ Vec.new(from.X,from.Y-3,from.Z),Vec.new(2,0,-2.5),Vec.new(4,1.4,-2.5),
            Vec.new(6,2.8,-2.5),Vec.new(8,4.2,-2.5),Vec.new(10,4.2,-2.5),Vec.new(10,4.2,2.5),
            Vec.new(8,4.55,2.5),Vec.new(6,5.95,2.5),Vec.new(4,7.35,2.5),Vec.new(2,8.4,2.5),to }
        local w={};for _,point in ipairs(points)do table.insert(w,{Position=point,Action="Walk"})end;return w
    end
    local goal=Vec.new(0,11.4,2.5)
    local result=Follow.WalkTo(rescueToken(),function()return goal end,0.8,nil,{noDoor=true,maxTime=5,rescueJuke=goal})
    check(result=="arrived" and root.Position.Y>11,"landing/second-flight turn stranded the stair rescue: "..tostring(result)..":"..root.Position.X..","..root.Position.Y..","..root.Position.Z)
    check(world.doubles==0 and now<104.5,"stair landing caused repeated double jumps or excessive delay")
end)
scenario("a preempted rescue cannot change AutoHide's airborne classification", function()
    local rescue=rescueToken()
    hum.FloorMaterial, hum.State="Air","Freefall"
    FH.RescueSupport={hum=hum,root=root,pos=root.Position,feetY=0,at=now,since=now-1,valid=true,velocity=Vec.new(),filterAt=rayFilterAt}
    Follow.RescueControl={token=rescue,hum=hum,root=root}
    local evade={owner="evade",priority=100,ok=function()return true end}
    FH.Motion={token=evade,hum=hum,priority=100,untilAt=now+1,aim=Vec.new(10,3,0)}
    if Follow.RescueGrounded then check(not Follow.RescueGrounded(hum,root),"stale rescue claimed support after AutoHide took over") end
    check(Follow.Airborne(hum,root),"rescue contact proof changed an evade owner's flight state")
end)
scenario("a carried valid rescue leg is not stopped by ownership inspection", function()
    if not Follow.RescueControlled then return end
    local token=rescueToken()
    local control={token=token,hum=hum,root=root,seen=now}
    Follow.RescueControl=control
    FH.Move(token,hum,Vec.new(80,3,0))
    local continued=true
    for _=1,20 do
        continued=FH.CarryMotion(token,hum,root,0.75) and continued
        task.wait(0.07)
    end
    check(continued and root.Position.X>20,"an aged coordinator cancelled an actively carried safe leg")
    check(Follow.RescueControl==control and FH.MotionActive(),"ownership inspection revoked an active movement lease")
    FH.ReleaseMotion(token,false)
    check(Follow.RescueControl==nil and FH.Motion.token==nil and FH.StallIntent==nil,"explicit cancellation left a replayable rescue intent")
end)
scenario("a delayed long-distance native detour cannot pull rescue back through its cleared window", function()
    box("HighWindow", Vec.new(3,0,-20), Vec.new(3.5,5.4,20))
    FH.BanDirect=now+20
    world.route=function(from,to)
        if from.X>=5 then return {{Position=Vec.new(from.X,0,from.Z),Action="Walk"},{Position=to,Action="Walk"}} end
        return {{Position=Vec.new(from.X,0,from.Z),Action="Walk"},{Position=Vec.new(0,0,22),Action="Walk"},
            {Position=Vec.new(8,0,22),Action="Walk"},{Position=to,Action="Walk"}}
    end
    local goal=Vec.new(125,3,0)
    local backward=false;local previous=0
    world.frameSample=function()
        if root.Position.X>5 and root.Position.X<previous-0.05 then backward=true end
        previous=root.Position.X
    end
    local result=Follow.WalkTo(rescueToken(),function()return goal end,0.8,nil,{noDoor=true,maxTime=9,rescueJuke=goal})
    check(result=="arrived" and not backward,"old native start restored a reverse window leg for a distant pod")
    check(world.doubles>=1 and now<108.8,"distant rescue abandoned the verified window and followed the obsolete walking circuit")
end)
scenario("a follow cache refresh does not revoke a still-valid rescue coordinator", function()
    if not Follow.RescueControlled then return end -- Contract belongs to the new coordinator.
    local token=rescueToken()
    local control={token=token,hum=hum,root=root,seen=now}
    Follow.RescueControl=control
    FH.Move(token,hum,Vec.new(20,3,0))
    FH.ResetCaches(true)
    check(Follow.RescueControl==control and FH.Motion.token==token,"another mode's cache refresh revoked rescue movement ownership")
    FH.ReleaseMotion(token,false)
    check(Follow.RescueControl==nil,"rescue release retained ownership after cache refresh")
end)
scenario("a silently ignored takeoff on reported Air is confirmed only from real support", function()
    for i = 1, 24 do box("Tread", Vec.new(2 + (i - 1) * 0.5, 0, -4), Vec.new(2 + i * 0.5, i * 0.35, 4)) end
    box("Landing", Vec.new(14, 0, -4), Vec.new(24, 8.4, 4))
    world.stepHeight, world.airReport, world.airReportX = 0.2, true, 6
    world.ignoreSpaceAfterX = 6
    FH.BanDirect = now + 20
    world.route = function(from, to)
        local w = { { Position = Vec.new(from.X, from.Y - 3, from.Z), Action = "Walk" } }
        for i = 4, 24, 4 do table.insert(w, { Position = Vec.new(2 + (i - 0.5) * 0.5, i * 0.35, 0), Action = "Walk" }) end
        table.insert(w, { Position = to, Action = "Walk" }); return w
    end
    local goal, token = Vec.new(22, 11.4, 0), rescueToken()
    local result = Follow.WalkTo(token, function() return goal end, 0.8, nil,
        { noDoor = true, maxTime = 4.5, rescueJuke = goal })
    check(result == "arrived" and now < 103.8, "reported airborne state stranded rescue on actual stair support")
    check(world.ignoredSpace and world.engineJumps == 1, "a successful API call suppressed confirmation of the missing supported first takeoff")
    check(hum.JumpPower == 36 and hum.JumpHeight == 7.2, "support recovery changed native jump properties")
end)
scenario("another movement owner can probe geometry while rescue retains its scope", function()
    local rescue=rescueToken()
    local wall=box("ProbeWall",Vec.new(2,0,-4),Vec.new(3,12,4))
    Follow.RescueControl={token=rescue,hum=hum,root=root,seen=now,failedObstacles={[wall]=now+5}}
    local ok, blocked=pcall(Follow.RescueFailedPart,7,wall)
    check(ok and blocked==false,"another owner's geometry query compared a boolean with a timestamp")
    local probed, safe=pcall(FH.TraversalLane,7,hum,root,Vec.new(6,0,0),0,6,true,true)
    check(probed and safe==false,"geometry probing threw while another rescue context existed")
    check(Follow.RescueFailedPart(rescue,wall)==true,"owner-specific failure memory was lost")
end)
local function tightCorner(frameStep, clearance)
    world.frameStep=frameStep
    box("Partition",Vec.new(4,0,-10),Vec.new(5,12,3))
    world.route=function(from,to)
        return {{Position=Vec.new(from.X,0,from.Z),Action="Walk"},{Position=Vec.new(2.8,0,clearance),Action="Walk"},
            {Position=Vec.new(6.2,0,clearance),Action="Walk"},{Position=to,Action="Walk"}}
    end
    local idle,longest=0,0
    world.frameSample=function(dt)
        if now>100.12 and Flat(root.Position-Vec.new(12,3,0)).Magnitude>3 then
            idle=Flat(root.AssemblyLinearVelocity).Magnitude<0.1 and idle+dt or 0
            longest=math.max(longest,idle)
        end
    end
    local goal=Vec.new(12,3,0)
    local result=Follow.WalkTo(rescueToken(),function()return goal end,0.8,nil,{noDoor=true,maxTime=3,rescueJuke=goal})
    check(result=="arrived", "tight-corner rescue stopped before the goal")
    check(longest<math.max(0.09,(frameStep or 0.01)*1.1),"corner arrival tolerance inserted a stationary interval: "..longest)
    check(world.jumps==0,"walking corner recovery injected an unnecessary jump")
end
scenario("rescue does not wait at tight native corners before continuing", function()tightCorner(nil,4.05)end)
scenario("rescue clears a tight corner at exact native clearance",function()tightCorner(nil,4.0)end)
scenario("rescue corner steering remains continuous at 60 fps",function()tightCorner(1/60,4.05)end)
scenario("rescue corner steering remains continuous at 30 fps",function()tightCorner(1/30,4.05)end)
scenario("rescue corner steering remains continuous at 10 fps",function()tightCorner(0.1,4.05)end)
scenario("an AutoHelp task error releases its own movement before retrying", function()
    local oldStep=AR.Step
    AR.Active,AR.Token=true,1
    AR.Step=function(token)
        Follow.RescueControl={token=token,hum=hum,root=root,seen=now}
        FH.Move(token,hum,Vec.new(20,3,0))
        error("synthetic geometry failure")
    end
    task.delay(0.15,function() AR.Active=false end)
    AR.Loop(1)
    AR.Step=oldStep
    check(FH.Motion.token==nil and Follow.RescueControl==nil and FH.StallIntent==nil,"failed rescue task retained movement ownership")
    check(root.Position.X<0.1 and world.warning~=nil,"failed rescue kept walking or swallowed its error")
end)
scenario("corner query skin allows tangency but still blocks entry into a wall", function()
    box("SolidWall",Vec.new(4,0,-10),Vec.new(5,12,3))
    root.Position=Vec.new(3,3,0);updateParts()
    check(not Follow.RescueBodyClear(hum,root,Vec.new(6,3,0),0,3),"query skin admitted movement into solid geometry")
    root.Position=Vec.new(3,3,4);updateParts()
    check(Follow.RescueBodyClear(hum,root,Vec.new(6,3,4),0,3),"a valid tangent corridor was treated as a wall collision")
    check(root.Size.X==2 and hum.WalkSpeed==16 and hum.JumpPower==36,"corner handling altered physical collision or movement strength")
end)
for _, problem in ipairs(failures) do print(problem) end
print("Navigation scenarios", scenarios, "checks", checks, "failures", #failures)
assert(#failures == 0, "navigation/native interaction regression")
