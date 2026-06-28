# EduLab Linux

Bộ cài nhanh cho máy Linux desktop dùng trong môi trường học tập IC3.

Khuyến nghị dùng **Linux Mint Xfce 64-bit** hoặc **Xubuntu 64-bit**. Máy cần có Internet khi cài.

Giao diện mặc định dùng một kiểu duy nhất: **EduLab Windows 10-like Desktop**. Bố cục ưu tiên giống Windows 10 nhất có thể trên Linux Mint/Xubuntu Xfce: taskbar dưới màu đen, nút Start bên trái, File Explorer và trình duyệt được ghim trên taskbar, app icon-only, tray/clock bên phải, icon Trash trên Desktop, shortcut File Explorer/Settings và LMS nếu có cấu hình.

Bộ cài dùng theme GTK/Xfwm và icon Windows 10 từ B00merang, kèm wallpaper `assets/windows-10-blue-gradient.jpg` lấy từ file bạn đặt trong `downloads/`. Khi triển khai thương mại hoặc bàn giao cho khách hàng, hãy kiểm tra license/nhận diện thương hiệu theo chính sách của bạn.

Bộ cài không tạo thêm user `student`. Mặc định script cấu hình trực tiếp tài khoản Linux hiện tại, thường là user admin đang chạy `sudo`.

## Cài đặt

Mở Terminal trên máy Linux và chạy:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/zzhnzz1911/edulab-linux.git ~/edulab-linux
cd ~/edulab-linux
bash scripts/prepare-oneclick-launcher.sh
```

Sau đó mở Desktop và double-click:

```text
Install-EduLab.desktop
```

Khi cài, chương trình có thể hỏi:

- Mã EduLab nếu bạn đã tự tạo `.edulab-installer-password.sha256` cho bản cài riêng.
- Xác nhận có muốn cài đặt không.
- Mật khẩu admin/sudo của máy Linux.

## Gỡ cài đặt

Double-click:

```text
Uninstall-EduLab.desktop
```

Hoặc chạy:

```bash
cd ~/edulab-linux
bash scripts/edulab-oneclick-uninstaller.sh
```

Trình gỡ chỉ gỡ cấu hình/shortcut EduLab, không xóa `Documents`, `Downloads` hoặc Desktop.

## Ghi chú

- Nếu file `.desktop` hỏi quyền chạy, chọn **Allow Launching**, **Trust and Launch** hoặc tùy chọn tương đương.
- Nếu cài xong giao diện chưa đổi ngay, hãy đăng xuất rồi đăng nhập lại. Có thể chạy lại `bash scripts/apply-desktop-style.sh` để áp lại giao diện.
- Theme/icon Windows 10 được tải lúc cài từ GitHub. Máy cần có Internet trong lần cài đầu.
- Nếu muốn chạy thử bằng Terminal thay vì double-click, dùng `sudo bash scripts/install-edulab.sh --browser chrome` trong thư mục project.
