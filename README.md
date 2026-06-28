# EduLab Linux

Dự án này tạo bộ cài nhanh cho máy Linux desktop thay thế Windows trong môi trường học tập IC3. Mục tiêu là giao diện quen thuộc, dễ dùng, có phần mềm văn phòng và bộ gõ tiếng Việt, nhưng không dùng logo, icon, wallpaper hoặc nhận diện thương hiệu Microsoft.

## Nền tảng khuyến nghị

Khuyến nghị mặc định: **Linux Mint Xfce LTS 64-bit**.

Lý do:

- Nhẹ, hợp máy trường học yếu đến trung bình.
- Giao diện menu + taskbar quen với người dùng Windows.
- Dựa trên Ubuntu LTS, dễ bảo trì bằng `apt`.

Xubuntu LTS cũng phù hợp. Kubuntu LTS đẹp hơn nhưng nên dùng cho máy RAM 8 GB trở lên.

## Cấu trúc

```text
.
├── Install-EduLab.desktop
├── Uninstall-EduLab.desktop
├── README.md
├── assets
│   ├── edulab-familiar-wallpaper.svg
│   └── win11-experimental-wallpaper.svg
├── docs
│   ├── BRAND-COMPLIANCE.md
│   └── TEST-CHECKLIST.md
└── scripts
    ├── apply-desktop-style.sh
    ├── build-installer-package.sh
    ├── edulab-oneclick-installer.sh
    ├── edulab-oneclick-uninstaller.sh
    ├── install-edulab.sh
    ├── install-win11-look-experimental.sh
    ├── post-clone.sh
    ├── prepare-oneclick-launcher.sh
    └── uninstall-edulab.sh
```

## Cách dùng chính

Mặc định có **hai file để bấm**:

```text
Install-EduLab.desktop
Uninstall-EduLab.desktop
```

Khi bấm file này, EduLab sẽ cài cho **tài khoản Linux hiện tại** trên **một máy**:

- Không tạo user học sinh.
- Không hỏi LMS.
- Không tạo shortcut LMS.
- Cài giao diện EduLab, wallpaper, font, bộ gõ tiếng Việt.
- Cài ONLYOFFICE Desktop Editors.
- Cài Chrome mặc định.
- Tạo shortcut ONLYOFFICE, Trình duyệt và Bài tập.

Trình cài sẽ hỏi bạn có chấp nhận cài đặt không. Nếu đồng ý, hệ thống sẽ hỏi mật khẩu admin/sudo của máy Linux trước khi cài.

LMS và user học sinh vẫn hỗ trợ bằng dòng lệnh nâng cao, nhưng không bật trong launcher mặc định.

## Cài từ link Git

Trên máy Linux Mint/Xubuntu cần cài, mở Terminal và chạy:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/USER/edulab-linux.git ~/edulab-linux
cd ~/edulab-linux
bash scripts/prepare-oneclick-launcher.sh
```

Đổi `https://github.com/USER/edulab-linux.git` thành link Git thật của bạn.

Sau đó double-click `Install-EduLab.desktop`, hoặc chạy trực tiếp:

```bash
bash scripts/edulab-oneclick-installer.sh
```

## Chuẩn bị launcher trên Linux

Sau khi copy project vào máy Linux, ví dụ `~/edulab-linux`, chạy một lần:

```bash
cd ~/edulab-linux
bash scripts/prepare-oneclick-launcher.sh
```

Sau đó double-click:

```text
Install-EduLab.desktop
```

Nếu trình quản lý file hỏi quyền chạy, chọn **Allow Launching**, **Trust and Launch** hoặc tùy chọn tương đương.

## Gỡ cài đặt

Double-click:

```text
Uninstall-EduLab.desktop
```

Hoặc chạy trong Terminal:

```bash
cd ~/edulab-linux
bash scripts/edulab-oneclick-uninstaller.sh
```

Mặc định script gỡ chỉ xóa helper, shortcut, autostart, wallpaper và policy do EduLab tạo. Script không xóa `~/Documents`, `~/Downloads`, Desktop hoặc thư mục `Bai-tap`.

Nếu cần gỡ thêm app theo trạng thái EduLab đã ghi lại, dùng tùy chọn nâng cao:

```bash
sudo bash scripts/uninstall-edulab.sh --student-user "$USER" --remove-apps
```

## Đóng gói để gửi cho máy khác

Trên máy Linux đang giữ project:

```bash
bash scripts/build-installer-package.sh
```

File tạo ra:

```text
dist/edulab-linux-installer.tar.gz
```

Gửi file `.tar.gz` này cho người dùng. Trên máy nhận:

```bash
mkdir -p ~/edulab-linux
tar -xzf edulab-linux-installer.tar.gz -C ~/edulab-linux
cd ~/edulab-linux
bash scripts/prepare-oneclick-launcher.sh
```

Rồi double-click `Install-EduLab.desktop`.

## Kiểm tra script

Trong Linux Mint/Xubuntu:

```bash
bash -n scripts/install-edulab.sh
bash -n scripts/post-clone.sh
bash -n scripts/apply-desktop-style.sh
bash -n scripts/install-win11-look-experimental.sh
bash -n scripts/edulab-oneclick-installer.sh
bash -n scripts/edulab-oneclick-uninstaller.sh
bash -n scripts/prepare-oneclick-launcher.sh
bash -n scripts/build-installer-package.sh
bash -n scripts/uninstall-edulab.sh
```

## Dùng dòng lệnh nâng cao

Cài cho user hiện tại, không LMS:

```bash
sudo bash scripts/install-edulab.sh \
  --student-user "$USER" \
  --student-fullname "$USER" \
  --browser chrome
```

Cài kiểu phòng máy, tạo/cấu hình user học sinh và LMS:

```bash
sudo bash scripts/install-edulab.sh \
  --student-user student \
  --student-password 'Student@123' \
  --lms-url 'https://lms.example.edu.vn' \
  --browser chrome
```

`Student@123` chỉ là mật khẩu test. Khi triển khai thật, đổi theo chính sách khách hàng.

Gỡ cấu hình EduLab cho user hiện tại:

```bash
sudo bash scripts/uninstall-edulab.sh --student-user "$USER"
```

## Đẩy project lên GitHub

Trên máy đã có Git, tạo repository rỗng trên GitHub rồi chạy trong thư mục project:

```bash
git init
git add .
git commit -m "Prepare EduLab installer for Git distribution"
git branch -M main
git remote add origin https://github.com/USER/edulab-linux.git
git push -u origin main
```

Các thư mục nặng như `downloads`, `tools`, `vms` và `dist` đã được đưa vào `.gitignore`, không nên đẩy lên Git.

## Cài offline

Gói hiện tại chưa phải bản offline hoàn toàn. Phần mềm như ONLYOFFICE, Chrome, theme/icon/font được tải từ repository chính thức khi chạy cài đặt.

Nếu cần cài không Internet, cần làm thêm bản offline gồm các gói `.deb` và local apt repo.

## Post-clone

Chỉ dùng khi triển khai phòng máy bằng clone image:

```bash
cd ~/edulab-linux
sudo bash scripts/post-clone.sh --hostname IC3-LAB-01
sudo reboot
```

Nếu máy có SSH server và cần host key riêng:

```bash
sudo bash scripts/post-clone.sh --hostname IC3-LAB-01 --reset-ssh-host-keys
sudo reboot
```

## Tuân thủ thương hiệu

- Không dùng logo, icon, wallpaper, font hoặc tên gọi thương hiệu Microsoft trong bản mặc định.
- Không dùng crack, KMS, key lậu hoặc phần mềm không rõ license.
- Script `install-win11-look-experimental.sh` chỉ để thử nghiệm trong lab/VM, không bật mặc định trong bản bàn giao.

Xem thêm: `docs/BRAND-COMPLIANCE.md` và `docs/TEST-CHECKLIST.md`.
