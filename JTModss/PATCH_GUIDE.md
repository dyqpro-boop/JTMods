# Hướng Dẫn Quy Trình Patch & Đóng Gói IPA (HNMod)

Tài liệu này hướng dẫn chi tiết quy trình tiêm (inject) `HNMod.framework` vào file nhị phân `Runner` của ứng dụng J&T Express, thay thế phông chữ SFU Futura cho giao diện Flutter/Native, và đóng gói lại thành file `.ipa` cài đặt hoàn chỉnh cho iOS.

---

## 🛠 Thư Mục Công Cụ (`C:\Users\hauvi\Desktop\ipamod\`)

Tất cả công cụ patch và nén IPA được đặt tại thư mục `C:\Users\hauvi\Desktop\ipamod\`:

```
C:\Users\hauvi\Desktop\ipamod\
├── patch.cmd            # Kịch bản CMD chính - tự động chọn phiên bản, patch binary và thay phông chữ
├── patch_runner.py      # Python script tiêm dependency @rpath/HNMod.framework/HNMod vào Runner
├── replace_fonts.py     # Python script thay các tệp Roboto TTF bằng SFU Futura tương ứng độ đậm
├── Tools/
│   └── round_home_menu_icons.py # Bo tròn 9 icon chức năng trang chủ Flutter
├── check_macho.py       # Python script đọc Mach-O 64-bit header & kiểm tra LC_LOAD_DYLIB
├── insipa.cmd           # Kịch bản CMD kích hoạt đóng gói IPA
├── insipa.ps1           # PowerShell script nén Payload thành file .ipa (loại bỏ rác)
├── 290/                 # Thư mục giải nén IPA phiên bản 290
├── 316/                 # Thư mục giải nén IPA phiên bản 316
├── 318/                 # Thư mục giải nén IPA phiên bản 318
└── <phiên_bản_mới>/     # Tự động nhận diện khi tạo thêm thư mục mới (319, 320...)
```

---

## 🔍 Lý Do Cần `replace_fonts.py` Cho Giao Diện App J&T Express

Ứng dụng J&T Express trên iOS được xây dựng bằng **Flutter**. Khác với giao diện iOS Native (dùng `UILabel`), Flutter tự vẽ toàn bộ chữ trên màn hình (Skia/Impeller Canvas) dựa trên các tệp phông chữ **Roboto** được nhúng trực tiếp trong:
1. `Payload/Runner.app/`
2. `Payload/Runner.app/Frameworks/App.framework/flutter_assets/fonts/`

Do đó, script `replace_fonts.py` sẽ ghi đè các tệp `Roboto-*.ttf` có trong app bằng SFU Futura. Script giữ các mức đậm gần tương ứng: Regular → Regular, Medium → Book, SemiBold/Bold → Bold, Black → Heavy, Light/Thin → Light. Những font khác (ví dụ font biểu tượng) không bị thay.

---

## 📋 Quy Trình Thực Hiện Từng Bước

### Bước 1: Chuẩn bị file `HNMod.framework`
1. Build dự án Swift để tạo ra tệp dynamic framework `HNMod.framework`.
2. Chép thư mục `HNMod.framework` vào vị trí sau trong phiên bản tương ứng:
   `C:\Users\hauvi\Desktop\ipamod\<phiên_bản>\Payload\Runner.app\Frameworks\HNMod.framework`

---

### Bước 2: Chạy `patch.cmd` để tiêm `HNMod` & thay phông chữ

1. Double-click vào file `C:\Users\hauvi\Desktop\ipamod\patch.cmd` (hoặc gõ `patch` trong CMD).
2. Nhập số tương ứng với phiên bản muốn patch (ví dụ: gõ `3` cho `318`).
3. Tiến trình tự động chạy qua 4 giai đoạn:
   - **[1/4] Kiểm tra Runner TRƯỚC khi patch**: Kiểm tra cấu trúc Mach-O.
   - **[2/4] Patch Dynamic Library (`HNMod`)**: Chèn `@rpath/HNMod.framework/HNMod` vào `Runner`.
   - **[3/4] Thay thế font SFU Futura cho Flutter UI**: Chạy `replace_fonts.py` ghi đè các tệp Roboto có trong app bằng SFU Futura theo mức đậm tương ứng.
   - **[4/4] Kiểm tra lại `Runner.patched`**: Xác nhận `HNMod` đã có trong `LC_LOAD_DYLIB`.

4. **Xác nhận ghi đè**:
   Gõ `Y` (hoặc `y`) và nhấn `Enter` để ghi đè `Runner.patched` lên `Runner`.

---

### Bước 3: Đóng gói lại file `.ipa` bằng `insipa.cmd`

1. Double-click vào file `C:\Users\hauvi\Desktop\ipamod\insipa.cmd`.
2. Chọn thư mục phiên bản cần đóng gói (ví dụ `318`).
3. Script nén chuẩn `ZipArchive` loại bỏ file rác và tạo tệp `.ipa` hoàn chỉnh (ví dụ: `C:\Users\hauvi\Desktop\ipamod\318\318.ipa`).

### Bo tròn icon chức năng trang chủ

Các icon của giao diện trang chủ Flutter được đóng gói trong `App.framework\flutter_assets\images\menu`. Chạy script sau trên thư mục `images\menu` của bản app đã giải nén, trước khi đóng gói IPA:

```powershell
python C:\Users\hauvi\Documents\GitHub\JTMods\Tools\round_home_menu_icons.py `
  "C:\Users\hauvi\Desktop\ipamod\324\Payload\Runner.app\Frameworks\App.framework\flutter_assets\images\menu" `
  "C:\Users\hauvi\Desktop\ipamod\324\menu-icons-original"
```

Script áp mặt nạ tròn (bán kính 50% khung vuông) cho 9 icon chức năng trên trang chủ và lưu bản gốc vào thư mục backup. Thư mục backup phải mới hoặc rỗng. Thay đổi asset trong app bundle làm chữ ký app không còn hợp lệ; cần đóng gói/ký lại theo quy trình cài đặt đang dùng.

### Chọn giao diện sáng/tối

Trong ứng dụng, mở nút nổi **HN** → **Giao diện** rồi chọn **Theo hệ thống**, **Sáng** hoặc **Tối**. Lựa chọn được lưu trong `UserDefaults` và áp dụng lên các cửa sổ UIKit của ứng dụng.

J&T Express sử dụng Flutter cho giao diện chính. Thiết lập này cập nhật chế độ giao diện iOS mà Flutter có thể nhận; các màn hình Flutter chỉ tự đổi màu nếu ứng dụng hỗ trợ theme theo chế độ hệ thống. Một số màn hình hoặc màu được đặt cố định có thể không đổi. Build lại `HNMod.framework`, patch và ký lại IPA theo quy trình phía trên.
