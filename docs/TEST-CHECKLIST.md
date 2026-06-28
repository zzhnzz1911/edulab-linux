# Checklist kiểm thử phòng máy EduLab Linux

Checklist này dùng cho VM master, máy clone thử và lô máy thật trước khi bàn giao.

## 1. Kiểm thử cài đặt nền

- [ ] ISO đúng phiên bản LTS, 64-bit.
- [ ] Máy boot ổn định sau cài đặt và sau `sudo apt upgrade -y`.
- [ ] Tài khoản quản trị riêng tồn tại, ví dụ `adminlab`.
- [ ] Tài khoản học sinh `student` đăng nhập được.
- [ ] Tài khoản học sinh không thuộc nhóm `sudo` hoặc `admin`.
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
- [ ] Không có shortcut, wallpaper hoặc icon tự tạo mang nhận diện Microsoft.

## 3. Kiểm thử Desktop học sinh

- [ ] Đăng nhập tài khoản học sinh lần đầu không hiện lỗi.
- [ ] Desktop có shortcut ONLYOFFICE.
- [ ] Desktop có shortcut Trình duyệt.
- [ ] Desktop có shortcut Bài tập.
- [ ] Nếu có cấu hình `--lms-url`, Desktop có shortcut LMS.
- [ ] Shortcut ONLYOFFICE mở được ứng dụng.
- [ ] Shortcut Trình duyệt mở đúng trình duyệt đã chọn.
- [ ] Shortcut Bài tập mở đúng thư mục `~/Bai-tap`.
- [ ] Nếu có cấu hình `--lms-url`, shortcut LMS mở đúng URL của trường.
- [ ] Theme/icon hiển thị rõ, không mô phỏng Windows hoặc Office.

## 4. Kiểm thử tiếng Việt

- [ ] `ibus-unikey` đã cài.
- [ ] Có thể chọn bộ gõ Vietnamese/Unikey trong Input Method.
- [ ] Gõ được tiếng Việt trong trình duyệt.
- [ ] Gõ được tiếng Việt trong ONLYOFFICE Writer.
- [ ] Gõ được tiếng Việt trong tên file và thư mục.
- [ ] Sau logout/login, bộ gõ vẫn dùng được.

## 5. Kiểm thử ONLYOFFICE cho bài IC3

- [ ] Mở ONLYOFFICE Desktop Editors từ menu và shortcut.
- [ ] Tạo và lưu file `.docx`.
- [ ] Tạo và lưu file `.xlsx`.
- [ ] Tạo và lưu file `.pptx`.
- [ ] Mở lại file đã lưu trong `~/Bai-tap`.
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
- [ ] Lịch sử shell tài khoản học sinh đã được dọn.
- [ ] File trong `~/Bai-tap`, Desktop, Documents, Downloads không bị xóa.
- [ ] Nếu dùng `--reset-ssh-host-keys`, SSH host keys được tạo lại.
- [ ] Log tồn tại tại `/var/log/edulab-post-clone.log`.

## 8. Kiểm thử hiệu năng máy yếu đến trung bình

- [ ] Login tài khoản học sinh dưới 60 giây trên HDD, dưới 30 giây trên SSD.
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
- [ ] Tài khoản quản trị được bảo mật bằng mật khẩu riêng.
- [ ] Tài khoản học sinh đúng chính sách mật khẩu của trường.
- [ ] Đã ghi nhận phiên bản ISO, ngày tạo image, ngày clone, người thực hiện.
