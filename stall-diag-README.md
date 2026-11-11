# Diag Ket — nhận diện vì sao nhân vật đứng yên

Diag nằm trong D và **tự bật khi nạp script**, không cần bấm phím. Nút **Diag Ket** ở tab Hacks dùng để tắt/bật. Phím T vẫn là phím tắt script như cũ; Diag không dùng phím nào. Diag chỉ đọc trạng thái, không điều khiển nhân vật, không gửi gì ra mạng.

## File ở đâu

- Ngay khi nạp script, Diag tạo file `D_stall_<ngày>_<giờ>.json` ở **thư mục gốc Workspace của executor**. Với Delta, đó là thư mục `workspace` của Delta, không có thư mục con.
- Console (F9) in dòng `[Diag] bat. File: D_stall_....json`.
- File được ghi lại mỗi lần phát hiện kẹt. Khi tắt bằng nút hoặc gỡ script, Diag ghi thêm một lần cuối.
- Nếu executor không có `writefile`, khi tắt Diag sẽ copy JSON vào clipboard (nếu có `setclipboard`).

## Ghi gì

Mỗi lần nhân vật đứng yên quá 1,2 giây trong khi AutoFarm/Follow/AutoHide/AutoHelp đang bật, Diag ghi một "lần kẹt", và console in `[Diag] ket #n: <lý do>`.

- `reason`: phân loại nhanh, ví dụ:
  - `controller-holds-position`;
  - `pushing-but-blocked`;
  - `move-refused: lane-rejected`;
  - `no-movement-while-planning`;
  - `no-owner-moving`;
  - `interacting`.
- `now` và `history` (khoảng 2,5 giây trước đó):
  - vị trí, tốc độ, trạng thái Humanoid, sàn;
  - tính năng giữ quyền di chuyển, khoảng cách tới điểm nhắm, cờ `precise`;
  - chế độ tìm đường, số waypoint, thời gian chờ tính đường;
  - trạng thái AutoHide/AutoHelp/AutoExit.
- `probe`: tia dò 8 hướng ở 3 độ cao, sàn, trần và hướng tới điểm nhắm.
- `duration` và `resumedBy`: kẹt bao lâu, ai làm nhân vật đi tiếp.

Tối đa 80 lần kẹt mỗi phiên. File có tọa độ map, nên chỉ gửi trực tiếp để phân tích, đừng đưa lên repo.
