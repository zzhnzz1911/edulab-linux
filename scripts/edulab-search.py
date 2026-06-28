#!/usr/bin/env python3
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk, Pango


WIDTH = 430
HEIGHT = 360
TASKBAR_HEIGHT = 40
DESKTOP_FIELD_CODE_RE = re.compile(r"%[fFuUdDnNickvm]")
PID_FILE = f"/tmp/edulab-search-{os.getuid()}.pid"


CSS = b"""
window {
  background: #202020;
}

.root {
  background: #202020;
  color: #f3f3f3;
  border: 1px solid rgba(255, 255, 255, 0.18);
}

.search-entry {
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 0;
  padding: 7px 10px;
  background: #f2f2f2;
  color: #202020;
}

.section-title {
  color: #cfcfcf;
  font-size: 11px;
  font-weight: 600;
  margin-top: 8px;
  margin-bottom: 4px;
}

.app-button {
  border: 0;
  border-radius: 0;
  padding: 6px 8px;
  background: transparent;
  color: #f3f3f3;
}

.app-button:hover {
  background: rgba(255, 255, 255, 0.12);
}

.app-button label {
  color: #f3f3f3;
}
"""


def command_exists(command):
  return shutil.which(command) is not None


def first_command(candidates):
  for command in candidates:
    if command_exists(command[0]):
      return command
  return None


def browser_icon_name():
  if command_exists("google-chrome-stable") or command_exists("google-chrome"):
    return "google-chrome"
  if command_exists("chromium") or command_exists("chromium-browser"):
    return "chromium"
  if command_exists("firefox"):
    return "firefox"
  return "web-browser"


def clean_desktop_exec(exec_line):
  try:
    parts = shlex.split(exec_line)
  except ValueError:
    return None

  cleaned = []
  for part in parts:
    part = DESKTOP_FIELD_CODE_RE.sub("", part).strip()
    if part:
      cleaned.append(part)
  return cleaned or None


def read_desktop_entry(path):
  data = {}
  in_entry = False

  try:
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
      for raw_line in handle:
        line = raw_line.strip()
        if not line or line.startswith("#"):
          continue
        if line == "[Desktop Entry]":
          in_entry = True
          continue
        if line.startswith("[") and in_entry:
          break
        if not in_entry or "=" not in line:
          continue

        key, value = line.split("=", 1)
        if key in {"Name", "Comment", "Exec", "Icon", "NoDisplay", "Hidden", "Terminal", "Categories"}:
          data[key] = value
  except OSError:
    return None

  if data.get("Hidden", "").lower() == "true" or data.get("NoDisplay", "").lower() == "true":
    return None
  if data.get("Terminal", "").lower() == "true":
    return None

  name = data.get("Name", "").strip()
  command = clean_desktop_exec(data.get("Exec", ""))
  if not name or not command:
    return None

  return {
    "name": name,
    "icon": data.get("Icon", "application-x-executable") or "application-x-executable",
    "command": command,
    "search": " ".join([name, data.get("Comment", ""), data.get("Exec", ""), data.get("Categories", "")]).lower(),
  }


def scan_desktop_apps():
  apps = []
  seen = set()
  for directory in ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]:
    if not os.path.isdir(directory):
      continue
    for filename in sorted(os.listdir(directory)):
      if not filename.endswith(".desktop"):
        continue
      entry = read_desktop_entry(os.path.join(directory, filename))
      if not entry:
        continue
      key = entry["name"].lower()
      if key in seen:
        continue
      seen.add(key)
      apps.append(entry)
  return apps


def icon(name, size):
  if name and os.path.isabs(name) and os.path.exists(name):
    image = Gtk.Image.new_from_file(name)
  else:
    image = Gtk.Image.new_from_icon_name(name, Gtk.IconSize.DIALOG)
  image.set_pixel_size(size)
  return image


def label(text, xalign=0):
  item = Gtk.Label(label=text)
  item.set_xalign(xalign)
  item.set_ellipsize(Pango.EllipsizeMode.END)
  return item


def add_class(widget, class_name):
  widget.get_style_context().add_class(class_name)


def launch(command):
  if not command:
    return
  try:
    subprocess.Popen(command, start_new_session=True)
  except Exception:
    pass
  Gtk.main_quit()


def monitor_workarea():
  screen = Gdk.Screen.get_default()
  monitor = screen.get_primary_monitor()
  if monitor < 0:
    monitor = 0
  try:
    return screen.get_monitor_workarea(monitor)
  except AttributeError:
    geometry = screen.get_monitor_geometry(monitor)
    geometry.height = max(0, geometry.height - TASKBAR_HEIGHT)
    return geometry


class SearchWindow(Gtk.Window):
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

    self.entries = self.build_entries()
    self.results = []
    self.results_box = None

    css_provider = Gtk.CssProvider()
    css_provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
      Gdk.Screen.get_default(),
      css_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    root.set_border_width(12)
    add_class(root, "root")
    self.add(root)

    self.search_entry = Gtk.SearchEntry()
    self.search_entry.set_placeholder_text("Ask me anything")
    self.search_entry.connect("search-changed", self.on_search_changed)
    self.search_entry.connect("activate", self.on_search_activate)
    add_class(self.search_entry, "search-entry")
    root.pack_start(self.search_entry, False, False, 0)

    scroller = Gtk.ScrolledWindow()
    scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroller.set_shadow_type(Gtk.ShadowType.NONE)
    self.results_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    scroller.add(self.results_box)
    root.pack_start(scroller, True, True, 0)

    self.populate("")
    self.position_window()
    GLib.timeout_add(300, self.close_when_unfocused)

  def build_entries(self):
    entries = [
      {"name": "Browser", "icon": browser_icon_name(), "command": browser_command(), "search": "browser chrome web internet"},
      {"name": "File Explorer", "icon": "system-file-manager", "command": ["edulab-open-files"], "search": "file explorer files folder"},
      {"name": "Settings", "icon": "preferences-system", "command": settings_command(), "search": "settings control panel preferences"},
      {"name": "Keyboard settings", "icon": "preferences-desktop-keyboard", "command": keyboard_command(), "search": "keyboard input unikey vietnamese"},
    ]
    seen = {entry["name"].lower() for entry in entries}
    for entry in scan_desktop_apps():
      if entry["name"].lower() in seen:
        continue
      seen.add(entry["name"].lower())
      entries.append(entry)
    return entries

  def position_window(self):
    workarea = monitor_workarea()
    x = workarea.x + 48
    y = workarea.y + workarea.height - HEIGHT
    self.move(max(x, 0), max(y, 0))

  def on_focus_in(self, *_args):
    self.had_focus = True
    return False

  def on_key_press(self, _widget, event):
    if event.keyval == Gdk.KEY_Escape:
      Gtk.main_quit()
      return True
    return False

  def close_when_unfocused(self):
    if time.monotonic() - self.mapped_at < 0.7:
      return True
    if self.had_focus and not self.is_active() and not self.has_toplevel_focus():
      Gtk.main_quit()
      return False
    return True

  def app_button(self, entry):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(button, "app-button")
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    row.pack_start(icon(entry["icon"], 28), False, False, 0)
    row.pack_start(label(entry["name"]), True, True, 0)
    button.add(row)
    button.connect("clicked", lambda *_: launch(entry["command"]))
    return button

  def clear_results(self):
    for child in self.results_box.get_children():
      self.results_box.remove(child)

  def populate(self, query):
    query = query.strip().lower()
    self.clear_results()
    if query:
      self.results = [
        entry for entry in self.entries if query in entry["name"].lower() or query in entry["search"]
      ][:12]
      title = "Search results"
    else:
      self.results = self.entries[:8]
      title = "Most used"

    title_label = label(title)
    add_class(title_label, "section-title")
    self.results_box.pack_start(title_label, False, False, 0)
    if self.results:
      for entry in self.results:
        self.results_box.pack_start(self.app_button(entry), False, False, 0)
    else:
      self.results_box.pack_start(label("No results"), False, False, 8)
    self.results_box.show_all()

  def on_search_changed(self, entry):
    self.populate(entry.get_text())

  def on_search_activate(self, _entry):
    if self.results:
      launch(self.results[0]["command"])


def browser_command():
  return first_command(
    [["edulab-browser"], ["google-chrome-stable"], ["google-chrome"], ["chromium"], ["chromium-browser"], ["firefox"]]
  ) or ["xdg-open", "about:blank"]


def settings_command():
  return first_command([["edulab-open-settings"], ["xfce4-settings-manager"], ["cinnamon-settings"], ["gnome-control-center"]]) or [
    "xdg-open",
    os.path.expanduser("~/.config"),
  ]


def keyboard_command():
  return first_command([["xfce4-keyboard-settings"], ["ibus-setup"], ["cinnamon-settings", "keyboard"], ["gnome-control-center", "keyboard"]]) or settings_command()


def existing_pid():
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


def toggle_existing():
  pid = existing_pid()
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
  if existing_pid() == os.getpid():
    try:
      os.remove(PID_FILE)
    except OSError:
      pass


def main():
  if "DISPLAY" not in os.environ:
    return 1
  if toggle_existing():
    return 0
  write_pid_file()
  window = SearchWindow()
  window.show_all()
  window.position_window()
  window.present()
  window.search_entry.grab_focus()
  Gtk.main()
  remove_pid_file()
  return 0


if __name__ == "__main__":
  sys.exit(main())
