# Diag Ket — nhận diện vì sao nhân vật đứng yên

Diag nằm trong D (nút **Diag Ket [T]** ở tab Hacks, hoặc phím **T**). Diag chỉ đọc trạng thái, không điều khiển nhân vật và không gửi dữ liệu ra mạng.

## Cách dùng

1. Bật AutoFarm / AutoHelp / AutoHide như bình thường.
2. Bấm **T** (hoặc nút Diag). Console in `[Diag] bat. File: D_diag/stall-....json`.
3. Chơi bình thường. Mỗi lần nhân vật đứng yên quá 1,2 giây trong khi một tính năng di chuyển đang bật, console in `[Diag] ket #n: <lý do>` và nút hiện số lần kẹt.
4. Bấm **T** lần nữa để tắt và lưu. Gửi file `workspace/D_diag/stall-....json` của executor để phân tích.
   - Nếu executor không có `writefile`, Diag copy JSON vào clipboard (nếu có `setclipboard`).

## File ghi gì

Với mỗi lần kẹt:

- `reason`: phân loại nhanh, ví dụ:
  - `controller-holds-position (wall-slide / hold-no-lane)`;
  - `pushing-but-blocked`;
  - `move-refused: lane-rejected`;
  - `no-movement-while-planning`;
  - `no-owner-moving`;
  - `interacting`.
- `now` và `history` (khoảng 2,5 giây trước đó, 10 mẫu/giây):
  - vị trí, tốc độ, trạng thái Humanoid, vật liệu sàn, WalkSpeed;
  - tính năng đang giữ quyền di chuyển và thời hạn còn lại, khoảng cách tới điểm đang nhắm;
  - chế độ tìm đường (`direct`/`path`/`none`), số waypoint, thời gian chờ tính đường;
  - các cờ AutoHide/AutoHelp/AutoExit và lý do lệnh di chuyển bị từ chối.
- `probe`: tia dò 8 hướng ở 3 độ cao, sàn, trần và hướng tới điểm nhắm. Mỗi tia ghi tên part, khoảng cách, pháp tuyến, kích thước, CanCollide và có phải cửa không.
- `duration` và `resumedBy`: kẹt bao lâu, ai làm nhân vật đi tiếp.

Tối đa 80 lần kẹt mỗi phiên. File chứa tọa độ trên map, nên chỉ gửi cho người phân tích, đừng đưa lên repo.
