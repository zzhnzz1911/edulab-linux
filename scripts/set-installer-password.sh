#!/usr/bin/env bash
# Đặt mã cài đặt riêng cho launcher EduLab.
# Script chỉ lưu SHA-256 hash, không lưu mật khẩu thô trong repository.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
HASH_FILE="$PROJECT_DIR/.edulab-installer-password.sha256"

die() {
  echo "LỖI: $*" >&2
  exit 1
}

sha256_text() {
  local text="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$text" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$text" | shasum -a 256 | awk '{print $1}'
  else
    die "Không tìm thấy sha256sum hoặc shasum."
  fi
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

main() {
  local password
  local confirm_password
  local hash

  echo "Đặt mã cài đặt EduLab"
  echo "====================="
  echo
  echo "Lưu ý: repo public vẫn có thể bị người rành kỹ thuật sửa script để bỏ qua bước này."
  echo "Mã này dùng để chặn cài đặt nhầm hoặc người dùng phổ thông, không thay thế repo private."
  echo

  read_secret "Nhập mã cài đặt mới: " password
  echo
  read_secret "Nhập lại mã cài đặt mới: " confirm_password
  echo

  [[ -n "$password" ]] || die "Mã cài đặt không được trống."
  [[ "$password" == "$confirm_password" ]] || die "Hai lần nhập mã không khớp."
  [[ "${#password}" -ge 8 ]] || die "Nên dùng mã cài đặt ít nhất 8 ký tự."

  hash="$(sha256_text "$password")"
  password=""
  confirm_password=""

  printf '%s\n' "$hash" >"$HASH_FILE"
  chmod 0600 "$HASH_FILE" 2>/dev/null || true

  echo
  echo "Đã tạo file hash: $HASH_FILE"
  echo "Muốn bật mã cài đặt cho bản trên GitHub, commit và push file này."
}

main "$@"
