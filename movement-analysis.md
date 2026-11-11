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
