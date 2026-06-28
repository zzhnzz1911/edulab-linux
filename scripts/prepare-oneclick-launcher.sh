#!/usr/bin/env bash
# Prepare one-click desktop launchers after copying the project to Linux.
# This is useful when the project came from Windows, USB, or a shared folder.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

trust_launcher() {
  local path="$1"
  local checksum=""

  chmod 0755 "$path"
  if command -v gio >/dev/null 2>&1; then
    if command -v sha256sum >/dev/null 2>&1; then
      checksum="$(sha256sum "$path" 2>/dev/null | awk '{print $1}')"
      if [[ -n "$checksum" ]]; then
        gio set -t string "$path" metadata::xfce-exe-checksum "$checksum" 2>/dev/null || true
      fi
    fi
    gio set "$path" metadata::trusted true 2>/dev/null || true
  fi
  touch "$path" 2>/dev/null || true
}

LAUNCHER="$PROJECT_DIR/Install-EduLab.desktop"
UNINSTALL_LAUNCHER="$PROJECT_DIR/Uninstall-EduLab.desktop"

[[ -f "$LAUNCHER" ]] || die "Missing Install-EduLab.desktop."
[[ -f "$UNINSTALL_LAUNCHER" ]] || die "Missing Uninstall-EduLab.desktop."

echo "Preparing EduLab scripts and desktop launchers..."
chmod 0755 "$PROJECT_DIR"/scripts/*.sh

trust_launcher "$LAUNCHER"
trust_launcher "$UNINSTALL_LAUNCHER"

DESKTOP_DIR=""
if command -v xdg-user-dir >/dev/null 2>&1; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
fi
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"

if [[ -d "$DESKTOP_DIR" ]]; then
  DESKTOP_COPY="$DESKTOP_DIR/Install-EduLab.desktop"
  cp "$LAUNCHER" "$DESKTOP_COPY"
  trust_launcher "$DESKTOP_COPY"
  echo "Copied launcher to Desktop: $DESKTOP_COPY"

  UNINSTALL_DESKTOP_COPY="$DESKTOP_DIR/Uninstall-EduLab.desktop"
  cp "$UNINSTALL_LAUNCHER" "$UNINSTALL_DESKTOP_COPY"
  trust_launcher "$UNINSTALL_DESKTOP_COPY"
  echo "Copied uninstall launcher to Desktop: $UNINSTALL_DESKTOP_COPY"
fi

echo "Done. You can double-click Install-EduLab.desktop or Uninstall-EduLab.desktop."
