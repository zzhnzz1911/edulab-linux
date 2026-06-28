#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk


WIDTH = 360
HEIGHT = 294
TASKBAR_HEIGHT = 40
PID_FILE = f"/tmp/edulab-notification-menu-{os.getuid()}.pid"


CSS = b"""
window {
  background: transparent;
}

.root {
  background: #202020;
  color: #f3f3f3;
  border: 1px solid rgba(255, 255, 255, 0.18);
}

.title {
  color: #ffffff;
  font-size: 15px;
  font-weight: 600;
}

.text {
  color: #f3f3f3;
  font-size: 13px;
}

.subtle {
  color: #bdbdbd;
  font-size: 13px;
}

.action-button {
  border: 0;
  border-radius: 0;
  background: transparent;
  color: #d9d9d9;
  padding: 7px 10px;
}

.action-button:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
}

.action-button:disabled,
.action-button:disabled label {
  color: #777777;
}

.row {
  background: transparent;
  padding: 10px 0;
}

separator {
  background: rgba(255, 255, 255, 0.16);
}

switch {
  border-radius: 10px;
  background: #111111;
  border: 2px solid #f2f2f2;
}

switch:checked {
  background: #0078d7;
}

switch slider {
  background: #f2f2f2;
}

.quick-action {
  border: 0;
  border-radius: 0;
  background: #2e2e2e;
  color: #ffffff;
  padding: 9px;
}

.quick-action:hover {
  background: #3b3b3b;
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


def get_do_not_disturb():
  output = run_output(["xfconf-query", "-c", "xfce4-notifyd", "-p", "/do-not-disturb"]).lower()
  return output in ("true", "1", "yes")


def set_do_not_disturb(active):
  value = "true" if active else "false"
  if run_quiet(["xfconf-query", "-c", "xfce4-notifyd", "-p", "/do-not-disturb", "-s", value]):
    return
  run_quiet(["xfconf-query", "-c", "xfce4-notifyd", "-p", "/do-not-disturb", "-n", "-t", "bool", "-s", value])


def open_notification_settings():
  for command in ("xfce4-notifyd-config", "xfce4-settings-manager"):
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


class NotificationMenu(Gtk.Window):
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
    root.set_border_width(14)
    add_class(root, "root")
    self.add(root)

    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    title = text_label("Notifications", "title")
    header.pack_start(title, True, True, 0)

    clear_button = Gtk.Button(label="Clear all")
    clear_button.set_sensitive(False)
    clear_button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(clear_button, "action-button")
    header.pack_end(clear_button, False, False, 0)
    root.pack_start(header, False, False, 0)

    root.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 12)

    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    add_class(row, "row")
    row.pack_start(text_label("Do not disturb", "text"), True, True, 0)
    self.dnd_switch = Gtk.Switch()
    self.dnd_switch.set_active(get_do_not_disturb())
    self.dnd_switch.connect("notify::active", self.on_dnd_changed)
    row.pack_end(self.dnd_switch, False, False, 0)
    root.pack_start(row, False, False, 0)

    root.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 8)

    empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    empty.set_vexpand(True)
    empty.set_valign(Gtk.Align.CENTER)
    empty.pack_start(text_label("No notifications", "subtle", 0.5), False, False, 0)
    root.pack_start(empty, True, True, 0)

    quick = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    settings = Gtk.Button(label="All settings")
    settings.set_relief(Gtk.ReliefStyle.NONE)
    add_class(settings, "quick-action")
    settings.connect("clicked", lambda *_: open_notification_settings())
    quick.pack_start(settings, True, True, 0)

    focus = Gtk.Button(label="Focus assist")
    focus.set_relief(Gtk.ReliefStyle.NONE)
    add_class(focus, "quick-action")
    focus.connect("clicked", self.on_focus_clicked)
    quick.pack_start(focus, True, True, 0)
    root.pack_end(quick, False, False, 0)

    self.position_window()
    GLib.timeout_add(300, self.close_when_unfocused)

  def on_dnd_changed(self, switch, _param):
    set_do_not_disturb(switch.get_active())

  def on_focus_clicked(self, *_args):
    self.dnd_switch.set_active(not self.dnd_switch.get_active())

  def position_window(self):
    screen = Gdk.Screen.get_default()
    monitor = screen.get_primary_monitor()
    if monitor < 0:
      monitor = 0
    geometry = screen.get_monitor_geometry(monitor)
    x = geometry.x + geometry.width - WIDTH - 8
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
  window = NotificationMenu()
  window.show_all()
  window.present()
  window.grab_focus()
  Gtk.main()
  remove_pid_file()
  return 0


if __name__ == "__main__":
  sys.exit(main())
