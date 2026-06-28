# EduLab Linux

Bộ cài nhanh cho máy Linux desktop dùng trong môi trường học tập IC3.

Khuyến nghị dùng **Linux Mint Xfce 64-bit** hoặc **Xubuntu 64-bit**. Máy cần có Internet khi cài.

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

- Mã EduLab do người cung cấp bộ cài gửi.
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

Trình gỡ chỉ gỡ cấu hình/shortcut EduLab, không xóa `Documents`, `Downloads`, Desktop hoặc thư mục `Bai-tap`.

## Ghi chú

- Nếu file `.desktop` hỏi quyền chạy, chọn **Allow Launching**, **Trust and Launch** hoặc tùy chọn tương đương.
- Nếu cài xong giao diện chưa đổi ngay, hãy đăng xuất rồi đăng nhập lại.
- EduLab không dùng logo, icon, wallpaper hoặc tài sản thương hiệu Microsoft trong bản mặc định.
