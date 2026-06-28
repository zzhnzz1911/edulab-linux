# EduLab Linux

Bộ cài nhanh để biến Linux Mint/Xubuntu Xfce thành giao diện gần giống Windows 10 cho phòng máy học tập.

Script cài trực tiếp lên user Linux hiện tại, thường là user admin đang chạy `sudo`. Dự án không tạo user `student`, không tạo thư mục bài tập, và không xóa dữ liệu cá nhân.

## Tính năng chính

- Giao diện Windows 10-like trên Xfce: taskbar đen phía dưới, nút Start, ô `Ask me anything`, app icon-only, tray góc phải.
- Start menu custom có danh sách app, ô tìm kiếm, tile ghim, click ra ngoài hoặc bấm Start lần nữa để đóng.
- Desktop có Trash, shortcut Browser, File Explorer, Settings, ONLYOFFICE nếu cài.
- Bộ gõ US/Vietnamese, đổi bằng `Super+Space`, có nút `ENG` trên taskbar.
- Quick settings góc phải kiểu Windows: pin, âm lượng, Wi-Fi/Bluetooth, brightness, settings.
- Theme GTK/Xfwm, icon và wallpaper Windows 10-like.

## Yêu cầu

Khuyến nghị:

- Linux Mint Xfce 64-bit hoặc Xubuntu 64-bit.
- Có Internet trong lần cài đầu.
- User hiện tại có quyền `sudo`.

Các môi trường desktop khác có thể chạy một phần, nhưng giao diện giống Windows 10 nhất là trên Xfce.

## Cài Đặt Nhanh

Mở Terminal trên máy Linux:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/zzhnzz1911/edulab-linux.git ~/edulab-linux
cd ~/edulab-linux
bash scripts/prepare-oneclick-launcher.sh
```

Sau đó double-click file trên Desktop:

```text
Install-EduLab.desktop
```

Nếu hệ thống hỏi quyền chạy file `.desktop`, chọn **Allow Launching**, **Trust and Launch**, hoặc tùy chọn tương đương.

## Cài Bằng Terminal

Dùng cách này khi test trong VM hoặc muốn thấy log trực tiếp:

```bash
cd ~/edulab-linux
sudo bash scripts/install-edulab.sh --browser chrome
```

Cài xong, đăng xuất/đăng nhập lại. Nếu muốn áp giao diện ngay:

```bash
bash scripts/apply-desktop-style.sh
xfce4-panel -r
```

## Cập Nhật Bản Mới

Khi repo GitHub có bản mới:

```bash
cd ~/edulab-linux
git fetch origin
git reset --hard origin/main
sudo bash scripts/install-edulab.sh --browser chrome
bash scripts/apply-desktop-style.sh
xfce4-panel -r
```

## Tùy Chọn Cài Đặt

```bash
sudo bash scripts/install-edulab.sh [tùy chọn]
```

Tùy chọn thường dùng:

- `--browser chrome`: cài Google Chrome, mặc định.
- `--browser chromium`: cài Chromium từ repo distro nếu có.
- `--browser edge --allow-microsoft-edge`: cài Microsoft Edge.
- `--browser none`: không cài trình duyệt.
- `--no-onlyoffice`: không cài ONLYOFFICE.
- `--lms-url URL`: tạo shortcut/chính sách homepage LMS.
- `--target-user USER`: cài cho một user có sẵn. Bình thường không cần truyền vì script tự lấy user đang gọi `sudo`.
- `--dry-run`: chỉ in thao tác, không thay đổi hệ thống.

Ví dụ:

```bash
sudo bash scripts/install-edulab.sh --browser chrome --no-onlyoffice
sudo bash scripts/install-edulab.sh --browser chrome --lms-url https://example.edu.vn
```

## Gỡ Cài Đặt

Cách dễ nhất:

```text
Uninstall-EduLab.desktop
```

Hoặc chạy bằng Terminal:

```bash
cd ~/edulab-linux
bash scripts/edulab-oneclick-uninstaller.sh
```

Nếu muốn chạy script gỡ trực tiếp:

```bash
cd ~/edulab-linux
sudo bash scripts/uninstall-edulab.sh --target-user "$USER"
```

Mặc định script gỡ chỉ xóa helper, shortcut, autostart, wallpaper, theme/icon EduLab và policy trình duyệt do EduLab tạo. Script không xóa `Documents`, `Downloads`, Desktop cá nhân hoặc dữ liệu user.

Muốn gỡ thêm app đã cài theo trạng thái EduLab:

```bash
cd ~/edulab-linux
sudo bash scripts/uninstall-edulab.sh --target-user "$USER" --remove-apps
```

Dùng cho tự động hóa, không hỏi xác nhận:

```bash
sudo bash scripts/uninstall-edulab.sh --target-user "$USER" --yes
```

## Log Và Sửa Lỗi Nhanh

Log cài đặt:

```bash
cat /var/log/edulab-install.log
```

Log gỡ cài đặt:

```bash
cat /var/log/edulab-uninstall.log
```

Áp lại giao diện nếu taskbar/wallpaper chưa đổi:

```bash
cd ~/edulab-linux
bash scripts/apply-desktop-style.sh
xfce4-panel -r
```

Test quick settings góc phải:

```bash
edulab-open-quick-settings
cat ~/.cache/edulab/quick-settings.log | tail -20
```

Nếu popup bị kẹt:

```bash
pkill -f edulab-quick-settings-menu
edulab-open-quick-settings
```

## Ghi Chú

- Âm lượng trong quick settings chỉnh qua `pactl` hoặc `amixer`.
- Độ sáng chỉnh qua `brightnessctl` hoặc `xbacklight`. Trong VirtualBox có thể không chỉnh được nếu VM không có backlight device.
- Theme/icon Windows 10-like được tải từ GitHub trong lúc cài. Khi dùng thương mại hoặc bàn giao khách hàng, hãy tự kiểm tra license/theme/icon/wallpaper theo chính sách của bạn.
