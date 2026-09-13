# Nộp Draglet lên Unikorn

Mở https://unikorn.vn/products/new với tư cách **tác giả**. Dán các trường dưới đây. Ảnh lấy trong `site/assets/`.

## Trường cơ bản

- **Tên sản phẩm:** Draglet
- **Tagline:** Thả vào đây. Kéo tiếp sau.
- **Website:** https://anhxuanpham.github.io/Draglet/
- **GitHub:** https://github.com/anhxuanpham/Draglet
- **Vai trò:** Sản phẩm của tôi (tác giả)
- **Nền tảng:** macOS
- **Danh mục gợi ý:** Productivity / Utilities
- **Tags gợi ý:** macOS, Finder, menu bar, drag and drop, productivity, file transfer, Swift

## Ảnh

- **Thumbnail / icon:** `site/assets/icon-256.png` hoặc `icon.png`
- **Ảnh demo (theo thứ tự):**
  1. `shelf-one.png` (khay 1 file, Light)
  2. `shelf-many.png` (khay 20 file)
  3. `shelf-dark.png` (khay 100 file, Dark)
  4. `settings.png` (Settings)
  5. `about.png` (About, phiên bản 0.2.0)

## Mô tả (dán nguyên, >500 ký tự)

Draglet là khay tạm trên menu bar macOS. Bạn đang kéo file trong Finder, cửa sổ đích chưa mở, không muốn giữ chuột. Lắc ngang khi đang kéo, hoặc bấm Control-Option-Space, rồi thả vào khay. Đổi cửa sổ, Space, hay app. Kéo file ra đích sau.

Vấn đề nó giải: macOS không giữ hộ một drag khi bạn phải đổi ngữ cảnh. Kéo-thả giữa hai cửa sổ Finder, Desktop, và app khác buộc bạn thả giữa chừng rồi kéo lại. Draglet đứng đúng đoạn giữa đó.

Tính năng chính:

- Lắc khi đang giữ chuột, hoặc phím tắt, để gọi khay cạnh con trỏ.
- Giữ tham chiếu file và thư mục local. Không copy, không đổi tên, không xóa file gốc. App đích mới thực hiện copy hay link.
- Cmd-click, Shift-click, rồi kéo nhóm đã chọn. Drag all kéo cả khay.
- Quick Look bằng Space hoặc double-click. Reveal in Finder từ menu chuột phải.
- Ẩn khay bằng × hoặc Escape, hàng vẫn còn. Clear All nằm trong menu. Undo hoàn tác mục gỡ tay, không hoàn tác thao tác của app đích.
- Nhiều khay có tên. Kéo text, URL, PNG/TIFF. Thư mục yêu thích mở Finder. Lưu phiên sau khi thoát là tùy chọn, mặc định tắt.

Đối tượng: người dùng macOS hay chuyển file giữa Finder và các cửa sổ app, không cần cloud clipboard hay file manager mới.

Bắt đầu: cần macOS 14 trở lên. Tải DMG universal (Intel và Apple Silicon) từ trang sản phẩm, kéo Draglet vào Applications. Bản 0.2.0 ký ad-hoc, chưa notarize. Lần đầu mở: chuột phải app, chọn Open. Biểu tượng khay hiện trên menu bar.

Khác gì Yoink hay Dropover: Draglet không có tài khoản, không upload, không theo dõi clipboard. Mã nguồn GPL-3.0. Gọi khay bằng lắc khi đang kéo, giữ focus app nguồn. Khay là AppKit native, không phải overlay tài khoản.

## Tránh khai trên Unikorn

- Không nói đã notarize hay có trên App Store.
- Không bịa số user, rating, hay thời gian tiết kiệm.
- Không hứa Windows hay iOS.
