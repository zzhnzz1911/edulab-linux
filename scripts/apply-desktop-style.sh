#!/usr/bin/env bash
# Áp giao diện "quen Windows" nhưng không dùng tài sản thương hiệu Microsoft.
# Chạy script này trong chính tài khoản cần tùy biến, ví dụ tài khoản student.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
USER_BG_DIR="$HOME/.local/share/backgrounds/edulab"
USER_WALLPAPER="$USER_BG_DIR/edulab-familiar-wallpaper.svg"
SYSTEM_WALLPAPER="/usr/share/backgrounds/edulab/edulab-familiar-wallpaper.svg"

log() {
  printf '[edulab-style] %s\n' "$*"
}

xfconf_set() {
  local channel="$1"
  local property="$2"
  local type="$3"
  local value="$4"

  command -v xfconf-query >/dev/null 2>&1 || return 0

  if xfconf-query -c "$channel" -p "$property" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$property" -s "$value" >/dev/null 2>&1 || true
  else
    xfconf-query -c "$channel" -p "$property" -n -t "$type" -s "$value" >/dev/null 2>&1 || true
  fi
}

gsettings_set_if_exists() {
  local schema="$1"
  local key="$2"
  local value="$3"

  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings list-schemas 2>/dev/null | grep -qx "$schema" || return 0
  gsettings set "$schema" "$key" "$value" >/dev/null 2>&1 || true
}

prepare_wallpaper() {
  mkdir -p "$USER_BG_DIR"

  if [[ -f "$SYSTEM_WALLPAPER" ]]; then
    cp "$SYSTEM_WALLPAPER" "$USER_WALLPAPER" 2>/dev/null || true
  elif [[ -f "$PROJECT_DIR/assets/edulab-familiar-wallpaper.svg" ]]; then
    cp "$PROJECT_DIR/assets/edulab-familiar-wallpaper.svg" "$USER_WALLPAPER" 2>/dev/null || true
  fi

  [[ -f "$USER_WALLPAPER" ]] && printf '%s\n' "$USER_WALLPAPER"
}

apply_common_gtk_style() {
  mkdir -p "$HOME/.config/gtk-3.0"

  cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc
gtk-icon-theme-name=Papirus
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=false
EOF

  cat > "$HOME/.gtkrc-2.0" <<'EOF'
gtk-theme-name="Arc"
gtk-icon-theme-name="Papirus"
gtk-font-name="Noto Sans 10"
EOF
}

apply_xfce_style() {
  command -v xfconf-query >/dev/null 2>&1 || return 0

  # Theme, icon, font: dùng gói mở trong repository, không dùng asset Microsoft.
  xfconf_set xsettings /Net/ThemeName string "Arc"
  xfconf_set xsettings /Net/IconThemeName string "Papirus"
  xfconf_set xsettings /Gtk/FontName string "Noto Sans 10"

  # Window buttons bên phải theo thói quen Windows: minimize, maximize, close.
  xfconf_set xfwm4 /general/button_layout string "|HMC"
  xfconf_set xfwm4 /general/title_alignment string "center"
  xfconf_set xfwm4 /general/easy_click string "Alt"
  xfconf_set xfwm4 /general/workspace_count int "1"

  # Panel dưới màn hình, full width, không autohide, kích thước dễ bấm.
  xfconf_set xfce4-panel /panels/panel-1/position string "p=12;x=0;y=0"
  xfconf_set xfce4-panel /panels/panel-1/length uint "100"
  xfconf_set xfce4-panel /panels/panel-1/size uint "42"
  xfconf_set xfce4-panel /panels/panel-1/nrows uint "1"
  xfconf_set xfce4-panel /panels/panel-1/mode uint "0"
  xfconf_set xfce4-panel /panels/panel-1/autohide-behavior uint "0"
  xfconf_set xfce4-panel /panels/panel-1/position-locked bool "true"

  # Icon desktop lớn vừa đủ cho học sinh dễ nhìn.
  xfconf_set xfce4-desktop /desktop-icons/icon-size uint "48"
  xfconf_set xfce4-desktop /desktop-icons/show-tooltips bool "true"

  local wallpaper="$1"
  if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' | while read -r prop; do
      xfconf-query -c xfce4-desktop -p "$prop" -s "$wallpaper" >/dev/null 2>&1 || true
    done
  fi

  # Nạp lại panel để thay đổi ổn định hơn. Nếu đang thi hoặc đang mở app, lệnh này chỉ restart panel.
  if command -v xfce4-panel >/dev/null 2>&1; then
    xfce4-panel -r >/dev/null 2>&1 || true
  fi
}

apply_cinnamon_style() {
  local wallpaper="$1"

  gsettings_set_if_exists org.cinnamon.desktop.interface gtk-theme "'Arc'"
  gsettings_set_if_exists org.cinnamon.desktop.interface icon-theme "'Papirus'"
  gsettings_set_if_exists org.cinnamon.desktop.interface font-name "'Noto Sans 10'"

  if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
    gsettings_set_if_exists org.cinnamon.desktop.background picture-uri "'file://$wallpaper'"
  fi
}

main() {
  log "Áp giao diện EduLab quen Windows cho user: $USER"

  local wallpaper
  wallpaper="$(prepare_wallpaper || true)"

  apply_common_gtk_style
  apply_xfce_style "$wallpaper"
  apply_cinnamon_style "$wallpaper"

  log "Hoàn tất. Đăng xuất/đăng nhập lại nếu panel hoặc wallpaper chưa đổi ngay."
}

main "$@"
