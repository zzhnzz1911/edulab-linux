#!/usr/bin/env bash
# Trình cài một-cú-click cho EduLab Linux.
# Mặc định cài đầy đủ cho tài khoản hiện tại trên một máy, không tạo user học sinh.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
INSTALL_SCRIPT="$PROJECT_DIR/scripts/install-edulab.sh"
INSTALL_PASSWORD_HASH_FILE="$PROJECT_DIR/.edulab-installer-password.sha256"
STYLE_SCRIPT="$PROJECT_DIR/scripts/apply-desktop-style.sh"

DEFAULT_BROWSER="chrome"
DEFAULT_PASSWORD_PLACEHOLDER="EduLab@Local"

pause_end() {
  echo
  read -r -p "Nhấn Enter để đóng cửa sổ..." _ || true
}

die() {
  echo
  echo "LỖI: $*" >&2
  pause_end
  exit 1
}

on_error() {
  local line="$1"
  trap - ERR
  echo
  echo "Có lỗi khi chạy trình cài ở dòng $line."
  echo "Hãy chụp màn hình đoạn lỗi phía trên để kiểm tra lại."
  pause_end
  exit 1
}
trap 'on_error "$LINENO"' ERR

current_user_fullname() {
  local user="$1"
  local gecos

  gecos="$(getent passwd "$user" </dev/null 2>/dev/null | cut -d: -f5 | cut -d, -f1 || true)"
  printf '%s\n' "${gecos:-$user}"
}

sha256_text() {
  local text="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$text" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$text" | shasum -a 256 | awk '{print $1}'
  else
    die "Không tìm thấy sha256sum hoặc shasum để kiểm tra mã cài đặt."
  fi
}

configured_install_password_hash() {
  local hash="${EDULAB_INSTALL_PASSWORD_SHA256:-}"

  if [[ -z "$hash" && -f "$INSTALL_PASSWORD_HASH_FILE" ]]; then
    hash="$(awk 'NF {print $1; exit}' "$INSTALL_PASSWORD_HASH_FILE")"
  fi

  printf '%s\n' "$hash"
}

read_secret() {
  local prompt="$1"
  local output_var="$2"
  local value=""

  if [[ -t 0 ]]; then
    printf '%s' "$prompt"
    stty -echo 2>/dev/null || true
  fi

  if ! IFS= read -r value; then
    value=""
  fi

  if [[ -t 0 ]]; then
    stty echo 2>/dev/null || true
  fi

  printf -v "$output_var" '%s' "$value"
}

require_installer_password() {
  local expected_hash
  local actual_hash
  local password
  local attempt

  expected_hash="$(configured_install_password_hash)"
  [[ -n "$expected_hash" ]] || return 0

  [[ "$expected_hash" =~ ^[0-9a-fA-F]{64}$ ]] || \
    die "Hash mã cài đặt không hợp lệ trong $INSTALL_PASSWORD_HASH_FILE."

  echo "Bộ cài này yêu cầu mã cài đặt EduLab."
  echo

  for attempt in 1 2 3; do
    read_secret "Nhập mã cài đặt EduLab: " password
    echo

    actual_hash="$(sha256_text "$password")"
    password=""

    if [[ "${actual_hash,,}" == "${expected_hash,,}" ]]; then
      echo "Mã cài đặt hợp lệ."
      echo
      return 0
    fi

    echo "Mã cài đặt không đúng."
  done

  die "Nhập sai mã cài đặt quá 3 lần."
}

confirm_install() {
  local answer

  echo "Script sẽ thay đổi cấu hình hệ thống và cài thêm phần mềm bằng apt."
  echo "Bạn có thể hủy ở bước này nếu chưa muốn cài."
  echo
  if ! read -r -p "Bạn có chấp nhận cài đặt EduLab trên máy này không? [y/N]: " answer; then
    answer=""
  fi

  case "${answer,,}" in
    y|yes|c|co|có)
      ;;
    *)
      echo
      echo "Đã hủy cài đặt. Chưa có thay đổi nào được thực hiện."
      pause_end
      exit 0
      ;;
  esac
}

main() {
  if [[ -t 0 && -t 1 ]]; then
    clear || true
  fi

  [[ -f "$INSTALL_SCRIPT" ]] || die "Không tìm thấy $INSTALL_SCRIPT."

  echo "EduLab Linux - cài nhanh"
  echo "========================"
  echo

  require_installer_password

  local target_user="${USER:-}"
  local target_fullname

  if [[ -z "$target_user" ]]; then
    target_user="$(id -un </dev/null 2>/dev/null || true)"
  fi
  [[ -n "$target_user" ]] || die "Không xác định được user hiện tại."

  target_fullname="$(current_user_fullname "$target_user")"

  echo "Sẽ cài EduLab cho tài khoản Linux hiện tại: $target_user"
  echo "Bao gồm giao diện, font, bộ gõ tiếng Việt, ONLYOFFICE, trình duyệt và shortcut cơ bản."
  echo
  echo "Nếu được hỏi mật khẩu, nhập mật khẩu admin/sudo của máy Linux này."
  echo

  confirm_install

  if [[ "$(id -u </dev/null)" -eq 0 ]]; then
    STUDENT_PASSWORD="$DEFAULT_PASSWORD_PLACEHOLDER" bash "$INSTALL_SCRIPT" \
      --student-user "$target_user" \
      --student-fullname "$target_fullname" \
      --browser "$DEFAULT_BROWSER"
  else
    echo
    echo "Đang yêu cầu quyền sudo. Hệ thống sẽ hỏi mật khẩu admin/sudo nếu cần."
    sudo -v || die "Không xác thực được quyền sudo."

    sudo env STUDENT_PASSWORD="$DEFAULT_PASSWORD_PLACEHOLDER" bash "$INSTALL_SCRIPT" \
      --student-user "$target_user" \
      --student-fullname "$target_fullname" \
      --browser "$DEFAULT_BROWSER"
  fi

  if [[ "$(id -u </dev/null)" -ne 0 && -f "$STYLE_SCRIPT" ]]; then
    echo
    echo "Đang áp giao diện EduLab Windows 10-like cho phiên hiện tại..."
    bash "$STYLE_SCRIPT" || true
  fi

  echo
  echo "Hoàn tất cài EduLab cho user $target_user."
  echo "Hãy đăng xuất rồi đăng nhập lại để giao diện nhận đủ cấu hình."

  pause_end
}

main "$@"
