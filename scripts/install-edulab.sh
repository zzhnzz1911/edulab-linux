#!/usr/bin/env bash
# Cài đặt bộ máy trạm EduLab cho phòng máy IC3.
# Script này ưu tiên Ubuntu/Xubuntu/Kubuntu LTS và Linux Mint dựa trên Ubuntu.
# Mặc định không cài Microsoft Edge vì Edge dùng tên và icon Microsoft.

set -Eeuo pipefail

PROJECT_NAME="EduLab Linux"
LOG_FILE="/var/log/edulab-install.log"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

STUDENT_USER="${STUDENT_USER:-student}"
STUDENT_FULLNAME="${STUDENT_FULLNAME:-Hoc sinh}"
STUDENT_PASSWORD="${STUDENT_PASSWORD:-Student@123}"
RESET_STUDENT_PASSWORD=0

LMS_URL="${LMS_URL:-}"
BROWSER_CHOICE="${BROWSER_CHOICE:-chrome}"
EXERCISES_DIR_NAME="${EXERCISES_DIR_NAME:-Bai-tap}"
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
  --student-user USER             Tên tài khoản học sinh. Mặc định: student
  --student-fullname NAME         Tên hiển thị. Mặc định: Hoc sinh
  --student-password PASSWORD     Mật khẩu khi tạo tài khoản mới. Mặc định: Student@123
  --reset-student-password        Đổi mật khẩu nếu tài khoản học sinh đã tồn tại
  --lms-url URL                   Địa chỉ LMS để tạo shortcut và chính sách trình duyệt. Mặc định: bỏ qua
  --browser chrome|chromium|edge|none
                                  Trình duyệt cần cài. Mặc định: chrome
  --allow-microsoft-edge          Bắt buộc nếu chọn --browser edge
  --no-onlyoffice                 Không cài ONLYOFFICE Desktop Editors
  --dry-run                       Chỉ in thao tác, không thay đổi hệ thống
  -h, --help                      Hiển thị trợ giúp

Ví dụ:
  sudo bash scripts/install-edulab.sh \
    --student-user student \
    --student-password 'Student@123' \
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
      --student-user)
        STUDENT_USER="${2:-}"
        shift 2
        ;;
      --student-fullname)
        STUDENT_FULLNAME="${2:-}"
        shift 2
        ;;
      --student-password)
        STUDENT_PASSWORD="${2:-}"
        shift 2
        ;;
      --reset-student-password)
        RESET_STUDENT_PASSWORD=1
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

setup_logging() {
  if [[ "$DRY_RUN" -eq 0 ]]; then
    install -d -m 0755 "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
}

validate_config() {
  [[ -n "$STUDENT_USER" ]] || die "Tên tài khoản học sinh không được trống."
  [[ "$STUDENT_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || \
    die "Tên tài khoản '$STUDENT_USER' không hợp lệ. Chỉ dùng chữ thường, số, _, - và bắt đầu bằng chữ/_"

  [[ -n "$STUDENT_PASSWORD" ]] || die "Mật khẩu học sinh không được trống."
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

install_base_packages() {
  log "Cài gói nền, font, bộ gõ và theme mở."
  apt_install_available \
    ca-certificates curl gnupg lsb-release sudo \
    xdg-utils xdg-user-dirs desktop-file-utils dbus-x11 \
    fonts-dejavu fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji \
    fonts-liberation fonts-crosextra-carlito fonts-crosextra-caladea \
    ibus ibus-gtk ibus-gtk3 ibus-gtk4 ibus-unikey im-config language-pack-vi \
    arc-theme papirus-icon-theme xfce4-whiskermenu-plugin file-roller p7zip-full unzip
}

install_wallpaper_assets() {
  log "Cài wallpaper EduLab trung tính, không dùng tài sản thương hiệu Microsoft."
  run install -d -m 0755 /usr/share/backgrounds/edulab

  if [[ -f "$PROJECT_DIR/assets/edulab-familiar-wallpaper.svg" ]]; then
    run install -m 0644 "$PROJECT_DIR/assets/edulab-familiar-wallpaper.svg" \
      /usr/share/backgrounds/edulab/edulab-familiar-wallpaper.svg
  else
    log "CẢNH BÁO: Không tìm thấy assets/edulab-familiar-wallpaper.svg, bỏ qua wallpaper."
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

create_student_user() {
  local user_created=0

  if id "$STUDENT_USER" >/dev/null 2>&1; then
    log "Tài khoản $STUDENT_USER đã tồn tại."
  else
    log "Tạo tài khoản học sinh: $STUDENT_USER"
    run useradd -m -s /bin/bash -c "$STUDENT_FULLNAME" "$STUDENT_USER"
    user_created=1
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ "$user_created" -eq 1 || "$RESET_STUDENT_PASSWORD" -eq 1 ]]; then
      log "Thiết lập mật khẩu cho $STUDENT_USER."
      printf '%s:%s\n' "$STUDENT_USER" "$STUDENT_PASSWORD" | chpasswd
      passwd -u "$STUDENT_USER" >/dev/null 2>&1 || true
    else
      log "Không đổi mật khẩu tài khoản đã tồn tại. Dùng --reset-student-password nếu cần."
    fi

    if id -nG "$STUDENT_USER" | grep -Eq '(^| )(sudo|admin)( |$)'; then
      log "CẢNH BÁO: $STUDENT_USER đang thuộc nhóm quản trị. Nên bỏ quyền sudo trước khi bàn giao phòng máy."
    fi
  fi
}

install_helper_scripts() {
  local first_login
  local open_exercises
  local open_lms
  local browser_helper

  first_login='#!/usr/bin/env bash
# Chạy một lần khi học sinh đăng nhập để áp theme và bộ gõ.
set -u

MARKER="$HOME/.config/edulab/first-login.done"
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
  gsettings set org.gnome.desktop.interface gtk-theme "Arc" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface icon-theme "Papirus" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface font-name "Noto Sans 10" >/dev/null 2>&1 || true
  gsettings set org.cinnamon.desktop.interface gtk-theme "Arc" >/dev/null 2>&1 || true
  gsettings set org.cinnamon.desktop.interface icon-theme "Papirus" >/dev/null 2>&1 || true
  gsettings set org.cinnamon.desktop.interface font-name "Noto Sans 10" >/dev/null 2>&1 || true
fi

if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xsettings -p /Net/ThemeName -s "Arc" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 10" >/dev/null 2>&1 || true
fi

if command -v edulab-apply-desktop-style >/dev/null 2>&1; then
  edulab-apply-desktop-style >/dev/null 2>&1 || true
fi

touch "$MARKER"
'

  open_exercises="#!/usr/bin/env bash
# Mở thư mục bài tập của người dùng hiện tại.
set -u
mkdir -p \"\$HOME/$EXERCISES_DIR_NAME\"
exec xdg-open \"\$HOME/$EXERCISES_DIR_NAME\"
"

  open_lms="#!/usr/bin/env bash
# Mở LMS đã cấu hình cho phòng máy.
set -u
exec edulab-browser \"$LMS_URL\"
"

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
  write_root_file "/usr/local/bin/edulab-open-exercises" "$open_exercises"
  write_root_file "/usr/local/bin/edulab-open-lms" "$open_lms"
  write_root_file "/usr/local/bin/edulab-browser" "$browser_helper"
  run chmod 0755 /usr/local/bin/edulab-first-login.sh /usr/local/bin/edulab-open-exercises /usr/local/bin/edulab-open-lms /usr/local/bin/edulab-browser

  if [[ -f "$SCRIPT_DIR/apply-desktop-style.sh" ]]; then
    run install -m 0755 "$SCRIPT_DIR/apply-desktop-style.sh" /usr/local/bin/edulab-apply-desktop-style
  else
    log "CẢNH BÁO: Không tìm thấy scripts/apply-desktop-style.sh, bỏ qua helper giao diện."
  fi
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
gtk-theme-name=Arc
gtk-icon-theme-name=Papirus
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=false'

  run install -d -m 0755 "$base_dir/.config/gtk-3.0"
  write_root_file "$settings" "$content"
  write_root_file "$gtkrc" 'gtk-theme-name="Arc"
gtk-icon-theme-name="Papirus"
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

  install_desktop_entry "$target_dir/ONLYOFFICE.desktop" "$owner" "$group" \
    "$(desktop_entry_content "ONLYOFFICE" "Soạn thảo văn bản, bảng tính và trình chiếu" "desktopeditors" "onlyoffice-desktopeditors" "Office;")"

  if [[ "$BROWSER_CHOICE" != "none" ]]; then
    install_desktop_entry "$target_dir/Trinh-duyet.desktop" "$owner" "$group" \
      "$(desktop_entry_content "Trình duyệt" "Mở trình duyệt web" "$browser_exec" "$browser_icon" "Network;WebBrowser;")"
  fi

  install_desktop_entry "$target_dir/Bai-tap.desktop" "$owner" "$group" \
    "$(desktop_entry_content "Bài tập" "Mở thư mục bài tập" "edulab-open-exercises" "folder-documents" "Utility;")"

  if [[ -n "$LMS_URL" ]]; then
    install_desktop_entry "$target_dir/LMS.desktop" "$owner" "$group" \
      "$(desktop_entry_content "LMS" "Mở hệ thống học tập trực tuyến" "edulab-open-lms" "web-browser" "Network;")"
  fi
}

configure_student_desktop() {
  local home
  local group
  local desktop_dir

  home="$(getent passwd "$STUDENT_USER" | cut -d: -f6)"
  [[ -n "$home" ]] || die "Không tìm thấy home của $STUDENT_USER."
  group="$(id -gn "$STUDENT_USER")"

  log "Tạo thư mục bài tập, shortcut và cấu hình desktop cho $STUDENT_USER."
  run install -d -m 0755 "$home/$EXERCISES_DIR_NAME"
  run chown "$STUDENT_USER:$group" "$home/$EXERCISES_DIR_NAME"

  write_gtk_settings "$home" "$STUDENT_USER" "$group"

  run install -d -m 0755 "$home/.config/autostart"
  install_desktop_entry "$home/.config/autostart/edulab-first-login.desktop" "$STUDENT_USER" "$group" \
    "$(desktop_entry_content "EduLab First Login" "Áp cấu hình EduLab khi đăng nhập" "/usr/local/bin/edulab-first-login.sh" "preferences-desktop" "Settings;")"

  desktop_dir="$(desktop_dir_for_user "$STUDENT_USER" "$home")"
  install_shortcuts_to_dir "$desktop_dir" "$STUDENT_USER" "$group"
}

configure_skel() {
  log "Cấu hình /etc/skel để tài khoản tạo sau này cũng có shortcut."
  run install -d -m 0755 "/etc/skel/$EXERCISES_DIR_NAME"
  write_gtk_settings "/etc/skel" "root" "root"
  run install -d -m 0755 /etc/skel/.config/autostart
  install_desktop_entry "/etc/skel/.config/autostart/edulab-first-login.desktop" "root" "root" \
    "$(desktop_entry_content "EduLab First Login" "Áp cấu hình EduLab khi đăng nhập" "/usr/local/bin/edulab-first-login.sh" "preferences-desktop" "Settings;")"
  install_shortcuts_to_dir "/etc/skel/Desktop" "root" "root"
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
    "STUDENT_USER=$STUDENT_USER
BROWSER_CHOICE=$BROWSER_CHOICE
INSTALL_ONLYOFFICE=$INSTALL_ONLYOFFICE
LMS_CONFIGURED=$lms_configured"
  run chmod 0644 /var/lib/edulab/install-state.env
}

main() {
  parse_args "$@"
  validate_config
  require_root_for_changes
  setup_logging

  log "Bắt đầu cài đặt $PROJECT_NAME."
  check_platform
  install_base_packages
  install_wallpaper_assets
  install_browser
  install_onlyoffice
  create_student_user
  install_helper_scripts
  configure_input_method
  configure_student_desktop
  configure_skel
  configure_browser_policy
  write_install_state

  if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database /usr/share/applications
  fi

  log "Hoàn tất. Hãy đăng xuất/đăng nhập vào tài khoản $STUDENT_USER để kiểm thử."
  log "Log cài đặt: $LOG_FILE"
}

main "$@"
