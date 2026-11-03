-- FTF movement observation recorder v1. Standalone; never controls the avatar.
-- No HTTP, remotes, pathfinding, shape casts, virtual keys or property changes.
-- Run without AutoFollow/AutoFarm/AutoHelp/AutoHide. Export is local and explicit.
local Players = game:GetService("Players")
local World = game:GetService("Workspace")
local Storage = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
local shared = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then shared = result end
end
local previous = shared.FTFMovementRecorder
if type(previous) == "table" and type(previous.Show) == "function" then
    previous.Show()
    return
end

local SAMPLE, CONTEXT = 0.1, 0.5
local MAX_FRAMES, MAX_BYTES, MAX_LINES = 6000, 4 * 1024 * 1024, 20000
local R = {
    running = false,
    mode = "general",
    lines = {},
    bytes = 0,
    frames = 0,
    segment = 0,
    maps = {},
    mapCount = 0,
    people = {},
    personCount = 0,
    entities = {},
    entityCount = 0,
    catalog = {},
    queue = {},
    cursor = 1,
    scanCount = 0,
    queued = {},
    connections = {},
    characterConnections = {},
}
local gui, status, toggle, hint, preview, pageLabel
local pages, page, frozenExport
local notify = function() end
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.IgnoreWater = true
pcall(function() ray.RespectCanCollide = true end)
local function rounded(n)
    if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then return 0 end
    return math.round(n * 100) / 100
end
local function vec(v) return { rounded(v.X), rounded(v.Y), rounded(v.Z) } end
local function now() return math.max(0, math.round((os.clock() - (R.started or os.clock())) * 1000)) end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function disconnect(list)
    for _, connection in ipairs(list) do
        connection:Disconnect()
    end
    table.clear(list)
end
local function stop(reason)
    if not R.running then return end
    R.running = false
    -- A footer is reserved even when the sample/byte limit is reached.
    local line = Http:JSONEncode({ k = "stop", t = now(), reason = reason or "button", frames = R.frames })
    R.lines[#R.lines + 1], R.bytes = line, R.bytes + #line + 1
    notify(
        reason == "limit" and "Đã đủ dung lượng; hãy xuất file." or "Đã dừng; dữ liệu vẫn còn."
    )
end
local function append(record)
    if not R.running then return false end
    record.t = record.t or now()
    record.segment = record.segment or R.segment
    record.for_mode = record.for_mode or R.mode
    local line = Http:JSONEncode(record)
    if R.bytes + #line + 1024 > MAX_BYTES or #R.lines >= MAX_LINES - 1 then
        stop("limit")
        return false
    end
    R.lines[#R.lines + 1], R.bytes = line, R.bytes + #line + 1
    return true
end
local function classify(name)
    local n = string.lower(name)
    if string.find(n, "computer", 1, true) then return "computer" end
    if string.find(n, "pod", 1, true) then return "pod" end
    if string.find(n, "exit", 1, true) then return "exit" end
    if string.find(n, "door", 1, true) then return "door" end
    if string.find(n, "window", 1, true) then return "window" end
    if string.find(n, "stair", 1, true) or string.find(n, "step", 1, true) then return "stairs" end
    if string.find(n, "ramp", 1, true) or string.find(n, "slide", 1, true) then return "ramp" end
    if string.find(n, "vent", 1, true) then return "vent" end
    return "geometry"
end
local function entity(part)
    if not part or not part:IsA("BasePart") then return nil end
    local id = R.entities[part]
    if id then return id end
    if R.entityCount >= 700 then return nil end
    R.entityCount += 1
    id = R.entityCount
    R.entities[part] = id
    local names, owner = { part.Name }, part.Parent
    local kind = classify(part.Name)
    for _ = 1, 3 do
        if not owner or owner == R.map or owner == World then break end
        names[#names + 1] = owner.Name
        if kind == "geometry" then kind = classify(owner.Name) end
        owner = owner.Parent
    end
    -- Only map geometry is named; no player names, chat or account identifiers.
    if not R.map or not part:IsDescendantOf(R.map) then names = { "world_geometry" } end
    if
        not append({
            k = "entity",
            id = id,
            names = names,
            kind = kind,
            p = vec(part.Position),
            size = vec(part.Size),
            f = vec(part.CFrame.LookVector),
            up = vec(part.CFrame.UpVector),
            collidable = part.CanCollide,
            material = part.Material.Name,
            color = { rounded(part.Color.R), rounded(part.Color.G), rounded(part.Color.B) },
            transparency = rounded(part.Transparency),
        })
    then
        return nil
    end
    return id
end
local function event(name, data) append({ k = "event", name = name, data = data or {} }) end
local function resolveMap()
    local value = Storage:FindFirstChild("CurrentMap", true)
    if value and value:IsA("ObjectValue") and value.Value and value.Value:IsDescendantOf(World) then
        return value.Value, "CurrentMap_ObjectValue"
    end
    local named = World:FindFirstChild("CurrentMap")
    if named and (named:IsA("Model") or named:IsA("Folder")) then return named, "workspace_CurrentMap" end
    return nil, "unknown"
end
local function scanBatch()
    if not R.map then return end
    -- Incremental discovery only inside this map, capped at 40 nodes per tick.
    for _ = 1, 40 do
        local item = R.queue[R.cursor]
        if not item or R.scanCount >= 30000 then break end
        R.queue[R.cursor], R.cursor = false, R.cursor + 1
        R.scanCount += 1
        if item.Parent and item:IsDescendantOf(R.map) then
            if item:IsA("BasePart") and #R.catalog < 256 then
                local kind = classify(item.Name)
                if kind == "geometry" and item.Parent then kind = classify(item.Parent.Name) end
                if kind ~= "geometry" then R.catalog[#R.catalog + 1] = { part = item, kind = kind } end
            end
            if #R.queue < 30000 then
                for _, child in ipairs(item:GetChildren()) do
                    if #R.queue >= 30000 then break end
                    if not R.queued[child] then
                        R.queued[child] = true
                        R.queue[#R.queue + 1] = child
                    end
                end
            end
        end
    end
end
local function segment(map, source, character, root)
    if R.map == map and R.character == character and R.segment > 0 then return end
    local mapChanged = R.map ~= map or R.segment == 0
    R.map, R.character, R.segment = map, character, R.segment + 1
    R.lastFrame, R.lastState, R.lastJumpRequest = nil, nil, nil
    R.lastContextBody, R.motionStallAt, R.stallReported = nil, nil, nil
    R.mode, R.modeUntil, R.podProgress, R.rescueCommit, R.beastWatch = "general", nil, nil, nil, nil
    if map and not R.maps[map] then
        R.mapCount += 1
        R.maps[map] = R.mapCount
    end
    if mapChanged then
        R.queue, R.queued, R.cursor, R.scanCount, R.catalog = {}, {}, 1, 0, {}
        if map then
            for _, child in ipairs(map:GetChildren()) do
                if #R.queue >= 30000 then break end
                R.queued[child] = true
                R.queue[#R.queue + 1] = child
            end
        end
        if R.mapConnection then R.mapConnection:Disconnect() end
        R.mapConnection = map
                and map.DescendantAdded:Connect(function(item)
                    if #R.queue < 30000 and not R.queued[item] then
                        R.queued[item] = true
                        R.queue[#R.queue + 1] = item
                    end
                end)
            or nil
    end
    local origin
    if map and map:IsA("Model") then
        local ok, cf = pcall(function() return map:GetPivot() end)
        if ok then origin = vec(cf.Position) end
    end
    append({
        k = "segment",
        map = map and map.Name or "unknown",
        map_id = map and R.maps[map] or 0,
        map_source = source,
        map_origin = origin,
        spawn = root and vec(root.Position),
        reason = mapChanged and "map_or_round" or "character_changed",
    })
end
local STAT_NAMES = {
    "ActionInput",
    "ActionProgress",
    "IsTyping",
    "Typing",
    "IsHacking",
    "Captured",
    "InPodium",
    "InPod",
    "Ragdoll",
    "IsBeast",
    "Escaped",
    "Crawling",
    "IsCrawling",
}
local function stats(p)
    local result = {}
    local folder = p:FindFirstChild("TempPlayerStatsModule")
    if not folder then return result end
    for _, key in ipairs(STAT_NAMES) do
        local v = folder:FindFirstChild(key)
        if v and v:IsA("ValueBase") then
            local value = v.Value
            if type(value) == "boolean" or finite(value) then result[key] = value end
        end
    end
    return result
end
local function actionKind()
    local folder = player:FindFirstChild("TempPlayerStatsModule")
    local value = folder and folder:FindFirstChild("ActionEvent")
    local target = value and value:IsA("ObjectValue") and value.Value
    for _ = 1, 5 do
        if not target or target == World or target == R.map then break end
        local kind = classify(target.Name)
        if kind ~= "geometry" then return kind end
        target = target.Parent
    end
    return "unknown"
end
local function computerDone(part)
    local owner = part
    for _ = 1, 3 do
        if not owner or owner == R.map then break end
        local screen = owner:FindFirstChild("Screen")
        if screen and screen:IsA("BasePart") then
            local c = screen.Color
            return screen.Transparency > 0.5 or (c.G > 0.4 and c.G > c.R * 1.4 and c.G > c.B * 1.4)
        end
        owner = owner.Parent
    end
    return nil -- No screen evidence: completion is unknown, not assumed unfinished.
end
local function infer(root, hum, nearestPod, nearestComputer, threat, nearestExit)
    local state, reasons, tags = stats(player), {}, {}
    local scores = { general = 0, autohelp = 0, autofarm = 0, autohide = 0 }
    local function evidence(mode, score, reason)
        scores[mode] = math.max(scores[mode], score)
        reasons[#reasons + 1] = reason
    end
    local function toward(item)
        if not item then return false end
        local delta = item.part.Position - root.Position
        local flat = Vector3.new(delta.X, 0, delta.Z)
        local move = hum.MoveDirection
        return flat.Magnitude > 0.1 and move.Magnitude > 0.1 and move.Unit:Dot(flat.Unit) > 0.25
    end
    local captured = state.Captured == true or state.InPodium == true or state.InPod == true
    local blocked = captured or state.Ragdoll == true or state.Escaped == true or state.IsBeast == true
    if blocked then
        tags[#tags + 1] = captured and "self_captured" or (state.IsBeast and "playing_beast" or "not_active_survivor")
    else
        local action = actionKind()
        local workingPC = state.IsTyping == true
            or state.Typing == true
            or state.IsHacking == true
            or (action == "computer" and state.ActionInput == true)
        if workingPC then
            evidence("autofarm", 100, "observed_computer_interaction")
            tags[#tags + 1] = "hacking"
            R.rescueCommit = nil
        end
        if action == "pod" and state.ActionInput == true then
            evidence("autohelp", 100, "observed_pod_interaction")
            tags[#tags + 1] = "rescuing"
        end
        if action == "exit" and state.ActionInput == true then
            evidence("autofarm", 100, "observed_exit_interaction")
            tags[#tags + 1] = "opening_exit"
        end
        if nearestPod then
            tags[#tags + 1] = "occupied_pod_present"
            evidence("autohelp", 30, "occupied_pod_in_map")
            local distance = nearestPod.distance
            local progressing = R.podProgress
                and R.podProgress.part == nearestPod.part
                and R.podProgress.distance - distance > 0.35
            if not workingPC and distance <= 160 and (toward(nearestPod) or progressing) then
                local closePC = nearestComputer
                    and nearestComputer.distance < 14
                    and nearestComputer.distance < distance * 0.45
                    and toward(nearestComputer)
                evidence("autohelp", closePC and 55 or 88, "approaching_occupied_pod")
                if not closePC then R.rescueCommit = os.clock() + 4 end
            elseif distance <= 7 and math.abs(nearestPod.part.Position.Y - root.Position.Y) <= 4 then
                evidence("autohelp", 90, "at_occupied_pod")
            elseif R.rescueCommit and os.clock() < R.rescueCommit then
                evidence("autohelp", 82, "recent_rescue_approach_during_detour")
            end
            R.podProgress = { part = nearestPod.part, distance = distance }
            if action == "door" and state.ActionInput == true and R.rescueCommit then
                evidence("autohelp", 86, "door_interaction_after_rescue_approach")
                R.rescueCommit = os.clock() + 4
            end
        else
            R.podProgress, R.rescueCommit = nil, nil
        end
        if threat then
            tags[#tags + 1] = "beast_observed"
            local sameFloor = math.abs(threat.part.Position.Y - root.Position.Y) <= 8
            local watch = R.beastWatch
            if not watch or watch.part ~= threat.part or os.clock() - (watch.seenAt or 0) > 2 then
                watch = { part = threat.part, p = threat.part.Position, movedAt = os.clock() }
                R.beastWatch = watch
            end
            watch.seenAt = os.clock()
            if (threat.part.Position - watch.p).Magnitude > 0.75 then
                watch.p, watch.movedAt = threat.part.Position, os.clock()
            end
            local afk = os.clock() - watch.movedAt >= 40
            if afk then tags[#tags + 1] = "beast_stationary_40s" end
            local delta = threat.part.Position - root.Position
            local away = Vector3.new(-delta.X, 0, -delta.Z)
            local fleeing = away.Magnitude > 0.1 and hum.MoveDirection:Dot(away.Unit) > 0.25
            local approaching = threat.part.AssemblyLinearVelocity:Dot(
                delta.Magnitude > 0.1 and -delta.Unit or Vector3.new()
            ) > 1
            if sameFloor and threat.distance <= 28 then
                tags[#tags + 1] = "beast_near"
                if threat.visible == false then tags[#tags + 1] = "beast_behind_geometry" end
                if not afk and (fleeing or approaching or (threat.distance <= 12 and threat.visible ~= false)) then
                    evidence(
                        "autohide",
                        threat.visible == false and 70 or 78,
                        "near_beast_with_escape_or_closing_evidence"
                    )
                end
            elseif not sameFloor then
                tags[#tags + 1] = "beast_other_height"
            end
        else
            R.beastWatch = nil
        end
        if nearestComputer then
            if nearestComputer.distance <= 65 and toward(nearestComputer) then
                evidence("autofarm", 65, "approaching_unfinished_or_unknown_computer")
            elseif
                nearestComputer.distance <= 8 and math.abs(nearestComputer.part.Position.Y - root.Position.Y) <= 4
            then
                evidence("autofarm", 50, "near_unfinished_or_unknown_computer")
            end
        end
        if nearestExit and nearestExit.distance <= 30 and toward(nearestExit) then
            evidence("autofarm", 60, "approaching_exit")
        end
    end
    local chosen, best = "general", 0
    for _, mode in ipairs({ "autohelp", "autofarm", "autohide" }) do
        if scores[mode] > best then
            chosen, best = mode, scores[mode]
        end
    end
    -- A captive somewhere in the map alone does not prove a rescue intention.
    if best < 50 then
        chosen, best = "general", 0
    end
    if
        not blocked
        and R.mode ~= "general"
        and scores[R.mode] >= best - 12
        and scores[R.mode] >= 50
        and R.modeUntil
        and os.clock() < R.modeUntil
        and best < 95
    then
        chosen, best = R.mode, scores[R.mode]
    end
    if chosen ~= R.mode then
        R.mode, R.modeUntil = chosen, os.clock() + 1
        event("inferred_situation", { selected = chosen, scores = scores, reasons = reasons })
    end
    local candidates = {}
    for _, mode in ipairs({ "autohelp", "autofarm", "autohide" }) do
        if scores[mode] >= 50 then candidates[#candidates + 1] = mode end
    end
    return {
        primary = chosen,
        confidence = best >= 95 and "observed_interaction"
            or (#candidates > 1 and "overlapping_situations" or (best >= 65 and "likely" or "uncertain")),
        candidates = candidates,
        scores = scores,
        reasons = reasons,
        tags = tags,
        nearest_occupied_pod = nearestPod and rounded(nearestPod.distance),
        nearest_computer = nearestComputer and rounded(nearestComputer.distance),
        beast_distance = threat and rounded(threat.distance),
        beast_line_of_sight = threat and threat.visible,
    }
end
local function sensors(root, hum)
    local position = root.Position
    local forward = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
    if forward.Magnitude < 0.1 then forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
    if forward.Magnitude < 0.1 then forward = Vector3.new(0, 0, -1) end
    forward = forward.Unit
    local side = Vector3.new(-forward.Z, 0, forward.X)
    local feet = position.Y - (hum.HipHeight > 0 and hum.HipHeight or 2) - root.Size.Y * 0.5
    local low, body = Vector3.new(position.X, feet + 0.08, position.Z), Vector3.new(position.X, feet + 2, position.Z)
    local specs = {
        { "ground", position, Vector3.new(0, -8, 0) },
        { "ahead_ground", position + forward * 4, Vector3.new(0, -12, 0) },
        { "front_low", low, forward * 6 },
        { "front_body", body, forward * 6 },
        { "left", body, -side * 5 },
        { "right", body, side * 5 },
        { "front_left", body, (forward - side).Unit * 6 },
        { "front_right", body, (forward + side).Unit * 6 },
        { "headroom", position, Vector3.new(0, 5, 0) },
    }
    local result = {}
    for _, spec in ipairs(specs) do
        local hit = World:Raycast(spec[2], spec[3], ray)
        result[#result + 1] = {
            ray = spec[1],
            origin = vec(spec[2]),
            direction = vec(spec[3]),
            hit = hit ~= nil,
            id = hit and entity(hit.Instance),
            distance = hit and rounded(hit.Distance),
            p = hit and vec(hit.Position),
            normal = hit and vec(hit.Normal),
        }
    end
    return result
end
local function describeScene(root, hum, readings, targets, inference, pod, computer)
    local byName, tags = {}, {}
    for _, reading in ipairs(readings) do
        byName[reading.ray] = reading
    end
    local function near(name, limit)
        local reading = byName[name]
        return reading and reading.hit and reading.distance <= limit
    end
    if near("front_low", 3.5) and not near("front_body", 3.5) then tags[#tags + 1] = "low_obstacle_ahead" end
    if near("front_body", 3.5) then tags[#tags + 1] = "front_blocked" end
    for _, name in ipairs({ "left", "right", "front_left", "front_right" }) do
        if near(name, 2.5) then tags[#tags + 1] = name .. "_obstacle" end
    end
    local ground, ahead = byName.ground, byName.ahead_ground
    if ground.hit and ground.normal[2] < 0.95 then tags[#tags + 1] = "sloped_support" end
    if not ahead.hit then
        tags[#tags + 1] = "no_ground_within_ahead_probe"
    elseif ground.hit then
        local difference = ahead.p[2] - ground.p[2]
        if difference > 0.2 then tags[#tags + 1] = "rise_ahead" end
        if difference < -3 then tags[#tags + 1] = "drop_ahead" end
    end
    local tagged = {}
    for _, target in ipairs(targets) do
        if target.distance < 12 and not tagged[target.kind] then
            tagged[target.kind] = true
            if table.find({ "window", "door", "stairs", "ramp", "exit", "vent" }, target.kind) then
                tags[#tags + 1] = target.kind .. "_near"
            end
        end
    end
    local targetHeights = {}
    for _, item in ipairs({ { "pod", pod }, { "computer", computer } }) do
        if item[2] then
            local dy = item[2].part.Position.Y - root.Position.Y
            targetHeights[item[1]] = rounded(dy)
            if math.abs(dy) > 6 then tags[#tags + 1] = item[1] .. (dy > 0 and "_above" or "_below") end
        end
    end
    local clock, last = os.clock(), R.lastContextBody
    local motion = { input = vec(hum.MoveDirection), velocity = vec(root.AssemblyLinearVelocity) }
    local observed = stats(player)
    local interacting = observed.ActionInput == true
        or observed.IsTyping == true
        or observed.Typing == true
        or observed.IsHacking == true
    local noTravelExpected = interacting
        or observed.Captured == true
        or observed.InPodium == true
        or observed.InPod == true
        or observed.Ragdoll == true
    if last and clock - last.at <= 1.5 then
        local delta = root.Position - last.p
        local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
        motion.elapsed_ms, motion.horizontal, motion.height_change =
            math.round((clock - last.at) * 1000), rounded(horizontal), rounded(delta.Y)
        if delta.Y > 0.8 then tags[#tags + 1] = "rising" end
        if delta.Y < -0.8 then tags[#tags + 1] = "descending" end
        if
            hum.MoveDirection.Magnitude > 0.1
            and last.dir.Magnitude > 0.1
            and hum.MoveDirection.Unit:Dot(last.dir.Unit) < -0.5
        then
            tags[#tags + 1] = "direction_reversal"
            event("direction_reversal", { p = vec(root.Position), from = vec(last.dir), to = vec(hum.MoveDirection) })
        end
        if hum.MoveDirection.Magnitude > 0.1 and horizontal < 0.12 and not noTravelExpected then
            R.motionStallAt = R.motionStallAt or last.at
            motion.low_progress_ms = math.round((clock - R.motionStallAt) * 1000)
            if clock - R.motionStallAt >= 1 then
                tags[#tags + 1] = "input_with_low_horizontal_progress"
                if not R.stallReported then
                    event(
                        "possible_stall",
                        { duration_ms = motion.low_progress_ms, meaning = "observation_not_confirmed_bug" }
                    )
                    R.stallReported = true
                end
            end
        else
            if R.stallReported then event("progress_resumed", { p = vec(root.Position) }) end
            R.motionStallAt, R.stallReported = nil, nil
        end
    end
    R.lastContextBody = { at = clock, p = root.Position, dir = hum.MoveDirection }
    local state, phase = observed, "travelling_or_unknown"
    local action = actionKind()
    if state.Captured == true or state.InPodium == true or state.InPod == true then
        phase = "self_captured"
    elseif state.Ragdoll == true then
        phase = "ragdolled"
    elseif state.IsTyping == true or state.Typing == true or state.IsHacking == true then
        phase = "hacking"
    elseif interacting and action == "pod" then
        phase = "rescuing"
    elseif interacting and action == "exit" then
        phase = "opening_exit"
    elseif interacting and action == "door" then
        phase = "door_interaction"
    elseif inference.primary == "autohelp" then
        phase = pod and pod.distance <= 7 and "near_pod" or "rescue_approach"
    elseif inference.primary == "autohide" then
        phase = "possible_evasion"
    elseif inference.primary == "autofarm" then
        phase = computer and computer.distance <= 8 and "near_pc_not_hacking" or "pc_or_exit_approach"
    end
    return {
        phase = phase,
        tags = tags,
        motion = motion,
        target_height_difference = targetHeights,
        interaction_kind = action,
        action_input = interacting,
    }
end
local function context(root, hum)
    local nearby = {}
    local nearestPod, nearestComputer, threat, nearestExit
    local occupiedPods = {}
    for _, entry in ipairs(R.catalog) do
        local part = entry.part
        if part.Parent and part:IsDescendantOf(R.map) then
            local distance = (part.Position - root.Position).Magnitude
            local item = { part = part, kind = entry.kind, distance = distance }
            local torso = part:FindFirstChild("CapturedTorso")
            if torso and torso:IsA("ObjectValue") and torso.Value then occupiedPods[#occupiedPods + 1] = item end
            if
                torso
                and torso:IsA("ObjectValue")
                and torso.Value
                and (not nearestPod or distance < nearestPod.distance)
            then
                nearestPod = item
            end
            if
                entry.kind == "computer"
                and not computerDone(part)
                and (not nearestComputer or distance < nearestComputer.distance)
            then
                nearestComputer = item
            end
            if entry.kind == "exit" and (not nearestExit or distance < nearestExit.distance) then nearestExit = item end
            if distance <= 45 then nearby[#nearby + 1] = { part = part, kind = entry.kind, distance = distance } end
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    local targets = {}
    for i = 1, math.min(10, #nearby) do
        local item = nearby[i]
        local torso = item.part:FindFirstChild("CapturedTorso")
        local occupied, completed
        if torso and torso:IsA("ObjectValue") then occupied = torso.Value ~= nil end
        if item.kind == "computer" then completed = computerDone(item.part) end
        targets[#targets + 1] = {
            id = entity(item.part),
            kind = item.kind,
            p = vec(item.part.Position),
            distance = rounded(item.distance),
            collidable = item.part.CanCollide,
            occupied = occupied,
            computer_done = completed,
        }
    end
    local others, excluded = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        local character = p.Character
        if character then excluded[#excluded + 1] = character end
        local part = character and character:FindFirstChild("HumanoidRootPart")
        if p ~= player and part and (part.Position - root.Position).Magnitude <= 65 then
            if not R.people[p] then
                R.personCount += 1
                R.people[p] = R.personCount
            end
            local state = stats(p)
            if
                state.IsBeast == true and (not threat or (part.Position - root.Position).Magnitude < threat.distance)
            then
                threat = { part = part, distance = (part.Position - root.Position).Magnitude }
            end
            others[#others + 1] = {
                id = R.people[p],
                p = vec(part.Position),
                v = vec(part.AssemblyLinearVelocity),
                beast = state.IsBeast == true,
                role_known = state.IsBeast ~= nil,
                captured = state.Captured == true or state.InPodium == true or state.InPod == true,
            }
        end
    end
    ray.FilterDescendantsInstances = excluded
    if threat then threat.visible = World:Raycast(root.Position, threat.part.Position - root.Position, ray) == nil end
    local inference = infer(root, hum, nearestPod, nearestComputer, threat, nearestExit)
    local readings = sensors(root, hum)
    table.sort(occupiedPods, function(a, b) return a.distance < b.distance end)
    local rescueTargets = {}
    for i = 1, math.min(5, #occupiedPods) do
        local item = occupiedPods[i]
        rescueTargets[#rescueTargets + 1] =
            { id = entity(item.part), p = vec(item.part.Position), distance = rounded(item.distance) }
    end
    local camera = World.CurrentCamera
    append({
        k = "context",
        rays = readings,
        nearby = targets,
        others = others,
        inference = inference,
        scene = describeScene(root, hum, readings, targets, inference, nearestPod, nearestComputer),
        rescue_targets = rescueTargets,
        computer_goal = nearestComputer
            and { id = entity(nearestComputer.part), p = vec(nearestComputer.part.Position) },
        camera = camera and { p = vec(camera.CFrame.Position), f = vec(camera.CFrame.LookVector) },
        discovery = { visited = R.scanCount, queued = math.max(0, #R.queue - R.cursor + 1) },
    })
end
local function bindCharacter(hum)
    if R.hum == hum then return end
    disconnect(R.characterConnections)
    R.hum = hum
    if hum then
        R.characterConnections[1] = hum.StateChanged:Connect(function(old, new)
            if R.running then event("humanoid_state", { from = old.Name, to = new.Name }) end
        end)
    end
end
local function tick()
    if not R.running then return end
    local clock = os.clock()
    if clock < R.nextSample then return end
    R.nextSample = clock + SAMPLE -- Never catch up with a burst after a slow frame.
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    bindCharacter(hum)
    if clock >= R.nextMap then
        R.nextMap = clock + 0.5
        R.resolvedMap, R.mapSource = resolveMap()
    end
    segment(R.resolvedMap, R.mapSource or "unknown", character, root)
    scanBatch()
    if not hum or not root or hum.Health <= 0 then
        if not R.absent then
            event("character_unavailable")
            R.absent = true
        end
        return
    end
    if R.absent then
        event("character_available")
        R.absent = false
    end
    if clock >= R.nextContext then
        R.nextContext = clock + CONTEXT
        context(root, hum)
    end
    local state = hum:GetState().Name
    local velocity = root.AssemblyLinearVelocity
    if R.lastFrame and state == "Freefall" and R.lastFrame.air and velocity.Y - R.lastFrame.vy > 12 then
        -- A measured upward velocity change, not proof of a double jump (lift/platforms can cause it).
        event("airborne_upward_change", { delta_vy = rounded(velocity.Y - R.lastFrame.vy) })
    end
    R.lastFrame = { vy = velocity.Y, air = hum.FloorMaterial == Enum.Material.Air }
    local localStats = stats(player)
    local folder = player:FindFirstChild("TempPlayerStatsModule")
    local action = folder and folder:FindFirstChild("ActionEvent")
    local target = action and action:IsA("ObjectValue") and action.Value
    if target and not target:IsA("BasePart") then target = target.Parent end
    local targetId = target and R.map and target:IsA("BasePart") and target:IsDescendantOf(R.map) and entity(target)
        or nil
    if
        append({
            k = "frame",
            p = vec(root.Position),
            f = vec(root.CFrame.LookVector),
            m = vec(hum.MoveDirection),
            v = vec(velocity),
            state = state,
            floor = hum.FloorMaterial.Name,
            speed = rounded(hum.WalkSpeed),
            jump_power = rounded(hum.JumpPower),
            jump_height = rounded(hum.JumpHeight),
            use_jump_power = hum.UseJumpPower,
            hip_height = rounded(hum.HipHeight),
            root_size = vec(root.Size),
            up = vec(root.CFrame.UpVector),
            health = rounded(hum.Health),
            stats = localStats,
            target = targetId,
        })
    then
        R.frames += 1
    end
    if R.frames >= MAX_FRAMES then stop("limit") end
end
local function start()
    if R.running then return end
    if R.frames >= MAX_FRAMES or R.bytes >= MAX_BYTES - 2048 or #R.lines >= MAX_LINES - 2 then
        notify("Phiên đã đầy. Xuất file rồi bấm Phiên mới.")
        return
    end
    if not R.started then
        R.started, R.created = os.clock(), os.date("!%Y-%m-%dT%H:%M:%SZ")
        R.session = os.date("!%Y%m%d-%H%M%S") .. "-" .. tostring(math.random(1000, 9999))
    end
    R.running, R.nextSample, R.nextMap, R.nextContext = true, 0, 0, 0
    R.lastContextBody, R.motionStallAt, R.stallReported = nil, nil, nil
    if #R.lines == 0 then
        append({
            k = "header",
            schema = "ftf-movement-observation",
            version = 1,
            session = R.session,
            created_utc = R.created,
            place = game.PlaceId,
            sample_hz = 10,
            context_hz = 2,
            position_units = "studs",
            purpose = "situational_reference_not_replay_or_automatic_training",
            mode_labels = "inferred_from_observations_not_actual_bot_toggles",
            inference_version = 1,
            limits = { frames = MAX_FRAMES, bytes = MAX_BYTES },
            people = "anonymous_session_ids",
        })
    else
        R.lastFrame = nil
        event("resume")
    end
    frozenExport = nil
    notify("Đang ghi. Hãy tự chơi; tắt các chế độ tự đi.")
end
local function reset()
    stop("new_session")
    if R.mapConnection then
        R.mapConnection:Disconnect()
        R.mapConnection = nil
    end
    disconnect(R.characterConnections)
    for _, key in ipairs({
        "started",
        "created",
        "session",
        "map",
        "character",
        "hum",
        "lastFrame",
        "resolvedMap",
        "absent",
        "lastJumpRequest",
        "podProgress",
        "rescueCommit",
        "beastWatch",
        "modeUntil",
    }) do
        R[key] = nil
    end
    R.mode = "general"
    R.lines, R.bytes, R.frames, R.segment = {}, 0, 0, 0
    R.maps, R.mapCount, R.people, R.personCount = {}, 0, {}, 0
    R.entities, R.entityCount, R.catalog, R.queue, R.cursor, R.scanCount = {}, 0, {}, {}, 1, 0
    R.queued = {}
    pages, page, frozenExport = nil, nil, nil
    if preview then preview.Visible = false end
    notify("Phiên mới sẵn sàng. Bấm Ghi.")
end
local renderPage
local function export()
    stop("export")
    if #R.lines == 0 then
        notify("Chưa có dữ liệu. Bấm Ghi trước.")
        return
    end
    if not frozenExport then frozenExport = table.concat(R.lines, "\n") .. "\n" end
    local filename = "ftf-movement-" .. R.session .. ".jsonl"
    if type(writefile) == "function" then
        local ok, result = pcall(writefile, filename, frozenExport)
        if ok and result ~= false then
            notify("Đã lưu: " .. filename .. " (workspace của executor)")
            return filename
        end
    end
    -- No file API: a bounded, selectable text page instead of a huge mobile textbox.
    pages, page = {}, 1
    local group, size = {}, 0
    for _, line in ipairs(R.lines) do
        if size + #line + 1 > 12000 and #group > 0 then
            pages[#pages + 1] = table.concat(group, "\n") .. "\n"
            group, size = {}, 0
        end
        group[#group + 1], size = line, size + #line + 1
    end
    if #group > 0 then pages[#pages + 1] = table.concat(group, "\n") .. "\n" end
    renderPage()
    notify("Không lưu được file. Dùng các trang văn bản bên dưới.")
    return nil
end

-- UI: touch buttons, draggable title, no keyboard shortcuts competing with D.
local function new(class, properties, parent)
    local item = Instance.new(class)
    for key, value in pairs(properties) do
        item[key] = value
    end
    item.Parent = parent
    return item
end
local parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not parent then error("Recorder needs PlayerGui; join a game before running it.") end
if parent:FindFirstChild("FTFMovementRecorderUI") then
    warn("Recorder UI already exists. Use its buttons; data was not replaced.")
    return
end
gui = new("ScreenGui", {
    Name = "FTFMovementRecorderUI",
    ResetOnSpawn = false,
    DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parent)
local panel = new("Frame", {
    Size = UDim2.fromOffset(304, 245),
    Position = UDim2.new(0, 12, 0, 65),
    BackgroundColor3 = Color3.fromRGB(22, 25, 32),
    BorderSizePixel = 0,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
local title = new("TextLabel", {
    Size = UDim2.new(1, -58, 0, 34),
    BackgroundTransparency = 1,
    Text = "FTF · Ghi cách di chuyển",
    TextSize = 15,
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    Active = true,
}, panel)
local minimize = new("TextButton", {
    Size = UDim2.fromOffset(45, 30),
    Position = UDim2.new(1, -50, 0, 2),
    BackgroundTransparency = 1,
    Text = "−",
    TextSize = 22,
    TextColor3 = Color3.new(1, 1, 1),
}, panel)
status = new("TextLabel", {
    Position = UDim2.fromOffset(10, 35),
    Size = UDim2.new(1, -20, 0, 26),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(150, 210, 255),
    TextSize = 12,
    TextWrapped = true,
}, panel)
local message = new("TextLabel", {
    Position = UDim2.fromOffset(10, 62),
    Size = UDim2.new(1, -20, 0, 44),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(220, 220, 220),
    TextSize = 12,
    TextWrapped = true,
    Text = "Tắt tự di chuyển. Bấm Ghi rồi tự chơi.",
}, panel)
local function button(text, x, y, width, callback)
    local item = new("TextButton", {
        Text = text,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, 35),
        BackgroundColor3 = Color3.fromRGB(51, 65, 90),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
    }, panel)
    new("UICorner", { CornerRadius = UDim.new(0, 5) }, item)
    R.connections[#R.connections + 1] = item.Activated:Connect(callback)
    return item
end
toggle = button("Ghi", 10, 110, 85, function()
    if R.running then
        stop("button")
    else
        start()
    end
end)
button("Xuất file", 104, 110, 90, export)
local resetAt = -10
button("Phiên mới", 203, 110, 91, function()
    if #R.lines > 0 and os.clock() - resetAt > 4 then
        resetAt = os.clock()
        notify("Xuất file trước! Bấm Phiên mới lần nữa để xóa phiên này.")
        return
    end
    reset()
end)
hint = new("TextBox", {
    Position = UDim2.fromOffset(10, 153),
    Size = UDim2.fromOffset(284, 35),
    BackgroundColor3 = Color3.fromRGB(35, 39, 49),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    PlaceholderText = "Tên map / tình huống / lý do chọn đường...",
    Text = "",
    ClearTextOnFocus = false,
}, panel)
local modeNames = { general = "Chung", autohelp = "AutoHelp", autofarm = "AutoFarm", autohide = "AutoHide" }
local modeLabel = new("TextLabel", {
    Position = UDim2.fromOffset(10, 197),
    Size = UDim2.fromOffset(135, 35),
    BackgroundTransparency = 1,
    Text = "Tự: Chung",
    TextSize = 12,
    TextColor3 = Color3.fromRGB(150, 210, 255),
    TextWrapped = true,
}, panel)
button("Đánh dấu", 153, 197, 141, function()
    if not R.running then
        notify("Bấm Ghi trước khi đánh dấu.")
        return
    end
    -- Limit notes by Unicode codepoints, without splitting Vietnamese characters.
    local text = hint.Text
    local boundary = utf8.offset(text, 121)
    if boundary then text = string.sub(text, 1, boundary - 1) end
    event("note", { text = text ~= "" and text or "marked_by_player" })
    hint.Text = ""
    notify("Đã đánh dấu thời điểm và ghi chú.")
end)
preview = new("Frame", {
    Position = UDim2.fromOffset(0, 35),
    Size = UDim2.fromOffset(304, 210),
    BackgroundColor3 = Color3.fromRGB(22, 25, 32),
    Visible = false,
}, panel)
pageLabel = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 36),
    Position = UDim2.fromOffset(5, 0),
    BackgroundTransparency = 1,
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 11,
    TextWrapped = true,
}, preview)
local textScroll = new("ScrollingFrame", {
    Position = UDim2.fromOffset(6, 38),
    Size = UDim2.fromOffset(292, 120),
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = Color3.fromRGB(15, 17, 22),
    ScrollBarThickness = 5,
}, preview)
local textBox = new("TextBox", {
    Name = "Data",
    Size = UDim2.new(1, -10, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Text = "",
    TextEditable = false,
    MultiLine = true,
    TextWrapped = true,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 11,
    BackgroundTransparency = 1,
}, textScroll)
local previewData = textBox
local function pageButton(text, x, callback)
    local b = new("TextButton", {
        Text = text,
        Size = UDim2.fromOffset(90, 30),
        Position = UDim2.fromOffset(x, 169),
        BackgroundColor3 = Color3.fromRGB(51, 65, 90),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
    }, preview)
    R.connections[#R.connections + 1] = b.Activated:Connect(callback)
end
pageButton("Trước", 8, function()
    if pages then
        page = math.max(1, page - 1)
        renderPage()
    end
end)
pageButton("Chép trang", 107, function()
    if not pages then return end
    if type(setclipboard) == "function" then
        local ok, result = pcall(setclipboard, pages[page])
        if ok and result ~= false then
            notify("Đã chép trang " .. page)
            return
        end
    end
    previewData:CaptureFocus()
    previewData.SelectionStart, previewData.CursorPosition = 1, #previewData.Text + 1
    notify("Nhấn giữ văn bản rồi chọn Sao chép.")
end)
pageButton("Sau", 206, function()
    if pages then
        page = math.min(#pages, page + 1)
        renderPage()
    end
end)
local closePreview = new("TextButton", {
    Text = "×",
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -32, 0, 0),
    BackgroundTransparency = 1,
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 20,
}, preview)
R.connections[#R.connections + 1] = closePreview.Activated:Connect(function() preview.Visible = false end)
-- Keep the page renderer's textbox reference outside the UI hierarchy lookup.
renderPage = function()
    if not pages then return end
    preview.Visible = true
    previewData.Text = pages[page]
    pageLabel.Text = string.format("Trang %d/%d · chép đủ trang nếu không lưu được file", page, #pages)
end
local collapsed, previewWasVisible = false, false
R.connections[#R.connections + 1] = minimize.Activated:Connect(function()
    if not collapsed then previewWasVisible = preview.Visible end
    collapsed = not collapsed
    panel.Size = UDim2.fromOffset(304, collapsed and 35 or 245)
    for _, child in ipairs(panel:GetChildren()) do
        if child:IsA("GuiObject") and child ~= title and child ~= minimize then
            child.Visible = not collapsed and (child ~= preview or previewWasVisible)
        end
    end
    minimize.Text = collapsed and "+" or "−"
end)
notify = function(text)
    message.Text = text
    toggle.Text = R.running and "Dừng" or (#R.lines > 0 and "Tiếp tục" or "Ghi")
end
local drag, dragOrigin, panelOrigin
R.connections[#R.connections + 1] = title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        drag, dragOrigin, panelOrigin = input, input.Position, panel.Position
    end
end)
R.connections[#R.connections + 1] = Input.InputChanged:Connect(function(input)
    if not drag then return end
    if input ~= drag and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = input.Position - dragOrigin
    local size = gui.AbsoluteSize
    local x = math.clamp(panelOrigin.X.Offset + delta.X, 0, math.max(0, size.X - 304))
    local y = math.clamp(panelOrigin.Y.Offset + delta.Y, 0, math.max(0, size.Y - panel.AbsoluteSize.Y))
    panel.Position = UDim2.fromOffset(x, y)
end)
R.connections[#R.connections + 1] = Input.InputEnded:Connect(function(input)
    if input == drag or input.UserInputType == Enum.UserInputType.MouseButton1 then drag = nil end
end)
R.connections[#R.connections + 1] = Input.JumpRequest:Connect(function()
    if not R.running or Input:GetFocusedTextBox() then return end
    if R.lastJumpRequest and os.clock() - R.lastJumpRequest < 0.08 then return end
    R.lastJumpRequest = os.clock()
    event("jump_request", { meaning = "request_not_confirmed_double_jump" })
end)
local KEY_NAMES =
    { W = true, A = true, S = true, D = true, Space = true, LeftShift = true, RightShift = true, E = true }
for _, binding in ipairs({ { Input.InputBegan, true }, { Input.InputEnded, false } }) do
    R.connections[#R.connections + 1] = binding[1]:Connect(function(input, processed)
        if R.running and not Input:GetFocusedTextBox() and KEY_NAMES[input.KeyCode.Name] then
            event("key", { key = input.KeyCode.Name, down = binding[2], processed = processed == true })
        end
    end)
end
local uiAt = 0
R.connections[#R.connections + 1] = Run.Heartbeat:Connect(function()
    if R.running then
        local ok, problem = pcall(tick)
        if not ok then
            stop("error")
            warn("Recorder stopped; export retained data: " .. tostring(problem))
        end
    end
    if os.clock() >= uiAt then
        uiAt = os.clock() + 0.5
        status.Text = string.format(
            "%s · %d mẫu · %.0f KB · %s",
            R.running and "Đang ghi" or "Đã dừng",
            R.frames,
            R.bytes / 1024,
            R.map and R.map.Name or "map chưa rõ"
        )
        modeLabel.Text = "Tự: " .. modeNames[R.mode]
    end
end)
shared.FTFMovementRecorder = {
    Show = function() gui.Enabled = true end,
    Start = start,
    Stop = function() stop("api") end,
    Export = export,
}
