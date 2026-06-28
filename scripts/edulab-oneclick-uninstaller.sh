#!/usr/bin/env bash
# Trình gỡ một-cú-click cho EduLab Linux.
# Mặc định chỉ gỡ cấu hình, shortcut và helper EduLab cho tài khoản hiện tại.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
UNINSTALL_SCRIPT="$PROJECT_DIR/scripts/uninstall-edulab.sh"

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
  echo "Có lỗi khi chạy trình gỡ ở dòng $line."
  echo "Hãy chụp màn hình đoạn lỗi phía trên để kiểm tra lại."
  pause_end
  exit 1
}
trap 'on_error "$LINENO"' ERR

confirm_uninstall() {
  local answer

  echo "Script sẽ gỡ shortcut, autostart, helper và cấu hình hệ thống của EduLab."
  echo "Script KHÔNG xóa Documents, Downloads hoặc Desktop."
  echo "Chrome/ONLYOFFICE và các phần mềm đã cài sẽ được giữ lại mặc định."
  echo
  if ! read -r -p "Bạn có chắc muốn gỡ cấu hình EduLab không? [y/N]: " answer; then
    answer=""
  fi

  case "${answer,,}" in
    y|yes|c|co|có)
      ;;
    *)
      echo
      echo "Đã hủy gỡ cài đặt. Chưa có thay đổi nào được thực hiện."
      pause_end
      exit 0
      ;;
  esac
}

main() {
  if [[ -t 0 && -t 1 ]]; then
    clear || true
  fi

  [[ -f "$UNINSTALL_SCRIPT" ]] || die "Không tìm thấy $UNINSTALL_SCRIPT."

  local target_user="${SUDO_USER:-${USER:-}}"

  echo "EduLab Linux - gỡ cài đặt"
  echo "========================="
  echo
  echo "Sẽ gỡ cấu hình EduLab cho tài khoản hiện tại: $target_user"
  echo "Nếu được hỏi mật khẩu, nhập mật khẩu admin/sudo của máy Linux này."
  echo

  confirm_uninstall

  if [[ "$(id -u)" -eq 0 ]]; then
    bash "$UNINSTALL_SCRIPT" --target-user "$target_user"
  else
    echo
    echo "Đang yêu cầu quyền sudo. Hệ thống sẽ hỏi mật khẩu admin/sudo nếu cần."
    sudo -v || die "Không xác thực được quyền sudo."
    sudo bash "$UNINSTALL_SCRIPT" --target-user "$target_user"
  fi

  echo
  echo "Hoàn tất gỡ cấu hình EduLab cho user $target_user."
  echo "Nếu Desktop chưa cập nhật ngay, hãy đăng xuất rồi đăng nhập lại."

  pause_end
}

main "$@"
