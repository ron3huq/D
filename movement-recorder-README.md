# Bộ ghi cách di chuyển trong Flee the Facility

Đây là script **riêng**, không tích hợp vào D, DA hoặc de. Bộ ghi quan sát cách bạn tự chơi để tham khảo khi cải tiến logic xử lý tình huống. Nó không phát lại tuyến đường, không điều khiển nhân vật và không tự huấn luyện bot.

## Cách dùng trên điện thoại

1. Vào game và **tắt các chế độ tự di chuyển**. Nếu phiên Roblox trước bị văng khi bật D/de, hãy vào một phiên mới và chỉ chạy bộ ghi.
2. Chạy file [movement-recorder.luau](movement-recorder.luau), hoặc dùng lệnh:

   ```lua
   loadstring(game:HttpGet("https://raw.githubusercontent.com/ron3huq/D/main/movement-recorder.luau"))()
   ```

3. Bấm **Ghi**, rồi tự chơi bình thường. Không cần chọn AutoHelp, AutoFarm hay AutoHide.
4. Bấm **Dừng → Xuất file**. Gửi file `ftf-movement-<thời gian>-<mã>.jsonl` cho tôi phân tích.

File nằm trong **workspace của executor**, không phải workspace của Roblox Studio. Vị trí thư mục tùy bản executor. Tìm tên file vừa hiện trên bảng hoặc dùng trình quản lý file của executor. Có thể đổi đuôi `.jsonl` thành `.txt` khi gửi, không cần sửa nội dung.

Nếu không có API lưu file hoặc lưu thất bại, bộ ghi hiện văn bản thành nhiều trang. Chép **đủ các trang theo thứ tự** bằng nút **Chép trang / Sau**. Có thể nhấn giữ chọn văn bản nếu clipboard cũng không được hỗ trợ. Các trang ghép lại là dữ liệu gốc, không phải ảnh hay video.

## Tự nhận diện tình huống

Nhãn **Tự: ...** chỉ là phân loại dựa trên trạng thái quan sát được, không bật chế độ trong D và không đọc các biến nội bộ của D.

| Nhãn | Dấu hiệu dùng để nhận diện |
| --- | --- |
| AutoFarm | Đang hack PC; đang tiến về PC chưa hoàn thành hoặc chưa rõ trạng thái; đang tương tác/tiến tới exit. |
| AutoHelp | Đang tương tác cứu pod; tiến về pod **đang có người bị giam**; vừa đổi đường hoặc mở cửa sau một đoạn tiếp cận cứu người. |
| AutoHide | Beast ở gần cùng độ cao tương đối và có dấu hiệu tiếp cận, hoặc bạn đang chạy ra xa. Beast quan sát thấy đứng tại chỗ 40 giây được ghi riêng. |
| Chung | Chưa đủ dấu hiệu, đang bị giam, đang làm Beast, hoặc không phải tình huống Survivor đang hoạt động. |

Khi vừa đi cứu vừa có Beast gần, file có thể chứa **cả AutoHelp và AutoHide**, kèm điểm bằng chứng, lý do, khoảng cách, vị trí và nhãn chính. Một người bị giam ở xa không tự động có nghĩa là bạn đang đi cứu. Đang hack là bằng chứng mạnh hơn việc chỉ đi theo hướng một pod. Beast ở tầng khác không tự động được coi là đang đuổi.

Đây vẫn là suy luận: hướng đi không cho biết chắc ý định của bạn. File giữ lại quan sát thô, các tình huống chồng nhau và mức độ chắc chắn để phân tích lại, thay vì coi nhãn dự đoán là sự thật. Nhận diện cập nhật tối đa 2 lần/giây. Các ngưỡng là quy tắc quan sát tham khảo, không phải logic AutoHide/AutoHelp của D.

Nếu muốn giải thích một quyết định khó hiểu, nhập ngắn vào ô ghi chú rồi bấm **Đánh dấu**, ví dụ: “đi vòng để mở cửa”, “qua cửa sổ tránh beast”. Đây là tùy chọn; không cần dùng để chọn loại tình huống.

## Nhiều map, nhiều lần chơi

- Đổi map hoặc hồi sinh tạo **segment mới** trong cùng file, kèm tên map, mã map của phiên ghi và vị trí xuất phát. Hai lượt cùng tên map vẫn phân biệt được khi đối tượng map thay đổi.
- Nếu game không cung cấp map qua `ReplicatedStorage.CurrentMap` hoặc `Workspace.CurrentMap`, file ghi **unknown**, không đoán tên map. Có thể đánh dấu tên map bằng ghi chú.
- Bấm **Dừng / Tiếp tục** để ngừng rồi ghi tiếp vào cùng phiên. Dữ liệu trước đó được giữ lại.
- Mỗi phiên tối đa **6.000 mẫu chuyển động** (khoảng 10 phút có nhân vật), **4 MiB** hoặc **20.000 dòng**, tùy giới hạn nào đến trước. Đầy sẽ tự dừng; sau đó xuất file.
- Muốn bắt đầu file mới: xuất file trước rồi bấm **Phiên mới** hai lần trong 4 giây. Thao tác này xóa bộ đệm hiện tại.
- Bấm dấu **− / +** để thu gọn/mở bảng, kéo thanh tiêu đề để đổi chỗ. Chạy lại script đang mở sẽ giữ nguyên phiên ghi.
- Xuất lại sau khi tiếp tục sẽ cập nhật file cùng tên với toàn bộ dữ liệu của phiên. Chuyển server hoặc đóng Roblox làm mất phần chưa xuất.

Không cần đi cùng một tuyến nhiều lần. Những đoạn bạn tìm cầu thang lên tầng khác, đổi đường khi bị chắn, mở cửa vào phòng pod, nhảy qua cửa sổ, bị kẹt rồi tự thoát, hoặc quyết định bỏ chạy đều hữu ích. Chơi bình thường là đủ; dữ liệu này để tham khảo cách xử lý các biến và tình huống khác nhau.

## Những gì được ghi

- Tối đa 10 mẫu/giây: vị trí, hướng nhìn/hướng chạy, vận tốc, trạng thái Humanoid, thông số nhảy/tốc độ đọc từ game, trạng thái tương tác có sẵn và mục tiêu tương tác.
- Yêu cầu nhảy và chuyển trạng thái được ghi riêng theo thời gian. Một yêu cầu nhảy **không chứng minh** game đã thực hiện double jump. Tăng vận tốc khi trên không cũng có thể do thang máy, bệ di chuyển hoặc lực khác.
- Bối cảnh tối đa 2 lần/giây: chín tia dò ngắn quanh người, mặt đất phía trước, vật thể tương tác gần đó và các người chơi trong 65 studs bằng mã vô danh trong phiên. Khi thấy Beast trong phạm vi ghi có thêm một tia kiểm tra vật che giữa hai người. Tia dò bỏ qua nhân vật để nhận biết địa hình.
- `scene` ghi giai đoạn: tiếp cận PC, gần PC nhưng chưa hack, đang hack, tiếp cận pod, cứu người, tương tác cửa/exit, né Beast, bị giam hoặc ragdoll. Kèm dấu hiệu vật cản thấp, vật chắn trước/trái/phải/chéo, cửa sổ/cửa/cầu thang/cầu trượt gần đó, mặt dốc, bậc cao phía trước, vực hoặc chưa thấy đất trong tầm dò.
- Lưu chênh độ cao tới mục tiêu, các pod đang có người (tối đa 5), PC gần nhất chưa hoàn thành hoặc chưa rõ trạng thái, hướng camera khi có, quãng tiến ngang và độ cao thay đổi. Nhờ vậy phân biệt được mục tiêu ở tầng trên/dưới và việc bạn chọn đi tới pod khác thay vì pod gần nhất.
- Có ghi sự kiện quay ngược hướng, yêu cầu di chuyển nhưng ít tiến ngang, rồi lúc tiến được trở lại. Đây là **dấu hiệu quan sát**, không kết luận bot lỗi hay bạn bị kẹt thật. Đang hack, giữ tương tác, bị giam hoặc ragdoll không bị coi là đang cố đi nhưng mắc kẹt. Khoảng thời gian dừng ghi không được tính như đang quan sát Beast AFK.
- Khám phá đối tượng tương tác theo từng đợt nhỏ trong map; không quét toàn bộ workspace mỗi khung hình. Trong map lớn, danh sách PC/pod/cửa cần thời gian bổ sung. File có số lượng đã khám phá và còn chờ.
- Không ghi nội dung chat, tên/UserId người chơi, API key hoặc HWID. Chỉ ghi nội dung ô ghi chú khi bạn bấm Đánh dấu.

Phím máy tính chỉ được **quan sát**, không được gửi. Trên điện thoại, hướng di chuyển, vận tốc, yêu cầu nhảy và trạng thái game vẫn được ghi dù không có phím WASD. Trạng thái bò/mở cửa phụ thuộc dữ liệu game cung cấp; dữ liệu không có sẽ không được bịa ra.

Không có lệnh điều khiển, remote interaction, `VirtualInputManager`, `ComputeAsync`, `Blockcast` hay gửi dữ liệu qua mạng trong bộ ghi. Chỉ nút Xuất file mới gọi API lưu file cục bộ của executor. Điều này tách bộ ghi khỏi các khâu tự di chuyển đang được điều tra lỗi crash; chưa phải cam kết đã kiểm thử thực tế trên Delta/Android.

## Định dạng và kiểm tra

File là UTF-8 **JSON Lines**: một đối tượng JSON trên mỗi dòng. `schema = ftf-movement-observation`, `version = 1`, `inference_version = 1`.

| `k` | Nội dung |
| --- | --- |
| `header` | Phiên bản, giới hạn, tần suất, thời gian UTC, mục đích tham khảo. |
| `segment` | Map, nguồn nhận diện map, segment và vị trí spawn. |
| `entity` | Từ điển đối tượng địa hình/tương tác, kích thước, hướng và mã tham chiếu. |
| `frame` | Chuyển động và trạng thái game tại `t` mili giây từ lúc bắt đầu. |
| `context` | Tia dò, đối tượng gần, mục tiêu cứu/PC, góc nhìn khi có, người chơi vô danh, `inference` và `scene`. |
| `event` | Chuyển trạng thái, yêu cầu nhảy, suy luận đổi tình huống, ghi chú, tạm dừng nhân vật/hồi sinh. |
| `stop` | Lý do dừng và tổng mẫu; đây không phải kết thúc trận. |

Các bản ghi quan sát có `for_mode`; `general` là chưa đủ cơ sở phân loại hoặc không thuộc ba tình huống. `context.inference` chứa `primary`, `candidates`, `scores`, `confidence`, `reasons`, `tags`. Điểm là trọng số quy tắc, **không phải xác suất thống kê**. Vị trí dùng studs, làm tròn 0,01. Mã entity/person chỉ có ý nghĩa trong file/phiên này. Một mẫu mới sau khi bị khựng không tạo hàng loạt mẫu bù.

Kiểm tra không cần Roblox, dùng Luau CLI:

```sh
luau-compile movement-recorder.luau
python3 tests/run-movement-recorder.py /path/to/luau
```

Fixture chạy toàn bộ script với API quan sát giả lập: nhiều map, hồi sinh, nhảy, tương tác, tự nhận diện và tình huống chồng nhau, bảo toàn dữ liệu khi xuất/lưu lỗi, chia trang, giới hạn bộ đệm. Python đọc lại JSONL độc lập. Các kiểm tra này không thay thế chạy thử trên thiết bị thật.
