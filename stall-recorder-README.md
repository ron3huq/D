# stall-recorder.luau — ghi lại vì sao nhân vật đứng yên / đi lòng vòng

Đây là script **riêng**, chạy song song với D. Script chỉ quan sát: không di chuyển nhân vật, không bấm phím, không gửi remote, không dùng mạng.

## Chạy

1. Chạy D như bình thường.
2. Chạy `stall-recorder.luau` trong cùng executor. Thứ tự nạp không quan trọng; nạp sau D thì có thêm trạng thái nội bộ của D.
3. Script **tự khởi động và tự lưu**, không cần bấm gì. Một khung nhỏ ở góc dưới trái (kéo đi được) hiển thị:
   - số lần đứng yên (stall), đi tới đi lui (pace), giật (jitter);
   - tên file, dung lượng đã ghi, và `luu: OK` hoặc `LOI: <lý do>`.
4. Khung chỉ còn một nút nhỏ **Stop** (kéo để di chuyển): bấm là dừng ghi, lưu lần cuối, tắt AutoHop và đóng nút.
5. **AutoHop** nằm trong recorder (phím 9 trong D để trống): tự bật khi chạy recorder, 10 giây sau mới hoạt động. Đổi server (server công khai ngẫu nhiên còn chỗ, nếu không được thì vào lại game) khi: trận đang chạy mà mình ở sảnh (vào giữa trận / bị bắt thua trong khi đồng đội còn chơi), hoặc mình là Beast. Đã thoát thì không đổi. Muốn script tự chạy lại ở server mới, đặt D và recorder vào thư mục autoexec của executor.

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
