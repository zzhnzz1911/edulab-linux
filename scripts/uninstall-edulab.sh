#!/usr/bin/env bash
# Gỡ cấu hình EduLab Linux một cách an toàn.
# Script không xóa dữ liệu cá nhân, không xóa Desktop, Documents hoặc Downloads.

set -Eeuo pipefail

PROJECT_NAME="EduLab Linux"
LOG_FILE="/var/log/edulab-uninstall.log"
STATE_FILE="/var/lib/edulab/install-state.env"

TARGET_USER="${SUDO_USER:-${USER:-}}"
REMOVE_APPS=0
YES=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
EduLab Linux - uninstall-edulab.sh

Cách dùng:
  sudo bash scripts/uninstall-edulab.sh [tùy chọn]

Tùy chọn:
  --target-user USER      Tài khoản cần gỡ shortcut/cấu hình EduLab. Mặc định: user gọi sudo
  --remove-apps           Gỡ thêm app đã cài theo trạng thái EduLab nếu xác định được
  --yes                   Không hỏi xác nhận, dùng cho tự động hóa
  --dry-run               Chỉ in thao tác, không thay đổi hệ thống
  -h, --help              Hiển thị trợ giúp

Mặc định script chỉ gỡ helper, shortcut, autostart, wallpaper và policy EduLab.
Script không xóa Documents, Downloads hoặc Desktop.
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  log "LỖI: $*"
  exit 1
}

run() {
  log "+ $*"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$@"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target-user)
        TARGET_USER="${2:-}"
        shift 2
        ;;
      --target-user=*)
        TARGET_USER="${1#*=}"
        shift
        ;;
      --remove-apps)
        REMOVE_APPS=1
        shift
        ;;
      --yes)
        YES=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Không hiểu tùy chọn: $1"
        ;;
    esac
  done
}

setup_logging() {
  if [[ "$DRY_RUN" -eq 0 ]]; then
    install -d -m 0755 "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
}

require_root_for_changes() {
  if [[ "$DRY_RUN" -eq 0 && "${EUID}" -ne 0 ]]; then
    die "Hãy chạy bằng sudo: sudo bash scripts/uninstall-edulab.sh ..."
  fi
}

validate_config() {
  [[ -n "$TARGET_USER" ]] || die "Không xác định được user cần gỡ. Hãy truyền --target-user USER."
  [[ "$TARGET_USER" != "root" ]] || die "Không gỡ cấu hình Desktop cho root. Hãy truyền --target-user USER thật."
  [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || \
    die "Tên tài khoản '$TARGET_USER' không hợp lệ."

  if [[ "$DRY_RUN" -eq 0 ]]; then
    id "$TARGET_USER" >/dev/null 2>&1 || die "Không tìm thấy tài khoản $TARGET_USER."
  fi
}

confirm_action() {
  local answer

  [[ "$YES" -eq 0 ]] || return 0

  echo "Sắp gỡ cấu hình $PROJECT_NAME cho user: $TARGET_USER"
  echo "Không xóa Documents, Downloads hoặc Desktop."
  if [[ "$REMOVE_APPS" -eq 1 ]]; then
    echo "Có bật --remove-apps: script sẽ cố gỡ thêm ứng dụng theo trạng thái EduLab."
  fi
  echo
  read -r -p "Tiếp tục gỡ cài đặt? [y/N]: " answer

  case "${answer,,}" in
    y|yes|c|co|có) ;;
    *) die "Đã hủy gỡ cài đặt." ;;
  esac
}

remove_file() {
  local path="$1"

  if [[ -e "$path" || -L "$path" ]]; then
    run rm -f -- "$path"
  else
    log "Bỏ qua vì không tồn tại: $path"
  fi
}

remove_empty_dir() {
  local path="$1"

  if [[ -d "$path" ]]; then
    log "+ xóa thư mục nếu rỗng: $path"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      rmdir --ignore-fail-on-non-empty -- "$path" 2>/dev/null || true
    fi
  fi
}

desktop_dir_for_user() {
  local user="$1"
  local home="$2"
  local desktop_dir=""

  if [[ "$DRY_RUN" -eq 0 && "$user" != "root" ]]; then
    desktop_dir="$(runuser -u "$user" -- xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi

  if [[ -z "$desktop_dir" || "$desktop_dir" == "$home" ]]; then
    desktop_dir="$home/Desktop"
  fi
  printf '%s\n' "$desktop_dir"
}

user_home() {
  if [[ "$DRY_RUN" -eq 0 ]]; then
    getent passwd "$TARGET_USER" | cut -d: -f6
  else
    printf '/home/%s\n' "$TARGET_USER"
  fi
}

remove_user_shortcuts() {
  local home="$1"
  local desktop_dir="$2"

  log "Gỡ shortcut và autostart EduLab của user $TARGET_USER."
  remove_file "$desktop_dir/ONLYOFFICE.desktop"
  remove_file "$desktop_dir/Trinh-duyet.desktop"
  remove_file "$desktop_dir/File-Explorer.desktop"
  remove_file "$desktop_dir/Settings.desktop"
  remove_file "$desktop_dir/Bai-tap.desktop"
  remove_file "$desktop_dir/LMS.desktop"
  remove_file "$home/.config/autostart/edulab-first-login.desktop"
  remove_file "$home/.config/edulab/first-login.done"
  remove_file "$home/.config/edulab/desktop-style-v4.done"
  remove_file "$home/.config/edulab/desktop-style-v5.done"
  remove_file "$home/.config/edulab/desktop-style-v6.done"
  remove_file "$home/.config/edulab/desktop-style-v7.done"
  remove_file "$home/.config/edulab/desktop-style-v8.done"
  remove_file "$home/.config/edulab/desktop-style-v9.done"
  remove_file "$home/.config/edulab/desktop-style-v10.done"
  remove_file "$home/.config/edulab/desktop-style-v11.done"
  remove_file "$home/.config/edulab/desktop-style-v12.done"
  remove_file "$home/.config/edulab/desktop-style-v13.done"
  remove_file "$home/.config/edulab/desktop-style-v14.done"
  remove_file "$home/.config/edulab/desktop-style-v15.done"
  remove_file "$home/.config/edulab/desktop-style-v16.done"
  remove_file "$home/.config/edulab/desktop-style-v17.done"
  remove_file "$home/.config/edulab/desktop-style-v18.done"
  remove_file "$home/.config/edulab/desktop-style-v19.done"
  remove_file "$home/.config/edulab/desktop-style-v20.done"
  remove_file "$home/.config/edulab/desktop-style-v21.done"
  remove_file "$home/.config/edulab/desktop-style-v22.done"
  remove_file "$home/.config/edulab/desktop-style-v23.done"
  remove_file "$home/.config/autostart/edulab-taskbar-search.desktop"
  remove_file "$home/.config/edulab/icons/input-eng.svg"
  remove_file "$home/.config/edulab/icons/power-win10.svg"
  remove_file "$home/.config/edulab/icons/volume-win10.svg"
  remove_file "$home/.config/edulab/icons/notifications-win10.svg"
  remove_file "$home/.local/share/backgrounds/edulab/windows-10-blue-gradient.jpg"
  remove_file "$home/.themes/EduLab-Windows10/xfce-notify-4.0/gtk.css"
  remove_file "$home/.config/xfce4/panel/verve-101.rc"
  remove_file "$home/.config/xfce4/panel/verve-102.rc"
  remove_file "$home/.config/xfce4/panel/verve-103.rc"
  remove_file "$home/.config/xfce4/panel/verve-104.rc"
  remove_file "$home/.config/xfce4/panel/verve-105.rc"
  remove_file "$home/.config/xfce4/panel/launcher-101/search.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-102/search.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-103/search.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-104/search.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-105/search.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-101/file-explorer.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-102/file-explorer.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-103/file-explorer.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-104/file-explorer.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-105/file-explorer.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-101/start.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-102/start.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-103/start.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-101/browser.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-102/browser.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-103/browser.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-104/browser.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-105/browser.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-107/input-language.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-108/input-language.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-109/input-language.desktop"
  remove_file "$home/.config/xfce4/panel/launcher-110/input-language.desktop"
  local panel_id
  for panel_id in {101..120}; do
    remove_file "$home/.config/xfce4/panel/launcher-$panel_id/power.desktop"
    remove_file "$home/.config/xfce4/panel/launcher-$panel_id/volume.desktop"
    remove_file "$home/.config/xfce4/panel/launcher-$panel_id/notifications.desktop"
    remove_empty_dir "$home/.config/xfce4/panel/launcher-$panel_id"
  done

  remove_empty_dir "$home/.config/edulab"
  remove_empty_dir "$home/.local/share/backgrounds/edulab"
  remove_empty_dir "$home/.config/edulab/icons"
  remove_empty_dir "$home/.themes/EduLab-Windows10/xfce-notify-4.0"
  remove_empty_dir "$home/.themes/EduLab-Windows10"
  remove_empty_dir "$home/.config/xfce4/panel/launcher-101"
  remove_empty_dir "$home/.config/xfce4/panel/launcher-102"
  remove_empty_dir "$home/.config/xfce4/panel/launcher-103"
  remove_empty_dir "$home/.config/xfce4/panel/launcher-104"
  remove_empty_dir "$home/.config/xfce4/panel/launcher-105"
}

remove_system_helpers() {
  log "Gỡ helper và cấu hình hệ thống của EduLab."
  remove_file "/usr/local/bin/edulab-first-login.sh"
  remove_file "/usr/local/bin/edulab-open-exercises"
  remove_file "/usr/local/bin/edulab-open-lms"
  remove_file "/usr/local/bin/edulab-open-settings"
  remove_file "/usr/local/bin/edulab-open-files"
  remove_file "/usr/local/bin/edulab-browser"
  remove_file "/usr/local/bin/edulab-language-indicator"
  remove_file "/usr/local/bin/edulab-apply-desktop-style"
  remove_file "/usr/local/bin/edulab-start-menu"
  remove_file "/usr/local/bin/edulab-input-menu"
  remove_file "/usr/local/bin/edulab-quick-settings-menu"
  remove_file "/usr/local/bin/edulab-volume-menu"
  remove_file "/usr/local/bin/edulab-notification-menu"
  remove_file "/usr/local/bin/edulab-search"
  remove_file "/etc/profile.d/edulab-input-method.sh"
  remove_file "/usr/share/backgrounds/edulab/windows-10-blue-gradient.jpg"

  remove_empty_dir "/usr/share/backgrounds/edulab"

  if [[ -d "/usr/share/themes/Windows 10" ]]; then
    run rm -rf -- "/usr/share/themes/Windows 10"
  fi
  if [[ -d "/usr/share/icons/Windows 10" ]]; then
    run rm -rf -- "/usr/share/icons/Windows 10"
  fi
}

remove_browser_policies() {
  log "Gỡ policy trình duyệt do EduLab tạo."
  remove_file "/etc/opt/chrome/policies/managed/edulab.json"
  remove_file "/etc/chromium/policies/managed/edulab.json"
  remove_file "/etc/opt/edge/policies/managed/edulab.json"
}

state_value() {
  local key="$1"

  [[ -r "$STATE_FILE" ]] || return 0
  awk -F= -v key="$key" '$1 == key { print $2; exit }' "$STATE_FILE"
}

remove_installed_apps() {
  local packages=()
  local installed_packages=()
  local browser_choice
  local install_onlyoffice
  local pkg

  [[ "$REMOVE_APPS" -eq 1 ]] || return 0
  command -v apt-get >/dev/null 2>&1 || die "Không tìm thấy apt-get để gỡ ứng dụng."
  command -v dpkg >/dev/null 2>&1 || die "Không tìm thấy dpkg để kiểm tra ứng dụng."

  browser_choice="$(state_value BROWSER_CHOICE || true)"
  install_onlyoffice="$(state_value INSTALL_ONLYOFFICE || true)"

  if [[ "$install_onlyoffice" == "1" ]]; then
    packages+=("onlyoffice-desktopeditors")
  fi

  case "$browser_choice" in
    chrome) packages+=("google-chrome-stable") ;;
    chromium) packages+=("chromium" "chromium-browser") ;;
    edge) packages+=("microsoft-edge-stable") ;;
  esac

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log "Không có app nào trong trạng thái EduLab để gỡ."
    return 0
  fi

  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      installed_packages+=("$pkg")
    else
      log "Bỏ qua app chưa cài: $pkg"
    fi
  done

  if [[ "${#installed_packages[@]}" -eq 0 ]]; then
    log "Không tìm thấy app EduLab nào đang cài để gỡ."
    return 0
  fi

  log "Gỡ app theo trạng thái EduLab: ${installed_packages[*]}"
  run env DEBIAN_FRONTEND=noninteractive apt-get remove -y --auto-remove "${installed_packages[@]}"
}

remove_state() {
  remove_file "$STATE_FILE"
  remove_empty_dir "/var/lib/edulab"
}

refresh_desktop_database() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database /usr/share/applications
  fi
}

main() {
  parse_args "$@"
  require_root_for_changes
  setup_logging
  validate_config
  confirm_action

  local home
  local desktop_dir

  home="$(user_home)"
  [[ -n "$home" ]] || die "Không tìm thấy home của $TARGET_USER."
  desktop_dir="$(desktop_dir_for_user "$TARGET_USER" "$home")"

  log "Bắt đầu gỡ cấu hình $PROJECT_NAME."
  remove_user_shortcuts "$home" "$desktop_dir"
  remove_system_helpers
  remove_browser_policies
  remove_installed_apps
  remove_state
  refresh_desktop_database

  log "Hoàn tất gỡ cấu hình EduLab. Log gỡ cài đặt: $LOG_FILE"
}

main "$@"
