#!/usr/bin/env bash
# Đóng gói project thành file .tar.gz để đem qua máy Linux khác.
# Script loại các thư mục nặng như VM/ISO/downloads, không đụng dữ liệu ngoài project.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
PACKAGE_NAME="edulab-linux-installer.tar.gz"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"

die() {
  echo "LỖI: $*" >&2
  exit 1
}

command -v tar >/dev/null 2>&1 || die "Không tìm thấy lệnh tar."

mkdir -p "$DIST_DIR"
chmod 0755 "$PROJECT_DIR"/scripts/*.sh
chmod 0755 "$PROJECT_DIR"/*.desktop

echo "Đang tạo gói: $PACKAGE_PATH"
tar \
  --exclude='./.git' \
  --exclude='./dist' \
  --exclude='./downloads' \
  --exclude='./tools' \
  --exclude='./vms' \
  -czf "$PACKAGE_PATH" \
  -C "$PROJECT_DIR" \
  .

echo "Xong: $PACKAGE_PATH"
echo "Copy file này sang máy Linux, giải nén, rồi chạy scripts/prepare-oneclick-launcher.sh."
