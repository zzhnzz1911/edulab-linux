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


WIDTH = 360
HEIGHT = 154
TASKBAR_HEIGHT = 40
PID_FILE = f"/tmp/edulab-volume-menu-{os.getuid()}.pid"


CSS = b"""
window {
  background: transparent;
}

.root {
  background: #202020;
  color: #f3f3f3;
  border: 1px solid rgba(255, 255, 255, 0.18);
}

.header {
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
}

.device {
  color: #cfcfcf;
  font-size: 12px;
}

.percent {
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
}

.icon-button {
  border: 0;
  border-radius: 0;
  background: transparent;
  color: #f3f3f3;
  padding: 4px;
}

.icon-button:hover {
  background: rgba(255, 255, 255, 0.12);
}

scale trough {
  min-height: 4px;
  border-radius: 0;
  background: #5a5a5a;
}

scale highlight {
  border-radius: 0;
  background: #0078d7;
}

scale slider {
  min-width: 10px;
  min-height: 22px;
  border-radius: 0;
  border: 0;
  background: #f2f2f2;
}

.link-button {
  border: 0;
  border-radius: 0;
  background: transparent;
  color: #d9d9d9;
  padding: 8px 10px;
}

.link-button:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
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


def clamp(value, low, high):
  return max(low, min(high, value))


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

  output = run_output(["amixer", "get", "Master"]).lower()
  return "[off]" in output


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


def open_mixer():
  for command in ("pavucontrol", "xfce4-mixer"):
    try:
      subprocess.Popen([command], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
      Gtk.main_quit()
      return
    except OSError:
      continue
  Gtk.main_quit()


def add_class(widget, class_name):
  widget.get_style_context().add_class(class_name)


def text_label(text, css_class, xalign=0):
  item = Gtk.Label(label=text)
  item.set_xalign(xalign)
  add_class(item, css_class)
  return item


def icon_name_for_state(volume, muted):
  if muted or volume <= 0:
    return "audio-volume-muted-symbolic"
  if volume < 35:
    return "audio-volume-low-symbolic"
  if volume < 70:
    return "audio-volume-medium-symbolic"
  return "audio-volume-high-symbolic"


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


class VolumeMenu(Gtk.Window):
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
    root.set_border_width(12)
    add_class(root, "root")
    self.add(root)

    root.pack_start(text_label("Speakers", "header"), False, False, 0)
    self.device_label = text_label("", "device")
    root.pack_start(self.device_label, False, False, 4)

    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    row.set_margin_top(8)
    root.pack_start(row, False, False, 0)

    self.icon = Gtk.Image.new_from_icon_name("audio-volume-high-symbolic", Gtk.IconSize.BUTTON)
    self.mute_button = Gtk.Button()
    self.mute_button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(self.mute_button, "icon-button")
    self.mute_button.add(self.icon)
    self.mute_button.connect("clicked", self.on_mute_clicked)
    row.pack_start(self.mute_button, False, False, 0)

    self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    self.scale.set_draw_value(False)
    self.scale.set_hexpand(True)
    self.scale.connect("value-changed", self.on_volume_changed)
    row.pack_start(self.scale, True, True, 0)

    self.percent_label = text_label("", "percent", 1)
    self.percent_label.set_size_request(42, -1)
    row.pack_start(self.percent_label, False, False, 0)

    mixer_button = Gtk.Button(label="Volume mixer...")
    mixer_button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(mixer_button, "link-button")
    mixer_button.connect("clicked", lambda *_: open_mixer())
    root.pack_start(mixer_button, False, False, 10)

    self.refresh()
    self.position_window()
    GLib.timeout_add(300, self.close_when_unfocused)

  def refresh(self):
    self.updating = True
    volume = get_volume()
    muted = get_muted()
    self.scale.set_value(volume)
    self.percent_label.set_text(f"{volume}%")
    self.device_label.set_text("Muted" if muted else "System audio")
    self.icon.set_from_icon_name(icon_name_for_state(volume, muted), Gtk.IconSize.BUTTON)
    self.updating = False

  def on_volume_changed(self, scale):
    if self.updating:
      return
    set_volume(scale.get_value())
    self.refresh()

  def on_mute_clicked(self, *_args):
    toggle_mute()
    time.sleep(0.05)
    self.refresh()

  def position_window(self):
    screen = Gdk.Screen.get_default()
    monitor = screen.get_primary_monitor()
    if monitor < 0:
      monitor = 0
    geometry = screen.get_monitor_geometry(monitor)
    pointer = pointer_position(screen)
    anchor_x = geometry.x + geometry.width - 170
    if pointer:
      anchor_x = pointer[0]
    x = clamp(anchor_x - WIDTH // 2, geometry.x, geometry.x + geometry.width - WIDTH)
    y = geometry.y + geometry.height - HEIGHT - TASKBAR_HEIGHT - 6
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
  window = VolumeMenu()
  window.show_all()
  window.present()
  window.grab_focus()
  Gtk.main()
  remove_pid_file()
  return 0


if __name__ == "__main__":
  sys.exit(main())
