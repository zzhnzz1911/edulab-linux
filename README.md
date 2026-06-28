# EduLab Linux

Bộ script tùy biến Linux Mint/Xubuntu Xfce thành giao diện Windows 10-like.

Script chạy trên user Linux hiện tại, thường là user admin đang dùng `sudo`.

## Có Gì

- Taskbar đen phía dưới, nút Start, ô `Ask me anything`.
- Start menu custom giống Windows 10, có tìm kiếm app và tile ghim.
- Desktop có Trash, Browser, File Explorer, Settings.
- Bộ gõ US/Vietnamese, đổi bằng `Super+Space`, có nút `ENG`.
- Quick settings góc phải cho pin, âm thanh, Wi-Fi/Bluetooth, độ sáng.
- Theme, icon và wallpaper Windows 10-like.

## Yêu Cầu

- Linux Mint Xfce 64-bit hoặc Xubuntu 64-bit.
- Máy có Internet khi cài.
- User hiện tại có quyền `sudo`.

## Cài Đặt

Mở Terminal và chạy:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/zzhnzz1911/edulab-linux.git ~/edulab-linux
cd ~/edulab-linux
sudo bash scripts/install-edulab.sh --browser chrome
bash scripts/apply-desktop-style.sh
xfce4-panel -r
```

Sau khi cài xong, nếu giao diện chưa đổi hết thì đăng xuất rồi đăng nhập lại.

## Cập Nhật

```bash
cd ~/edulab-linux
git fetch origin
git reset --hard origin/main
sudo bash scripts/install-edulab.sh --browser chrome
bash scripts/apply-desktop-style.sh
xfce4-panel -r
```

## Gỡ Cài Đặt

```bash
cd ~/edulab-linux
sudo bash scripts/uninstall-edulab.sh --target-user "$USER"
```

Lệnh gỡ chỉ xóa cấu hình, shortcut, helper, theme/icon/wallpaper và policy do EduLab tạo. Không xóa `Documents`, `Downloads`, Desktop cá nhân hoặc dữ liệu user.

Nếu muốn gỡ luôn app đã cài theo trạng thái EduLab:

```bash
cd ~/edulab-linux
sudo bash scripts/uninstall-edulab.sh --target-user "$USER" --remove-apps
```

## Ghi Chú

- Có thể đổi trình duyệt bằng `--browser chromium`, `--browser edge --allow-microsoft-edge`, hoặc `--browser none`.
- Không muốn cài ONLYOFFICE thì thêm `--no-onlyoffice`.
- Âm lượng chỉnh qua `pactl` hoặc `amixer`.
- Độ sáng chỉnh qua `brightnessctl` hoặc `xbacklight`; trong VirtualBox có thể không chỉnh được nếu VM không có backlight device.
- Log cài đặt nằm ở `/var/log/edulab-install.log`.
