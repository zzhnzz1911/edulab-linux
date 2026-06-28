#!/usr/bin/env bash
# Trình cài một-cú-click cho EduLab Linux.
# Mặc định cài đầy đủ cho tài khoản hiện tại trên một máy, không tạo user học sinh.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
INSTALL_SCRIPT="$PROJECT_DIR/scripts/install-edulab.sh"

DEFAULT_BROWSER="chrome"
DEFAULT_PASSWORD_PLACEHOLDER="EduLab@Local"

pause_end() {
  echo
  read -r -p "Nhấn Enter để đóng cửa sổ..." _
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
  local gecos
  gecos="$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1 || true)"
  printf '%s\n' "${gecos:-$USER}"
}

confirm_install() {
  local answer

  echo "Script sẽ thay đổi cấu hình hệ thống và cài thêm phần mềm bằng apt."
  echo "Bạn có thể hủy ở bước này nếu chưa muốn cài."
  echo
  read -r -p "Bạn có chấp nhận cài đặt EduLab trên máy này không? [y/N]: " answer

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
  clear || true

  [[ -f "$INSTALL_SCRIPT" ]] || die "Không tìm thấy $INSTALL_SCRIPT."

  local target_user="$USER"
  local target_fullname

  target_fullname="$(current_user_fullname)"

  echo "EduLab Linux - cài nhanh"
  echo "========================"
  echo
  echo "Mặc định sẽ cài đầy đủ cho tài khoản hiện tại: $target_user"
  echo "Không tạo user học sinh, không hỏi LMS, không tạo shortcut LMS."
  echo "Sẽ cài giao diện, font, bộ gõ tiếng Việt, ONLYOFFICE, trình duyệt và shortcut cơ bản."
  echo
  echo "Nếu được hỏi mật khẩu, nhập mật khẩu admin/sudo của máy Linux này."
  echo

  confirm_install

  if [[ "$(id -u)" -eq 0 ]]; then
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

  echo
  echo "Hoàn tất cài EduLab cho user $target_user."
  echo "Hãy đăng xuất rồi đăng nhập lại để giao diện nhận đủ cấu hình."

  pause_end
}

main "$@"
