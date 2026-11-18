# stall-recorder.luau — ghi lại vì sao nhân vật đứng yên / đi lòng vòng

Đây là script **riêng**, chạy song song với D. Script chỉ quan sát: không di chuyển nhân vật, không bấm phím, không gửi remote, không dùng mạng.

## Chạy

1. Chạy D như bình thường.
2. Chạy `stall-recorder.luau` trong cùng executor. Thứ tự nạp không quan trọng; nạp sau D thì có thêm trạng thái nội bộ của D.
3. Script **tự khởi động và tự lưu**, không cần bấm gì. Một khung nhỏ ở góc dưới trái (kéo đi được) hiển thị:
   - số lần đứng yên (stall), đi tới đi lui (pace), giật (jitter);
   - tên file, dung lượng đã ghi, và `luu: OK` hoặc `LOI: <lý do>`.
4. Recorder không còn nút trên màn hình (chỗ đó giờ là nút **Pause** của AutoHop). Muốn dừng ghi: chạy `getgenv().DStallRecorder.Stop()` (lưu lần cuối rồi dừng).
5. **AutoHop** giờ là script riêng `autohop.luau` (không còn trong recorder, phím 9 trong D vẫn để trống): chạy là tự bật, 10 giây sau mới hoạt động. Đổi server (server công khai ngẫu nhiên còn chỗ, nếu không được thì vào lại game) khi: trận đang chạy mà mình ở sảnh (vào giữa trận / bị bắt thua trong khi đồng đội còn chơi), hoặc mình là Beast. Đã thoát thì không đổi. Muốn tự chạy lại ở server mới, đặt D, recorder và autohop vào thư mục autoexec của executor.

Để treo máy nhiều trận thì cứ để chạy. Nếu bị đổi server, executor phải tự chạy lại script; với Delta, đặt file vào thư mục `autoexec`.

## File

- Nằm ở **thư mục gốc Workspace của executor** (Delta: thư mục `workspace`).
- Tên file: `D_stall_<ngày>_<giờ>_p1.txt`, `_p2.txt`...
- Định dạng JSON Lines: mỗi dòng là một bản ghi.
- File được tạo ngay khi chạy script.
- Nếu executor có `appendfile`, script ghi nối vào file. Nếu không, mỗi phần khoảng 3 MB rồi sang phần mới.
- Tổng dung lượng tối đa 200 MB, sửa `MAX_TOTAL_MB` trong script nếu cần.
- Ngoài ghi ngay mỗi khi có sự cố, script còn lưu định kỳ mỗi 10 giây.

## Ghi những gì

| Bản ghi | Nội dung |
|---|---|
| `header`, `round`, `summary` (mỗi phút), `end` | Thông tin phiên, map từng trận, bộ đếm |
| `incident` kind `stall` | Đứng yên ≥ 1,2 s (không tính lúc bị bắt/ngã/đã thoát) |
| `incident` kind `pacing` | Trong 8 s đi ≥ 24 stud nhưng chỉ dời được ≤ 6 stud |
| `incident` kind `jitter` | Trong 3 s đổi chiều ≥ 4 lần, dời ≤ 3 stud |
| `resume` | Đứng yên bao lâu thì đi tiếp |
| `lobbyScan` | Ở sảnh: các nhãn chữ / part / nút có tên map hoặc chữ vote (để tìm chỗ bầu map) |

Mỗi `incident` gồm:

- `history`: 3 giây trước đó, 10 mẫu/giây. Mỗi mẫu có:
  - vị trí, tốc độ, trạng thái Humanoid, sàn;
  - hướng nhập (`MoveDirection`), điểm `MoveTo` đang nhắm và chênh độ cao;
  - cờ bị bắt/ngã/hack;
  - `d`: trạng thái nội bộ của D, gồm tính năng giữ quyền di chuyển, khoảng cách điểm nhắm, cờ `precise`, chế độ tìm đường, thời gian chờ tính đường, lệnh bị từ chối và phân loại `reason`.
- `probe`: tia dò 8 hướng ở 3 độ cao, sàn, trần và hướng tới điểm nhắm (tên part, khoảng cách, pháp tuyến, kích thước, CanCollide).
- `pods`: Pod đang giam người (khoảng cách, chênh tầng).
- `beast`: khoảng cách, chênh tầng, có quay mặt về mình không.

File có tọa độ map, nên chỉ gửi trực tiếp để phân tích, không đưa lên repo.

## Version 2 (round 43)

- **Only matches you really played are saved.** Everything is kept in memory
  for the current round. When the round ends it is written to the file only
  if you were in the map from the start of that round (not joined mid-round)
  and spent at least 30 s inside it. AFK server hops, half-finished rounds and
  lobby-only time are dropped; if nothing qualifies, no file is created.
  Calling DStallRecorder.Stop() mid-round saves that round only if it already qualifies.
- New lines in the file:
  - `s` — the full movement trail every 0.1 s (position, speed, vertical
    speed, state, floor material, input direction, facing, walk speed,
    captured/escaped/hacking/crawling; D's state every 0.5 s when D runs).
  - `cell` — the shape of the map around you: each new 6x6 stud cell you
    enter (per floor) gets 16 directions x 4 heights (0.5, 1.8, 3.5, 5.5
    studs) of 16-stud rays (distance, part, normal, class, size, kind), the
    floor height 3 studs out in each direction (steps, stairs, drops),
    floor and ceiling.
  - `mapParts` / `mapBox` — once per round: every door, exit, computer, pod,
    window, stair, step, ramp, ladder/truss, wedge, vent, rail, fence,
    barrier, table/desk/shelf/crate with position, size, facing, collision
    and transparency.
  - `roundEnd` — map, time inside, escaped/caught.
- Play normally through every kind of place (stairs, turning stairs,
  windows, rails, drops, vents, narrow rooms, doors) and send the files.

### v2.1

- A round counts once you were in the map from its start and 10 s inside it
  (was 30 s, judged only when the round ended). From that moment it is
  written to the file live (flushed every 2 s), so a round that ends early
  (Beast left, you were caught) or a server hop / teleport right after it
  is still saved. A `teleport` line marks a hop.

### v2.2

- A round is saved as soon as you have really been inside its map for 10 s
  (total), whenever that happens; standing in the lobby never counts. The
  old rule also required being inside within 40 s of the map appearing and
  having seen the lobby first, which skipped many played rounds (long
  loading, recorder started late, same map twice).
- The map's box is re-measured every 10 s while it streams in; a new round
  is detected by a new map object, not only a new map name.
- Errors are no longer silent: the first one (and every 500th) is printed
  and written as an `error` line; cell/map scans are isolated so one bad
  scan cannot stop the recording.

### v2.3 (needs the matching D)

- `ev` lines: D's decision log, every event in order since the last line -
  plan results, accepted routes (all waypoints and jump marks), walk mode
  changes, shortcuts, door/exit/hack/pod steps, evade jukes, hop/stair
  decisions - each with D's movement owner at that moment.
- `players` lines (1 per second in a match): every player's role, position,
  facing, speed, captured/ragdoll/escaped/crawling and what they are using
  (computer/exit/pod trigger), plus computers left when the game exposes it.
- D's state is attached to the trail every 0.2 s (was 0.5 s) and now also
  carries the walk goal, the motion aim, the target pod and the Beast
  (position, facing, speed, distance, measured hammer reach).

### v2.4

- Saving rule is now simply time: once the recorder has been running for
  90 s, everything is written to the file (the first 90 s included) and
  from then on live, flushed every 2 s. Sessions shorter than 90 s are not
  saved. Rounds are still marked with `round` / `roundEnd` lines.
- While the Beast is near (< 30 studs) or D reports a threat, D's state is
  attached to every 0.1 s sample (chases are recorded in full detail).
