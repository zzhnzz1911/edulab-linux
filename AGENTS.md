# Hướng dẫn cho Codex trong project EduLab Linux

## Bối cảnh

Đây là project dựng bộ cài Linux desktop cho môi trường học tập IC3.

Mặc định hiện tại:

- Có launcher cài: `Install-EduLab.desktop`.
- Có launcher gỡ: `Uninstall-EduLab.desktop`.
- Launcher cài đầy đủ cho tài khoản Linux hiện tại trên một máy.
- Không tạo user học sinh mặc định.
- Không hỏi LMS mặc định.
- Không tạo shortcut LMS nếu không truyền `--lms-url`.
- Nếu có `.edulab-installer-password.sha256`, launcher cài sẽ hỏi mã cài đặt EduLab trước khi hỏi sudo.

## Quy tắc quan trọng

- Không dùng logo, icon, wallpaper, font hoặc tên gọi thương hiệu Microsoft trong bản mặc định.
- Không dùng crack, KMS, key lậu hoặc phần mềm không rõ license.
- Theme/icon kiểu Windows chỉ nằm trong script experimental, không bật mặc định.
- Script shell cần có comment tiếng Việt, kiểm tra lỗi cơ bản và không xóa dữ liệu nguy hiểm.
- Không xóa `~/Documents`, `~/Downloads`, Desktop người dùng hoặc thư mục `Bai-tap`.
- Ưu tiên thay đổi nhỏ, dễ bảo trì, dễ clone.

## File chính

- `Install-EduLab.desktop`: launcher một-cú-click.
- `Uninstall-EduLab.desktop`: launcher gỡ cấu hình EduLab.
- `scripts/edulab-oneclick-installer.sh`: wrapper mặc định cài cho user hiện tại, không hỏi LMS.
- `scripts/edulab-oneclick-uninstaller.sh`: wrapper gỡ mặc định cho user hiện tại.
- `scripts/install-edulab.sh`: cài phần mềm, font, bộ gõ, theme, shortcut.
- `scripts/uninstall-edulab.sh`: gỡ helper, shortcut, policy và cấu hình EduLab an toàn.
- `scripts/prepare-oneclick-launcher.sh`: cấp quyền chạy và trust launcher sau khi copy project.
- `scripts/set-installer-password.sh`: tạo hash mã cài đặt riêng cho launcher.
- `scripts/build-installer-package.sh`: đóng gói project thành `.tar.gz`, loại `downloads`, `tools`, `vms`.
- `scripts/post-clone.sh`: chạy sau khi clone máy, chỉ dùng cho phòng máy.
- `scripts/apply-desktop-style.sh`: áp giao diện EduLab an toàn, quen Windows.
- `scripts/install-win11-look-experimental.sh`: thử nghiệm giao diện Win11-like trong VM/lab.
- `docs/TEST-CHECKLIST.md`: checklist kiểm thử phòng máy.
- `docs/BRAND-COMPLIANCE.md`: tài liệu tránh tài sản thương hiệu Microsoft.
- `assets/`: wallpaper tự tạo, không copy từ Microsoft.

## Lệnh kiểm tra

Trong Linux Mint/Xubuntu:

```bash
bash -n scripts/install-edulab.sh
bash -n scripts/post-clone.sh
bash -n scripts/apply-desktop-style.sh
bash -n scripts/install-win11-look-experimental.sh
bash -n scripts/edulab-oneclick-installer.sh
bash -n scripts/edulab-oneclick-uninstaller.sh
bash -n scripts/prepare-oneclick-launcher.sh
bash -n scripts/set-installer-password.sh
bash -n scripts/build-installer-package.sh
bash -n scripts/uninstall-edulab.sh
```

Chạy launcher thủ công:

```bash
bash scripts/edulab-oneclick-installer.sh
bash scripts/edulab-oneclick-uninstaller.sh
```

Chạy cài thật cho user hiện tại:

```bash
sudo bash scripts/install-edulab.sh \
  --student-user "$USER" \
  --student-fullname "$USER" \
  --browser chrome
```
