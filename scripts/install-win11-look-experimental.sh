#!/usr/bin/env bash
# THỬ NGHIỆM giao diện kiểu Win11 cho Linux Mint/Xfce.
# Không dùng trong bản bàn giao khách hàng nếu chính sách là tránh nhận diện Microsoft.
# Lý do: license mã nguồn mở không tự động xử lý rủi ro trademark/trade dress.

set -Eeuo pipefail

THEME_REPO_URL="https://github.com/yeyushengfan258/Win11-gtk-theme/archive/refs/heads/main.zip"
ICON_REPO_URL="https://github.com/yeyushengfan258/We10X-icon-theme/archive/refs/heads/master.zip"
THEME_NAME="Win11-Experiment"
ICON_NAME="We10X"
WORK_DIR=""
SKIP_DEPS=0
HEAVY_PANEL=0
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
USER_BG_DIR="$HOME/.local/share/backgrounds/edulab"
EXPERIMENTAL_WALLPAPER="$USER_BG_DIR/win11-experimental-wallpaper.svg"

usage() {
  cat <<'USAGE'
EduLab experimental Win11 look

Cách dùng:
  bash scripts/install-win11-look-experimental.sh
  bash scripts/install-win11-look-experimental.sh --skip-deps
  bash scripts/install-win11-look-experimental.sh --skip-deps --heavy-panel

Script này:
  - Cài dependency build theme qua apt nếu cần.
  - Tải Win11 GTK theme và We10X icon theme từ GitHub.
  - Cài vào home user hiện tại: ~/.local/share/themes và ~/.local/share/icons.
  - Áp theme/icon cho Xfce/Cinnamon nếu có công cụ cấu hình.
  - --heavy-panel sẽ thay panel Xfce hiện tại bằng bố cục taskbar icon-centered.

  Lưu ý:
  Dùng để thử nghiệm giao diện trong VM/lab. Không bật mặc định trong image thương mại.
USAGE
}

log() {
  printf '[win11-experimental] %s\n' "$*"
}

die() {
  log "LỖI: $*"
  exit 1
}

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

require_tools() {
  command -v curl >/dev/null 2>&1 || die "Thiếu curl."
  command -v unzip >/dev/null 2>&1 || die "Thiếu unzip."
  command -v sassc >/dev/null 2>&1 || die "Thiếu sassc. Hãy cài bằng admin: sudo apt install sassc"
}

install_dependencies() {
  if [[ "$SKIP_DEPS" -eq 1 ]]; then
    log "Bỏ qua cài dependency theo tùy chọn --skip-deps."
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log "Không phải hệ apt, bỏ qua cài dependency tự động."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    log "Không tìm thấy sudo, bỏ qua cài dependency tự động."
    return
  fi

  if ! sudo -n true >/dev/null 2>&1; then
    log "Cần quyền admin để cài dependency. Nếu được hỏi mật khẩu, nhập mật khẩu admin."
    if ! sudo true; then
      log "User hiện tại không được phép sudo."
      log "Hãy cài dependency bằng admin trước rồi chạy lại với --skip-deps."
      return
    fi
  fi

  log "Cài dependency build theme nếu thiếu."
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl unzip sassc gtk2-engines-murrine gnome-themes-extra

  # Plugin Xfce là phần phụ trợ cho panel mạnh hơn. Một số distro/repo không có gói này,
  # nên không để nó làm hỏng toàn bộ quá trình cài theme.
  if apt-cache show xfce4-whiskermenu-plugin >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xfce4-whiskermenu-plugin || true
  fi

  if apt-cache show xfce4-docklike-plugin >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xfce4-docklike-plugin || true
  else
    log "Repository hiện tại không có xfce4-docklike-plugin, bỏ qua taskbar docklike."
    return
  fi
}

theme_assets_present() {
  compgen -G "$HOME/.local/share/themes/$THEME_NAME*" >/dev/null 2>&1 &&
    compgen -G "$HOME/.local/share/icons/$ICON_NAME*" >/dev/null 2>&1
}

download_and_unpack() {
  WORK_DIR="$(mktemp -d /tmp/edulab-win11-look.XXXXXX)"
  log "Tải theme vào $WORK_DIR."

  curl -fL "$THEME_REPO_URL" -o "$WORK_DIR/win11-gtk-theme.zip"
  curl -fL "$ICON_REPO_URL" -o "$WORK_DIR/we10x-icon-theme.zip"

  unzip -q "$WORK_DIR/win11-gtk-theme.zip" -d "$WORK_DIR"
  unzip -q "$WORK_DIR/we10x-icon-theme.zip" -d "$WORK_DIR"
}

install_theme() {
  local theme_src="$WORK_DIR/Win11-gtk-theme-main"
  local icon_src="$WORK_DIR/We10X-icon-theme-master"

  [[ -x "$theme_src/install.sh" ]] || die "Không tìm thấy install.sh của Win11 GTK theme."
  [[ -x "$icon_src/install.sh" ]] || die "Không tìm thấy install.sh của We10X icon theme."

  mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons"

  log "Cài Win11 GTK theme vào user hiện tại."
  (
    cd "$theme_src"
    ./install.sh \
      --dest "$HOME/.local/share/themes" \
      --name "$THEME_NAME" \
      --theme default \
      --color light \
      --size standard \
      --tweaks square solid
  )

  log "Cài We10X icon theme vào user hiện tại."
  (
    cd "$icon_src"
    ./install.sh \
      --dest "$HOME/.local/share/icons" \
      --name "$ICON_NAME" \
      --theme blue
  )
}

prepare_wallpaper() {
  mkdir -p "$USER_BG_DIR"

  if [[ -f "$PROJECT_DIR/assets/win11-experimental-wallpaper.svg" ]]; then
    cp "$PROJECT_DIR/assets/win11-experimental-wallpaper.svg" "$EXPERIMENTAL_WALLPAPER"
  else
    log "Không tìm thấy wallpaper experimental trong project, bỏ qua wallpaper."
  fi
}

detect_installed_theme() {
  local candidate
  for candidate in \
    "$HOME/.local/share/themes/$THEME_NAME" \
    "$HOME/.local/share/themes/$THEME_NAME-light" \
    "$HOME/.local/share/themes/$THEME_NAME-Light" \
    "$HOME/.local/share/themes"/"$THEME_NAME"*; do
    if [[ -d "$candidate" ]]; then
      basename "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$THEME_NAME"
}

detect_installed_icon() {
  local candidate
  for candidate in \
    "$HOME/.local/share/icons/$ICON_NAME" \
    "$HOME/.local/share/icons/$ICON_NAME-blue" \
    "$HOME/.local/share/icons"/"$ICON_NAME"*; do
    if [[ -d "$candidate" ]]; then
      basename "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$ICON_NAME"
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

backup_xfce_panel() {
  local src="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
  local dst_dir="$HOME/.config/edulab/backups"
  local stamp

  [[ -f "$src" ]] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "$dst_dir"
  cp "$src" "$dst_dir/xfce4-panel.$stamp.xml"
  log "Đã backup panel cũ: $dst_dir/xfce4-panel.$stamp.xml"
}

set_panel_plugin_type() {
  local id="$1"
  local plugin_type="$2"
  xfconf_set xfce4-panel "/plugins/plugin-$id" string "$plugin_type"
}

apply_win11_css() {
  mkdir -p "$HOME/.config/gtk-3.0"

  cat > "$HOME/.config/gtk-3.0/gtk.css" <<'EOF'
.xfce4-panel {
  background-color: rgba(248, 250, 252, 0.94);
  border-top: 1px solid rgba(15, 23, 42, 0.16);
}

.xfce4-panel button,
.xfce4-panel .flat,
.xfce4-panel .toggle {
  border-radius: 9px;
  margin: 4px 2px;
  padding: 3px 7px;
  color: #111827;
}

.xfce4-panel button:hover {
  background-color: rgba(59, 130, 246, 0.14);
}

#whiskermenu-button {
  border-radius: 10px;
  padding-left: 10px;
  padding-right: 10px;
}
EOF
}

apply_heavy_xfce_panel() {
  command -v xfconf-query >/dev/null 2>&1 || return 0

  if ! panel_plugin_available docklike; then
    log "Chưa có xfce4-docklike-plugin nên chưa bật được taskbar icon-centered."
    log "Cài bằng admin: sudo apt install xfce4-docklike-plugin"
    return
  fi

  backup_xfce_panel
  apply_win11_css

  local ids=()
  local id=101

  # Nhóm Start + taskbar nằm giữa nhờ hai separator expand hai bên.
  set_panel_plugin_type "$id" separator
  xfconf_set xfce4-panel "/plugins/plugin-$id/expand" bool "true"
  xfconf_set xfce4-panel "/plugins/plugin-$id/style" uint "0"
  ids+=("$id")
  id=$((id + 1))

  if panel_plugin_available whiskermenu; then
    set_panel_plugin_type "$id" whiskermenu
    xfconf_set xfce4-panel "/plugins/plugin-$id/button-icon" string "view-app-grid-symbolic"
    xfconf_set xfce4-panel "/plugins/plugin-$id/button-title" string ""
    xfconf_set xfce4-panel "/plugins/plugin-$id/show-button-title" bool "false"
    ids+=("$id")
    id=$((id + 1))
  fi

  set_panel_plugin_type "$id" docklike
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
      ids+=("$id")
      id=$((id + 1))
    fi
  done

  xfconf_int_array xfce4-panel /panels 1
  xfconf_int_array xfce4-panel /panels/panel-1/plugin-ids "${ids[@]}"
  xfconf_set xfce4-panel /panels/panel-1/position string "p=12;x=0;y=0"
  xfconf_set xfce4-panel /panels/panel-1/length uint "100"
  xfconf_set xfce4-panel /panels/panel-1/size uint "52"
  xfconf_set xfce4-panel /panels/panel-1/nrows uint "1"
  xfconf_set xfce4-panel /panels/panel-1/mode uint "0"
  xfconf_set xfce4-panel /panels/panel-1/autohide-behavior uint "0"
  xfconf_set xfce4-panel /panels/panel-1/position-locked bool "true"
  xfconf_set xfce4-panel /panels/panel-1/icon-size uint "30"

  log "Đã áp heavy panel: Start + Docklike Taskbar căn giữa."
}

xfconf_set_plugin_if_type() {
  local plugin_type="$1"
  local property_suffix="$2"
  local type="$3"
  local value="$4"
  local prop
  local id

  command -v xfconf-query >/dev/null 2>&1 || return 0
  xfconf-query -c xfce4-panel -l 2>/dev/null | grep '^/plugins/plugin-[0-9]\+$' | while read -r prop; do
    if [[ "$(xfconf-query -c xfce4-panel -p "$prop" 2>/dev/null || true)" == "$plugin_type" ]]; then
      id="${prop##*/}"
      xfconf_set xfce4-panel "/plugins/$id/$property_suffix" "$type" "$value"
    fi
  done
}

apply_theme() {
  local theme
  local icon

  theme="$(detect_installed_theme)"
  icon="$(detect_installed_icon)"

  log "Áp GTK theme: $theme"
  log "Áp icon theme: $icon"

  if command -v xfconf-query >/dev/null 2>&1; then
    xfconf_set xsettings /Net/ThemeName string "$theme"
    xfconf_set xsettings /Net/IconThemeName string "$icon"
    xfconf_set xsettings /Gtk/FontName string "Noto Sans 10"
    xfconf_set xfwm4 /general/theme string "$theme"
    xfconf_set xfwm4 /general/button_layout string "|HMC"
    xfconf_set xfce4-panel /panels/panel-1/position string "p=12;x=0;y=0"
    xfconf_set xfce4-panel /panels/panel-1/length uint "100"
    xfconf_set xfce4-panel /panels/panel-1/size uint "48"
    xfconf_set xfce4-panel /panels/panel-1/position-locked bool "true"
    xfconf_set xfce4-panel /panels/panel-1/background-style uint "1"
    xfconf_set xfce4-panel /panels/panel-1/dark-mode bool "false"
    xfconf_set xfce4-panel /panels/panel-1/icon-size uint "28"

    # Đổi nút menu thành biểu tượng app-grid trung tính, không dùng logo Microsoft.
    xfconf_set_plugin_if_type whiskermenu button-icon string "view-app-grid-symbolic"
    xfconf_set_plugin_if_type whiskermenu button-title string ""
    xfconf_set_plugin_if_type whiskermenu show-button-title bool "false"

    if [[ -f "$EXPERIMENTAL_WALLPAPER" ]]; then
      xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' | while read -r prop; do
        xfconf-query -c xfce4-desktop -p "$prop" -s "$EXPERIMENTAL_WALLPAPER" >/dev/null 2>&1 || true
      done
      xfconf_set xfce4-desktop /desktop-icons/icon-size uint "44"
    fi

    xfce4-panel -r >/dev/null 2>&1 || true
  fi

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.cinnamon.desktop.interface gtk-theme "$theme" >/dev/null 2>&1 || true
    gsettings set org.cinnamon.desktop.interface icon-theme "$icon" >/dev/null 2>&1 || true
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-deps)
        SKIP_DEPS=1
        shift
        ;;
      --heavy-panel)
        HEAVY_PANEL=1
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

  log "Bắt đầu thử nghiệm Win11-like GTK theme cho user: $USER"
  log "Nguồn theme: $THEME_REPO_URL"
  log "Nguồn icon:  $ICON_REPO_URL"

  install_dependencies
  require_tools
  prepare_wallpaper
  if theme_assets_present; then
    log "Theme/icon đã có trong home, bỏ qua tải lại."
  else
    download_and_unpack
    install_theme
  fi
  apply_theme
  if [[ "$HEAVY_PANEL" -eq 1 ]]; then
    apply_heavy_xfce_panel
    xfce4-panel -r >/dev/null 2>&1 || true
  fi

  log "Xong. Hãy logout/login lại nếu cửa sổ hoặc panel chưa đổi ngay."
}

main "$@"
