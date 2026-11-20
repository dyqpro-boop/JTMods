# HNMod - iOS Runner Dynamic Library Mod

Mã nguồn dự án dynamic library mod (`HNMod`) hỗ trợ tích hợp nút gửi STK nhanh, nhật ký cuộc gọi giả lập, bỏ qua cảnh báo định vị vị trí, tự động đánh dấu đáp án bài test và chọn giao diện sáng/tối cho ứng dụng J&T Express trên iOS.

---

## 🛠 Cấu Trúc Dự Án

```
swift/
├── Package.swift               # Cấu hình Swift Package Manager (SPM)
├── HNModBootstrap/             # Target C/ObjC bootstrap
│   ├── HNModBootstrap.m
│   └── include/HNModBootstrap.h
├── iOS_Mod/                    # Mã nguồn chính của HNMod (Swift)
│   ├── HNLocationHook.swift    # Bypass cảnh báo yêu cầu bật vị trí GPS
│   ├── HNModManager.swift      # Điểm khởi chạy trung tâm của Mod
│   ├── HNFloatingMenu.swift    # Giao diện menu nổi Floating Button
│   ├── HNBankConfig.swift      # Cấu hình STK & thông tin chuyển khoản
│   ├── HNCompactWorkflow.swift # Luồng gửi STK SMS nhanh & giải mã SĐT
│   ├── HNJTSheetHook.swift     # Hook menu chọn thao tác giao hàng (HN Flash / STK)
│   ├── HNDeliveryDetailHook.swift # Hook chi tiết đơn hàng
│   ├── HNAlertHook.swift       # Hook các hộp thoại alert
│   ├── HNPresentHook.swift     # Hook UIViewController presentation
│   ├── HNQuizHook.swift        # Can thiệp đáp án bài test 5 câu
│   ├── HNURLProtocol.swift     # Intercept & chỉnh sửa API response
│   └── HNCallHistory.swift     # Màn hình giả lập Nhật ký cuộc gọi iOS
└── PATCH_GUIDE.md              # Hướng dẫn chi tiết quy trình patch & đóng gói IPA
```

---

## 📦 Hướng Dẫn Patch & Đóng Gói IPA

Chi tiết từng bước về cách sử dụng bộ công cụ tại `C:\Users\hauvi\Desktop\ipamod\` (`patch.cmd`, `patch_runner.py`, `replace_fonts.py`, `check_macho.py`, `insipa.cmd`, `insipa.ps1`) xem tại:

👉 **[PATCH_GUIDE.md](PATCH_GUIDE.md)**
