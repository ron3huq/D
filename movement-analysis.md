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
