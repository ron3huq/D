# Movement reference analysis — 2026-11-03

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
