#!/usr/bin/env bash
# Cài đặt bộ máy trạm EduLab cho phòng máy IC3.
# Script này ưu tiên Ubuntu/Xubuntu/Kubuntu LTS và Linux Mint dựa trên Ubuntu.
# Mặc định không cài Microsoft Edge vì Edge dùng tên và icon Microsoft.

set -Eeuo pipefail

PROJECT_NAME="EduLab Linux"
LOG_FILE="/var/log/edulab-install.log"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

GTK_THEME_NAME="Windows 10"
ICON_THEME_NAME="Windows 10"
FONT_NAME="Noto Sans 10"
WIN10_GTK_THEME_REPO="https://github.com/B00merang-Project/Windows-10.git"
WIN10_ICON_THEME_REPO="https://github.com/B00merang-Artwork/Windows-10.git"
WIN10_THEME_BRANCH="${WIN10_THEME_BRANCH:-master}"
WIN10_WALLPAPER_NAME="windows-10-blue-gradient.jpg"
WIN10_WALLPAPER_DOWNLOAD_NAME="Wallpaper Alchemy - Hình Nền Gradient Xanh Mặc Định Windows 10 4K.jpg"
WIN10_SYSTEM_WALLPAPER="/usr/share/backgrounds/edulab/$WIN10_WALLPAPER_NAME"

TARGET_USER="${TARGET_USER:-${EDULAB_TARGET_USER:-}}"

LMS_URL="${LMS_URL:-}"
BROWSER_CHOICE="${BROWSER_CHOICE:-chrome}"
INSTALL_ONLYOFFICE=1
ALLOW_MICROSOFT_EDGE=0
DRY_RUN=0
APT_UPDATED=0

usage() {
  cat <<'USAGE'
EduLab Linux - install-edulab.sh

Cách dùng:
  sudo bash scripts/install-edulab.sh [tùy chọn]

Tùy chọn thường dùng:
  --target-user USER              Tài khoản hiện có cần cài giao diện. Mặc định: user đang gọi sudo
  --lms-url URL                   Địa chỉ LMS để tạo shortcut và chính sách trình duyệt. Mặc định: bỏ qua
  --browser chrome|chromium|edge|none
                                  Trình duyệt cần cài. Mặc định: chrome
  --allow-microsoft-edge          Bắt buộc nếu chọn --browser edge
  --no-onlyoffice                 Không cài ONLYOFFICE Desktop Editors
  --dry-run                       Chỉ in thao tác, không thay đổi hệ thống
  -h, --help                      Hiển thị trợ giúp

Ví dụ:
  sudo bash scripts/install-edulab.sh \
    --browser chrome
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  log "LỖI: $*"
  exit 1
}

run() {
  log "+ $*"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$@"
  fi
}

write_root_file() {
  local path="$1"
  local content="$2"
  log "+ ghi file $path"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    install -d -m 0755 "$(dirname "$path")"
    printf '%s\n' "$content" >"$path"
  else
    printf '%s\n' "$content"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target-user)
        TARGET_USER="${2:-}"
        shift 2
        ;;
      --target-user=*)
        TARGET_USER="${1#*=}"
        shift
        ;;
      --lms-url)
        LMS_URL="${2:-}"
        shift 2
        ;;
      --browser)
        BROWSER_CHOICE="${2:-}"
        shift 2
        ;;
      --allow-microsoft-edge)
        ALLOW_MICROSOFT_EDGE=1
        shift
        ;;
      --no-onlyoffice)
        INSTALL_ONLYOFFICE=0
        shift
        ;;
      --dry-run)
        DRY_RUN=1
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
}

resolve_target_user() {
  if [[ -n "$TARGET_USER" ]]; then
    return
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
  elif [[ -n "${USER:-}" && "${USER:-}" != "root" ]]; then
    TARGET_USER="$USER"
  else
    TARGET_USER="$(id -un 2>/dev/null || true)"
  fi
}

setup_logging() {
  if [[ "$DRY_RUN" -eq 0 ]]; then
    install -d -m 0755 "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
}

validate_config() {
  [[ -n "$TARGET_USER" ]] || die "Không xác định được user cần cài. Hãy chạy bằng sudo từ user thật hoặc truyền --target-user USER."
  [[ "$TARGET_USER" != "root" ]] || die "Không cài giao diện Desktop cho root. Hãy chạy sudo từ user hiện tại hoặc truyền --target-user USER thật."
  [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || \
    die "Tên tài khoản '$TARGET_USER' không hợp lệ. Chỉ dùng chữ thường, số, _, - và bắt đầu bằng chữ/_"

  if [[ -n "$LMS_URL" ]]; then
    [[ "$LMS_URL" =~ ^https?:// ]] || die "LMS_URL phải bắt đầu bằng http:// hoặc https://"
    [[ "$LMS_URL" != *\"* && "$LMS_URL" != *\\* ]] || die "LMS_URL không được chứa dấu ngoặc kép hoặc dấu \\."
  fi

  case "$BROWSER_CHOICE" in
    chrome|chromium|edge|none) ;;
    *) die "--browser chỉ nhận: chrome, chromium, edge, none" ;;
  esac

  if [[ "$BROWSER_CHOICE" == "edge" && "$ALLOW_MICROSOFT_EDGE" -ne 1 ]]; then
    die "Microsoft Edge dùng tên/icon Microsoft. Nếu khách hàng chấp thuận, chạy lại với --allow-microsoft-edge."
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    id "$TARGET_USER" >/dev/null 2>&1 || die "Không tìm thấy tài khoản hiện có: $TARGET_USER."
  fi
}

require_root_for_changes() {
  if [[ "$DRY_RUN" -eq 0 && "${EUID}" -ne 0 ]]; then
    die "Hãy chạy bằng sudo: sudo bash scripts/install-edulab.sh ..."
  fi
}

check_platform() {
  command -v apt-get >/dev/null 2>&1 || die "Script này chỉ hỗ trợ hệ Debian/Ubuntu dùng apt."
  command -v dpkg >/dev/null 2>&1 || die "Không tìm thấy dpkg."

  local arch
  arch="$(dpkg --print-architecture)"
  [[ "$arch" == "amd64" ]] || die "Bản triển khai này chỉ hỗ trợ máy 64-bit amd64/x86_64. Kiến trúc hiện tại: $arch"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local id_like="${ID_LIKE:-}"
    case " ${ID:-} ${id_like} " in
      *ubuntu*|*debian*)
        log "Hệ điều hành phát hiện: ${PRETTY_NAME:-không rõ}"
        ;;
      *)
        log "CẢNH BÁO: Chưa xác nhận distro này: ${PRETTY_NAME:-không rõ}. Tiếp tục vì có apt."
        ;;
    esac
  fi
}

apt_update() {
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    run apt-get update
    APT_UPDATED=1
  fi
}

apt_install() {
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

apt_install_available() {
  local available=()
  local pkg

  apt_update
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      log "Bỏ qua gói chưa có trong repo hiện tại: $pkg"
    fi
  done

  if [[ "${#available[@]}" -gt 0 ]]; then
    apt_install "${available[@]}"
  fi
}

install_gpg_key_from_url() {
  local url="$1"
  local keyring="$2"
  local extra_url="${3:-}"

  log "+ cài khóa GPG: $keyring"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: tải khóa từ $url"
    [[ -n "$extra_url" ]] && log "DRY-RUN: tải thêm khóa từ $extra_url"
    return
  fi

  local tmp_asc tmp_gpg
  tmp_asc="$(mktemp)"
  tmp_gpg="$(mktemp)"

  curl -fsSL "$url" -o "$tmp_asc"
  if [[ -n "$extra_url" ]]; then
    curl -fsSL "$extra_url" >>"$tmp_asc" || log "CẢNH BÁO: không tải được khóa phụ $extra_url"
  fi

  gpg --dearmor <"$tmp_asc" >"$tmp_gpg"
  install -m 0644 "$tmp_gpg" "$keyring"
  rm -f "$tmp_asc" "$tmp_gpg"
}

install_git_asset_tree() {
  local label="$1"
  local repo="$2"
  local branch="$3"
  local target="$4"
  local tmp_dir

  log "Cài $label từ $repo."

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: sẽ clone nhánh $branch vào $target"
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    log "CẢNH BÁO: Không tìm thấy git, bỏ qua $label."
    return
  fi

  tmp_dir="$(mktemp -d)"
  if git clone --depth 1 --branch "$branch" "$repo" "$tmp_dir"; then
    rm -rf -- "$target"
    install -d -m 0755 "$target"
    cp -a "$tmp_dir/." "$target/"
    rm -rf -- "$target/.git"
    find "$target" -type d -exec chmod 0755 {} +
    find "$target" -type f -exec chmod 0644 {} +
  else
    log "CẢNH BÁO: Không tải được $label. Sẽ dùng theme/icon fallback nếu có."
  fi

  rm -rf -- "$tmp_dir"
}

install_base_packages() {
  log "Cài gói nền, font, bộ gõ và theme mở."
  apt_install_available \
    ca-certificates curl git gnupg lsb-release sudo \
    xdg-utils xdg-user-dirs desktop-file-utils dbus-x11 \
    libglib2.0-bin x11-xkb-utils \
    python3-gi gir1.2-gtk-3.0 \
    gtk2-engines-murrine gtk2-engines-pixbuf hicolor-icon-theme adwaita-icon-theme \
    fonts-dejavu fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji \
    fonts-liberation fonts-crosextra-carlito fonts-crosextra-caladea \
    ibus ibus-gtk ibus-gtk3 ibus-gtk4 ibus-unikey im-config language-pack-vi \
    network-manager-gnome \
    arc-theme papirus-icon-theme thunar thunar-volman xfce4-whiskermenu-plugin \
    xfce4-pulseaudio-plugin xfce4-power-manager xfce4-power-manager-plugins xfce4-notifyd \
    file-roller p7zip-full unzip
}

install_windows10_theme_assets() {
  install_git_asset_tree "GTK/Xfwm theme Windows 10" \
    "$WIN10_GTK_THEME_REPO" "$WIN10_THEME_BRANCH" "/usr/share/themes/$GTK_THEME_NAME"

  install_git_asset_tree "icon theme Windows 10" \
    "$WIN10_ICON_THEME_REPO" "$WIN10_THEME_BRANCH" "/usr/share/icons/$ICON_THEME_NAME"

  if [[ "$DRY_RUN" -eq 0 && -d "/usr/share/icons/$ICON_THEME_NAME" ]]; then
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
      gtk-update-icon-cache -f -q "/usr/share/icons/$ICON_THEME_NAME" || true
    fi
  fi
}

install_wallpaper_assets() {
  log "Cài wallpaper Windows 10-like từ asset của dự án."
  run install -d -m 0755 /usr/share/backgrounds/edulab

  if [[ -f "$PROJECT_DIR/assets/$WIN10_WALLPAPER_NAME" ]]; then
    run install -m 0644 "$PROJECT_DIR/assets/$WIN10_WALLPAPER_NAME" "$WIN10_SYSTEM_WALLPAPER"
  elif [[ -f "$PROJECT_DIR/downloads/$WIN10_WALLPAPER_DOWNLOAD_NAME" ]]; then
    run install -m 0644 "$PROJECT_DIR/downloads/$WIN10_WALLPAPER_DOWNLOAD_NAME" "$WIN10_SYSTEM_WALLPAPER"
  else
    log "CẢNH BÁO: Không tìm thấy wallpaper Windows 10-like, bỏ qua wallpaper."
  fi
}

add_onlyoffice_repo() {
  local keyring="/usr/share/keyrings/onlyoffice.gpg"
  install_gpg_key_from_url "https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE" "$keyring"
  write_root_file "/etc/apt/sources.list.d/onlyoffice.list" \
    "deb [signed-by=$keyring] https://download.onlyoffice.com/repo/debian squeeze main"
  APT_UPDATED=0
}

install_onlyoffice() {
  [[ "$INSTALL_ONLYOFFICE" -eq 1 ]] || {
    log "Bỏ qua ONLYOFFICE theo tùy chọn --no-onlyoffice."
    return
  }

  log "Cài ONLYOFFICE Desktop Editors từ repository chính thức."
  add_onlyoffice_repo
  apt_update
  apt_install onlyoffice-desktopeditors
}

add_google_chrome_repo() {
  local keyring="/usr/share/keyrings/google-linux.gpg"
  install_gpg_key_from_url "https://dl.google.com/linux/linux_signing_key.pub" "$keyring"
  write_root_file "/etc/apt/sources.list.d/google-chrome.list" \
    "deb [arch=amd64 signed-by=$keyring] https://dl.google.com/linux/chrome/deb/ stable main"
  APT_UPDATED=0
}

add_microsoft_edge_repo() {
  local keyring="/usr/share/keyrings/packages.microsoft.gpg"
  install_gpg_key_from_url \
    "https://packages.microsoft.com/keys/microsoft.asc" \
    "$keyring" \
    "https://packages.microsoft.com/keys/microsoft-2025.asc"
  write_root_file "/etc/apt/sources.list.d/microsoft-edge.list" \
    "deb [arch=amd64 signed-by=$keyring] https://packages.microsoft.com/repos/edge stable main"
  APT_UPDATED=0
}

install_browser() {
  case "$BROWSER_CHOICE" in
    chrome)
      log "Cài Google Chrome Stable từ repository chính thức của Google."
      add_google_chrome_repo
      apt_update
      apt_install google-chrome-stable
      ;;
    chromium)
      log "Cài Chromium từ repository của distro nếu có."
      apt_update
      if apt-cache show chromium >/dev/null 2>&1; then
        apt_install chromium
      elif apt-cache show chromium-browser >/dev/null 2>&1; then
        apt_install chromium-browser
      else
        die "Không tìm thấy gói Chromium trong repository hiện tại. Hãy dùng --browser chrome hoặc cài thủ công."
      fi
      ;;
    edge)
      log "Cài Microsoft Edge vì đã có --allow-microsoft-edge. Lưu ý đây là phần mềm có nhận diện Microsoft."
      add_microsoft_edge_repo
      apt_update
      apt_install microsoft-edge-stable
      ;;
    none)
      log "Bỏ qua cài trình duyệt theo tùy chọn --browser none."
      ;;
  esac
}

install_helper_scripts() {
  local first_login
  local open_lms
  local open_settings
  local open_files
  local browser_helper

  first_login='#!/usr/bin/env bash
# Chạy một lần khi user đăng nhập để áp theme và bộ gõ.
set -u

MARKER="$HOME/.config/edulab/desktop-style-v19.done"
mkdir -p "$HOME/.config/edulab"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

if command -v im-config >/dev/null 2>&1; then
  im-config -n ibus >/dev/null 2>&1 || true
fi

if command -v ibus-daemon >/dev/null 2>&1; then
  ibus-daemon -drx >/dev/null 2>&1 || true
fi

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "Windows 10" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface icon-theme "Windows 10" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface font-name "Noto Sans 10" >/dev/null 2>&1 || true
  gsettings set org.cinnamon.desktop.interface gtk-theme "Windows 10" >/dev/null 2>&1 || true
  gsettings set org.cinnamon.desktop.interface icon-theme "Windows 10" >/dev/null 2>&1 || true
  gsettings set org.cinnamon.desktop.interface font-name "Noto Sans 10" >/dev/null 2>&1 || true
fi

if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xsettings -p /Net/ThemeName -s "Windows 10" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Net/IconThemeName -s "Windows 10" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 10" >/dev/null 2>&1 || true
fi

if command -v edulab-apply-desktop-style >/dev/null 2>&1; then
  edulab-apply-desktop-style >/dev/null 2>&1 || true
fi

touch "$MARKER"
'

  open_lms="#!/usr/bin/env bash
# Mở LMS đã cấu hình cho phòng máy.
set -u
exec edulab-browser \"$LMS_URL\"
"

  open_settings='#!/usr/bin/env bash
# Mở trung tâm cài đặt hệ thống bằng công cụ có sẵn của desktop.
set -u

for cmd in xfce4-settings-manager cinnamon-settings gnome-control-center mate-control-center; do
  if command -v "$cmd" >/dev/null 2>&1; then
    exec "$cmd"
  fi
done

exec xdg-open "$HOME/.config"
'

  open_files='#!/usr/bin/env bash
# Mở thư mục cá nhân theo thói quen dùng File Explorer.
set -u

for cmd in thunar nemo caja nautilus dolphin; do
  if command -v "$cmd" >/dev/null 2>&1; then
    exec "$cmd" "$HOME"
  fi
done

exec xdg-open "$HOME"
'

  browser_helper='#!/usr/bin/env bash
# Mở trình duyệt đã cài. Không gắn cứng vào một thương hiệu trong shortcut.
set -u

for cmd in google-chrome-stable google-chrome chromium chromium-browser microsoft-edge firefox; do
  if command -v "$cmd" >/dev/null 2>&1; then
    exec "$cmd" "$@"
  fi
done

exec xdg-open "${1:-about:blank}"
'

  write_root_file "/usr/local/bin/edulab-first-login.sh" "$first_login"
  write_root_file "/usr/local/bin/edulab-open-lms" "$open_lms"
  write_root_file "/usr/local/bin/edulab-open-settings" "$open_settings"
  write_root_file "/usr/local/bin/edulab-open-files" "$open_files"
  write_root_file "/usr/local/bin/edulab-browser" "$browser_helper"
  run rm -f /usr/local/bin/edulab-open-exercises /usr/local/bin/edulab-language-indicator
  run chmod 0755 \
    /usr/local/bin/edulab-first-login.sh \
    /usr/local/bin/edulab-open-lms \
    /usr/local/bin/edulab-open-settings \
    /usr/local/bin/edulab-open-files \
    /usr/local/bin/edulab-browser

  if [[ -f "$SCRIPT_DIR/apply-desktop-style.sh" ]]; then
    run install -m 0755 "$SCRIPT_DIR/apply-desktop-style.sh" /usr/local/bin/edulab-apply-desktop-style
  else
    log "CẢNH BÁO: Không tìm thấy scripts/apply-desktop-style.sh, bỏ qua helper giao diện."
  fi

  if [[ -f "$SCRIPT_DIR/edulab-start-menu.py" ]]; then
    run install -m 0755 "$SCRIPT_DIR/edulab-start-menu.py" /usr/local/bin/edulab-start-menu
  else
    log "CẢNH BÁO: Không tìm thấy scripts/edulab-start-menu.py, bỏ qua Start menu tùy biến."
  fi

  if [[ -f "$SCRIPT_DIR/edulab-input-menu.py" ]]; then
    run install -m 0755 "$SCRIPT_DIR/edulab-input-menu.py" /usr/local/bin/edulab-input-menu
  else
    log "CẢNH BÁO: Không tìm thấy scripts/edulab-input-menu.py, bỏ qua menu bộ gõ tùy biến."
  fi

  run rm -f /usr/local/bin/edulab-search
}

configure_input_method() {
  local content
  content='# Cấu hình bộ gõ tiếng Việt IBus cho toàn hệ thống.
# Người dùng vẫn có thể đổi trong phần Keyboard/Input Method của desktop.
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
'
  write_root_file "/etc/profile.d/edulab-input-method.sh" "$content"
  run chmod 0644 /etc/profile.d/edulab-input-method.sh
}

write_gtk_settings() {
  local base_dir="$1"
  local owner="$2"
  local group="$3"
  local settings="$base_dir/.config/gtk-3.0/settings.ini"
  local gtkrc="$base_dir/.gtkrc-2.0"
  local content

  content='[Settings]
gtk-theme-name=Windows 10
gtk-icon-theme-name=Windows 10
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=false'

  run install -d -m 0755 "$base_dir/.config/gtk-3.0"
  write_root_file "$settings" "$content"
  write_root_file "$gtkrc" 'gtk-theme-name="Windows 10"
gtk-icon-theme-name="Windows 10"
gtk-font-name="Noto Sans 10"'
  run chown -R "$owner:$group" "$base_dir/.config" "$gtkrc"
}

desktop_dir_for_user() {
  local user="$1"
  local home="$2"
  local desktop_dir=""

  if [[ "$DRY_RUN" -eq 0 ]]; then
    runuser -u "$user" -- xdg-user-dirs-update >/dev/null 2>&1 || true
    desktop_dir="$(runuser -u "$user" -- xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi

  if [[ -z "$desktop_dir" || "$desktop_dir" == "$home" ]]; then
    desktop_dir="$home/Desktop"
  fi
  printf '%s\n' "$desktop_dir"
}

desktop_entry_content() {
  local name="$1"
  local comment="$2"
  local exec_cmd="$3"
  local icon="$4"
  local categories="${5:-Utility;}"

  cat <<ENTRY
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$exec_cmd
Icon=$icon
Terminal=false
StartupNotify=true
Categories=$categories
ENTRY
}

install_desktop_entry() {
  local path="$1"
  local owner="$2"
  local group="$3"
  local content="$4"

  write_root_file "$path" "$content"
  run chmod 0755 "$path"
  run chown "$owner:$group" "$path"
  trust_desktop_entry "$path" "$owner"
}

trust_desktop_entry() {
  local path="$1"
  local owner="$2"
  local uid
  local runtime_dir
  local bus_path
  local checksum
  local env_args=()

  [[ "$DRY_RUN" -eq 0 ]] || return 0
  command -v gio >/dev/null 2>&1 || return 0
  id "$owner" >/dev/null 2>&1 || return 0

  uid="$(id -u "$owner")"
  runtime_dir="/run/user/$uid"
  bus_path="$runtime_dir/bus"
  env_args=("XDG_RUNTIME_DIR=$runtime_dir")
  if [[ -S "$bus_path" ]]; then
    env_args+=("DBUS_SESSION_BUS_ADDRESS=unix:path=$bus_path")
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    checksum="$(sha256sum "$path" 2>/dev/null | awk '{print $1}')"
    if [[ -n "$checksum" ]]; then
      runuser -u "$owner" -- env "${env_args[@]}" \
        gio set -t string "$path" metadata::xfce-exe-checksum "$checksum" >/dev/null 2>&1 || true
    fi
  fi
  runuser -u "$owner" -- env "${env_args[@]}" \
    gio set "$path" metadata::trusted true >/dev/null 2>&1 || true
  touch "$path" >/dev/null 2>&1 || true
}

remove_file_if_exists() {
  local path="$1"

  if [[ -e "$path" || -L "$path" ]]; then
    run rm -f -- "$path"
  fi
}

remove_empty_dir_if_exists() {
  local path="$1"

  if [[ -d "$path" && "$DRY_RUN" -eq 0 ]]; then
    rmdir --ignore-fail-on-non-empty -- "$path" 2>/dev/null || true
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    log "+ xóa thư mục nếu rỗng: $path"
  fi
}

install_shortcuts_to_dir() {
  local target_dir="$1"
  local owner="$2"
  local group="$3"
  local browser_icon="web-browser"
  local browser_exec="edulab-browser"

  case "$BROWSER_CHOICE" in
    chrome) browser_icon="google-chrome" ;;
    chromium) browser_icon="chromium" ;;
    edge) browser_icon="microsoft-edge" ;;
  esac

  run install -d -m 0755 "$target_dir"
  run chown "$owner:$group" "$target_dir"
  remove_file_if_exists "$target_dir/Bai-tap.desktop"
  remove_file_if_exists "$target_dir/Tep.desktop"
  remove_file_if_exists "$target_dir/Cai-dat.desktop"

  install_desktop_entry "$target_dir/ONLYOFFICE.desktop" "$owner" "$group" \
    "$(desktop_entry_content "ONLYOFFICE" "Soạn thảo văn bản, bảng tính và trình chiếu" "desktopeditors" "onlyoffice-desktopeditors" "Office;")"

  if [[ "$BROWSER_CHOICE" != "none" ]]; then
    install_desktop_entry "$target_dir/Trinh-duyet.desktop" "$owner" "$group" \
      "$(desktop_entry_content "Trình duyệt" "Mở trình duyệt web" "$browser_exec" "$browser_icon" "Network;WebBrowser;")"
  fi

  install_desktop_entry "$target_dir/File-Explorer.desktop" "$owner" "$group" \
    "$(desktop_entry_content "File Explorer" "Mở thư mục cá nhân" "edulab-open-files" "system-file-manager" "Utility;FileManager;")"

  install_desktop_entry "$target_dir/Settings.desktop" "$owner" "$group" \
    "$(desktop_entry_content "Settings" "Mở cài đặt hệ thống" "edulab-open-settings" "preferences-system" "Settings;")"

  if [[ -n "$LMS_URL" ]]; then
    install_desktop_entry "$target_dir/LMS.desktop" "$owner" "$group" \
      "$(desktop_entry_content "LMS" "Mở hệ thống học tập trực tuyến" "edulab-open-lms" "web-browser" "Network;")"
  fi
}

configure_target_desktop() {
  local home
  local group
  local desktop_dir

  home="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  [[ -n "$home" ]] || die "Không tìm thấy home của $TARGET_USER."
  group="$(id -gn "$TARGET_USER")"

  log "Tạo shortcut và cấu hình desktop cho $TARGET_USER."
  remove_empty_dir_if_exists "$home/Bai-tap"

  write_gtk_settings "$home" "$TARGET_USER" "$group"

  run install -d -m 0755 "$home/.config/autostart"
  install_desktop_entry "$home/.config/autostart/edulab-first-login.desktop" "$TARGET_USER" "$group" \
    "$(desktop_entry_content "EduLab First Login" "Áp cấu hình EduLab khi đăng nhập" "/usr/local/bin/edulab-first-login.sh" "preferences-desktop" "Settings;")"

  desktop_dir="$(desktop_dir_for_user "$TARGET_USER" "$home")"
  install_shortcuts_to_dir "$desktop_dir" "$TARGET_USER" "$group"
}

configure_browser_policy() {
  local policy

  if [[ -z "$LMS_URL" ]]; then
    log "Không cấu hình homepage/chính sách trình duyệt vì chưa đặt LMS_URL."
    return
  fi

  policy="{
  \"HomepageLocation\": \"$LMS_URL\",
  \"HomepageIsNewTabPage\": false,
  \"RestoreOnStartup\": 4,
  \"RestoreOnStartupURLs\": [\"$LMS_URL\"],
  \"BookmarkBarEnabled\": true
}"

  case "$BROWSER_CHOICE" in
    chrome)
      write_root_file "/etc/opt/chrome/policies/managed/edulab.json" "$policy"
      ;;
    chromium)
      write_root_file "/etc/chromium/policies/managed/edulab.json" "$policy"
      ;;
    edge)
      write_root_file "/etc/opt/edge/policies/managed/edulab.json" "$policy"
      ;;
    none)
      log "Không ghi chính sách trình duyệt vì --browser none."
      ;;
  esac
}

write_install_state() {
  local lms_configured=0

  [[ -n "$LMS_URL" ]] && lms_configured=1

  # Ghi trạng thái tối thiểu để script gỡ biết user và lựa chọn app đã cài.
  run install -d -m 0755 /var/lib/edulab
  write_root_file "/var/lib/edulab/install-state.env" \
    "TARGET_USER=$TARGET_USER
BROWSER_CHOICE=$BROWSER_CHOICE
INSTALL_ONLYOFFICE=$INSTALL_ONLYOFFICE
LMS_CONFIGURED=$lms_configured"
  run chmod 0644 /var/lib/edulab/install-state.env
}

main() {
  parse_args "$@"
  resolve_target_user
  validate_config
  require_root_for_changes
  setup_logging

  log "Bắt đầu cài đặt $PROJECT_NAME."
  check_platform
  install_base_packages
  install_windows10_theme_assets
  install_wallpaper_assets
  install_browser
  install_onlyoffice
  install_helper_scripts
  configure_input_method
  configure_target_desktop
  configure_browser_policy
  write_install_state

  if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database /usr/share/applications
  fi

  log "Hoàn tất. Hãy đăng xuất/đăng nhập lại tài khoản $TARGET_USER để kiểm thử."
  log "Log cài đặt: $LOG_FILE"
}

main "$@"
