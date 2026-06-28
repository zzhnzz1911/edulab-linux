#!/usr/bin/env python3
import os
import re
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk


WIDTH = 540
HEIGHT = 548
TASKBAR_HEIGHT = 40
PID_FILE = f"/tmp/edulab-quick-settings-menu-{os.getuid()}.pid"


CSS = b"""
window {
  background: transparent;
}

.root {
  background: #242424;
  color: #f3f3f3;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 8px;
}

.tile {
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 6px;
  background: #303030;
  color: #f5f5f5;
  padding: 0;
}

.tile:hover {
  background: #393939;
}

.tile-active {
  border-color: #0099f0;
  background: #1597e5;
}

.tile-icon {
  color: #ffffff;
}

.tile-title {
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
}

.tile-sub {
  color: #f1f1f1;
  font-size: 12px;
}

.muted {
  color: #b9b9b9;
}

.slider-row {
  background: transparent;
}

.slider-icon {
  color: #ffffff;
}

scale trough {
  min-height: 5px;
  border-radius: 3px;
  background: #8b8b8b;
}

scale highlight {
  border-radius: 3px;
  background: #1597e5;
}

scale slider {
  min-width: 18px;
  min-height: 18px;
  border-radius: 9px;
  border: 0;
  background: #1597e5;
  box-shadow: 0 0 0 4px rgba(255, 255, 255, 0.14);
}

.footer {
  background: #202020;
  color: #f3f3f3;
  border-radius: 0 0 8px 8px;
}

.footer-label {
  color: #ffffff;
  font-size: 14px;
  font-weight: 600;
}

.icon-button {
  border: 0;
  border-radius: 4px;
  background: transparent;
  color: #ffffff;
  padding: 6px;
}

.icon-button:hover {
  background: rgba(255, 255, 255, 0.12);
}
"""


def run_output(args):
  try:
    result = subprocess.run(
      args,
      check=False,
      text=True,
      stdout=subprocess.PIPE,
      stderr=subprocess.DEVNULL,
    )
  except OSError:
    return ""
  return result.stdout.strip()


def run_quiet(args):
  try:
    result = subprocess.run(args, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
  except OSError:
    return False
  return result.returncode == 0


def spawn_first(commands):
  for command in commands:
    try:
      subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
      Gtk.main_quit()
      return
    except OSError:
      continue


def clamp(value, low, high):
  return max(low, min(high, value))


def wifi_ssid():
  output = run_output(["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"])
  for line in output.splitlines():
    if line.startswith("yes:"):
      ssid = line.split(":", 1)[1].replace("\\:", ":").strip()
      return ssid or "Wi-Fi"
  return "Wi-Fi"


def bluetooth_active():
  output = run_output(["bluetoothctl", "show"]).lower()
  return "powered: yes" in output


def get_volume():
  output = run_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"])
  matches = re.findall(r"(\d{1,3})%", output)
  if matches:
    return clamp(int(matches[0]), 0, 100)

  output = run_output(["amixer", "get", "Master"])
  matches = re.findall(r"\[(\d{1,3})%\]", output)
  if matches:
    return clamp(int(matches[0]), 0, 100)
  return 50


def get_muted():
  output = run_output(["pactl", "get-sink-mute", "@DEFAULT_SINK@"]).lower()
  if "yes" in output:
    return True
  if "no" in output:
    return False
  return "[off]" in run_output(["amixer", "get", "Master"]).lower()


def set_volume(value):
  value = clamp(int(value), 0, 100)
  if run_quiet(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{value}%"]):
    run_quiet(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"])
    return
  run_quiet(["amixer", "set", "Master", f"{value}%"])
  run_quiet(["amixer", "set", "Master", "unmute"])


def toggle_mute():
  if run_quiet(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]):
    return
  run_quiet(["amixer", "set", "Master", "toggle"])


def brightness_available():
  return bool(run_output(["brightnessctl", "max"]) or run_output(["xbacklight", "-get"]))


def get_brightness():
  current = run_output(["brightnessctl", "get"])
  maximum = run_output(["brightnessctl", "max"])
  if current.isdigit() and maximum.isdigit() and int(maximum) > 0:
    return clamp(round(int(current) * 100 / int(maximum)), 0, 100)

  output = run_output(["xbacklight", "-get"])
  try:
    return clamp(round(float(output)), 0, 100)
  except ValueError:
    return 75


def set_brightness(value):
  value = clamp(int(value), 1, 100)
  if run_quiet(["brightnessctl", "set", f"{value}%"]):
    return
  run_quiet(["xbacklight", "-set", str(value)])


def battery_status():
  supplies_dir = "/sys/class/power_supply"
  try:
    names = sorted(os.listdir(supplies_dir))
  except OSError:
    return "AC power"

  for name in names:
    path = os.path.join(supplies_dir, name)
    if not name.startswith("BAT"):
      continue
    try:
      with open(os.path.join(path, "capacity"), "r", encoding="utf-8") as handle:
        capacity = handle.read().strip()
    except OSError:
      continue
    status = ""
    try:
      with open(os.path.join(path, "status"), "r", encoding="utf-8") as handle:
        status = handle.read().strip()
    except OSError:
      pass
    suffix = f" {status.lower()}" if status and status.lower() not in {"unknown", "not charging"} else ""
    return f"{capacity}%{suffix}"
  return "Plugged in"


def add_class(widget, class_name):
  widget.get_style_context().add_class(class_name)


def text_label(text, css_class, xalign=0):
  item = Gtk.Label(label=text)
  item.set_xalign(xalign)
  add_class(item, css_class)
  return item


def themed_icon(name, size=24, css_class="tile-icon"):
  image = Gtk.Image.new_from_icon_name(name, Gtk.IconSize.BUTTON)
  image.set_pixel_size(size)
  add_class(image, css_class)
  return image


def pointer_position(screen):
  try:
    data = screen.get_root_window().get_pointer()
  except Exception:
    return None
  if len(data) == 3:
    return int(data[0]), int(data[1])
  if len(data) >= 4:
    return int(data[1]), int(data[2])
  return None


class QuickSettingsMenu(Gtk.Window):
  def __init__(self):
    Gtk.Window.__init__(self, type=Gtk.WindowType.TOPLEVEL)
    self.set_decorated(False)
    self.set_resizable(False)
    self.set_skip_taskbar_hint(True)
    self.set_skip_pager_hint(True)
    self.set_accept_focus(True)
    self.set_focus_on_map(True)
    self.set_keep_above(True)
    self.set_type_hint(Gdk.WindowTypeHint.UTILITY)
    self.set_default_size(WIDTH, HEIGHT)
    self.set_size_request(WIDTH, HEIGHT)
    self.had_focus = False
    self.mapped_at = time.monotonic()
    self.updating = False
    self.connect("focus-in-event", self.on_focus_in)
    self.connect("focus-out-event", lambda *_: Gtk.main_quit())
    self.connect("key-press-event", self.on_key_press)

    css_provider = Gtk.CssProvider()
    css_provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
      Gdk.Screen.get_default(),
      css_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    add_class(root, "root")
    self.add(root)

    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
    content.set_border_width(26)
    root.pack_start(content, True, True, 0)

    grid = Gtk.Grid()
    grid.set_row_spacing(18)
    grid.set_column_spacing(18)
    content.pack_start(grid, False, False, 0)
    tiles = [
      self.tile("network-wireless-symbolic", wifi_ssid(), "", True, self.open_network),
      self.tile("bluetooth-symbolic", "Bluetooth", "", bluetooth_active(), self.open_bluetooth),
      self.tile("airplane-mode-symbolic", "Airplane mode", "", False, self.open_network),
      self.tile("preferences-desktop-accessibility-symbolic", "Accessibility", "", False, self.open_accessibility),
      self.tile("battery-good-symbolic", "Energy saver", "", False, self.open_power_settings),
      self.tile("video-display-symbolic", "Live captions", "", False, self.open_settings),
    ]
    for index, item in enumerate(tiles):
      grid.attach(item, index % 3, index // 3, 1, 1)

    self.brightness_scale = self.slider_row(
      content,
      "display-brightness-symbolic",
      get_brightness(),
      self.on_brightness_changed,
      sensitive=brightness_available(),
    )
    self.volume_icon = themed_icon("audio-volume-high-symbolic", 26, "slider-icon")
    self.volume_scale = self.slider_row(
      content,
      None,
      get_volume(),
      self.on_volume_changed,
      leading_widget=self.volume_button(),
      trailing_widget=self.mixer_button(),
    )

    footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    footer.set_border_width(20)
    add_class(footer, "footer")
    root.pack_end(footer, False, False, 0)

    footer.pack_start(themed_icon("battery-good-symbolic", 26, "slider-icon"), False, False, 0)
    self.battery_label = text_label(battery_status(), "footer-label")
    footer.pack_start(self.battery_label, True, True, 0)

    settings = Gtk.Button()
    settings.set_relief(Gtk.ReliefStyle.NONE)
    add_class(settings, "icon-button")
    settings.add(themed_icon("emblem-system-symbolic", 24, "slider-icon"))
    settings.connect("clicked", lambda *_: self.open_settings())
    footer.pack_end(settings, False, False, 0)

    self.refresh_volume_icon()
    self.position_window()
    GLib.timeout_add(300, self.close_when_unfocused)

  def tile(self, icon_name, title, subtitle="", active=False, callback=None):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    button.set_size_request(144, 72)
    add_class(button, "tile")
    if active:
      add_class(button, "tile-active")

    body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    body.set_border_width(10)
    icon_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    icon_row.pack_start(themed_icon(icon_name, 25), False, False, 0)
    body.pack_start(icon_row, True, True, 0)
    body.pack_end(text_label(subtitle, "tile-sub") if subtitle else Gtk.Box(), False, False, 0)
    body.pack_end(text_label(title, "tile-title"), False, False, 0)
    button.add(body)
    if callback:
      button.connect("clicked", lambda *_: callback())
    return button

  def volume_button(self):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(button, "icon-button")
    button.add(self.volume_icon)
    button.connect("clicked", self.on_mute_clicked)
    return button

  def mixer_button(self):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(button, "icon-button")
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
    row.pack_start(themed_icon("audio-volume-high-symbolic", 18, "slider-icon"), False, False, 0)
    row.pack_start(themed_icon("go-next-symbolic", 14, "slider-icon"), False, False, 0)
    button.add(row)
    button.connect("clicked", lambda *_: spawn_first([["pavucontrol"], ["xfce4-mixer"]]))
    return button

  def slider_row(self, parent, icon_name, value, callback, sensitive=True, leading_widget=None, trailing_widget=None):
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
    add_class(row, "slider-row")
    parent.pack_start(row, False, False, 0)

    if leading_widget is not None:
      row.pack_start(leading_widget, False, False, 0)
    elif icon_name:
      row.pack_start(themed_icon(icon_name, 28, "slider-icon"), False, False, 0)

    scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    scale.set_draw_value(False)
    scale.set_hexpand(True)
    scale.set_sensitive(sensitive)
    scale.set_value(value)
    scale.connect("value-changed", callback)
    row.pack_start(scale, True, True, 0)

    if trailing_widget is not None:
      row.pack_start(trailing_widget, False, False, 0)
    return scale

  def refresh_volume_icon(self):
    volume = get_volume()
    muted = get_muted()
    if muted or volume <= 0:
      name = "audio-volume-muted-symbolic"
    elif volume < 35:
      name = "audio-volume-low-symbolic"
    elif volume < 70:
      name = "audio-volume-medium-symbolic"
    else:
      name = "audio-volume-high-symbolic"
    self.volume_icon.set_from_icon_name(name, Gtk.IconSize.BUTTON)
    self.volume_icon.set_pixel_size(26)

  def on_volume_changed(self, scale):
    if self.updating:
      return
    set_volume(scale.get_value())
    self.refresh_volume_icon()

  def on_mute_clicked(self, *_args):
    toggle_mute()
    time.sleep(0.05)
    self.refresh_volume_icon()

  def on_brightness_changed(self, scale):
    if self.updating:
      return
    set_brightness(scale.get_value())

  def open_network(self):
    spawn_first([["nm-connection-editor"], ["xfce4-settings-manager"]])

  def open_bluetooth(self):
    spawn_first([["blueman-manager"], ["bluetooth-sendto"], ["xfce4-settings-manager"]])

  def open_accessibility(self):
    spawn_first([["xfce4-settings-manager", "--dialog", "accessibility-settings"], ["xfce4-settings-manager"]])

  def open_power_settings(self):
    spawn_first([["xfce4-power-manager-settings"], ["xfce4-settings-manager"]])

  def open_settings(self):
    spawn_first([["xfce4-settings-manager"], ["gnome-control-center"], ["cinnamon-settings"]])

  def position_window(self):
    screen = Gdk.Screen.get_default()
    monitor = screen.get_primary_monitor()
    if monitor < 0:
      monitor = 0
    geometry = screen.get_monitor_geometry(monitor)
    pointer = pointer_position(screen)
    anchor_x = geometry.x + geometry.width - 135
    if pointer:
      anchor_x = pointer[0]
    x = clamp(anchor_x - WIDTH + 78, geometry.x, geometry.x + geometry.width - WIDTH - 8)
    y = geometry.y + geometry.height - HEIGHT - TASKBAR_HEIGHT - 8
    self.move(max(x, geometry.x), max(y, geometry.y))

  def on_key_press(self, _widget, event):
    if event.keyval == Gdk.KEY_Escape:
      Gtk.main_quit()
      return True
    return False

  def on_focus_in(self, *_args):
    self.had_focus = True
    return False

  def close_when_unfocused(self):
    if time.monotonic() - self.mapped_at < 0.7:
      return True
    if self.had_focus and not self.is_active() and not self.has_toplevel_focus():
      Gtk.main_quit()
      return False
    return True


def existing_menu_pid():
  try:
    with open(PID_FILE, "r", encoding="utf-8") as handle:
      return int(handle.read().strip())
  except (OSError, ValueError):
    return None


def process_alive(pid):
  try:
    os.kill(pid, 0)
    return True
  except OSError:
    return False


def toggle_existing_menu():
  pid = existing_menu_pid()
  if pid and pid != os.getpid() and process_alive(pid):
    try:
      os.kill(pid, signal.SIGTERM)
    except OSError:
      pass
    return True
  return False


def write_pid_file():
  try:
    with open(PID_FILE, "w", encoding="utf-8") as handle:
      handle.write(str(os.getpid()))
  except OSError:
    pass


def remove_pid_file():
  if existing_menu_pid() == os.getpid():
    try:
      os.remove(PID_FILE)
    except OSError:
      pass


def main():
  if "DISPLAY" not in os.environ:
    return 1
  if toggle_existing_menu():
    return 0
  write_pid_file()
  window = QuickSettingsMenu()
  window.show_all()
  window.present()
  window.grab_focus()
  Gtk.main()
  remove_pid_file()
  return 0


if __name__ == "__main__":
  sys.exit(main())
