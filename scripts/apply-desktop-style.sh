#!/usr/bin/env bash
# Áp giao diện EduLab Windows 10-like Desktop cho tài khoản hiện tại.
# Chạy script này trong chính tài khoản cần tùy biến, ví dụ tài khoản admin hiện tại.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
GTK_THEME_NAME="Windows 10"
ICON_THEME_NAME="Windows 10"
FONT_NAME="Noto Sans 10"
USER_BG_DIR="$HOME/.local/share/backgrounds/edulab"
WALLPAPER_NAME="windows-10-blue-gradient.jpg"
WALLPAPER_DOWNLOAD_NAME="Wallpaper Alchemy - Hình Nền Gradient Xanh Mặc Định Windows 10 4K.jpg"
USER_WALLPAPER="$USER_BG_DIR/$WALLPAPER_NAME"
SYSTEM_WALLPAPER="/usr/share/backgrounds/edulab/$WALLPAPER_NAME"
PROJECT_WALLPAPER="$PROJECT_DIR/assets/$WALLPAPER_NAME"
DOWNLOAD_WALLPAPER="$PROJECT_DIR/downloads/$WALLPAPER_DOWNLOAD_NAME"

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

xfconf_string_array() {
  local channel="$1"
  local property="$2"
  shift 2

  command -v xfconf-query >/dev/null 2>&1 || return 0
  xfconf-query -c "$channel" -p "$property" -r >/dev/null 2>&1 || true

  local args=(-c "$channel" -p "$property" -n -a)
  local value
  for value in "$@"; do
    args+=(-t string -s "$value")
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

create_panel_launcher() {
  local id="$1"
  local filename="$2"
  local name="$3"
  local exec_cmd="$4"
  local icon="$5"
  local category="${6:-Utility;}"
  local show_label="${7:-false}"
  local launcher_dir="$HOME/.config/xfce4/panel/launcher-$id"

  panel_plugin_available launcher || return 1
  mkdir -p "$launcher_dir"

  cat > "$launcher_dir/$filename" <<ENTRY
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Exec=$exec_cmd
Terminal=false
StartupNotify=true
Categories=$category
ENTRY
  if [[ -n "$icon" ]]; then
    printf 'Icon=%s\n' "$icon" >> "$launcher_dir/$filename"
  fi

  set_panel_plugin_type "$id" launcher
  xfconf_string_array xfce4-panel "/plugins/plugin-$id/items" "$filename"
  xfconf_set xfce4-panel "/plugins/plugin-$id/show-label" bool "$show_label"
}

input_menu_command() {
  if command -v edulab-input-menu >/dev/null 2>&1; then
    printf '%s\n' "edulab-input-menu"
  elif [[ -x "$SCRIPT_DIR/edulab-input-menu.py" ]]; then
    printf '%s\n' "$SCRIPT_DIR/edulab-input-menu.py"
  else
    printf '%s\n' "ibus-setup"
  fi
}

browser_icon_name() {
  if command -v google-chrome-stable >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1; then
    printf '%s\n' "google-chrome"
  elif command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
    printf '%s\n' "chromium"
  elif command -v firefox >/dev/null 2>&1; then
    printf '%s\n' "firefox"
  else
    printf '%s\n' "web-browser"
  fi
}

create_input_indicator_icon() {
  local icon_dir="$HOME/.config/edulab/icons"
  local icon_path="$icon_dir/input-eng.svg"

  mkdir -p "$icon_dir"
  cat > "$icon_path" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" fill="none"/>
  <text x="32" y="41" text-anchor="middle" font-family="Segoe UI, Noto Sans, Arial, sans-serif" font-size="27" font-weight="700" fill="#f8fafc">ENG</text>
</svg>
EOF
  printf '%s\n' "$icon_path"
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

configure_taskbar_search_autostart() {
  local autostart_dir="$HOME/.config/autostart"

  mkdir -p "$autostart_dir"
  rm -f "$autostart_dir/edulab-taskbar-search.desktop"
}

start_taskbar_search() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -u "$(id -un)" -f "edulab-start-menu --taskbar-search" >/dev/null 2>&1 || true
    sleep 0.2
  fi
  rm -f "/tmp/edulab-taskbar-search-$(id -u).pid" >/dev/null 2>&1 || true
}

gsettings_set_if_exists() {
  local schema="$1"
  local key="$2"
  local value="$3"

  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings list-schemas 2>/dev/null | grep -qx "$schema" || return 0
  gsettings set "$schema" "$key" "$value" >/dev/null 2>&1 || true
}

gsettings_set_key_if_exists() {
  local schema="$1"
  local key="$2"
  local value="$3"

  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings list-schemas 2>/dev/null | grep -qx "$schema" || return 0
  gsettings list-keys "$schema" 2>/dev/null | grep -qx "$key" || return 0
  gsettings set "$schema" "$key" "$value" >/dev/null 2>&1 || true
}

desktop_dir_for_current_user() {
  local desktop_dir=""

  if command -v xdg-user-dir >/dev/null 2>&1; then
    desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi

  if [[ -z "$desktop_dir" || "$desktop_dir" == "$HOME" ]]; then
    desktop_dir="$HOME/Desktop"
  fi

  printf '%s\n' "$desktop_dir"
}

trust_desktop_launchers() {
  local desktop_dir
  local launcher
  local checksum

  desktop_dir="$(desktop_dir_for_current_user)"
  [[ -d "$desktop_dir" ]] || return 0

  rm -f -- "$desktop_dir/Bai-tap.desktop" "$desktop_dir/Tep.desktop" "$desktop_dir/Cai-dat.desktop" 2>/dev/null || true

  for launcher in "$desktop_dir"/*.desktop; do
    [[ -e "$launcher" ]] || continue
    chmod 0755 "$launcher" 2>/dev/null || true
    if command -v gio >/dev/null 2>&1; then
      if command -v sha256sum >/dev/null 2>&1; then
        checksum="$(sha256sum "$launcher" 2>/dev/null | awk '{print $1}')"
        if [[ -n "$checksum" ]]; then
          gio set -t string "$launcher" metadata::xfce-exe-checksum "$checksum" >/dev/null 2>&1 || true
        fi
      fi
      gio set "$launcher" metadata::trusted true >/dev/null 2>&1 || true
    fi
    touch "$launcher" 2>/dev/null || true
  done
}

prepare_wallpaper() {
  mkdir -p "$USER_BG_DIR"

  if [[ -f "$SYSTEM_WALLPAPER" ]]; then
    cp "$SYSTEM_WALLPAPER" "$USER_WALLPAPER" 2>/dev/null || true
  elif [[ -f "$PROJECT_WALLPAPER" ]]; then
    cp "$PROJECT_WALLPAPER" "$USER_WALLPAPER" 2>/dev/null || true
  elif [[ -f "$DOWNLOAD_WALLPAPER" ]]; then
    cp "$DOWNLOAD_WALLPAPER" "$USER_WALLPAPER" 2>/dev/null || true
  fi

  [[ -f "$USER_WALLPAPER" ]] && printf '%s\n' "$USER_WALLPAPER"
}

apply_common_gtk_style() {
  mkdir -p "$HOME/.config/gtk-3.0"

  cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Windows 10
gtk-icon-theme-name=Windows 10
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=false
EOF

  cat > "$HOME/.gtkrc-2.0" <<'EOF'
gtk-theme-name="Windows 10"
gtk-icon-theme-name="Windows 10"
gtk-font-name="Noto Sans 10"
EOF

  # Taskbar tối, phẳng và dùng accent xanh kiểu Windows 10.
  cat > "$HOME/.config/gtk-3.0/gtk.css" <<'EOF'
.xfce4-panel {
  background-color: #101010;
  color: #f8fafc;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}

.xfce4-panel button,
.xfce4-panel .flat,
.xfce4-panel .toggle {
  border-radius: 0;
  margin: 0;
  padding: 2px 7px;
  min-height: 34px;
  min-width: 32px;
  color: #f8fafc;
}

.xfce4-panel button:hover {
  background-color: rgba(255, 255, 255, 0.14);
}

.xfce4-panel button:checked,
.xfce4-panel button:active {
  background-color: rgba(0, 120, 215, 0.34);
}

.xfce4-panel button label {
  color: #f8fafc;
}

.xfce4-panel entry {
  min-height: 28px;
  border-radius: 0;
  border: 0;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #f2f2f2;
  color: #202020;
}

#whiskermenu-button {
  min-width: 48px;
  padding-left: 14px;
  padding-right: 14px;
}

menu,
.menu,
popover,
.popover {
  background-color: #f4f4f4;
  color: #202020;
}

menu label,
menuitem label,
popover label,
.popover label {
  color: #202020;
}

menuitem:disabled label,
menuitem label:disabled,
popover label:disabled,
.popover label:disabled {
  color: #707070;
}

menuitem:hover,
menuitem:hover label,
menuitem:selected,
menuitem:selected label {
  background-color: #0078d7;
  color: #ffffff;
}

#XfceNotifyWindow,
#XfceNotifyWindow.osd {
  min-width: 330px;
  padding: 12px;
  background-color: #202020;
  color: #f8fafc;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 0;
}

#XfceNotifyWindow label,
#XfceNotifyWindow label#summary,
#XfceNotifyWindow label#body {
  color: #f8fafc;
}

#XfceNotifyWindow button {
  min-height: 30px;
  padding: 4px 10px;
  border-radius: 0;
}
EOF
}

apply_notification_style() {
  local theme_name="EduLab-Windows10"
  local theme_dir="$HOME/.themes/$theme_name/xfce-notify-4.0"

  mkdir -p "$theme_dir"
  cat > "$theme_dir/gtk.css" <<'EOF'
#XfceNotifyWindow,
#XfceNotifyWindow.osd,
#XfceNotifyWindow .osd {
  min-width: 330px;
  padding: 12px;
  background-color: #202020;
  color: #f8fafc;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 0;
}

#XfceNotifyWindow label,
#XfceNotifyWindow label#summary,
#XfceNotifyWindow label#body {
  color: #f8fafc;
}

#XfceNotifyWindow button {
  min-height: 30px;
  padding: 4px 10px;
  border-radius: 0;
}
EOF

  xfconf_set xfce4-notifyd /theme string "$theme_name"
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
  local start_command="edulab-start-menu"
  local search_command="edulab-start-menu --search"
  local browser_icon
  local input_icon
  local input_command
  local search_label="Ask me anything                 "

  if ! command -v edulab-start-menu >/dev/null 2>&1; then
    start_command="xfce4-popup-whiskermenu"
    search_command="xfce4-popup-whiskermenu"
  fi
  browser_icon="$(browser_icon_name)"

  if create_panel_launcher "$id" "start.desktop" "Start" "$start_command" "start-here" "Utility;"; then
    ids+=("$id")
    id=$((id + 1))
  elif panel_plugin_available whiskermenu; then
    set_panel_plugin_type "$id" whiskermenu
    xfconf_set xfce4-panel "/plugins/plugin-$id/button-icon" string "start-here"
    xfconf_set xfce4-panel "/plugins/plugin-$id/button-title" string ""
    xfconf_set xfce4-panel "/plugins/plugin-$id/show-button-title" bool "false"
    xfconf_set xfce4-panel "/plugins/plugin-$id/menu-width" uint "520"
    xfconf_set xfce4-panel "/plugins/plugin-$id/menu-height" uint "640"
    xfconf_set xfce4-panel "/plugins/plugin-$id/show-command-settings" bool "true"
    xfconf_set xfce4-panel "/plugins/plugin-$id/show-command-lockscreen" bool "true"
    xfconf_set xfce4-panel "/plugins/plugin-$id/show-command-switchuser" bool "false"
    ids+=("$id")
    id=$((id + 1))
  fi

  if create_panel_launcher "$id" "search.desktop" "$search_label" "$search_command" "system-search" "Utility;" "true"; then
    ids+=("$id")
    id=$((id + 1))
  fi

  if create_panel_launcher "$id" "file-explorer.desktop" "File Explorer" "edulab-open-files" "system-file-manager" "FileManager;"; then
    ids+=("$id")
    id=$((id + 1))
  fi

  if create_panel_launcher "$id" "browser.desktop" "Browser" "edulab-browser" "$browser_icon" "Network;WebBrowser;"; then
    ids+=("$id")
    id=$((id + 1))
  fi

  set_panel_plugin_type "$id" tasklist
  # Taskbar icon-only giống thanh taskbar Windows 10.
  xfconf_set xfce4-panel "/plugins/plugin-$id/show-labels" bool "false"
  xfconf_set xfce4-panel "/plugins/plugin-$id/flat-buttons" bool "true"
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
  for plugin in systray power-manager-plugin pulseaudio; do
    if panel_plugin_available "$plugin"; then
      set_panel_plugin_type "$id" "$plugin"
      ids+=("$id")
      id=$((id + 1))
    fi
  done

  input_icon="$(create_input_indicator_icon)"
  input_command="$(input_menu_command)"
  if create_panel_launcher "$id" "input-language.desktop" "ENG" "$input_command" "$input_icon" "Utility;" "true"; then
    xfconf_set xfce4-panel "/plugins/plugin-$id/disable-tooltips" bool "true"
    ids+=("$id")
    id=$((id + 1))
  fi

  for plugin in clock notification-plugin showdesktop; do
    if panel_plugin_available "$plugin"; then
      set_panel_plugin_type "$id" "$plugin"
      if [[ "$plugin" == "clock" ]]; then
        xfconf_set xfce4-panel "/plugins/plugin-$id/mode" uint "2"
        xfconf_set xfce4-panel "/plugins/plugin-$id/digital-format" string "%H:%M"
        xfconf_set xfce4-panel "/plugins/plugin-$id/tooltip-format" string "%A, %d/%m/%Y"
      fi
      ids+=("$id")
      id=$((id + 1))
    fi
  done

  xfconf_int_array xfce4-panel /panels 1
  xfconf_int_array xfce4-panel /panels/panel-1/plugin-ids "${ids[@]}"

  xfconf_set xfce4-panel /panels/panel-1/position string "p=12;x=0;y=0"
  xfconf_set xfce4-panel /panels/panel-1/length uint "100"
  xfconf_set xfce4-panel /panels/panel-1/size uint "40"
  xfconf_set xfce4-panel /panels/panel-1/nrows uint "1"
  xfconf_set xfce4-panel /panels/panel-1/mode uint "0"
  xfconf_set xfce4-panel /panels/panel-1/autohide-behavior uint "0"
  xfconf_set xfce4-panel /panels/panel-1/position-locked bool "true"
  xfconf_set xfce4-panel /panels/panel-1/icon-size uint "24"
  xfconf_set xfce4-panel /panels/panel-1/background-style uint "1"
  xfconf_set xfce4-panel /panels/panel-1/dark-mode bool "true"
}

apply_file_explorer_style() {
  local bookmarks="$HOME/.config/gtk-3.0/bookmarks"
  local dir

  mkdir -p "$HOME/.config/gtk-3.0"

  if command -v xfconf-query >/dev/null 2>&1; then
    xfconf_set thunar /last-view string "ThunarDetailsView"
    xfconf_set thunar /misc-single-click bool "false"
    xfconf_set thunar /last-show-hidden bool "false"
    xfconf_set thunar /misc-thumbnail-mode string "THUNAR_THUMBNAIL_MODE_ONLY_LOCAL"
  fi

  : > "$bookmarks"
  for dir in \
    "$HOME/Desktop" \
    "$HOME/Documents" \
    "$HOME/Downloads" \
    "$HOME/Pictures" \
    "$HOME/Videos" \
    "$HOME/Music"; do
    if [[ -d "$dir" ]]; then
      printf 'file://%s\n' "$dir" >> "$bookmarks"
    fi
  done
}

apply_input_switcher_style() {
  if command -v setxkbmap >/dev/null 2>&1; then
    setxkbmap -layout us,vn -variant , -option grp:win_space_toggle >/dev/null 2>&1 || true
  fi

  if command -v xfconf-query >/dev/null 2>&1; then
    xfconf_set keyboard-layout /Default/XkbDisable bool "false"
    xfconf_set keyboard-layout /Default/XkbLayout string "us,vn"
    xfconf_set keyboard-layout /Default/XkbVariant string ","
    xfconf_set keyboard-layout /Default/XkbOptions/Group string "grp:win_space_toggle"
  fi

  gsettings_set_key_if_exists org.freedesktop.ibus.general preload-engines "['xkb:us::eng', 'Unikey']"
  gsettings_set_key_if_exists org.freedesktop.ibus.general engines-order "['xkb:us::eng', 'Unikey']"
  gsettings_set_key_if_exists org.freedesktop.ibus.general use-system-keyboard-layout "false"
  gsettings_set_key_if_exists org.freedesktop.ibus.general.hotkey triggers "['<Super>space']"
  gsettings_set_key_if_exists org.freedesktop.ibus.general.hotkey triggers-backward "['<Shift><Super>space']"
  gsettings_set_key_if_exists org.freedesktop.ibus.panel show-icon-on-systray "false"
  gsettings_set_key_if_exists org.freedesktop.ibus.panel show-im-name "false"

  if command -v ibus >/dev/null 2>&1; then
    ibus restart >/dev/null 2>&1 || true
  fi
}

apply_xfce_style() {
  command -v xfconf-query >/dev/null 2>&1 || return 0

  xfconf_set xsettings /Net/ThemeName string "$GTK_THEME_NAME"
  xfconf_set xsettings /Net/IconThemeName string "$ICON_THEME_NAME"
  xfconf_set xsettings /Gtk/FontName string "$FONT_NAME"

  # Window buttons bên phải theo thói quen Windows: minimize, maximize, close.
  xfconf_set xfwm4 /general/theme string "$GTK_THEME_NAME"
  xfconf_set xfwm4 /general/button_layout string "|HMC"
  xfconf_set xfwm4 /general/title_alignment string "left"
  xfconf_set xfwm4 /general/easy_click string "Alt"
  xfconf_set xfwm4 /general/workspace_count int "1"
  xfconf_set xfwm4 /general/use_compositing bool "true"

  # Icon desktop lớn vừa đủ cho người dùng dễ nhìn.
  xfconf_set xfce4-desktop /desktop-icons/style int "2"
  xfconf_set xfce4-desktop /desktop-icons/icon-size uint "48"
  xfconf_set xfce4-desktop /desktop-icons/show-tooltips bool "true"
  xfconf_set xfce4-desktop /desktop-icons/file-icons/show-trash bool "true"
  xfconf_set xfce4-desktop /desktop-icons/file-icons/show-home bool "false"
  xfconf_set xfce4-desktop /desktop-icons/file-icons/show-filesystem bool "false"
  xfconf_set xfce4-desktop /desktop-icons/file-icons/show-removable bool "false"

  # Phím tắt quen thuộc: Super mở Start, Super+E mở File Explorer, Super+I mở Settings.
  if command -v edulab-start-menu >/dev/null 2>&1; then
    xfconf_set xfce4-keyboard-shortcuts "/commands/custom/Super_L" string "edulab-start-menu"
  else
    xfconf_set xfce4-keyboard-shortcuts "/commands/custom/Super_L" string "xfce4-popup-whiskermenu"
  fi
  xfconf_set xfce4-keyboard-shortcuts "/commands/custom/<Super>e" string "edulab-open-files"
  xfconf_set xfce4-keyboard-shortcuts "/commands/custom/<Super>i" string "edulab-open-settings"

  apply_xfce_taskbar
  configure_taskbar_search_autostart
  apply_file_explorer_style
  apply_input_switcher_style
  trust_desktop_launchers
  apply_xfce_wallpaper "$1"

  # Nạp lại panel để thay đổi ổn định hơn. Nếu đang thi hoặc đang mở app, lệnh này chỉ restart panel.
  if command -v xfce4-panel >/dev/null 2>&1; then
    xfce4-panel -r >/dev/null 2>&1 || true
  fi
  start_taskbar_search
}

apply_cinnamon_style() {
  local wallpaper="$1"

  gsettings_set_if_exists org.cinnamon.desktop.interface gtk-theme "'$GTK_THEME_NAME'"
  gsettings_set_if_exists org.cinnamon.desktop.interface icon-theme "'$ICON_THEME_NAME'"
  gsettings_set_if_exists org.cinnamon.desktop.interface font-name "'$FONT_NAME'"
  gsettings_set_if_exists org.cinnamon.theme name "'$GTK_THEME_NAME'"

  if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
    gsettings_set_if_exists org.cinnamon.desktop.background picture-uri "'file://$wallpaper'"
  fi

  gsettings_set_key_if_exists org.nemo.desktop trash-icon-visible "true"
  gsettings_set_key_if_exists org.nemo.desktop home-icon-visible "false"
  gsettings_set_key_if_exists org.nemo.desktop computer-icon-visible "false"
}

main() {
  local current_user="${USER:-}"
  if [[ -z "$current_user" ]]; then
    current_user="$(id -un 2>/dev/null || printf 'unknown')"
  fi

  log "Áp giao diện EduLab Windows 10-like cho user: $current_user"

  local wallpaper
  wallpaper="$(prepare_wallpaper || true)"

  apply_common_gtk_style
  apply_notification_style
  apply_xfce_style "$wallpaper"
  apply_cinnamon_style "$wallpaper"

  log "Hoàn tất. Đăng xuất/đăng nhập lại nếu panel hoặc wallpaper chưa đổi ngay."
}

main "$@"
