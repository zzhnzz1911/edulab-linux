#!/usr/bin/env bash
# Chạy sau khi clone image sang máy khác.
# Script đổi hostname, tạo machine-id mới, dọn cache/lịch sử trong vùng an toàn.
# Không xóa thư mục tài liệu, Desktop, Downloads hay dữ liệu học sinh.

set -Eeuo pipefail
shopt -s nullglob

LOG_FILE="/var/log/edulab-post-clone.log"
HOSTNAME_TARGET=""
RESET_SSH_HOST_KEYS=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
EduLab Linux - post-clone.sh

Cách dùng:
  sudo bash scripts/post-clone.sh --hostname IC3-LAB-01

Tùy chọn:
  --hostname NAME             Đổi hostname của máy clone
  --reset-ssh-host-keys       Tạo lại SSH host keys nếu máy có openssh-server
  --dry-run                   Chỉ in thao tác, không thay đổi hệ thống
  -h, --help                  Hiển thị trợ giúp

Ví dụ:
  sudo bash scripts/post-clone.sh --hostname IC3-P01-M01
  sudo bash scripts/post-clone.sh --hostname IC3-P01-M01 --reset-ssh-host-keys
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
      --hostname)
        HOSTNAME_TARGET="${2:-}"
        shift 2
        ;;
      --reset-ssh-host-keys)
        RESET_SSH_HOST_KEYS=1
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
    die "Hãy chạy bằng sudo: sudo bash scripts/post-clone.sh --hostname IC3-LAB-01"
  fi
}

validate_hostname() {
  local value="$1"
  [[ -n "$value" ]] || return 0
  [[ "${#value}" -le 63 ]] || die "Hostname quá dài: $value"
  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$|^[A-Za-z0-9]$ ]] || \
    die "Hostname không hợp lệ: $value"
}

backup_file_if_exists() {
  local path="$1"
  local backup_dir="/var/backups/edulab"
  local stamp

  [[ -e "$path" && ! -L "$path" ]] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  run install -d -m 0700 "$backup_dir"
  run cp -a "$path" "$backup_dir/$(basename "$path").$stamp.bak"
}

set_hostname_if_requested() {
  if [[ -z "$HOSTNAME_TARGET" ]]; then
    log "Không đổi hostname vì chưa truyền --hostname."
    return
  fi

  validate_hostname "$HOSTNAME_TARGET"
  run hostnamectl set-hostname "$HOSTNAME_TARGET"
}

reset_machine_id() {
  log "Reset machine-id để máy clone có định danh riêng."

  backup_file_if_exists "/etc/machine-id"
  backup_file_if_exists "/var/lib/dbus/machine-id"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    : > /etc/machine-id
    if [[ -e /var/lib/dbus/machine-id && ! -L /var/lib/dbus/machine-id ]]; then
      rm -f /var/lib/dbus/machine-id
    fi
  else
    log "+ truncate -s 0 /etc/machine-id"
    log "+ xóa /var/lib/dbus/machine-id nếu là file thường"
  fi

  if command -v systemd-machine-id-setup >/dev/null 2>&1; then
    run systemd-machine-id-setup
  elif command -v dbus-uuidgen >/dev/null 2>&1; then
    run dbus-uuidgen --ensure=/etc/machine-id
  else
    log "CẢNH BÁO: không có systemd-machine-id-setup/dbus-uuidgen. Machine-id mới sẽ được tạo ở lần boot tiếp theo nếu distro hỗ trợ."
  fi
}

reset_ssh_host_keys_if_requested() {
  [[ "$RESET_SSH_HOST_KEYS" -eq 1 ]] || {
    log "Không reset SSH host keys. Dùng --reset-ssh-host-keys nếu máy có SSH server và cần định danh riêng."
    return
  }

  if [[ ! -d /etc/ssh ]]; then
    log "Không có /etc/ssh, bỏ qua reset SSH host keys."
    return
  fi

  log "Tạo lại SSH host keys."
  run install -d -m 0700 /var/backups/edulab/ssh-host-keys

  local key
  for key in /etc/ssh/ssh_host_*; do
    [[ -e "$key" ]] || continue
    run cp -a "$key" "/var/backups/edulab/ssh-host-keys/$(basename "$key").$(date '+%Y%m%d-%H%M%S').bak"
    run rm -f "$key"
  done

  if command -v ssh-keygen >/dev/null 2>&1; then
    run ssh-keygen -A
  else
    log "CẢNH BÁO: không tìm thấy ssh-keygen."
  fi
}

safe_remove_path() {
  local path="$1"
  [[ -e "$path" ]] || return 0

  case "$path" in
    /home/*/.cache/*|/home/*/.local/share/Trash/*|/home/*/.config/google-chrome/*|/home/*/.config/chromium/*|/home/*/.config/microsoft-edge/*|/tmp/edulab-*|/var/tmp/edulab-*)
      run rm -rf -- "$path"
      ;;
    *)
      log "Bỏ qua xóa ngoài vùng an toàn: $path"
      ;;
  esac
}

safe_truncate_file() {
  local path="$1"
  [[ -e "$path" ]] || return 0

  case "$path" in
    /home/*/.bash_history|/home/*/.zsh_history|/home/*/.python_history|/home/*/.local/share/recently-used.xbel)
      log "+ truncate $path"
      if [[ "$DRY_RUN" -eq 0 ]]; then
        : > "$path"
      fi
      ;;
    *)
      log "Bỏ qua truncate ngoài vùng an toàn: $path"
      ;;
  esac
}

clean_user_state() {
  local home="$1"
  local user
  user="$(basename "$home")"

  [[ -d "$home" ]] || return 0
  log "Dọn cache/lịch sử cho $user."

  safe_remove_path "$home/.cache/thumbnails"
  safe_remove_path "$home/.cache/google-chrome"
  safe_remove_path "$home/.cache/chromium"
  safe_remove_path "$home/.cache/microsoft-edge"
  safe_remove_path "$home/.local/share/Trash/files"
  safe_remove_path "$home/.local/share/Trash/info"

  safe_truncate_file "$home/.bash_history"
  safe_truncate_file "$home/.zsh_history"
  safe_truncate_file "$home/.python_history"
  safe_truncate_file "$home/.local/share/recently-used.xbel"

  local profile_file
  for profile_file in \
    "$home"/.config/google-chrome/*/History* \
    "$home"/.config/google-chrome/*/Cookies* \
    "$home"/.config/google-chrome/*/"Login Data"* \
    "$home"/.config/google-chrome/*/"Visited Links" \
    "$home"/.config/google-chrome/*/Sessions/* \
    "$home"/.config/chromium/*/History* \
    "$home"/.config/chromium/*/Cookies* \
    "$home"/.config/chromium/*/"Login Data"* \
    "$home"/.config/chromium/*/"Visited Links" \
    "$home"/.config/chromium/*/Sessions/* \
    "$home"/.config/microsoft-edge/*/History* \
    "$home"/.config/microsoft-edge/*/Cookies* \
    "$home"/.config/microsoft-edge/*/"Login Data"* \
    "$home"/.config/microsoft-edge/*/"Visited Links" \
    "$home"/.config/microsoft-edge/*/Sessions/*; do
    safe_remove_path "$profile_file"
  done
}

clean_system_cache_and_logs() {
  log "Dọn cache hệ thống an toàn."

  if command -v apt-get >/dev/null 2>&1; then
    run apt-get clean
  fi

  if command -v journalctl >/dev/null 2>&1; then
    run journalctl --rotate
    run journalctl --vacuum-time=1s
  fi

  local tmp_path
  for tmp_path in /tmp/edulab-* /var/tmp/edulab-*; do
    safe_remove_path "$tmp_path"
  done
}

clean_all_users() {
  local home
  for home in /home/*; do
    clean_user_state "$home"
  done

  # Root history chỉ truncate file lịch sử rõ ràng, không xóa cấu hình root.
  if [[ -e /root/.bash_history ]]; then
    log "+ truncate /root/.bash_history"
    [[ "$DRY_RUN" -eq 0 ]] && : > /root/.bash_history
  fi
}

main() {
  parse_args "$@"
  require_root_for_changes
  setup_logging

  log "Bắt đầu post-clone EduLab."
  set_hostname_if_requested
  reset_machine_id
  reset_ssh_host_keys_if_requested
  clean_all_users
  clean_system_cache_and_logs

  log "Hoàn tất post-clone. Khuyến nghị reboot để hostname/machine-id/session mới có hiệu lực đầy đủ."
  log "Log post-clone: $LOG_FILE"
}

main "$@"
