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

xfconf_int_array() {
  local channel="$1"
  local property="$2"
  shift 2

  command -v xfconf-query >/dev/null 2>&1 || return 0
  xfconf-query -c "$channel" -p "$property" -r >/dev/null 2>&1 || true

  local args=(-c "$channel" -p "$property" -n -a)
  local value
  for value in "$@"; do
    args+=(-t int -s "$value")
  done

  xfconf-query "${args[@]}" >/dev/null 2>&1 || true
}

panel_plugin_available() {
  local plugin="$1"
  [[ -f "/usr/share/xfce4/panel/plugins/$plugin.desktop" ]]
}

set_panel_plugin_type() {
  local id="$1"
  local plugin_type="$2"

  xfconf_set xfce4-panel "/plugins/plugin-$id" string "$plugin_type"
}

backup_xfce_panel() {
  local src="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
  local dst_dir="$HOME/.config/edulab/backups"
  local stamp

  [[ -f "$src" ]] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "$dst_dir"
  cp "$src" "$dst_dir/xfce4-panel.$stamp.xml" 2>/dev/null || true
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

  # Taskbar tối, phẳng và dễ nhìn; dùng CSS GTK, không dùng asset Microsoft.
  cat > "$HOME/.config/gtk-3.0/gtk.css" <<'EOF'
.xfce4-panel {
  background-color: #20242a;
  color: #f8fafc;
  border-top: 1px solid rgba(255, 255, 255, 0.10);
}

.xfce4-panel button,
.xfce4-panel .flat,
.xfce4-panel .toggle {
  border-radius: 2px;
  margin: 2px 1px;
  padding: 2px 8px;
  color: #f8fafc;
}

.xfce4-panel button:hover {
  background-color: rgba(95, 179, 165, 0.28);
}

#whiskermenu-button {
  font-weight: 600;
  padding-left: 10px;
  padding-right: 12px;
}
EOF
}

apply_xfce_wallpaper() {
  local wallpaper="$1"
  local found=0
  local prop

  [[ -n "$wallpaper" && -f "$wallpaper" ]] || return 0
  command -v xfconf-query >/dev/null 2>&1 || return 0

  while read -r prop; do
    [[ -n "$prop" ]] || continue
    found=1
    xfconf-query -c xfce4-desktop -p "$prop" -s "$wallpaper" >/dev/null 2>&1 || true
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' || true)

  # Một số máy mới chưa có property last-image, tạo fallback để wallpaper vẫn ăn sau lần đăng nhập kế.
  if [[ "$found" -eq 0 ]]; then
    xfconf_set xfce4-desktop /backdrop/screen0/monitor0/workspace0/last-image string "$wallpaper"
    xfconf_set xfce4-desktop /backdrop/screen0/monitorVirtual1/workspace0/last-image string "$wallpaper"
  fi

  while read -r prop; do
    [[ -n "$prop" ]] || continue
    xfconf-query -c xfce4-desktop -p "$prop" -s 5 >/dev/null 2>&1 || true
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/image-style$' || true)
}

apply_xfce_taskbar() {
  command -v xfconf-query >/dev/null 2>&1 || return 0

  backup_xfce_panel

  local ids=()
  local id=101

  if panel_plugin_available whiskermenu; then
    set_panel_plugin_type "$id" whiskermenu
    xfconf_set xfce4-panel "/plugins/plugin-$id/button-icon" string "start-here"
    xfconf_set xfce4-panel "/plugins/plugin-$id/button-title" string "EduLab"
    xfconf_set xfce4-panel "/plugins/plugin-$id/show-button-title" bool "true"
    ids+=("$id")
    id=$((id + 1))
  fi

  set_panel_plugin_type "$id" tasklist
  xfconf_set xfce4-panel "/plugins/plugin-$id/show-labels" bool "true"
  xfconf_set xfce4-panel "/plugins/plugin-$id/flat-buttons" bool "false"
  xfconf_set xfce4-panel "/plugins/plugin-$id/show-handle" bool "false"
  xfconf_set xfce4-panel "/plugins/plugin-$id/grouping" uint "1"
  ids+=("$id")
  id=$((id + 1))

  set_panel_plugin_type "$id" separator
  xfconf_set xfce4-panel "/plugins/plugin-$id/expand" bool "true"
  xfconf_set xfce4-panel "/plugins/plugin-$id/style" uint "0"
  ids+=("$id")
  id=$((id + 1))

  local plugin
  for plugin in systray notification-plugin pulseaudio power-manager-plugin clock showdesktop; do
    if panel_plugin_available "$plugin"; then
      set_panel_plugin_type "$id" "$plugin"
      if [[ "$plugin" == "clock" ]]; then
        xfconf_set xfce4-panel "/plugins/plugin-$id/mode" uint "2"
        xfconf_set xfce4-panel "/plugins/plugin-$id/digital-format" string "%H:%M  %d/%m"
      fi
      ids+=("$id")
      id=$((id + 1))
    fi
  done

  xfconf_int_array xfce4-panel /panels 1
  xfconf_int_array xfce4-panel /panels/panel-1/plugin-ids "${ids[@]}"

  xfconf_set xfce4-panel /panels/panel-1/position string "p=12;x=0;y=0"
  xfconf_set xfce4-panel /panels/panel-1/length uint "100"
  xfconf_set xfce4-panel /panels/panel-1/size uint "46"
  xfconf_set xfce4-panel /panels/panel-1/nrows uint "1"
  xfconf_set xfce4-panel /panels/panel-1/mode uint "0"
  xfconf_set xfce4-panel /panels/panel-1/autohide-behavior uint "0"
  xfconf_set xfce4-panel /panels/panel-1/position-locked bool "true"
  xfconf_set xfce4-panel /panels/panel-1/icon-size uint "26"
  xfconf_set xfce4-panel /panels/panel-1/background-style uint "1"
  xfconf_set xfce4-panel /panels/panel-1/dark-mode bool "true"
}

apply_xfce_style() {
  command -v xfconf-query >/dev/null 2>&1 || return 0

  # Theme, icon, font: dùng gói mở trong repository, không dùng asset Microsoft.
  xfconf_set xsettings /Net/ThemeName string "Arc"
  xfconf_set xsettings /Net/IconThemeName string "Papirus"
  xfconf_set xsettings /Gtk/FontName string "Noto Sans 10"

  # Window buttons bên phải theo thói quen desktop phổ biến: minimize, maximize, close.
  xfconf_set xfwm4 /general/theme string "Arc"
  xfconf_set xfwm4 /general/button_layout string "|HMC"
  xfconf_set xfwm4 /general/title_alignment string "center"
  xfconf_set xfwm4 /general/easy_click string "Alt"
  xfconf_set xfwm4 /general/workspace_count int "1"

  # Icon desktop lớn vừa đủ cho học sinh dễ nhìn.
  xfconf_set xfce4-desktop /desktop-icons/icon-size uint "48"
  xfconf_set xfce4-desktop /desktop-icons/show-tooltips bool "true"

  apply_xfce_taskbar
  apply_xfce_wallpaper "$1"

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
