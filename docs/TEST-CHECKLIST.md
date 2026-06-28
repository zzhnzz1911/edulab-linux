# Checklist kiểm thử phòng máy EduLab Linux

Checklist này dùng cho VM master, máy clone thử và lô máy thật trước khi bàn giao.

## 1. Kiểm thử cài đặt nền

- [ ] ISO đúng phiên bản LTS, 64-bit.
- [ ] Máy boot ổn định sau cài đặt và sau `sudo apt upgrade -y`.
- [ ] Tài khoản hiện tại/admin đăng nhập được.
- [ ] Tài khoản hiện tại/admin có quyền `sudo` để chạy bộ cài.
- [ ] Timezone, ngày giờ, NTP đúng với địa phương.
- [ ] Mạng LAN/Wi-Fi hoạt động.
- [ ] Âm thanh, màn hình, bàn phím, chuột hoạt động.

## 2. Kiểm thử script install

- [ ] `bash scripts/install-edulab.sh --dry-run ...` chạy không báo lỗi cấu hình.
- [ ] `sudo bash scripts/install-edulab.sh ...` chạy xong không lỗi.
- [ ] Log tồn tại tại `/var/log/edulab-install.log`.
- [ ] Repository ONLYOFFICE được thêm bằng `signed-by=/usr/share/keyrings/onlyoffice.gpg`.
- [ ] Repository Chrome được thêm bằng `signed-by=/usr/share/keyrings/google-linux.gpg` nếu chọn Chrome.
- [ ] Không cài `ttf-mscorefonts-installer`.
- [ ] Theme/icon Windows 10 tải được từ GitHub hoặc có cảnh báo fallback rõ ràng trong log.
- [ ] Wallpaper `windows-10-blue-gradient.jpg` được cài vào `/usr/share/backgrounds/edulab/`.

## 3. Kiểm thử Desktop user hiện tại

- [ ] Đăng nhập lại tài khoản hiện tại/admin sau khi cài không hiện lỗi.
- [ ] Desktop có shortcut ONLYOFFICE.
- [ ] Desktop có shortcut Trình duyệt.
- [ ] Desktop có shortcut File Explorer.
- [ ] Desktop có shortcut Settings.
- [ ] Desktop không còn shortcut Bài tập.
- [ ] Desktop có icon Trash/Thùng rác.
- [ ] Nếu có cấu hình `--lms-url`, Desktop có shortcut LMS.
- [ ] Shortcut ONLYOFFICE mở được ứng dụng.
- [ ] Shortcut Trình duyệt mở đúng trình duyệt đã chọn.
- [ ] Shortcut File Explorer mở thư mục cá nhân trong file manager.
- [ ] Shortcut Settings mở trung tâm cài đặt hệ thống.
- [ ] Nếu có cấu hình `--lms-url`, shortcut LMS mở đúng URL của trường.
- [ ] Taskbar nằm dưới, nút Start bên trái, ô `Ask me anything` nhập được nằm trực tiếp trên taskbar, File Explorer/trình duyệt được ghim, app icon-only, tray/power/network/volume/ENG/clock/notification bên phải.
- [ ] Gõ trong ô `Ask me anything` trên taskbar thì app list lọc ngay trong hộp Start; nhấn Enter mở được kết quả đầu tiên.
- [ ] Nút Start hoặc phím Super mở menu tối có rail user/settings/power, app list và tile ghim.
- [ ] Nút 3 gạch trong Start bung/thu rail bên trái và hiện chữ User/Settings/Power.
- [ ] Desktop shortcut không hiện cảnh báo "Untrusted application launcher" khi mở.
- [ ] Theme GTK/Xfwm và icon theme đang là `Windows 10`.
- [ ] Wallpaper hiển thị đúng hình gradient xanh Windows 10-like.

## 4. Kiểm thử tiếng Việt

- [ ] `ibus-unikey` đã cài.
- [ ] Có thể đổi US/Vietnamese bằng `Super+Space`.
- [ ] Taskbar hiện nút `ENG` thay vì icon cờ keyboard layout.
- [ ] Bấm `ENG` mở menu bộ gõ ở góc phải phía trên taskbar; bấm `ENG` lần nữa hoặc click ra ngoài thì menu đóng.
- [ ] Gõ được tiếng Việt trong trình duyệt.
- [ ] Gõ được tiếng Việt trong ONLYOFFICE Writer.
- [ ] Gõ được tiếng Việt trong tên file và thư mục.
- [ ] Sau logout/login, bộ gõ vẫn dùng được.

## 5. Kiểm thử ONLYOFFICE cho bài IC3

- [ ] Mở ONLYOFFICE Desktop Editors từ menu và shortcut.
- [ ] Tạo và lưu file `.docx`.
- [ ] Tạo và lưu file `.xlsx`.
- [ ] Tạo và lưu file `.pptx`.
- [ ] Mở lại file đã lưu trong thư mục tài liệu người dùng.
- [ ] Gõ tiếng Việt, định dạng font, bảng biểu, hình ảnh hoạt động.
- [ ] Export PDF hoạt động nếu bài học yêu cầu.
- [ ] Không hiển thị lỗi font nghiêm trọng khi mở tài liệu mẫu.

## 6. Kiểm thử trình duyệt và LMS nếu có

- [ ] Nếu có LMS, trình duyệt mở được LMS.
- [ ] Nếu có LMS, đăng nhập được bằng tài khoản test.
- [ ] Upload/download file bài tập hoạt động.
- [ ] In hoặc lưu PDF từ trình duyệt hoạt động nếu trường yêu cầu.
- [ ] Nếu có cấu hình `--lms-url`, chính sách trang khởi động LMS hoạt động với Chrome/Chromium.

## 7. Kiểm thử post-clone

- [ ] Clone VM master sang VM thử.
- [ ] Chạy dry-run:

```bash
sudo bash scripts/post-clone.sh --hostname IC3-TEST-01 --dry-run
```

- [ ] Chạy thật:

```bash
sudo bash scripts/post-clone.sh --hostname IC3-TEST-01
sudo reboot
```

- [ ] Sau reboot, `hostnamectl` hiển thị hostname mới.
- [ ] `/etc/machine-id` khác với máy master.
- [ ] Cache apt đã được dọn.
- [ ] Lịch sử shell tài khoản hiện tại/admin đã được dọn nếu quy trình clone yêu cầu.
- [ ] File trong Desktop, Documents, Downloads không bị xóa.
- [ ] Nếu dùng `--reset-ssh-host-keys`, SSH host keys được tạo lại.
- [ ] Log tồn tại tại `/var/log/edulab-post-clone.log`.

## 8. Kiểm thử hiệu năng máy yếu đến trung bình

- [ ] Login tài khoản hiện tại/admin dưới 60 giây trên HDD, dưới 30 giây trên SSD.
- [ ] Mở trình duyệt + ONLYOFFICE đồng thời vẫn dùng được.
- [ ] RAM idle sau login hợp lý với cấu hình máy.
- [ ] Không có dịch vụ nền lạ hoặc phần mềm không dùng đến.
- [ ] Máy không nóng hoặc treo khi mở file bài mẫu.

## 9. Kiểm thử bàn giao lô máy

- [ ] Mỗi máy có hostname duy nhất.
- [ ] Mỗi máy có machine-id duy nhất.
- [ ] Mạng nội bộ không báo trùng hostname/IP.
- [ ] Nếu có LMS, tất cả máy vào LMS được.
- [ ] Tất cả máy mở file mẫu IC3 được.
- [ ] Tài khoản hiện tại/admin được bảo mật bằng mật khẩu riêng.
- [ ] Đã ghi nhận phiên bản ISO, ngày tạo image, ngày clone, người thực hiện.
