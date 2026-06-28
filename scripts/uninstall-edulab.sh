#!/usr/bin/env bash
# Gỡ cấu hình EduLab Linux một cách an toàn.
# Script không xóa dữ liệu cá nhân, không xóa Desktop và không xóa thư mục Bai-tap.

set -Eeuo pipefail

PROJECT_NAME="EduLab Linux"
LOG_FILE="/var/log/edulab-uninstall.log"
STATE_FILE="/var/lib/edulab/install-state.env"

TARGET_USER="${SUDO_USER:-${USER:-}}"
EXERCISES_DIR_NAME="Bai-tap"
REMOVE_APPS=0
YES=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
EduLab Linux - uninstall-edulab.sh

Cách dùng:
  sudo bash scripts/uninstall-edulab.sh [tùy chọn]

Tùy chọn:
  --student-user USER     Tài khoản cần gỡ shortcut/cấu hình EduLab. Mặc định: user gọi sudo
  --remove-apps           Gỡ thêm app đã cài theo trạng thái EduLab nếu xác định được
  --yes                   Không hỏi xác nhận, dùng cho tự động hóa
  --dry-run               Chỉ in thao tác, không thay đổi hệ thống
  -h, --help              Hiển thị trợ giúp

Mặc định script chỉ gỡ helper, shortcut, autostart, wallpaper và policy EduLab.
Script không xóa Documents, Downloads, Desktop hoặc thư mục Bai-tap.
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
      --student-user)
        TARGET_USER="${2:-}"
        shift 2
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
  [[ -n "$TARGET_USER" ]] || die "Không xác định được user cần gỡ. Hãy truyền --student-user USER."
  [[ "$TARGET_USER" != "root" ]] || die "Không gỡ cấu hình Desktop cho root. Hãy truyền --student-user USER thật."
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
  echo "Không xóa Documents, Downloads, Desktop hoặc thư mục $EXERCISES_DIR_NAME."
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
  remove_file "$desktop_dir/Bai-tap.desktop"
  remove_file "$desktop_dir/LMS.desktop"
  remove_file "$home/.config/autostart/edulab-first-login.desktop"
  remove_file "$home/.config/edulab/first-login.done"
  remove_file "$home/.config/edulab/desktop-style-v2.done"
  remove_file "$home/.local/share/backgrounds/edulab/edulab-familiar-wallpaper.svg"

  remove_empty_dir "$home/.config/edulab"
  remove_empty_dir "$home/.local/share/backgrounds/edulab"
}

remove_skel_shortcuts() {
  log "Gỡ shortcut EduLab trong /etc/skel cho user tạo sau này."
  remove_file "/etc/skel/Desktop/ONLYOFFICE.desktop"
  remove_file "/etc/skel/Desktop/Trinh-duyet.desktop"
  remove_file "/etc/skel/Desktop/Bai-tap.desktop"
  remove_file "/etc/skel/Desktop/LMS.desktop"
  remove_file "/etc/skel/.config/autostart/edulab-first-login.desktop"
}

remove_system_helpers() {
  log "Gỡ helper và cấu hình hệ thống của EduLab."
  remove_file "/usr/local/bin/edulab-first-login.sh"
  remove_file "/usr/local/bin/edulab-open-exercises"
  remove_file "/usr/local/bin/edulab-open-lms"
  remove_file "/usr/local/bin/edulab-browser"
  remove_file "/usr/local/bin/edulab-apply-desktop-style"
  remove_file "/etc/profile.d/edulab-input-method.sh"
  remove_file "/usr/share/backgrounds/edulab/edulab-familiar-wallpaper.svg"

  remove_empty_dir "/usr/share/backgrounds/edulab"
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
  remove_skel_shortcuts
  remove_system_helpers
  remove_browser_policies
  remove_installed_apps
  remove_state
  refresh_desktop_database

  log "Hoàn tất gỡ cấu hình EduLab. Log gỡ cài đặt: $LOG_FILE"
}

main "$@"
