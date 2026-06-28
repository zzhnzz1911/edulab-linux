#!/usr/bin/env bash
# Chuẩn bị quyền chạy cho file cài một-cú-click.
# Dùng sau khi copy project sang máy Linux, đặc biệt khi copy từ Windows/USB/Shared Folder.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

die() {
  echo "LỖI: $*" >&2
  exit 1
}

LAUNCHER="$PROJECT_DIR/Install-EduLab.desktop"
UNINSTALL_LAUNCHER="$PROJECT_DIR/Uninstall-EduLab.desktop"

[[ -f "$LAUNCHER" ]] || die "Không tìm thấy file launcher Install-EduLab.desktop."
[[ -f "$UNINSTALL_LAUNCHER" ]] || die "Không tìm thấy file launcher Uninstall-EduLab.desktop."

echo "Đang cấp quyền chạy cho script EduLab..."
chmod 0755 "$PROJECT_DIR"/scripts/*.sh

chmod 0755 "$LAUNCHER"
chmod 0755 "$UNINSTALL_LAUNCHER"

# Một số desktop như GNOME/Nemo cần đánh dấu launcher là đáng tin cậy.
# Nếu hệ thống không có gio thì bỏ qua, không làm hỏng gì.
if command -v gio >/dev/null 2>&1; then
  gio set "$LAUNCHER" metadata::trusted true 2>/dev/null || true
  gio set "$UNINSTALL_LAUNCHER" metadata::trusted true 2>/dev/null || true
fi

DESKTOP_DIR=""
if command -v xdg-user-dir >/dev/null 2>&1; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
fi
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"

if [[ -d "$DESKTOP_DIR" ]]; then
  DESKTOP_COPY="$DESKTOP_DIR/Install-EduLab.desktop"
  cp "$LAUNCHER" "$DESKTOP_COPY"
  chmod 0755 "$DESKTOP_COPY"
  if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_COPY" metadata::trusted true 2>/dev/null || true
  fi
  echo "Đã copy launcher ra Desktop: $DESKTOP_COPY"

  UNINSTALL_DESKTOP_COPY="$DESKTOP_DIR/Uninstall-EduLab.desktop"
  cp "$UNINSTALL_LAUNCHER" "$UNINSTALL_DESKTOP_COPY"
  chmod 0755 "$UNINSTALL_DESKTOP_COPY"
  if command -v gio >/dev/null 2>&1; then
    gio set "$UNINSTALL_DESKTOP_COPY" metadata::trusted true 2>/dev/null || true
  fi
  echo "Đã copy launcher gỡ ra Desktop: $UNINSTALL_DESKTOP_COPY"
fi

echo "Xong. Bây giờ có thể double-click file Install-EduLab.desktop hoặc Uninstall-EduLab.desktop."
