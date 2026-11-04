# Navigation controller follow-up — 2026-11-04

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
