# Ninth round — 2026-11-12 (8)

Source: 1 recorder file (Homestead) plus user reports.

| Finding | Change | Test |
|---|---|---|
| Fewer completed hacks after the 2 s / 30 s hack guard | Guard back to 6 s, skip 10 s. The older 4 s "unconfirmed" exit also sets the slot aside for 6 s when no ActionInput was ever seen | scenario adjusted |
| Rapid "undecided" shaking (Homestead #3–6) with `drop-shortcut` and `vertical-waypoint-advanced` firing every few frames | Drop shortcut: ≥ 15 studs saving, checked each 1 s, at most 2 per leg, 3 s cooldown after an attempt. Vertical advance only after 0.6 s without progress | — |
| Pod straight below a roof/floor: the flat direction to it is about 0 and flipped every frame (shaking on top) | WalkTo commits to one verified drop edge, or walks to the nearest edge/pit within 14 studs and steps off; otherwise it waits for the route | fails on `783bdd6` (stays on the roof), 0.9 s now |
| AutoHide turned away from holes it could walk into | `AH.DropAim`: if no verified jump lane exists but the walk into the drop is clear at body heights, it walks in (committed drop traversal) | — |
| Relaxed route entry could aim at waypoint 2 behind us (one step back) | Pick the farthest reachable waypoint within 6 studs | — |
| **Waiting at an open exit, the Beast starts chasing → the bot did not cross**: the escape goal was chosen, but the final crossing condition lacked the chase reason, so it returned to waiting and AutoHide took it elsewhere | Being chased is a crossing reason | fails on `783bdd6`, escapes in 1.3 s now |

## Verification

- Harness: 153 scenarios / 338 checks pass. D compiles.
- Nothing was run in Roblox.

# Live recorder data, eighth batch — 2026-11-12 (7)

Source: 14 recorder files (348 incidents).

| Finding | Change | Test |
|---|---|---|
| Exit opened by our own hold still read "closed" (`exit:still-closed-after-opening`): the gate was failed, the bot went to open the other exit, then repeated 1-step / 3 s stops | A gate counts as open when our hold reaches ≥ 98 % progress, or its panels lose collision / move compared with this round's first view (indicator transparency ignored). Valid per map | — |
| 125 s standing on a prop whose top the down-ray cannot see (`ground` none). Planner and local lanes both gave up | WalkTo stall breaker: with no plan pending, 1.5 s without progress triggers a blind 0.7 s walk toward the goal, or the most open of 8 directions | existing "planner pending" scenario still holds still and times out |
| E held 3.6 s without a hack, repeatedly at the same Ghost Town computer | Guard 2 s; a computer whose every slot refused is skipped for 30 s | — |
| Lobby: 116 stalls / 543 s of pauses between strolls and chats | Continuous strolling with chained points (mostly no pause). Only ~30 % short face-to-face stops (2–3.5 s), with varied partners and spots | — |
| User: waiting at a closed door during a rescue while the Beast opened it from the other side | A Beast within 8 studs behind a door preempts the rescue (a wall still does not) | fails on `600b5aa`, passes now |
| User: the head-on veer shook / started too late | Head-on detection up to 40 studs; re-veer on the same side with no gap back toward the Beast | scenario extended |

## Verification

- Harness: 151 scenarios / 335 checks pass. D compiles.
- Nothing was run in Roblox.

# Seventh round — 2026-11-12 (6): rescue head-on shaking

The user reported violent shaking when a rescue met a Beast head-on. The recorder file had no incident near the Beast (shaking faster than the 10 Hz sampling does not register as a reversal), so the cause was found in code.

| Cause | Change | Test |
|---|---|---|
| The previous round's 12-stud head-on hand-over (rescue → AutoHide) depended on our own velocity. AutoHide turned away, so the condition cleared, the higher-priority rescue reclaimed and turned back toward the Beast, and the cycle repeated: ownership flipped every frame | Hand-over back to immediate contact only (6 studs). The rescue itself veers around a facing Beast ahead: 6 studs to one side, held 0.7 s, same side while the Beast stays ahead. The avoidance ring makes the planner take the shortest way around | flip scenario fails on `5445241`, passes now. The veer scenario also fails on `5445241` and passes now |
| Possible "going backwards" on stairs: the vertical-waypoint advance accepted waypoints up to 6 studs **above** the feet, skipping an upper stair flight overhead | Upward limit 2 studs (step / hovering navmesh, as in the original live cases); downward limit 6 studs is kept | — |

## Verification

- Harness: 150 scenarios / 327 checks pass. D compiles.
- Nothing was run in Roblox.

# Live recorder data, sixth batch — 2026-11-12 (5)

Source: 1 recorder file (Arcade, 17 incidents).

| Finding | Change | Test |
|---|---|---|
| Chased toward an open exit, the bot centred, walked in, stopped at the volume's edge without escaping, and stood about 3 s. The exit was then failed, AutoHide no longer saw it as a priority, and the bot fled elsewhere when the Beast arrived. The strict clearance probe ended the crossing | A crossing that started at an open gate ends with a forced run into the volume. For the game bug where an entry is ignored, it steps back out in front of the gate and re-enters, up to 3 entries. Open exits are never removed from AutoHide's exit priority. While chased with an exit open, `AH.ExitGo` keeps trying it (3 retries) instead of fleeing elsewhere | re-entry scenario fails on `8c004c8`, passes now (2.8 s) |
| Corner oscillation guard ran a 4 s ground-route escape and skipped drops and vaults, so AutoHide "no longer jumps" | A cornered bot first takes a drop or a window/rail vault if one exists; the ground route escape lasts at most 2.5 s | not in harness |

## Verification

- Harness: 149 scenarios / 323 checks pass. D and the recorder compile.
- Nothing was run in Roblox.

# Live recorder data, fifth batch — 2026-11-12 (4)

Source: 3 recorder files (52 incidents, mostly Airport).

| Finding | Change | Test |
|---|---|---|
| AutoHide jitter in room corners: the aim alternated every 0.1–0.2 s between a ~20 stud steer into the wall and a ~4 stud opposite retreat (13 reversals, 1.6 studs net) | Oscillation guard in `AH.Go`: 3 reversals within 1.5 s run `AH.PathEscape`, a real route (through doorways, windows allowed) to an open flee point, for up to 4 s | not in harness (AH.Go is not extracted) |
| AutoHelp ran into a facing Beast. The ahead-avoidance ran only before the alarm, and rescue yielded to AutoHide only at 6 studs | Avoidance runs while chased too. Within 12 studs, a facing Beast we are running at preempts the rescue (unless already in pod contact) | fails on `b2f0e1e`, passes now |
| User: lobby "face to face" means in front of the other player's facing direction | Stand 3–5 studs along their LookVector (small side offset), then turn to them | — |

## Verification

- Harness: 148 scenarios / 322 checks pass. D compiles.
- Nothing was run in Roblox.

# Live recorder data, fourth batch — 2026-11-12 (3)

Source: 3 recorder files (47 incidents). 44 of them are one School exit wait: a 0.4 s step followed by about 3 s of standing, repeated, drifting up to 50 studs from the open exit. The user also reported that every other survivor had already escaped.

| Finding | Change | Test |
|---|---|---|
| AutoFarm's anti-stuck watch (`farmWatch`, 3 s) treated a legitimate exit wait as stuck and pushed the avatar: one step, one beat, drifting | No anti-stuck while `exitState.waiting`. The bot stands at the wait spot | — |
| Escaped players in the lobby could still count as in the match when a large map's bounding box reached the lobby, so the wait never released | `FH.InLobby`: players near `Workspace.LobbyInteractiveObjects` are never in the match | — |
| User rule: leave after 1 minute if nobody escapes | `FH.ExitWaitExpired`: 60 s of waiting with no new escape. Latched per exit so the escape is not restarted | escapes at 60.75 s |
| User: prefer jumping down over stairs | WalkTo drop shortcut: for a target more than 4 studs lower whose remaining route is longer than drop + straight + 6, a verified `Follow.DropLane` edge within 8 studs toward it is taken | fails on `1eaca2e` (7.2 s via stairs), 2.6 s now |
| Doorway/window shake (body brushing a frame rejects the lane) | `Follow.CenterAim` keeps the body centred between close side walls ahead (dense sampling for thin frames) | passes now; no-op in the open |

## Other changes

**AutoHide**
- Drops and window/rail vaults are considered during the whole flight (Beast within 70 studs instead of 32).
- Drop edges are searched up to 8 studs away.
- Flee picks weight long open runs over short ones ending in corners.

**AutoHelp**
- A facing Beast ahead gets an 8-point avoidance ring (4 studs, 2.5 s) and a replan every second.

## Verification and limits

- Harness: 147 scenarios / 320 checks pass with Luau 0.700.
- D and the recorder compile.
- The harness is a simplified model, and nothing was run in Roblox.

# Live recorder data, third batch — 2026-11-12 (2)

Source: 12 recorder files (262 incidents: 196 stalls, 44 pacing, 22 jitter).

| Finding | Change | Test |
|---|---|---|
| Open exit: the bot walked to it and paced in front of it in a 0.5 s move / 3 s stand cycle (Prison, Sanctuary). The 2.5 stud early stop also applied to crossing, so the bot stopped beside the frame and its straight crossing clipped the frame | Early stop only for opening. Before crossing, centre on the doorway line (trigger → volume, or the measured lane). Exit step reasons are logged, and the farm's exit state is now visible to the recorder | fails on `5599f91` (569 blocked frames), passes now |
| E held 15–73 s at a computer with ActionInput never set. The 3 s guard was reset by our own release/re-press, and computer progress rising from another player looked like our hack | Count from the last real ActionInput | fails before, passes now |
| Path aim at feet + 1.2 studs (exact border of the earlier fix), up to 27 s | Threshold 0.5 studs. Plus a final guard: a path aim < 0.6 studs away advances to the next waypoint (not at rescue corners) | — |
| Unreachable computer goal (inside furniture) on Sanctuary Zoo | Ring of 6 alternative approach points around the goal | — |
| User: a Beast outside a closed door walking in gave no alarm | Directional alarm sees through doors within 30 studs | fails before, passes now |

## Other changes

**AutoExit**
- An opened exit always wins.
- A closed exit with the Beast within 35 studs (walls ignored) is avoided.
- Chased with an exit open: escape now.
- While opening: below 70 % progress the bot flees from a threat; from 70 % it keeps opening.

**AutoHide**
- Closing in on the Beast within 12 studs (facing or not) raises the alarm.
- While ragdolled, Space is pressed once per second.
- Seer: best-effort detection from the Beast's stats (signal names unverified). The recorder now logs `beastState` changes so the real Seer signal can be identified.

**Keys**
- 0: Follow picker + AutoHide + AutoHelp. Pressing 0 again stops all of them.
- Load: AutoFarm + AutoHide + AutoHelp + ESP Player.

**Lobby**
- Library is preference #2.
- After voting the bot backs off, then stands 3–5 studs from a nearby player facing them. Who and where varies each time.

## Not addressed this round

- AutoHide route choice (windows, drops, open space instead of corners).
- Rescue-specific doorway centring.

## Verification

- Harness: 144 scenarios / 315 checks pass.
- D and the recorder compile.
- Nothing was run in Roblox.

# Live recorder data, second batch — 2026-11-12

Source: 15 recorder files (515 incidents: 353 stalls, 116 pacing, 46 jitter; 14 maps plus the lobby). Raw data stays out of the repo.

| Finding | Change |
|---|---|
| Pacing/jitter at open doorways and windows. `lane-rejected` 531× and `plan result-unusable:door` 814× in those incidents: brushing a door frame rejected the lane for 8 s, the only route through the opening was discarded, local steering backed out, then retried | `FH.PathAny` keeps a complete route through a rejected lane as a last resort for any goal (previously only for another floor). Default lane rejection is 3 s instead of 8 s. New scenario fails on `2b86371`, passes now. |
| AutoExit loop at Haunted Mansion: 0.5 s of walking then 3 s standing, repeated. Escape approach used `noDoor`, so a closed interior door meant "nopath", the exit was failed for 3 s, and so on | Exit approach may pass interior doors. An already open exit is never skipped after a failed approach, so the bot no longer runs to open the other gate. |
| Round running but the avatar is in the lobby (after escape/death/joining late) at the same spot on every map, idle 10–57 s | The AutoFarm loop strolls/votes whenever the avatar is not in the match. |
| Lobby scan: `Workspace.LobbyInteractiveObjects.MapVotingBoard` with `MapBoardA-D` (TitleLabel = map) and `VoteBoxA-D`. D walked under the board, not into the box, so no vote was cast | Pair each board with its VoteBox, step into it, then wait 3 studs in front. Without a preferred map, stroll near other players with varied points/pauses and no revisits. |
| E held up to 70 s at a computer while the game never set ActionInput | 3 s without ActionInput rejects that slot for 10 s; the next free slot (or another PC) is tried. |
| 21 path stalls (300 s) with the waypoint flat ≤ 1 stud but 1.6–4.5 studs above/below the feet (on props/rails, hovering navmesh). The previous "onward aim" did not clear them | Such a waypoint counts as reached and the route advances. |
| AutoHide pacing in open areas (75–130 studs travelled, < 6 net) | The flight heading persists across quick AutoHide restarts (3 s). |

## Controls

- **0**: AutoFarm + AutoHide + AutoHelp. It is enabled with Player ESP on load.
- **8**: Panic: a virtual chaser always behind us, so AutoHide flight runs continuously. Mode 0 overrides it.
- **9**: free.

## Verification

- Harness: 141 scenarios / 310 checks pass; D compiles.
- The doorway-rejection scenario fails on the previous commit and passes now.
- The prop-above-waypoint scenario passes on both versions (the harness does not reproduce the live geometry).
- Nothing was run in Roblox.

# Live stall-recorder data — 2026-11-11 (4)

Source: 13 recorder files from the user (110 incidents: 82 stalls, 20 pacing, 8 jitter, on 12 maps plus the lobby). Raw files and coordinates are not stored in this repo.

## What the data showed and what changed

| Finding (from the D snapshot in each incident) | Change |
|---|---|
| 27 stalls with **no movement owner**: AutoFarm and Follow were both off (only AutoHide/AutoHelp idle), at round start and in the lobby | On load D now enables AutoFarm, AutoHide, AutoHelp and Player ESP. `Follow.StartAutoFarm(true)` may start in the lobby. |
| Path mode, **aim 0.0–0.4 studs flat but 1.2–1.8 studs above the feet**, waypoint index frozen; stalls of 5, 15, 21, 25, 28 and 94 s on escalators, ledges and curbs | Under a raised waypoint, keep heading along the route (3 studs toward the next waypoint) so the jump/obstacle logic sees the step. Before, input was zero because the flat distance was < 0.5. |
| Follow/rescue to a target on another floor: planner results repeatedly **unusable** (`fails` 1→2→0…), mode stays `none`, stall or pacing | `setPath` no longer discards a complete native route when no waypoint passes the strict body-width entry test (beside a wall or rail); it follows the route's first leg. Diag now names why a plan was rejected. |
| ~1.9 s at each pod with E held. The user's own recordings free a pod with E held **0.1–0.2 s** (no progress bar) | Pod contact re-presses every 0.35 s after 0.3 s instead of holding up to 1.2 s before a retry. |
| AutoHide jitter in a corner (11 reversals / 3 s) | Hysteresis: keep a still-clear heading that leads away from the Beast instead of flipping. |
| User: running into a Beast that faces us | AutoHide alarm when the Beast faces us (≥ 0.7) within 22 studs and we move toward it. |

## Other requests in this round

- **Flee speed:** 18.5.
- **Fly + Speed:** flying at 3.5× speed.
- **AutoHide door closing:** taps E immediately (re-tapping until the doorway is blocked) when we have just crossed an open door with the Beast on the other side. The blind once-per-second tap remains as a fallback.
- **Lobby vote:** spots are found by labels showing a preferred map name, anywhere outside the current map. The recorder logs a lobby scan of map/vote labels and GUI buttons, because the actual lobby objects are still unknown.

## Verification and limits

- Harness: 138 scenarios / 305 checks pass with Luau 0.700, and D compiles.
- The head-on alarm test fails on the previous commit and passes now.
- The raised-waypoint and wall-entry tests pass on both versions: the harness does not reproduce the live navmesh/collision height mismatch. Those two fixes rest on the recorded state, not on a reproducing test.
- Nothing was run in Roblox.

# Follow-up — 2026-11-11 (3): live report "worse than before"

User report after playing `8500c8a`:
- standing still far more often;
- AutoHelp paces on the lower floor instead of climbing to an upstairs pod;
- jitter beside the pod without rescuing.

They also could not find the diag file, because **T is the script's unload key**, so Diag never ran.

- **Reverted** the unverified movement-core changes of `8500c8a`:
  - `Follow.WalkTo`, `Follow.PlanStep` and `Follow.RescueLocalLane` are back to `32dcc7d`;
  - the wall slide is removed.

  Only the read-only diag hook stays in WalkTo.
- **Diag** no longer uses T. It starts automatically on load. It writes `D_stall_<time>.json` to the executor's Workspace root and creates the file at start.
- **Reproduced and fixed: one bumped stair entrance removed every route upstairs.** `FH.RejectLane` marks a bumped lane for 8 s, and `FH.PathAny` discarded every native path crossing it. After one bump at the only stair entrance, no route to the upper floor existed; local steering paced below, bumped again and renewed the rejection. For a target on another floor, a complete route crossing a rejected lane is now kept as a last resort. New scenario: it fails on `32dcc7d` and passes now.
- **Real bug found by running the harness:** `FH.ExitPolicy`'s new gate/centre check used `ipairs({ gate, center })`. That loop ends at a nil gate, so nobody counted as near and the exit wait never released. Fixed.
- Considered but not changed: limiting `FH.PreciseMove` (analog approach used for all rescue legs since `bcbb5e5`) as the possible pod jitter. Doing so re-breaks the prop-edge scenario. Diag now records `precise` and the aim distance so live data can decide.

Verification: Luau 0.700 was built in this session. The harness is `python3 tests/run-navigation.py <luau>`: 135 scenarios / 300 checks pass, and D compiles. Nothing was run in Roblox.

# Stall diagnostics, wall slides, AutoHide/AutoHelp/AutoExit/lobby updates — 2026-11-11 (2)

Base: `32dcc7d`. User report after live play: still standing still often, especially pressed against walls, on props, and in front of obstacles. A pause of a few seconds usually ends in movement again. AutoHelp panics, backtracks and hits walls when the Pod is upstairs. AutoExit sometimes stands at an exit without opening or leaving.

## Stall causes found in code (not yet confirmed on live data)

- **Holding position while a route is computed.** In `Follow.WalkTo`, with no current plan, only `Follow.PlanStep` local steering moved the avatar. When it found nothing, the controller ordered a stand (`Move(root)`) until the native plan arrived, for up to 8 s. Now the last verified leg is carried first (`FH.CarryMotion`), then a wall slide is tried; the bot stands only after both fail.
- **Pressed against a wall near a corner.** When the next route point lay just past a wall edge, the route profile read "wall". The lane was rejected, the route reset, and a failed local step became a stand. Replanning then returned the same corner point, so the bot looped against the wall. `Follow.WallSlide` now slides along the wall surface, with a small push off it, on a verified short lane, and keeps the route. This runs on the wall branch, the lost-lookahead branch and the no-plan fallback. It is bounded and resets on real progress.
- **Narrow corridors / props.** Local side lanes were tested only at 8 studs, which a narrow corridor or a prop top never clears. Lanes are now tried at 8, 4.5 and 2.5 studs, plus straight ahead. The surface/drop lane search (`Follow.RescueLocalLane`) is used by every owner, not only rescue.
- **Target on another floor.** Non-rescue owners stood still while the connector route was computed. They now explore a verified local lane too. For any owner, that search no longer scores horizontal closeness to an upstairs/downstairs target as progress, because that led under the target floor into its walls. It prefers surfaces that rise toward an upper target, or descend toward a lower one.
- **Exit trigger not reachable by WalkTo's arrival test.** The trigger centre may sit against the gate or above a prop. WalkTo then kept pushing until its long timeout and never started holding E. Within 2.5 studs of the trigger volume it now hands over immediately. The hold range is measured to the trigger volume, not its centre.

## Behaviour changes requested by the user

- AutoHide contact alarm: Beast within 8 studs **and facing us**, not behind a wall (a door between still counts). This replaces the previous 6-stud facing-agnostic emergency. A Beast that has not moved for 40 s, or that has stood still for 15 s without hitting us, is safe. Free round: no capture 3 min 30 s into the round, or the Beast met us within 12 studs for 10 s without hitting us. A later capture or hit revokes it. While fleeing, walking speed is 17 (only a normal walking speed is raised). Flee targets get a small random jitter.
- AutoHelp: a visible Beast ahead on the rescue route that faces us triggers a sidestep. It also marks a short-lived planner cost around the Beast and requests a replan, so the native route search returns the shortest way around it.
- AutoExit: an already opened gate is preferred. A nearer closed gate wins only by more than its opening time, and one opened gate is enough. Gates that most teammates, or one nearby teammate, are at or heading to attract us. "Within 15 studs of one exit" is measured from the gate (trigger), not the escape volume centre outside. Previously people waiting in front of the gate could be counted as not near, which kept everybody waiting.
- AutoFarm lobby: vote for Shopping Center > Abandoned Prison > Sanctuary Zoo > Arctic Station > Arcade > Nuclear Power Plant > Spaceship. It uses a visible vote button, or walks onto a lobby vote pad found by name. It then steps back and strolls with random pauses. Other maps are not voted for. Lobby pad object names are not known from data; the GUI path reuses the existing vote-button reader.

## Diagnostics

`Diag Ket [T]` (see `stall-diag-README.md`) logs every standstill longer than 1.2 s while a movement feature is on. It records the owner, lease, aim distance, refused-move reason, WalkTo mode/plan wait, and surrounding ray hits to `workspace/D_diag/stall-*.json`. It is read-only. These fixes are code-level hypotheses; the diag file is what will confirm or refute them on real maps.

## Verification and limits

Whole-file syntax parses (Lua parser after a mechanical Luau→Lua rewrite of compound assignment/continue), as does the base file. Luau itself and the regression harness could not be executed in this environment. The harness function list and one outdated AutoHide test were updated for the new rules but have not been run. Nothing was tried in Roblox.

# AutoExit: barred gate leaf, solo repick and failed crossings — 2026-11-11

Base: `bcbb5e51218f61ff7967fe229e60b420ca854060` (still `main` HEAD when fetched).

## Causes found

- **A physically open exit could read as closed for the whole round.** `FH.ExitDoorOpen` and the crossing lane only tested a body-wide line from the room-side trigger to the escape-volume centre. In the supplied recordings (18 JSONL, 48,755 frames, 19 segments, 13 maps) one Haunted Mansion exit is a double gate whose second leaf is a permanent collidable barrier inside the exit model. The centre line grazes that barrier, so the old test reports "closed" even after the gate opens. The recorded escape passes through the gap beside it, about four studs off the centre line. The script then walked to the trigger and held E for up to 12 s at an already-open gate. It marked the gate failed, moved to the other gate and repeated. It never entered the wait/escape branch at that exit. An offline model of both tests on the recorded exit boxes confirms this: with the gate leaf removed, the old test stays closed and the new lane search finds a lane about 1.6 studs off centre. On the other recorded exits both tests agree. `FH.ExitLane` now samples lanes within the trigger's own footprint, intersected with the escape volume. It does not look into open space beside the model, where walls are invisible to this include-only probe. It prefers the centre lane when that lane has shoulder clearance. `FH.ExitTraverse` lines up with the chosen lane before crossing.
- **Becoming the last survivor could drop an open exit for a nearer closed one.** On the first solo turn `ExitRoute` cleared the selected door and ranked all doors by distance alone, ignoring whether they were open. The `stopped()` solo check also interrupted a committed escape. When the other survivors left, the bot could abandon an open gate and stand at a nearer closed gate holding E. Solo mode now keeps a selected open gate. It only interrupts a pending approach/opening. A closed gate wins only when it is nearer by more than about eight seconds of walking, roughly the time spent holding it open.
- **A failed crossing shuttled between volume and trigger.** When escape was not registered at the volume centre, every retry walked back out to the trigger and tried the same gate again indefinitely. The crossing now presses deeper into the volume after a short hold. A retry starting between trigger and volume crosses from there. Two failed crossings of the same gate put it on the existing 3 s failure list.

Unchanged: wait policy (at most one other Survivor, or at least half of the remaining Survivors within 15 studs of one exit, Beast excluded), the 22-stud Exit Beast escape, the 6-stud AutoHide emergency, PC slots, Fly level 1, no chat integration. No JumpPower/JumpHeight/velocity writes.

## Verification and limits

New spec scenarios cover: waiting at an open exit, then both teammates escape with a nearer closed gate present; a solo start with a far open and a near closed gate; the lane search beside a barred leaf. The Luau test runner could **not** be executed in this session: the environment blocked downloading or building a Luau binary. The modified functions and new scenarios were only parsed with a Lua syntax parser. The geometry claim rests on an offline model of the recorded boxes. Neither the harness nor Roblox gameplay has run these changes. Run `python3 tests/run-navigation.py /path/to/luau` before relying on them.

# Rescue perch arrival and physically open exit retention — 2026-11-08

Base: `ce4d085f1f61e4f06ff254d3ecc6516c00ce8a6b`, fetched before this repair.

## Reproduced failures

- **A rescue intermediate destination could stop inside the edge clearance.** The previous precise-arrival change covered sharp corners but left other rescue legs with a 0.5-stud render cutoff. A new landing case puts the avatar beyond an old takeoff onto a six-stud prop, then follows the actual navigation/controller code toward a landing just beyond its edge. Old code moves initially, stops short of the edge destination and fails to complete after three seconds, with 224 simulated collision frames. This is why checking only initial movement after landing was insufficient. Controlled rescue movement now uses the existing native analog precise-arrival controller for every leg, including jump continuations/drop entries. The revised case reaches its destination in 1.62 seconds with six collision frames. No collision properties, speed, velocity, JumpPower or JumpHeight are changed.
- **Contradictory UI could disable a confirmed exit while gates were open.** ExitOpen cleared the unlock latch for a blocked message or positive computer count before considering physical gate state. A focused both-open fixture first confirms unlock, then supplies contradictory UI: the old code disables ExitRoute immediately. The revised code checks live gate geometry before revoking that confirmed, same-map latch. It deliberately bypasses the geometry cache on this conflict so closed gates plus a new-round positive count reset immediately. The existing wait policy, survivor counts, same-door proximity and nearby-Beast escape rules are unchanged. This test isolates the signal/physical-state handoff with the fixture's gate-state boundary; it does not establish which UI values occurred during the user's live failure.

## Rescue route selection

The planner formerly skipped its local jump/window comparison once preview steering had moved three studs beyond the query's original start. It now evaluates from the live grounded pose and compares with the estimated remaining native route, rather than comparing a live shortcut with the whole old-start route. Flight keeps its committed steering; native takeoff support and collision checks still govern traversal. Existing and newly delayed window/detour coverage completes without jump-property changes. The delayed fixture also passes the baseline through another local shortcut mechanism, so it is coverage rather than evidence of a measured speed improvement from this planner change. No global shortest-route guarantee is inferred from it.

## Validation and limits

131 simulated scenarios / 283 assertions pass, including three prop widths, landing beyond an old takeoff, two open exits after obstacle landing, conflicting exit UI, delayed window comparison and existing stairs/door/ownership cases. Baseline comparison exposes two failures in the added coverage. Full Luau compilation and whitespace checks pass.

Re-read the local Library descent interval at 458.4–460.8 seconds: horizontal movement continues through the descending support, without using crawl/Shift as a model. No raw coordinates or recordings are committed. These behavior examples do not expose the revised script's internal state or reconstruct map collision meshes. There is no live Roblox Player/Studio test here. These fixes address demonstrated stop mechanisms; they do not prove that every reported obstacle/stair stall, circuitous rescue route or both-open exit failure is gone.

---

# PC slot ownership and rescue contact handoff — 2026-11-08

Base: `83722eddbc7ac806b9453d9a00ed608d9d9e369f`, freshly fetched from main.

- PC occupancy had two inconsistent implementations. The initial Main filter inferred the nearest slot from position, while contact also used the game-selected trigger. An offset hacker could reserve two neighbouring slots and leave no candidate even though one keyboard was free. Both now use the same live predicate: a nearby game-selected slot takes precedence; otherwise physical proximity reserves only the nearest slot. A stale target beyond 3.6 studs does not suppress the physical fallback. Existing real-progress protection remains in place.
- The numeric Follow/farm rescue owner skipped contactAdvance because it does not supply contactRange. Both rescue owners now use the same checked final approach. When already within a clear last metre, contactAdvance runs before starting another path job. It checks body-width obstacle rays and supported floor; failed contact still routes normally. Its motion requests precise native arrival, removing the default half-stud render stop from this short interaction leg. It still requires valid pod contact before holding E and actual CapturedTorso release for completion.
- Added three regressions: selected slot versus nearest neighbouring slot; the actual Main wrapper selecting that free keyboard; and a last-metre rescue with a path-boundary stub returning 1.35 studs outside the trigger (0.55 contact goal plus 0.8 waypoint tolerance). The latter isolates the navigation-to-contact handoff; movement, input and capsule release use the existing simulated physics, not a successful-interaction stub. Old source fails all three; revised source passes. In that rescue fixture, the first input occurs within 0.12 seconds without another route call.

Re-read the raw local Library 485.65–487.1-second stairs interval and Nuclear 5.1–7.9-second PC approach. Library retains horizontal travel while support rises; the PC example retains travel until the selected keyboard and subsequent input. Neither interval justifies an intermediate idle timer. No raw coordinates or recording files are included here; Shift/crawl is not used as a navigation model. Pod departures remain ambiguous and are not treated as failed rescue examples.

Validation: 124 simulated scenarios / 269 assertions pass, full Luau compilation and diff whitespace checks pass. Existing stair/door/corner cases remain green. This change addresses interaction handoff and slot selection; it does not establish that all reported stair, obstacle, wall or long-route stalls are resolved. No live Roblox Player/Studio session is available here, and the recorder does not contain the map collision meshes or a run of this revised script.

---

# Stop regression in 549dc8e — 2026-11-08

Base: `549dc8e6308964225b642138fc5951baaf3070d6`, fetched from `main` before this repair. The user reports that the last revision made stopping worse. This follow-up fixes concrete regressions in that revision rather than treating the previous simulation pass as evidence against the live report.

## Reproduced defects

1. **A cross-owner geometry query could throw a type error.** `RescueFailedPart` used a short-circuit expression that returns `false` when the active coordinator belongs to another token. The code checked only `~= nil` and then compared that boolean with `os.clock()`. The timestamp comparison now requires a number. Other owners can query geometry without inheriting rescue's failed-part memory or throwing; the owning rescue still sees its own unexpired failure marks.
2. **An ownership predicate could cancel valid carried movement.** `RescueControlled` released motion after 1.2 seconds since the last `Move`, even when `CarryMotion` was actively renewing a verified leg. Ownership inspection is now read-only. Completion, cancellation and the actual error handlers release movement explicitly. AutoHelp and Follow error cleanup now remove the failed token's lease/coordinator/intent before their existing retry backoff, while retaining the error warning.
3. **Tight-corner admission contradicted the render stop radius.** The prior body-clearance guard could require the actual waypoint before advancing, but ground/flight steering stopped within 0.5 stud. A valid native corner could therefore remain stationary until the 0.9-second progress guard discarded it. Only a rescue leg aiming at its current sharp corner now requests precise arrival. The render delta is passed through to native analog `Humanoid:Move` so the final frame reaches the point without overshooting/reversing. Ordinary movement and interaction stop behavior retain their existing default. WalkSpeed, jump properties and velocity are not edited.
4. **Exact-clearance tangency looked like entering a wall.** A swept box touching a valid native corridor boundary could report a hit even while moving along it. Rescue queries now use a 0.001-stud skin per horizontal side for this distinction. Actual character collision and pathfinding radius remain unchanged. A separate contact case verifies that moving into the wall is still blocked.

## Human recording cross-check

Re-read Nuclear Power Plant 5.1–7.9 seconds, Library 393–396.3 seconds and Facility_0 16–19.3 seconds from the local archive. In the Nuclear example, horizontal input continues across rising support and jump/landing transitions until computer contact. In the Library example, headings change through the approach while horizontal travel continues; the stationary frames begin at the selected ComputerTrigger3 and actual hacking progress. That is the continuity criterion used here: reaching each intermediate point must not insert a timer-length stand before the next leg. These are behavior examples, not coordinates/routes copied into D. A short hacking interval remains evidence of contact/start, not completion or a reason to abandon the PC.

The recordings are of the user's play, not an internal trace of the failing AutoHelp. They do not identify every live failure or establish full map coverage. Raw samples and inspection output remain local under untracked `work/`.

## Verification

**121 scenarios / 261 assertions pass.** The expanded suite exposes **9 failures against 549dc8e**, including the changed ownership contract, cross-owner type error, tight/exact-clearance corners, 60/30/10-fps scheduling, error cleanup and tangency. Unlike the old fixed-step-only fixture, the frame-rate cases round coroutine waits to the configured frame duration and pass that actual duration into the production render dispatcher.

The same synthetic tight-corner route changes from **2.73 to 0.96 simulated seconds**; the previous **0.9-second stationary interval** is absent. The 60/30/10-fps versions finish in approximately 0.97/0.97/1.1 seconds without unnecessary jumps. Tests also distinguish valid carried movement from explicit cancellation and run the actual AutoHelp error loop with a failing geometry task.

D compiles and `git diff --check` passes. PC interaction, native jump-input, AutoHide, chat and Fly functions compare unchanged. Follow.Main changes only in its error cleanup. The separate recorder is unchanged; no raw recording or coordinate table is committed.

**No live Roblox Player/Studio run was performed.** These results demonstrate the specific regressions above, not that every real-map pause has been eliminated or that the controller matches all of the user's human movement. Executor delivery, custom rig response and live mesh/streaming behavior remain unverified.

---

# Rescue ownership, physical support and completed crossings — 2026-11-08

Base: `628b72e173527baa20ac072bd42a6867f49201f7`, fetched again before committing. Live reports still describe frequent stalls and stair/door reversals; the previous passing fixtures did not establish smooth gameplay. Chat integration was explicitly cancelled and no chat code is changed. Fly remains at its existing level-1 setting.

## Runtime causes and changes

- **Air/Freefall is not sufficient to classify a stair contact.** A body can be physically supported while those signals remain airborne. The old follower then used only airborne clearance, suppressed the next supported takeoff and excluded its grounded progress recovery. Rescue now requires sustained nearby contact for 0.06 seconds, checks the surface slope and relative velocity along its normal, and shares that classification between flight, waypoint and jump admission. Tangential upward/downward motion on a wedge is compatible with support. An unsupported apex/fall cannot obtain contact progress from a stale solid-material flag; vertical progress requires an actual support ray. Native Space/game input remains responsible for takeoff.
- **Two movement writers could disagree within one rescue.** WalkTo selected a path/provisional leg, while `FH.RecoveryAim` could silently replace it with another escape point; render recovery could also add an unrelated stall jump or camera-forward pulse. A scoped rescue coordinator now keeps the chosen movement destination authoritative. Its progress observer still informs the verified stair-hop executor, which uses the same destination and shared input admission. The generic escape writer, periodic Space and W-pulse recovery do not act behind this coordinator. Nested door approaches restore the parent scope; manual relocation/respawn reset stale proofs and attempts. A coordinator without a heartbeat retires its lease and stall intent rather than holding movement indefinitely. A Follow cache refresh preserves a still-valid rescue owner. AutoHide may still preempt through the existing ownership rules.
- **Provisional exploration excluded real upward connectors.** Sampling ground only near the avatar's original height could miss the upper end of several supported treads, and local candidates otherwise admitted only near-level walking or drops. Rescue can trace a continuous uphill prefix before its full native plan returns. It retains and rechecks that committed prefix before repeating a full known-blocked trace towards another floor. This does not authorize a direct line through a floor panel.
- **A corner-cut failure was treated as loss of the entire route.** Rescue now falls back to the next valid sequential waypoint if a lookahead becomes blocked. At a sharp turn, entering the 1.2-stud waypoint tolerance alone no longer permits advancing into the next leg: the actual body footprint must clear that turn. This prevents cutting the central wall at a U-shaped stair landing, wedging at the second flight and replacing the route with jumps or local wandering. A closed-door interaction can still take over at its stand.
- **Nearby jump portals were absent from a distant walking detour.** Rescue compares up to two nearby physically verified single/two-input jump prefixes against the native route, then obtains a complete native continuation from each landing. A candidate cannot immediately return through its own portal, and no incomplete tail counts as a complete route. The current movement lease keeps moving while the continuation computes. Two ordinary takeoffs separated by real brief support also remain usable when the game refuses an airborne second input.
- **Fresh Space requests could hide one persistently failed obstacle.** A jump attempt's timer now follows actual forward or supported upward progress, not each input API admission. On a failed crossing, temporary memory records the actual blocking part as well as its approach lane. Merely changing the approach angle cannot immediately retry that same object indefinitely. Manual relocation and a new character clear this memory. If the game declines the second input, the controller can select the walking route rather than force an airborne state or edit velocity.
- **A delayed native result could restore a route from before a successful vault.** Completed crossing planes are retained briefly. A path requested before that crossing cannot adopt an entry that returns to its old side; a fresh query from the actual position may still prove that backtracking is necessary. This also covers distant goals outside the ordinary direct-shortcut scan, without tracing an entire large map every frame.

No JumpPower, JumpHeight, velocity boost, teleport or recorder integration is added. The PC interaction/Main functions, first/second Space timing functions and all AutoHide/chat functions compare unchanged against the base. Supported-first-takeoff confirmation additionally uses the rescue contact proof when a keyboard API reports success without delivering the jump. Shared movement helpers contain rescue-scoped changes, covered by the prior farm/contact/exit fixtures and a preemption case.

## Recordings revisited

The local archive remains available (18 JSONL recordings / 48,755 frames). Space-press pairs and surrounding state events were scanned, then the Library interval 486.15–486.8 seconds was examined again. Its first request is followed by another request, a brief Landed/Running transition and another ordinary Jumping transition while horizontal travel continues. A second Space API call alone is therefore neither evidence of an airborne boost nor evidence that the crossing finished. Earlier stair/ramp ascent and descent intervals remain documented below. Shift/crawl and unrelated feature keys are not learned as navigation commands; Pod departures are not treated as rescue/abandonment decisions.

The recordings describe human motion, not the failing AutoHelp's internal runtime state, and contain only partial map coverage. The specific failures below were reproduced with controlled geometry/state inputs. No raw recording, coordinate table or playback route is committed.

## Verification

**113 scenarios / 238 assertions pass**, using the actual source functions and complete render dispatcher with simulated game input/physics. The expanded harness exposes **8 behavioral failures against the fetched base**. D compiles and `git diff --check` passes. Convex wedge fixtures clip rays and swept bodies against geometric half-spaces, rather than reusing the tread-box support logic. The emulator now separates physical support from reported material/state for both frame updates and delayed callbacks, and wedge velocity includes actual vertical displacement. Coordinator-specific lifecycle checks are skipped when comparing a baseline that has no coordinator.

| Controlled case | Fetched base | Revised |
| --- | --- | --- |
| Supported treads reporting Air/Freefall | Stops; 4.5-second timeout | Arrives in 1.98 simulated seconds |
| Stair landing and reversing second flight, with a central wall | 5-second timeout | Arrives in 1.71 seconds; no collision attempts |
| Native connector query delayed at the foot of ascending stairs | Walks backward instead of onto the treads | Uses the checked uphill prefix before the query finishes |
| Local two-input window versus a remote walking circuit | Still on the circuit at the 4-second timeout | Arrives in 3.54 seconds with one accepted first/second pair |
| Delayed route from before a vault, target 125 studs away | 9-second timeout after restoring the detour | Arrives in 8.4 seconds without a reverse window leg |

Additional cases cover 35/60-degree wedges in both directions, unsupported/stale-material contact rejection, ordinary paired takeoffs with airborne double input disabled, ownership preemption, a dead coordinator, cross-mode cache refresh, manual relocation, a silently ignored supported first takeoff and rejection of a repeatedly failed high window. In the last case, the game refuses airborne second jumps: rescue uses two first-jump attempts, then completes by the valid walking route in 5.91 simulated seconds, with no jump-property edits.

**No Roblox Player/Studio session was run.** Real executor input, custom rigs, mesh collision, streaming, dynamic door bounds and production scheduling remain unverified. Passing these cases fixes the stated modeled causes; it does not prove all live stalls are eliminated, nor globally optimal routing on every incompletely observed map. The separate recorder and chat scripts are unchanged.

---

# Rescue stairs, doorway handoff and first-route latency — 2026-11-07 follow-up

Base: `a1d6d84dfdcedbc2e69456ad387f47ff036f50d5`, fetched from `main` before this follow-up. The user still reports live stalls on stair ascents/descents, after landing on objects and through doors. Those reports override the previous simulation results. This change also removes Fly levels 2/3, keeping the original level-1 speed of 20 and an on/off J toggle.

## Controller causes addressed

1. **A flight of diagonal stairs was tested as one jump obstacle.** The existing side-support test could reject different tread heights under the two shoulders, and the fallback classified the whole rise as a window requiring repeated double jumps. Rescue now traces consecutive supporting treads at 0.25-stud spacing, in either direction, with bounded per-tread rise/drop, body/head clearance and the Humanoid's slope limit. A missing support, closed door, tall wall or ceiling still rejects the lane. The proof is cached briefly and scoped to rescue, including a Follow-owned rescue; PC and AutoHide keep their existing admission rules. Stair walking still uses the native controller, and a blocked tread can request an ordinary native takeoff.
2. **A descending waypoint could remain below the actual tread.** Horizontal proximity then stopped movement while the 3D arrival check refused to advance. Rescue corrects waypoint height only to a nearby visible supporting floor, retaining waypoint order/actions. Live path entry checks use the current surface. If a higher tread already carried the body past an old takeoff, its proved next surface can advance the route immediately. A stranded takeoff underneath an object instead hands back to checked surface/drop exploration, rather than continually aiming at the avatar's feet. An independent grounded progress guard also invalidates a route after 0.9 seconds without real horizontal progress; successful API calls or vertical bouncing do not rearm it.
3. **The first usable native route stayed private until optional comparisons finished.** `PathAny` can now publish a best-so-far waypoint candidate to its owning WalkTo job. The same movement controller adopts it at the current position while a second profile/atlas comparison continues. Optional shorter-door comparison also runs in that planner job while the usable native leg remains available. Before adopting a delayed door result, its entry and remaining cost are checked again from the live position; a saving measured at the old start cannot force a longer reverse leg. Publication transfers no native Path ownership; cancellation tests check that outstanding candidates are destroyed.
4. **A native pass-through door leg was discarded before reaching its stand.** If its first waypoint was beyond a closed panel more than 3.4 studs away, entry validation could reject the whole leg. Provisional steering then wandered beside the wall before rediscovering the door. Rescue can retain that leg when the actual portal is on the intended route, on the correct floor and its interaction stand is reachable. Opening still precedes traversal of the panel.
5. **The opening/push/replan boundary lacked a door continuation.** Rescue now retains a short, body-checked crossing until the character has cleared the chosen doorway. The movement lease, manual control and owner cancellation still govern it. A newly obstructed lane cancels it; a stale reverse provisional destination cannot immediately pull the avatar back over the threshold. E is released before continuation.
6. **Local window shortcuts still carried a jump penalty.** The previous revision removed that penalty from native/atlas ranking but left it in `RescueShortcut`. A physically verified shorter window shortcut now competes by distance, including small savings. It need not move closer to the Pod in a straight line on every individual leg.

No JumpPower, JumpHeight, velocity boost or teleport was added. The PC interaction functions, Follow.Main, native jump-input functions and every AutoHide function compare unchanged against the base.

## Recording cross-check

Re-read the local JSONL around Library 485.65–487.1 seconds, Abandoned Facility 67.1–69.85 seconds and Arctic Station 82.65–84.4 seconds. These include changing headings across support, brief landings between native takeoffs and continued horizontal input; the controller must not require a fixed horizontal plane across the whole staircase. Library 458.4–460.8 seconds was also re-read for descent: the player retains forward travel across downward support and a native jump transition. Abandoned Facility 123.65–125.75 and Homestead 23.1–25.2 include falls/landings near stairs/ramps; those tags alone are not proof of a particular stair mesh or an optimal route.

The recordings guide continuity and input behavior, not fixed coordinates or route playback. Pod departures still do not establish who rescued or why the player left. Raw samples, coordinates and inspection output remain local under untracked `work/`.

## Verification and limits

The expanded harness runs the **complete production MotionStep dispatcher**, including stair/stall recovery, in addition to the actual navigation and interaction functions. Earlier fixtures called only takeoff/Tick and the final steering helpers, which missed interactions between recovery helpers. Terrain, collision response, input delivery and PathfindingService are still simulated; map geometry is synthetic rather than a reconstruction of the supplied maps.

**96 scenarios / 193 assertions pass** with Luau 0.741. The expanded harness exposes **10 failures** against the fetched base. D compiles and `git diff --check` passes. Examples in the same synthetic model:

| Scenario | Base | Revised |
| --- | --- | --- |
| Diagonal stair ascent | 4.47 simulated seconds; 8 first jumps / 5 second jumps | 1.98 seconds; 1 first jump / 0 second jumps |
| Descending waypoints 0.6 stud below the supporting treads | Stationary until the 5-second test timeout | Arrived in 1.86 seconds; no jumps |
| Closed door through confirmed Pod release | 8.25 seconds, with provisional wandering before opening | 3.93 seconds; no backtracking or >0.2-second stationary interval between doorway clearance and Pod contact |
| Second native profile delayed | First usable leg remained unadopted at the 0.4-second snapshot | Movement follows that leg before the delayed comparison completes |

Additional checks cover supported descent, low-step collision requiring native takeoffs, a blocked/covered stair, small-saving window shortcuts, door continuation/cancellation, landing on a wide prop and disposal after asynchronous cancellation. The low-step fixture explicitly holds the body at its old height when a step is refused; it does not lift the character through a blocked riser.

**No Roblox Player/Studio execution was possible here.** Live collision rigs, streaming, door animation/bounds, executor input and production scheduling across every map remain unverified. The measurements above demonstrate specific modeled regressions, not elimination of the user's live stalls or globally shortest routes on an incomplete map. The separate recorder is unchanged.

---

# AutoHelp recovery and route distance — 2026-11-07

Base: `51db610da4982d96d1aa0d1f1e44d75201227b00`, fetched before editing. The user reports continued live stalls and reversals. PC hacking is reported stable and its interaction functions are preserved. AutoHide steering is reported stable; its only changed function is `AH.Eval`, adding the requested exposed six-stud emergency, including a stationary/AFK Beast inside that range.

## Current routing objective

AutoHelp compares **distance along physically usable routes**, including native jumps, windows, fences and doors. A longer open corridor must not win merely because the short route needs a jump. Rescue-specific jump and door-opening penalties were removed from route ranking; ordinary follow/flee costs remain unchanged. Narrow-profile alternatives are compared when a native result contains a detour, and door alternatives are considered for even small measured savings. A native route can skip graph comparison only when it is already at the horizontal geometric lower bound within 0.01 stud. This is distance ranking, not a promise of lowest elapsed time or globally optimal routing across an incomplete map.

Native rescue pathfinding now starts before atlas comparison. Its single result is retained rather than recomputed after scanning. A longer result may still be compared against the atlas/doors; the rescue atlas budget is bounded at 0.12 seconds / 1,536 nodes. While a plan is pending, safe owned motion continues. A vertical-goal startup allows the native planner 0.15 seconds to establish a connector before local exploration; it does not wait indefinitely beneath the target.

## Stalls and reversals addressed

- **Different-level goals stopped provisional steering.** An early return rejected the direct ascent/descent and then waited, without considering safe local exits on the current surface. Rescue can now choose a supported local lane or a fully checked gravity landing in other directions. It retains that lane until reached, blocked or genuinely stalled rather than rescoring it every frame.
- **Concave corners excluded their only exit.** The old useful-direction filter disallowed backward rescue lanes. A verified retreat is now allowed when forward choices fail, with enough commitment to leave the pocket. A short entrance memory prevents provisional steering from immediately returning to the same dead end; a newly verified full plan can supersede it.
- **Corner probes were thinner than the whole body.** Rescue flat-lane admission now additionally sweeps a complete body footprint instead of relying solely on the thin forward plane. This catches a wall end that the earlier plane accepted but the simulated body then hit. Jump/stair admission keeps its existing geometry path. This additional check is scoped to rescue; PC interaction and AutoHide steering are unchanged.
- **Suspended wall contact was treated as endless free fall.** A stationary root in an airborne state with near-zero vertical velocity must remain unchanged for 0.45 seconds before recovery. The controller then tries a fully checked retreat/drop away from the stalled heading. Ordinary falling and a short jump apex do not trigger this. No airborne first-jump state, velocity edit or teleport is used.
- **Landing on a sill cancelled a crossing.** Rescue keeps the committed direction through a short supported landing and verifies a continuation/drop. Completed drops advance their path index rather than steering back toward the old window waypoint. Rescue dodges cannot replace an active crossing/drop and do not run just because an otherwise non-threatening Beast is nearby.
- **Manual reposition reused the old attempt.** After manual control, rescue clears its local directions, failed corridors, door history, suspended recovery and owned movement lease. Rejected corridors are now tagged by owner so only this rescue's stale marks are removed. The manual pause is excluded from the WalkTo travel timeout. Other movement owners' marks are retained.
- **Unreachable far targets could consume the entire 75-second rescue loop.** Three no-progress `nopath`/timeout route failures now return a bounded failure to target selection instead of silently retrying the same stationary route. This never declares a rescue complete. A physically sealed room still requires a valid exit; the script does not bypass collision.

## Recording cross-check

The previously supplied archive is still local (18 recordings / 48,755 frames). The Haunted Mansion interval at 108.4–109.55 seconds includes a `Landed`/`Running` transition between jumps while the player retains forward travel. The Library interval at 486.15–487.7 seconds likewise includes several short landings near stairs and a window without reversing to the takeoff. These support preserving an unfinished traversal through a sill contact; they do not establish a fixed route to replay. Pod departures and releases involving other players/Beast remain excluded as demonstrations of who rescued, when to abandon rescue or the duration of a valid rescue.

## Verification

**82 scenarios / 156 assertions pass** with Luau 0.741; D compiles and `git diff --check` passes. The expanded harness exposes eleven failures against `51db610`, including the concave pocket, high-object escape, sill crossing, manual timeout, atlas-before-native delay, shorter window vs open detour, six-stud emergency, suspended shelf contact, unwanted rescue juke, unreachable far target and retaining window ownership during native-hop cooldown. PC contact, slot occupancy, full hacking, all exit policies and previous directional AutoHide cases continue to pass. Source comparisons confirm the PC interaction/Main functions are unchanged and no AutoHide helper other than Eval changed.

Measured synthetic cases include: leaving the concave pocket while its native planner is still delayed; dropping off a blocked high object and reaching the goal in 2.52 simulated seconds with one collision attempt; a suspended contact beginning recovery after the 0.45-second guard rather than persisting throughout the test; and returning an unreachable far-Pod route failure in 1.8 simulated seconds rather than 75.6 on the baseline. Collision-attempt counters are model measurements, not live Roblox frame timing.

There is no Roblox Player/Studio run in this environment. Streaming, game rig collisions, executor input and all production coroutine schedules remain unverified. Passing these cases does not establish that every real-map stall has been eliminated. No raw recording, map coordinate table, route playback or recorder integration is committed.

---

# Navigation follow-up — 2026-11-05

Base: `7b2f96445b2fc3a03c0bf7bd5b324640829a681a`, fetched from `main` before editing. This revision addresses new live reports of stair pauses, rescue reversals and idle behavior after both exits open. The runtime reports remain authoritative; passing the previous fixtures did not establish smooth Roblox gameplay.

## Current exit policy

Only living, in-round Survivors count. Beast, lobby players, dead players and escaped players do not count; captured/ragdolled Survivors remain in the remaining-player denominator but do not count as assembled at a door.

The bot approaches a selected open exit and intentionally waits outside its escape volume. It leaves when **any** of these is true:

- At most one other Survivor remains.
- At least half the remaining Survivors, including our avatar when nearby, are within **15 studs of this same exit**, at a compatible elevation and with a clear approach. This includes 2/3, 1/2, 2/4 and everyone-near cases. People at different exits are not combined.
- Beast is within **22 studs of our avatar**, on the same elevation with a clear approach. This emergency exit check is independent of the directional AutoHide alarm.

An open selected door is retained when Beast approaches; it is not discarded and repicked. Confirmed endgame eligibility remains latched if its UI message disappears after opening the doors, but resets for round end, a new map, a positive computer count or explicit blocked state. Waiting renews a stationary command instead of inheriting a stale loiter destination. A ready/unsafe wait can redirect to escaping on the next controller iteration without finishing a trip to the old wait point.

Automatic rescue yields only near an open exit (within 18 studs of the exit center) when this escape policy is ready or the emergency check fires. It does not yield simply because a distant exit opened. Rescue tokens, pending rescue checks and the follow busy gate share this handoff; manual input and explicit user-requested commands retain precedence.

## Stair and rescue changes

- A native hop no longer waits out the full fixed 0.5-second cooldown after **observed landing on a higher tread with horizontal progress**. Re-admission requires the same root/owner, at least 0.2 seconds since the first input, at least 0.7 stud horizontal progress, a support rise above 0.25 stud, no current airborne state and native support. The existing cooldown remains for same-height stationary attempts. No jump properties or velocities are changed, and this does not permit an airborne first jump.
- Delayed plans are adopted at the forward end of a verified segment containing the avatar. Previously choosing the nearest vertex could pick the waypoint just passed, reversing rescue movement. Lanes still require real clearance and do not skip a pending jump action. A necessary, verified detour may still initially lead away from the Pod; this change does not claim a globally shortest route on unseen maps.
- An elevated native-waypoint fixture was inspected as a possible stair cause; it already passes against the baseline. No speculative waypoint-height rewrite is included. The confirmed fixed-cooldown failure and backward adoption failure are the targeted changes.

## Directional AutoHide

The ordinary alarm now requires Beast to be facing our avatar and physically closing toward it, on a compatible elevation with line of sight. Facing/velocity projections use a broad forward cone rather than exact angular equality. Lateral travel, retreat and stationary facing do not independently raise the alarm. Brief observed displacement can provide velocity when replication reports zero, with a short expiry and rejection of implausibly large jumps. Map/round/character changes reset the existing movement tracking. Walls and other floors do not produce a proximity-only alarm. Existing flee safe-time hysteresis remains to prevent frame-to-frame mode oscillation.

## Checks and remaining uncertainty

`python3 tests/run-navigation.py /path/to/luau` passes **71 scenarios / 132 assertions**. The expanded suite exercises the actual exit policy, priority, route, traversal and directional threat evaluator, including both-open waiting, release after one teammate leaves, assembly ratios at one door, emergency escape retaining the same door, delayed UI signals, and shared movement handoff. The same harness exposes **nine failures** against `7b2f964`; the new handoff-helper-only scenario is skipped on that baseline. The elevated-waypoint fixture passing on both versions is not counted as a discovered defect. D compiles with Luau 0.741 and `git diff --check` passes.

These are deterministic simulations with modeled pathfinding, collisions and game acknowledgement, not Roblox Player/Studio execution. They do not fully reproduce production coroutine timing, streaming or rig-specific stair collision. Actual live stair behavior still requires gameplay validation. No raw recordings, player coordinates or recorder modifications are included.

---

# Đọc kỹ bản ghi Workspace — 04/11/2026

Đã lập chỉ mục toàn bộ 18 file / 48.755 frame / 19 đoạn / 13 map, sau đó đối chiếu sâu 15 đoạn tiêu biểu gồm 537 frame theo phím, trạng thái, cảm biến và mục tiêu tương tác. Không khẳng định đã xem video hay chơi lại Roblox.

## Các đoạn đã đối chiếu

| Đoạn | File, khoảng giây | Nhận xét và giới hạn |
|---|---|---|
| Cửa — Nuclear Power Plant | `ftf-movement-20261104-025752-7868.jsonl` — 96.8–100.9 | E xuống 97.537s, nhả 97.656s; tiến độ vẫn tăng tới 99.275s khi ActionInput=false. Đi tiếp sau khi panel mở. Không học việc dừng ở cửa thành lỗi đứng chờ. |
| Cửa — Facility_0 | `ftf-movement-20261104-045547-1050.jsonl` — 10.4–13.5 | Một lần nhấn E ngắn khoảng 0,12s. Tiến độ tăng sau khi nhả phím; không có Space trong đoạn này. |
| Cửa — Shopping Center | `ftf-movement-20261104-050455-4824.jsonl` — 31.4–34.2 | E nhấn 31.736s, nhả 31.859s. Phân biệt chờ thao tác mở cửa hợp lý với chờ tính đường vô lý. |
| Cửa — Abandoned Facility | `ftf-movement-20261104-052034-5579.jsonl` — 184–187 | E nhấn 184.181s, nhả 184.329s. Kiểm tra chéo bằng chứng mở cửa với map khác, không học một tọa độ cụ thể. |
| Dốc cạnh cửa — Homestead | `ftf-movement-20261104-080621-9846.jsonl` — 238.1–242.6 | GroundRamp báo phía trước chỉ 0,25 stud trong lúc thao tác cửa. Không có nhảy cho tới sau khi đã đi qua cửa; nhãn ramp_near tự nó không chứng minh cần nhảy. |
| Nhảy gần cửa sổ — Homestead | `ftf-movement-20261104-080621-9846.jsonl` — 313.5–315.1 | Space 314.006s và 314.204s; trạng thái Jumping từ 314.019s nhưng frame 314.054s vẫn báo Grass. Có tăng vận tốc Y trên không sau lần Space thứ hai. Nhãn window_near không đủ để khẳng định mọi frame đều nằm trong khẩu độ cửa sổ. |
| Bậc/cửa sổ rồi xuống tầng — Haunted Mansion | `ftf-movement-20261104-075210-6426.jsonl` — 108.1–110 | Giữ hướng tiến; có Landed rồi Jumping trở lại trước khi rơi xuống tầng dưới. Không được đếm mọi Space gần nhau là double jump: một lần có thể là nhảy mới từ bậu. |
| Cầu thang và bậu — The Library | `ftf-movement-20261104-054153-5122.jsonl` — 484.5–489.1 | Đi lên trước, nhảy tại điểm vướng, có nhiều trạng thái Landed/Jumping. Hướng được điều chỉnh dần khi tiến, không đảo hướng qua lại. Cảm biến chạm mặt trước không đồng nghĩa toàn lối đi bị chặn. |
| Vượt barrier rồi đi dốc — Arctic Station | `ftf-movement-20261104-130409-7611.jsonl` — 82.5–87.1 | Nhiều lần nhảy mới sau Landed ở đầu đoạn; sau đó đi lên mái/dốc mà không nhấn Space dù front_low vẫn chạm vật. Không áp dụng spam nhảy cho toàn đoạn. |
| Lối xuống — Airport | `ftf-movement-20261104-130042-7165.jsonl` — 27.2–28.7 | Tiếp tục tiến trong khi rơi, hạ xuống Sand và đi tiếp. Có sức khỏe 100 trong đoạn quan sát; không suy rộng thành mọi độ cao đều an toàn. |
| Tiếp cận PC — Arcade | `ftf-movement-20261104-123851-9631.jsonl` — 410.6–412.5 | Phía trước có ClearWall thuộc ComputerTable. Nhấn E khi sát bàn, dừng điều khiển tiến; game căn chỉnh tới trigger rồi tiến độ tăng. Không học việc đẩy liên tục vào bàn. |
| Tiếp cận PC — Shopping Center | `ftf-movement-20261104-125056-4352.jsonl` — 327–329 | Đến bàn rồi game căn vị trí vào trigger. Các lần E ngắn ban đầu không có nghĩa phải nhấn E liên tục trong toàn bộ quá trình hack. |
| Giữ PC — Spaceship | `ftf-movement-20261104-131707-2228.jsonl` — 330–351 | Đứng căn tại bàn; tiến độ có các khoảng tạm ngưng và tiếp tục. Đoạn minh họa không chứng minh máy đã hoàn tất; không lấy việc người chơi tự rời bàn làm quy tắc bỏ máy. |
| Pod có người khác — chỉ tham khảo chuyển động | `ftf-movement-20261104-045547-1050.jsonl` — 69.1–70.2 | Có ba người khác trong context. Tới Pod, nhấn E, đổi hướng; không đủ dữ liệu để biết ai cứu hoặc tại sao rời. Không dùng để học quyết định bỏ cứu/thời gian cứu. |
| Tương tác Pod ở xa — loại khỏi chuẩn native | `ftf-movement-20261104-125056-4352.jsonl` — 234.1–235.1 | ActionEvent trỏ Pod cách rất xa nhân vật. Không dùng tiến độ này để suy ra đã tiếp cận/cứu Pod theo cách người chơi tự nhiên. |

## Kiểm tra phạm vi dữ liệu

| File | Số frame | Map |
|---|---:|---|
| `ftf-movement-20261104-025752-7868.jsonl` | 2361 | Nuclear Power Plant by D4niel_Foxy, SonicUnkn0wn, and posyonose |
| `ftf-movement-20261104-045547-1050.jsonl` | 3186 | Facility_0 by MrWindy |
| `ftf-movement-20261104-050455-4824.jsonl` | 3974 | Shopping Center by D4niel_Foxy |
| `ftf-movement-20261104-052034-5579.jsonl` | 1084 | Abandoned Facility Optimus by SonicUnkn0wn and D4niel_Foxy |
| `ftf-movement-20261104-052849-5959.jsonl` | 2328 | Abandoned Prison by D4niel_Foxy |
| `ftf-movement-20261104-053431-3252.jsonl` | 2291 | Shopping Center by D4niel_Foxy |
| `ftf-movement-20261104-054153-5122.jsonl` | 4012 | The Library by Drainhp & CodedAbyss |
| `ftf-movement-20261104-055526-2884.jsonl` | 2652 | Abandoned Facility Optimus by SonicUnkn0wn and D4niel_Foxy |
| `ftf-movement-20261104-073435-1708.jsonl` | 2390 | Facility_0 by MrWindy |
| `ftf-movement-20261104-074136-1518.jsonl` | 1928 | Ghost Town by D4niel_Foxy |
| `ftf-movement-20261104-075210-6426.jsonl` | 2407 | Haunted Mansion by BreifAwesomeDude |
| `ftf-movement-20261104-075816-2468.jsonl` | 3285 | Abandoned Facility Optimus by SonicUnkn0wn and D4niel_Foxy |
| `ftf-movement-20261104-080621-9846.jsonl` | 2726 | Homestead by MrWindy |
| `ftf-movement-20261104-123851-9631.jsonl` | 3128 | Arcade by D4niel_Foxy |
| `ftf-movement-20261104-125056-4352.jsonl` | 3985 | Shopping Center by D4niel_Foxy, Airport by deadlybones28 |
| `ftf-movement-20261104-130042-7165.jsonl` | 692 | Airport by deadlybones28 |
| `ftf-movement-20261104-130409-7611.jsonl` | 2448 | Arctic Station by CodedAbyss |
| `ftf-movement-20261104-131707-2228.jsonl` | 3878 | Spaceship by 7Siete_7 |

## Kết luận dùng để sửa mã

- Tiến độ cửa vẫn tăng sau khi nhả E. `ActionInput=false` không đủ để kết luận cửa ngừng mở. Mã mới theo dõi tiến độ có thời hạn, giữ thao tác và chỉ đi qua khi panel thực sự thông.
- Trạng thái nhảy xuất hiện trước khi `FloorMaterial` thành Air. Lần Space thứ hai phải dựa trên chuyến nhảy đã xác nhận, không cộng thêm một bộ đếm 0,2s từ cảm biến sàn cập nhật muộn. Game vẫn quyết định chấp nhận double jump; không thay JumpPower, JumpHeight hoặc vận tốc.
- Không dùng front_low, ramp_near hoặc window_near đơn lẻ làm lệnh nhảy. Đoạn dốc Homestead có chờ cửa thật; đoạn Arctic có các bước nhảy đã hạ chân trước, rồi đi lên mái không nhảy thêm.
- PC có căn chỉnh vị trí bởi game; không suy ra phải tiếp tục đẩy W vào bàn. Hack ngắn hoặc người chơi tự bỏ bàn không phải bằng chứng hoàn thành PC.
- Pod: có thể người khác cứu hoặc Beast làm người chơi đổi đường. Không học quyết định bỏ cứu, người thực hiện cứu hoặc thời gian cứu từ các đoạn không xác định được nguyên nhân.

## Sàng lọc kỹ hơn so với thống kê ban đầu

Con số 10.450 cặp có tiến độ tăng trước đây là gộp nhiều loại tương tác, không phải chỉ hack PC. Ghép đúng target/entity, yêu cầu cùng mục tiêu, liên tục theo thời gian, gần tương tác và loại trạng thái/crawl/đứt quãng cho 7.511 cặp tiến độ PC tại chỗ; 859 cặp có ActionInput=true. Cửa tại chỗ: 1.757 cặp, trong đó 153 có ActionInput=true. 184 cặp tiến độ có target Pod lại ở rất xa nhân vật, nên bị loại khỏi bằng chứng cứu tự nhiên. Các số này vẫn là phép lọc quan sát, không chứng minh nguồn gốc mọi trạng thái của executor.

Chỉ mục tự động có 2.841 đoạn ứng viên chồng lấn; đó không phải 2.841 lần vượt vật cản/cứu đã được xác nhận. Những nhãn gần cửa sổ/dốc được dùng để tìm đoạn cần đọc, không dùng như ground truth.

## Kiểm chứng mã và phần còn thiếu

58 tình huống / 99 kiểm tra qua; D biên dịch thành công. Bộ kiểm tra mở rộng phát hiện 4 lỗi trên commit trước: nhận biết tiến độ cửa, nhấn E lặp giữa thao tác cửa, Space thứ hai bị trễ khi cảm biến sàn chậm, và coi sàn cũ là điểm nhảy mới trên không. Kiểm tra cửa nay chạy chính `PassDoor` và `Push`, nhưng animation/collision/input vẫn là mô phỏng.

Chưa chạy trong Roblox Player/Studio. Chưa biết đầy đủ streaming, rig, executor và mọi map. Không khẳng định các sửa đổi đã loại hết đứng khựng hoặc luôn cho đường ngắn nhất. Các timer dự phòng của Pod là giới hạn kỹ thuật cần thử thực tế, không phải thời gian cứu được học từ bản ghi. Recorder vẫn là file riêng; lần sửa này không thay recorder. Các file JSONL và timeline thô được giữ trong thư mục làm việc cục bộ, không commit; bảng trên chỉ là nhận xét và mốc đối chiếu, không chứa tọa độ map hoặc tuyến đường để phát lại.

---

# Earlier controller follow-up — 2026-11-04

Read `main` before editing: `dada887eabc5dd6d6dbe56b49317d9901e7b65e6` remained the head. The newly attached archive contains **18 JSONL files, 48,755 frames, 19 segments and 13 maps**, rather than the previous 15-file set. Recordings were extracted and analyzed locally; no raw recordings, recorded positions or recorder changes are committed. Synthetic test coordinates describe invented scenes only.

## What the new demonstrations support

With observed Shift/crawl, capture, ragdoll, escape and Beast frames excluded, the median moving velocity is approximately 16 studs/s. Of 10,450 contiguous observed progress-increase pairs, only 1,087 have ActionInput=true. These are observations, not proof of a specific control mode. Front/side proximity hits often coexist with movement, so a ray hit or a stationary timer cannot by itself justify a stop or jump. Hidden executor toggles and unrecorded states cannot be fully excluded. The examples cover more maps, but do not establish a universal shortest route or complete map coverage.

## Controller causes addressed

- **Replanning threw away an existing safe route.** A `replanToken` used `reset()`, clearing both waypoints and traversal state before the asynchronous replacement existed. An upstairs target then made provisional steering wait beneath it. Replanning now requests a replacement while the old route keeps its live collision checks; genuinely blocked lanes still invalidate immediately. Requests during native flight remain pending.
- **Intent was mistaken for work.** A retained RemoteHack target near the avatar suppressed render steering without game acknowledgement. Stale farm typing could also suppress a new rescue owner. Target retention no longer proves hacking, and rescue movement does not inherit the released farm's typing state. Existing movement lease priorities remain authoritative.
- **PC admission was mistaken for progress.** Static ActionInput refreshed the hold timer indefinitely; a separate wall-clock limit abandoned hacks that were actually progressing. Recent increases in the selected interaction's ActionProgress now renew work. Missing progress triggers bounded input retries and a tighter supported approach; a progressing unfinished PC stays selected. The old 3.1-stud stalled-contact fallback was removed.
- **PC slot availability was only checked before travel.** All three real ComputerTrigger positions are rechecked during approach/contact. A player occupies their nearest slot or nearby selected slot; stale remote selections far from the computer do not reserve it. Failed/occupied slots lead to another keyboard on the same PC; a visitor does not evict an already progressing hack.
- **Pod route goals inherited the avatar's floor.** The final-contact helper intentionally preserves current Y, but was also used to plan distant rescues. New route goals sample the Pod's elevation and an outside interaction boundary. An overhanging nearest side switches to a supported side at that elevation. Alternative sides scale with the actual trigger volume instead of fixed compass radii.
- **Rescue could wait 75 seconds and report done without a release.** CapturedTorso clearing is the completion evidence. Silent contact is retried, then returned as unconfirmed after 4.5 seconds without observed progress. The next attempt remembers that contact and tries a different supported side; recapture, respawn and map changes invalidate that memory. Failed approach positions also have a short local backoff.
- **A generic stall timer issued an unverified jump.** It now uses the existing geometry/native-height jump admission with the explicit movement owner. Door/full-height wall failures route around instead. No JumpPower, JumpHeight or velocity boost was added; existing native double-jump admission remains.

## Verification and limits

`python3 tests/run-navigation.py /path/to/luau` now runs **51 scenarios / 85 assertions**, including the real Main computer wrapper, WalkTo, RescuePod and Pod route selector. All pass with Luau 0.741. The same expanded harness against the original `dada887` source exposes **nine state/behavior failures**; the helper-only slot test is skipped for that baseline because its function did not exist. The upstairs rescue executes the entire synthetic route, native interaction and confirmed release in approximately 3.08 simulated seconds; the baseline first plans underneath the Pod. Route ranking also checks a farther Pod with a shorter feasible route against a nearby Pod behind a long detour. D compiles and `git diff --check` passes.

This is not Roblox Player or Studio execution. The native path service, input admission, collisions and game acknowledgement are modeled. Full door animation and the actual AutoFarm/AutoHelp/AutoHide coroutine schedules are not reproduced by the fixture; priority/takeover behavior is exercised at the shared controller boundary. Live latency, streaming, executor input differences, avatar rigs and unexplored geometry still need in-game testing. The pre-existing synthetic corner-detour case still records collision attempts: passing these checks does **not** establish smooth movement or elimination of every live-game stall. No globally shortest-path or all-map claim is made.

---

# Previous analysis — 2026-11-03

The supplied archive contains 15 JSONL recordings: 38,608 frames, 17 segments and 10 maps. These are behavioral references, not routes to replay. Raw recordings and player positions are not included in this repository.

## Interpreting the demonstrations

- Ignore F/G ESP toggles as movement inputs. Exclude Shift-held intervals, observed crawling and slowed crawling frames (1,728 frames in their union), plus capture/ragdoll/escape and discontinuous samples from movement timing analysis.
- Partial computer hacks demonstrate approach and interaction; they do not imply completion or that the bot should leave early.
- Valid moving samples have median horizontal speed 15.904 studs/s; native recorded WalkSpeed is 16 and normal JumpPower is 36. No speed or jump-power increase is inferred.
- There are 252 closely paired ground-then-air jump requests after exclusions, with median spacing 0.220 seconds (10th–90th percentiles 0.146–0.386). Requests are observations, not proof that every double jump succeeded.
- Nearby side/diagonal/low sensor hits frequently coexist with continuous movement. A proximity ray alone is insufficient reason to stop or jump.
- Of 9,408 valid computer-progress frame pairs, only 454 report ActionInput=true. Selected target plus actual advancing ActionProgress is therefore necessary evidence; an input API returning successfully is not proof of hacking. Native interaction can align the character at a keyboard.
- Recorded Pod triggers have spatial volume; their center distance is not the same as distance to a usable edge. Successful rescue examples are sparse, so no universal rescue timing is learned from them.

## Changes in D

- Measure the live colliding body instead of enlarging the visual avatar. Use forward body/foot clearance and support to distinguish walkable trim, stairs, actual walls and jumpable obstacles. Keep a real collider-size lower bound for native path requests.
- Maintain steering during native jumps; admit the second Space only after observed takeoff and a bounded delay. Release synthetic input and yield immediately to manual control, hacking, rescue or capture. No new jump-power, movement-speed, velocity or teleport writes.
- Retain an unfinished computer target. Separate the short, floor/line-of-sight verified keyboard approach from obstacle recovery; retry ignored native input without treating partial progress as completion. Suppress repeated remote activation when native keyboard input is available, retaining fallback and minigame handling.
- Approach the occupied Pod boundary, not its center, and acknowledge actual interaction. A distant red warning or a Beast separated by a wall/floor does not preempt rescue; an immediate exposed threat can still interrupt unsafe travel. A ready rescue contact gets its interaction first.
- Do not expire a route merely because its planner is slow while the avatar is making progress. Keep the timeout for genuinely stalled planning; replace obsolete detours when a same-floor direct supported route becomes clear.

## Validation and limits

Run `python3 tests/run-navigation.py /path/to/luau`.

The regression harness extracts the actual D functions, including the Main computer-contact wrapper, and exercises 39 scenarios / 58 assertions. It models physical contacts, delayed planning, native Space/E admission, real progress acknowledgement and manual cancellation. Cases include keyboard retries, partial hacks, single/double jumps, stairs, a separate upstairs connector, narrow passages, low decorations, walls/cliffs, delayed rescue travel, Pod contact and rescue priority. Door-route selection is tested with explicit portal geometry; full Roblox door execution is not simulated. All scenarios pass. D compiles, and formatting preserves compiled instructions.

These tests are controlled simulations, not Roblox/Delta execution or proof of optimal routing on every map. The samples do not cover every map or threat situation. This change does not claim to resolve executor crashes; real gameplay validation remains necessary.

## Round 9 (Workspace_8)

- AutoHelp <-> AutoHide ping-pong head-on with the Beast: `AR.ThreatPreempts` is now latched
  (stays with AutoHide for 1.5 s after the last trigger, up to 4 s while the Beast is within
  14 studs; released at once if the pod contact is ready). The raw check is `AR.ThreatPreemptsRaw`.
- Hand-over range: 6 studs normally; 16 studs when the Beast and I face each other on one
  straight line (both facing dot >= 0.85, clear line of sight). A Beast looking away keeps 6.
- One-beat pause between legs: `Follow.WalkTo`/`Follow.Chase` no longer stop the humanoid on
  arrival (only with `opts.stopAtEnd`); contact code stops by itself.
- AutoHide walk-into-drop lanes give up after 0.4 s on the ground without progress (1.5 s
  cooldown) instead of pressing into a lip with the Beast closing.
- Pod behind an enclosure wall (live: standing on the wall top, approach point 3.9 below the
  feet, held in place and shaking): a path whose goal is right under the feet now uses the
  step-off-edge branch, preferring the pod side.

## Round 10 (Workspace_9)

- AutoHelp ran from the lobby toward pods ~700 studs away (359 samples): `FH.InLobby` used
  `GetPivot()` on `LobbyInteractiveObjects`, which fails for a Folder. It now uses the bounds of
  the folder's parts (+180 studs). `AR.Pending` also refuses pods more than 450 studs away.
- AutoHelp is off below 10% health (`AR.LowHealth`: Humanoid, or the game's Health stat against
  the highest value seen).
- Key 9 AutoHop (`AH.HopToggle`, on at load, armed 10 s after switching on): changes server
  (random public server with room, else rejoin) when the round runs without us (joined
  mid-round / caught and out while teammates play) or when we are the Beast.
- Standing during slow route searches (corner, planner 2 s): the stall breaker now also runs
  while a plan job is pending (after 0.6 s); breaker walks do not count as route progress.
- The 0.9 s "pushing without progress -> reject lane and replan" rule now applies to every
  owner (farm, flee, exit), not only rescue.
- Exit forced run-in gives up after 0.5 s pressing into a frame, and stops retrying if blocked
  with a Beast threat.
- AutoHide red-alert E taps are suppressed within 7 studs of a computer (a tap started a hack and
  rooted the flight for 1.3 s); door-closing taps still work.
- AutoFarm/exit walks use the Beast-ahead veer (head-on Beast avoidance) that rescue used.

## Round 11 (Workspace_10)

- AutoHop moved out of D into `stall-recorder.luau` (self-contained, on at load, active after
  10 s). Key 9 in D is free again. The recorder UI is a single small draggable "Stop" button.
- Rescue rules bypassed: `AR.Step` picked pods without `AR.Pending()`, so the 10% health rule,
  the lobby check and the 450-stud guard were skipped (live: rescues from the lobby toward pods
  ~600 studs away). Every rescue now passes `AR.Pending()`, and a rescue in progress ends when
  health drops below 10%.
- Head-on hand-over keeps the user's 12 studs; a charging head-on Beast adds 0.6 x closing speed
  (up to 24). The Beast-ahead avoidance ring starts at 32 studs (was 20).
- Most common stall: a move into a rejected lane was refused for its whole TTL while the
  last-resort route led into it. `FH.Move` now slides past on one kept side (40/75/110 deg,
  wall-checked). Non-rescue lane rejections last 1.5 s (rescue 3 s).
- Exit lever: the 12 s cap (counted from the start, walking included) released nearly open
  gates. It now holds while progress rises (stop after 4 s without gain, cap 40 s). Becoming the
  last survivor no longer repicks during opening; AutoHelp waits while we hold a gate >= 50%.
- Vertical progress (climbing stairs toward a higher goal) counts as route progress for every
  owner (live: the route was dropped at the top of the stairs and the avatar walked back down).
- Repeated plan failures at one spot (3 in 20 s within 10 studs) or a goal a floor below after
  2 failures: step off the nearest edge (preferring the goal side) instead of pacing.
- `AH.PathEscape` (cornered / dead end): candidates include the far side of nearby doors and
  points 28 studs away from the Beast behind walls (the planner finds stairs/doors/windows);
  doors allowed, 4 s budget.
- Pod side retries get time for detours (up to 12 s instead of 4 s). Computer contact gives up
  a blocked side after 0.8 s (was 1.4 s).

## Round 12 (Workspace_11)

- AutoHop (recorder) worked: 30+ hops, for "round running without us" and "beast". Lane-rejected
  stalls are gone.
- Repeated hop-and-turn-back at the same spot (a jump over a rail/clip barrier that never
  succeeds, the replan returning the same route): the second no-progress reset within 4 studs /
  8 s marks the blocked spot bad for the planner (8 s) and bans direct mode for 3 s; the third
  gives the goal up ("nopath") so the caller picks another target.
- End of a partial route still short of the goal (AutoHide stood ~1 s on the last waypoint 26
  studs from its flee point): replan at once and head for the goal.
- Lobby: the stall breaker runs after 0.4 s while a plan is pending (spawn stood ~1.2 s on every
  join); a vote-box walk gives up after 8 s (was 25 s) when the box is crowded.

## Round 13 (Workspace2 + Workspace_12)

- AutoHop is its own script `autohop.luau` (on at load, active after 10 s); the recorder only
  records. D key 9 stays free.
- Exit gate "standing in front, never opening": a gate was marked opened for good once its panels
  had moved (someone else's partial hold that slid back), so the bot pushed into the shut gate
  (forced run-in, crossing-failed for minutes). Being stopped by a solid panel of that exit now
  revokes the mark (`FH.RevokeExitOpened`, 6 s proof window) and the bot goes back to open it.
- Rescue descent shaking: the "goal right under the feet -> step off" rule fired mid-jump near the
  pod (feet briefly above the goal); it now needs ground contact and 0.4 s on that height. A
  shortcut drop tried at a spot that left us on the same floor is not retried there for 15 s.
- Stairs up/down loop: the same spot read as a "wall" twice within 4 s while on a route no longer
  drops the route (stair treads/banisters); the no-progress rules still catch a real wall.
- Rescue vs Beast: any Beast closing in fast (> 6 studs/s) within 20 studs with line of sight
  hands over to AutoHide (latched), not only a perfectly head-on one.
- AutoHide dead ends: the best headings are checked for a way on at their end (7 rays, 10 studs);
  dead ends get -25 and are remembered for 25 s (-30), open junctions +4.
- Beast chat "free / free round / free win ..." (from the player who is the Beast this round)
  marks the round free for AutoHide; "not free" etc. cancels it. Ends with the round.
- Lobby face-to-face: the avatar now turns its body smoothly to face the other player squarely
  (a 0.6-stud step was below the input threshold and left it side-on).

## Round 14 (Workspace, 45 files)

- The recorder only flags stands >= 1.2 s, so the "one step, one beat" stutter was measured from
  the 0.1 s samples: 74 in-match micro-stops (0.15-0.9 s), almost all AutoFarm holding position.
  - No local lane while a plan is computed: the controller now keeps moving on an open heading
    toward the goal at once (non-rescue) instead of holding until the breaker.
  - The "goal right under the feet" rule waited 0.4 s still; it now only needs ground contact and
    a small vertical speed. Without an edge it keeps walking while it looks.
- Low health (<10%) stutter: with a captive in a pod, AutoFarm released movement every tick for
  AutoHelp, and AutoHide yielded to "pods pending", although the rescue never started (health
  gate). Both now use `AR.Pending()` (one gate), so the farm/hide continue normally.
- Natural turning: `FH.SmoothHeading` turns the input heading at a bounded rate (14 rad/s, 18 for
  near reversals) like a hand on the keys - only in open space at speed with the aim > 6 studs
  ahead; small corrections (< 25 deg), corners, walls and doorways stay exact.
- Pod behind a wall (Ghost Town: route around a platform, plan refresh unusable, local steering
  pulled at the pod behind the wall, next plan led back around): an unusable replan within 5 s of
  a good route keeps walking that route from the nearest point.
- Rescue vs Beast: a Beast within 16 studs of the pod (guarding it) holds the rescue back
  (farm/hide continue) until it leaves; free round / AFK Beast excepted. After a hand-over to
  AutoHide the rescue resumes only after 2.5 s and with the Beast beyond 18 studs (max 5 s).
- Lobby face-to-face: varied, human-paced turns (calm ease-in-out, two-stage glance with a beat,
  casual turn with a slight overshoot that settles), duration scaled by the angle.

## Round 15 (round 14 re-applied on the user's restored round-13 D)

- The round-14 game lag: `AR.Pending()` -> `AR.BeastCampsPod` -> `AH.Eval()` ->
  `AH.RescueContext()` -> `AR.Pending()` ... recursed without end; the stack overflow was caught
  and retried by every loop (hide, help, movement). The guard check now reads the cached
  `AH.Last` and is cached per pod for 0.3 s; a test fails if it re-enters `AH.Eval`.
- `FH.SmoothHeading` only casts rays while a sharp turn (>= 25 deg) is in progress, cached for
  0.12 s per heading pair.
- All other round-14 fixes are back (micro-stop removal, single rescue gate for farm/hide with
  low health, recent-route keep for pods behind walls, pod guarding, human lobby turns).
- Rescue vs a charging Beast reacts earlier: head-on charge 14 + 0.8 x closing speed (cap 30),
  any Beast closing > 6 studs/s within 24 studs (static head-on keeps the user's 12).
- Lobby turns: five styles now (glance away first, several small nudges, calm ease, two-stage
  glance, casual overshoot), human-paced.

## Round 16 (Workspace_1)

- Exit lever released at 98-99 %: the opening loop broke out as soon as progress read >= 0.98
  (and could also break on "panels moved" while holding), releasing E before the game finished;
  the gate reset, the run-in hit the shut panel ("gate-still-shut") and it started over. It now
  holds through the top until the progress falls back or reads full (0.3 s), max 3 s; while
  holding only a real geometric opening by someone else ends it. Past 70 % the holder keeps the
  movement: `FH.ExitHoldLocked` denies other owners, and only hard reasons (manual control,
  caught/ragdoll, Beast role, escaped, exits off) stop the hold - not AutoHide busy/farm abort.
- Lobby face-to-face reworked to how players turn: mostly a short movement-key tap toward them
  (native body rotation), quick linear camera-like flicks, double taps, flick with overshoot and
  correction. No slow eased glides.
- AutoHide: oscillation guard counts 3 reversals within 3 s (dead-end shuffles reversed every
  ~1.2 s); walk-into-drop keeps pushing 2.5 studs past the lip until it falls (it stood at the
  edge); hop-ups get a bonus (+2 per jump) instead of a penalty; a weave bias (+-55 deg,
  re-rolled every 1.5-3 s) bends the line unpredictably without frame-to-frame changes; open
  junctions +7, narrow pockets -6, dead ends -25.
- Micro-stops (0.15-0.9 s) in this recording: 16 (74 in the previous one).

## Round 17 (Workspace_2)

- "Step, beat, step" with a captive and low health: AutoFarm's PC walk aborted on "any captive in
  a pod" (`hasCaptured`) and `capturedPods()` ignored the rescue gate, so every walk to a computer
  stopped after a few studs, the lease ran out (~3 s standing), and it picked again. The farm's
  captive list is now empty whenever no rescue will run (health < 10% or `AR.Pending()` false).
- Exit gate "not even opening": a gate was believed open (panels had moved while someone held the
  lever, then slid back) and the bot stood in "waiting" for 30 s in front of the shut gate.
  Panel movement now counts only after the panels stayed put for 2 s, and while waiting the bot
  checks once a second for a solid panel of that gate between it and the gate centre; if found it
  drops the mark and goes to open it.

## Round 18 (Workspace_3 = the same two recordings as Workspace_2; fixes from the report + code review)

- Exit gate not opening (likely since round 16): the hold read the action-progress stat without
  checking it belonged to this hold. A stale value (1.0 left by the previous computer) counted
  as "reached the top" at once and the lever was let go after 0.3 s. Only progress seen rising
  from a low value (< 0.9) during this hold counts; if the stat never tracks the lever, the
  hold runs on time like the older builds (15 s, earlier if the gate itself shows open). Test:
  round 17 fails it (0.21 s), this build passes.
- Vents: the narrow route profile used a 4-stud agent height, so routes could lead through
  crawl-only openings the standing avatar cannot pass (pressing and shaking). Agent heights are
  5.2 / 5 now - vents are walls for routing.
- Drop shortcuts (jump a rail/ledge down instead of walking the stairs/ramp) are taken when they
  save 6+ studs (was 15).
- Rescue: with the pod within 30 studs and a closed door straight between us and it, that door is
  opened directly instead of a door-route search that could pick a different, far door.

## Round 19 (Workspace_4 + D_stall_20261113_143025)

- Turning "lag": the round-14 turn-rate smoothing is removed (direct heading again, as in the
  round-13 build the user liked); it made turns sluggish and scrape walls.
- Door/wall shaking: the rejected-lane slide flipped sides (left-right-left) at doors. A kept
  slide never changes side, slides only for aims > 4 studs away and never for precise contact.
- Rescue next to a pod from a ledge (Library: standing 2 studs above the approach point): the
  final pod approach may step down up to 3.5 studs, and the "goal under the feet" step-off works
  from 1.5 studs (1.2-stud edges when the goal is that close).
- School: the "island" rule took a low filing-cabinet edge for an island and hopped on/off it;
  an island now needs a 6+ stud edge and fires once per 10 s per spot.
- AutoHide: vents are never vaulted (they were treated like windows); windows/rails are found up
  to 14 studs to the side (8.5 before) with landing up to 17.5; open doors up to 22 studs (16).

## Round 20 (Workspace_5, 62 files)

- 153 micro-stops (0.15-0.9 s). Main pattern (Shopping Center upper floor, plans failing): the
  stall-breaker walked 6 studs, reached its point in ~0.35 s and stood there until its 0.7 s
  timer ran out (a standing beat), then picked the goal side again (to and fro = shaking).
  A breaker walk now ends on arrival, aims 10 studs, and keeps its heading for up to 2.5 s while
  it stays open. The fallback step-off walk also ends on arrival.
- Rejected lanes: a move toward one is no longer refused (a standing beat) nor slid sideways (a
  sharp turn that flipped left/right - present in many jitter incidents); it just continues and
  the no-progress rules handle real walls. "Keep the recent route" now applies to rescue only.

## Round 21 (Workspace_7; Workspace_6 was a copy of Workspace_5)

- Frame drops: during a rescue the door-detour search (up to 12 doors x native path
  computations) ran every 1.5 s for any route longer than the straight line by 0.01 stud, and
  after a failed door route the planner kept returning "door" mode. Now: rescue detours only for
  a real detour (>= 25 % + 6 studs) at most every 4 s; no door mode for 5 s after a door route
  failed. AutoHide dead-end probes are cached per 4-stud cell/heading for 1.5 s;
  `Follow.CenterAim` reuses its result for 0.1 s.
- Rescue shaking 20+ s in a cluttered School room: the avatar stood on a low prop and every
  native plan failed. When a plan fails, the planner now plans from the floor right beside us
  (1-5.5 studs lower, clear step) and prepends the step down.
- Round 20's "keep moving into a rejected lane" is reverted (it pushed into walls); the round-19
  kept-side slide is back.

## Round 22 (Workspace_8, 6 new files)

- Micro-stops in-match: 14 (153 two rounds ago).
- Rescue next to a pod but stuck behind a rail/ledge (Nuclear: 6-8 studs, hopping to and fro):
  silent help on the way in - within 10 studs flat / 6 studs height of the target pod the rescue
  trigger is sent remotely every 0.2 s while the avatar keeps moving, and released when the
  captive is out or the rescue ends.
- AutoHide walk-into-drop blocked by a rail before the drop: it hops over after 0.15 s (once)
  instead of standing 0.4 s and giving the drop up.
- Lobby face-to-face picks players around the map-vote area (within 30 studs of the board, and
  40 of us), nearest to the board first.

## Round 23 (Workspace_9, 2 new files)

- Doorway left/right dance (Arctic Station kitchen: ~6 s turning before entering an open
  doorway; 71 sharp heading flips in the two files): brushing the frame read as a "wall", which
  rejected the lane and dropped the route at the doorway; the next plan led back through it,
  rejected again, with side slides in between. The frame/leaf of an open door (or a part named
  *frame*/*door*) on the route is no longer a wall while following a path, and the 0.9 s
  no-progress rule replans without marking a doorway lane as blocked.
- Micro-stops in these files: 2. The AutoHide flight in the recording kept full speed while
  hopping onto a table (no stall to fix there).

## Round 24 (Workspace_10, 2 new files)

- Lobby strolling looked like a twitchy bot: random 4-13 stud hops around other players, the
  next often behind us (U-turns), some across the vote boxes. Stroll legs are now 8-26 studs,
  mostly ahead of where we face (within ~75 deg), never within 5 studs of a vote box, with an
  occasional short idle between legs.
- Twitching between the route and a sideways slide (lobby spawn and in-match): a rejected lane
  no longer changes the input at all (no refusal, no slide); it only steers the planner. Walls
  are handled by the no-progress rules (doorway exception and replan throttles from rounds 21-23).

## Round 25 (Workspace_11, 30 new files)

- Spinning around a goal (lobby/vote box; also in-match): arrival required a clear line from
  the root down to a ground-level goal, which slanted into the floor/a podium base, so the
  avatar overshot, turned 180 and overshot again. The line is now checked at body height, and
  an orbit guard ends a walk that stays within 1.6x the stop radius for over a second.
- Stairs: the blind breaker walk headed straight at a goal on another floor (into the side of a
  staircase, hop, fall back, reverse). No quick breaker toward a goal more than 5 studs up/down;
  the route finds the stairs.
- AutoHide -> AutoHelp beat: the hand-over latch kept the rescue waiting while AutoHide had
  already stopped fleeing (nobody moved). The latch now only holds while AutoHide is busy.
- Lobby: vote-box avoidance removed (user); stroll points keep 5 studs from every player and do
  not circle the same player twice in a row (no "shadow"); a stroll leg ends as soon as the
  board loads the preferred map we have not voted for; a finished round starts a new ballot
  even if we waited in the lobby; 10 % of lobby legs are walked holding Shift (released at the
  end of the leg / when a round starts).
- Exit lever: 65 % of holds the avatar turns its back to the gate (watching the room); body
  facing only, the hold is unchanged; AutoRotate restored afterwards.

## Round 26 (Workspace + D_stall_20261114_043129, 15 new files)

- Hacking: the hold starts as soon as the game has selected our slot within 2.6 studs (any
  attempt; it used to step in to 1.4 studs first - the beat before every hack), and the walk to a
  slot ends as soon as the slot is selected. A slot counts as taken when another player is
  nearest to it within 3.2 studs (2.2 before) or is walking into it. 35 % of hacks: while a
  teammate hacks the same computer, the avatar turns to face them (facing only).
- Exit watch-back turn is quicker (no slow glide). Fixture-safe vector blend instead of Lerp.
- UI: the main panel starts at the left edge below the middle (user screenshot), not the screen
  centre; the UI is locked (P) automatically 5 s after load.
- Stairs: the round-21 "plan from the floor beside a prop" stepped off staircases sideways when
  a plan failed mid-flight (fall, then turn back). It now runs only on a small flat prop
  (< 14 studs, not a stair/step/ramp/wedge) and never toward a higher goal.
- Holes: the walk-in drop hop (round 22) only fires when a real rail/lip is in front; an open
  hole edge is just walked into.
- Lobby crawl: a 12 s Shift-held session (10 % chance per leg), released early when a round
  starts or on unload.

## Round 27 (D_stall_20261114_045757)

- Exit gate not opening again (after round 26; round 25 was reported fine): the body was turned
  by writing the root frame on every hold tick (round 26 made it stronger), which can cancel the
  game's action. The watch-back turn is now done once, before the first hold tick, never during
  the hold; the co-hacker facing likewise happens once before a hack starts.
- Hacking: slot-taken radius back to 2.6 studs (3.2 skipped free slots); computers a teammate is
  hacking (with a slot free) score ~20 studs better per teammate (max 2) and the farm switches to
  one on its way; no 0.15 s wait after a hack attempt.
- Silent help while rescuing now covers any captive pod we pass within 10 studs, not only the
  target pod.
- Local steering after a dropped route knows the current running direction (velocity) and
  penalises reversing (it picked a way back mid-run).
- UI panel a little higher (0.38 of screen height).

## Round 28 (D_stall_20261114_051839)

- Chased toward an open exit, turned around in front of it: with the gate open and a Beast
  chasing, the route still went to the lever stand (beside the gate) before crossing. When chased,
  an open gate whose centre is within 25 studs on a clear straight line is now run into directly.
- Silent help only with a clear line to the pod (no wall in between).

## Round 29 (D_stall_20261114_054026)

- Rescue back-and-forth (School): "keep the recent route" (round 14) re-adopted an older route
  pointing back while local steering pointed ahead - alternating every ~0.6 s for seconds. The
  feature is disabled.
- Desk-hopping loop in cluttered rooms: the round-21 "plan from the floor beside a prop" stepped
  off a desk the native route had just climbed; now only after 2+ failed plans in a row.
- Fewer window/obstacle routes since round 18: the 5.2/5-stud agent heights excluded windows and
  gaps over obstacles. Back to 5/4 (low crawl vents stay excluded at 4).
- Mid-vault turnarounds: a finished plan (and the rescue route preview) is applied only on the
  ground, not while airborne.
- Rescue door shortcuts searched for a smaller detour (>= 12 % + 3 studs) every 2.5 s (was
  25 % + 6 every 4 s), with the 5 s door-failure pause kept.

## Round 30

- Hack: the 35 % "face a co-hacker" turn is gone. Instead the avatar faces the
  computer (screen / pivot) once before the first hold, AutoRotate stays off
  while holding and is restored afterwards (live: arrived diagonal to the desk
  and the hack did not register).
- Lobby crawl: rolled once per lobby visit (10 %), not per stroll leg.
- Lobby spacing: face-to-face spot 6-8.5 studs (was 3-5); stroll spots keep
  8 studs from every player (was 5).
- WalkTo: when plans fail twice in a row (shut in a small room, live Homestead
  rescue bouncing for seconds), open the nearest closed door on our floor
  within 12 studs and pass it, then replan; each door tried at most once per 5 s.

### Round 30b (same Workspace_1 data)

- AutoHide dead ends: a straight run that reaches the 20-stud scan limit is now
  judged one more scan ahead (Airport: ran 20 studs into a closed corridor
  and spun 180 degrees). Ends with <= 1 open heading cost -20 and are
  remembered with the other dead ends. Shared AH.OpenAt helper (cached).
- AutoHide stuck check every 0.18 s / 0.55 studs (was 0.25 s / 0.7): the
  0.45 s press into an invisible ComputerTable barrier is cut short.
- AutoHide: headings that change floor (stairs/ramps, >= 3 studs) +6.
- WalkTo entry test: a native route whose first leg failed our ray test was
  thrown away (entry-rejected, then local steering bouncing for seconds in
  Abandoned Prison / Homestead). A first waypoint within 10 studs and at most
  5 studs up is now trusted ("entry-trusted").
- Doors: no 8 s give-up just because the approach ended short of the
  trigger; the hold loop steps on and presses. Face the door once before the
  first press.
- Hand-over to AutoHelp: rescue keeps moving on its arrival momentum (or an
  open heading) while its first route is computed - it stood ~0.3 s at every
  hand-over. AutoHelp loop polls every 0.06 s while idle (was 0.15 s).

## Round 31 - Round 26 is the base again

D (and tests/) restored to Round 26 (cd3e7cb) at the user's request. Ported
from the Round 30b version, nothing else:
- the whole lobby / vote-map movement block (Follow.LobbyVotePads ..
  Follow.LobbyStep: crawl once per lobby visit, 8-stud spacing, 6-8.5 stud
  face-to-face distance, etc.);
- hack starts at once: FH.FaceComputer faces the computer once before the
  first press (Round 26 co-hacker facing kept as it was);
- exit lever: watch-back turn once before the first hold, no body writes
  while holding;
- UI frame position Y 0.38.

## Round 32 (on the Round 26 base)

- Silent help only with the pod in sight (FH.PodInSight: head and chest eye
  lines, walls/doors/glass block).
- Lobby: 20 % of visits tap Shift once a second for 13 s while strolling
  (Follow.LobbyShiftTaps); the 10 % crawl stays.
- AutoHide FleeSpeed 16.5; ContactRange 10; NearRange unchanged (32).
- Rescue head-on hand-over reach 12 -> 13.5 (charging base 14 -> 15.5).
- AutoHelp routing: window-capable path agents { {2.4,5}, {1.2,4} }, door
  detour for rescue when the route is > 1.12x+3 the straight line (every
  2.5 s), no plan switch mid-air, open the nearest door when shut in.
- Momentum carry while the first route is computed is written but disabled
  (`if false and ...`): the navigation test run hung and was not finished.

## Round 33

- Removed the lobby 1 s Shift taps (Follow.LobbyShiftTaps); 10 % crawl stays.
- Anti sharp turns: Follow.Pick penalises reversals (-6 x reverse dot) and
  uses the live velocity as heading when no previous direction is known.
- Wedge escape in WalkTo: barely moved (2.5 studs) for 2.5 s while not
  arrived -> walk 0.8 s toward the most open of 12 headings (biased to the
  goal), normal jump if something low blocks it, then replan.
- Test note: the hang comes from FH.PodInSight in the fixture (the same file
  with that check removed passes 166/368); not run again at the user's
  request.

## Round 34

- Momentum carry while the first route is computed is on again (anti beat).
- FH.FlipGuard in FH.GroundMoveStep (input layer, all features): ordinary
  turns are untouched; only a second full reversal within 0.6 s of the
  previous one (back-and-forth jitter) keeps the current heading 0.25 s more,
  only grounded, more than 3 studs from the aim, and only while that heading
  is open 2.5 studs ahead. Not test-run (user request).

- FH.FlipGuard skips AutoHide (owner "evade") entirely.

## Round 35

- Vault commit (not AutoHide): FH.JumpMoveStep keeps the takeoff heading
  through the air when the aim swings more than ~72 degrees away mid-jump;
  FH.LandCommit then keeps that heading 0.45 s after landing (only while 3
  studs ahead are open) so the avatar does not turn back on the far side of
  a window, prop or rail. Compile-checked only.

## Round 36

- Pre-jump hesitation: route and local steering alternated on props/ledges
  (055808: path -> none -> path every 0.3-0.5 s with "entry-rejected").
  A native route whose first leg is within 10 studs and at most 5 up is now
  trusted ("entry-trusted").
- AutoHelp stair hops: on a path leg climbing/descending >= 2 studs, running
  > 10 studs/s straight along two in-line legs (dot > 0.9: never at an
  angle into the side edge), stair/slope underfoot 2 studs ahead, headroom
  clear, > 8 studs from the goal: one normal jump, at most every 0.75 s.
- Corners: the Round 33 wedge escape covers getting stuck in a corner; no
  extra wall-slide steering was added. Compile-checked only.

## Round 37

- AutoHelp wide shortcut scan: Follow.RescueShortcut looks 25 route points /
  32 studs ahead (was 10 / 18) for a window/prop/rail cut; far cuts must save
  > 4 studs; best 4 candidates verified (was 2).
- AutoHide: jump lanes (windows, rails, props, drops) +4 each (+5 juking),
  floor change +6; far dead-end look-ahead (AH.OpenAt, one more 20-stud scan
  past a full run); after running through an open door with the Beast behind
  on the other side, one remote press shuts it (AH.CloseDoorBehind), no stop.
- FlipGuard (farm/help only): second reversal within 0.9 s holds 0.35 s.
- Co-hacker facing 65 % (was 35 %). Compile-checked only.

## Round 38

- AutoHide: vault candidates ranked nearest first (score = window 4 + 0.3 x
  distance gained - 2 x distance to the sill + lateral 2); any window, rail
  or prop on the way qualifies (not only lateral ones inside juke range);
  may cost up to 1 stud of Beast distance. Open doors also nearest first
  (0.3 x gained - 2 x distance).
- AutoHelp: Follow.RescueShortcut always also tests the route's last two
  points (beside the pod), however far along the route, so passing the pod
  room with a window cuts straight in (within 32 studs, same floor).
  Compile-checked only.

## Round 39

- Spin filter in FH.FlipGuard (farm/help only, never AutoHide): input that
  turns a full circle or more within 1.5 s while the body moves < 5 studs
  locks one open heading for 0.6 s. Not recorded within 4 studs of the aim.
- Wide map knowledge: the script already samples the loaded map in the
  background (FH.Nav atlas: 4-stud floor columns, links, door portals) and
  uses it for routes; no second scanner was added (frame cost). Ladders
  (TrussPart climbing) are not routed yet. Compile-checked only.

## Round 40 (on the user's 26590-line D)

- Key 0 (on) now runs Follow.AutoAll(true), the same start as on load
  (AutoFarm from any phase + AutoHide + AutoHelp). It used to open the
  Follow player picker instead.
- Hand-over beats: rescue waiting on its first route walks on (quick also
  for rescue while a job runs); route-search wait before walking out 0.15 s
  (was 0.4); AutoHelp idle poll 0.06 s (was 0.15).
- Exit lever: face the lever once before the first press; the 65 %
  watch-back turn happens once the game is clearly opening (progress >= 15 %);
  with a live progress stat, a press that shows no progress for 1.1 s is
  released and pressed again. Compile-checked only.
