#!/usr/bin/env python3
import os
import re
import shlex
import shutil
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk, Pango


WIDTH = 650
HEIGHT = 520
TASKBAR_HEIGHT = 40
DESKTOP_FIELD_CODE_RE = re.compile(r"%[fFuUdDnNickvm]")


CSS = b"""
window {
  background: #202020;
}

.root {
  background: #202020;
  color: #f3f3f3;
}

.rail {
  background: #2b2b2b;
}

.rail button {
  border: 0;
  border-radius: 0;
  padding: 11px 0;
  background: transparent;
  color: #f3f3f3;
}

.rail button:hover,
.app-button:hover,
.tile:hover {
  background: rgba(255, 255, 255, 0.12);
}

.rail label {
  color: #f3f3f3;
}

.section-title {
  color: #d8d8d8;
  font-size: 11px;
  font-weight: 600;
  margin-top: 8px;
  margin-bottom: 4px;
}

.search-entry {
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 0;
  padding: 6px 8px;
  background: #2d2d2d;
  color: #ffffff;
}

.app-button {
  border: 0;
  border-radius: 0;
  padding: 5px 8px;
  background: transparent;
  color: #f3f3f3;
}

.app-button label {
  color: #f3f3f3;
}

.suggested {
  background: rgba(255, 255, 255, 0.06);
}

.tile {
  border: 0;
  border-radius: 0;
  background: #0078d7;
  color: #ffffff;
  margin: 2px;
}

.tile label {
  color: #ffffff;
  font-size: 11px;
  font-weight: 600;
}

.tile-wide {
  background: #0078d7;
}

.tile-blue2 {
  background: #1683d8;
}

.tile-teal {
  background: #008575;
}

.tile-purple {
  background: #6b3fa0;
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


def launch(command):
  if not command:
    return
  try:
    subprocess.Popen(command, start_new_session=True)
  except Exception:
    pass
  Gtk.main_quit()


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
    "search": " ".join(
      [
        name,
        data.get("Comment", ""),
        data.get("Exec", ""),
        data.get("Categories", ""),
      ]
    ).lower(),
  }


def scan_desktop_apps():
  apps = []
  seen = set()
  directories = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
  ]

  for directory in directories:
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


class StartMenu(Gtk.Window):
  def __init__(self):
    Gtk.Window.__init__(self, type=Gtk.WindowType.TOPLEVEL)
    self.set_decorated(False)
    self.set_resizable(False)
    self.set_skip_taskbar_hint(True)
    self.set_skip_pager_hint(True)
    self.set_keep_above(True)
    self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
    self.set_default_size(WIDTH, HEIGHT)
    self.set_size_request(WIDTH, HEIGHT)
    self.connect("focus-out-event", lambda *_: Gtk.main_quit())
    self.connect("key-press-event", self.on_key_press)

    self.app_entries = self.build_app_entries()
    self.current_results = []
    self.search_entry = None
    self.apps_list = None
    self.rail = None
    self.rail_expanded = False

    css_provider = Gtk.CssProvider()
    css_provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
      Gdk.Screen.get_default(),
      css_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    root = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
    add_class(root, "root")
    self.add(root)

    root.pack_start(self.build_rail(), False, False, 0)
    root.pack_start(self.build_apps(), False, False, 0)
    root.pack_start(self.build_tiles(), True, True, 18)

    self.position_window()

  def position_window(self):
    screen = Gdk.Screen.get_default()
    monitor = screen.get_primary_monitor()
    if monitor < 0:
      monitor = 0
    geometry = screen.get_monitor_geometry(monitor)
    x = geometry.x
    y = geometry.y + geometry.height - HEIGHT - TASKBAR_HEIGHT
    self.move(max(x, 0), max(y, 0))

  def on_key_press(self, _widget, event):
    if event.keyval == Gdk.KEY_Escape:
      Gtk.main_quit()
      return True
    return False

  def build_rail(self):
    self.rail = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    add_class(self.rail, "rail")
    self.rebuild_rail()
    return self.rail

  def rebuild_rail(self):
    for child in self.rail.get_children():
      self.rail.remove(child)

    width = 170 if self.rail_expanded else 48
    self.rail.set_size_request(width, HEIGHT)
    self.rail.pack_start(self.rail_button("open-menu-symbolic", None, "Start", self.toggle_rail), False, False, 10)
    self.rail.pack_start(Gtk.Box(), True, True, 0)

    home_cmd = ["xdg-open", os.path.expanduser("~")]
    self.rail.pack_start(self.rail_button("avatar-default-symbolic", home_cmd, "User"), False, False, 0)
    self.rail.pack_start(self.rail_button("emblem-system-symbolic", self.settings_command(), "Settings"), False, False, 0)
    self.rail.pack_start(self.rail_button("system-shutdown-symbolic", self.power_command(), "Power"), False, False, 8)
    self.rail.show_all()

  def toggle_rail(self, *_args):
    self.rail_expanded = not self.rail_expanded
    self.rebuild_rail()

  def rail_button(self, icon_name, command, text=None, callback=None):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.pack_start(icon(icon_name, 18), False, False, 0)
    if self.rail_expanded and text:
      row.pack_start(label(text), True, True, 0)
    button.add(row)
    if callback:
      button.connect("clicked", callback)
    if command:
      button.connect("clicked", lambda *_: launch(command))
    return button

  def app_button(self, name, icon_name, command, suggested=False):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(button, "app-button")
    if suggested:
      add_class(button, "suggested")
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    row.pack_start(icon(icon_name, 28), False, False, 0)
    row.pack_start(label(name), True, True, 0)
    button.add(row)
    button.connect("clicked", lambda *_: launch(command))
    return button

  def app_button_from_entry(self, entry, suggested=False):
    return self.app_button(entry["name"], entry["icon"], entry["command"], suggested)

  def section_label(self, text):
    item = label(text)
    add_class(item, "section-title")
    return item

  def build_apps(self):
    apps = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    apps.set_size_request(230, HEIGHT)
    apps.set_border_width(16)

    self.search_entry = Gtk.SearchEntry()
    self.search_entry.set_placeholder_text("Type to search")
    self.search_entry.connect("search-changed", self.on_search_changed)
    self.search_entry.connect("activate", self.on_search_activate)
    add_class(self.search_entry, "search-entry")
    apps.pack_start(self.search_entry, False, False, 0)

    scroller = Gtk.ScrolledWindow()
    scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroller.set_shadow_type(Gtk.ShadowType.NONE)
    self.apps_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    scroller.add(self.apps_list)
    apps.pack_start(scroller, True, True, 8)

    self.populate_apps("")
    return apps

  def build_app_entries(self):
    entries = [
      {
        "name": "Browser",
        "icon": browser_icon_name(),
        "command": self.browser_command(),
        "search": "browser web internet chrome chromium firefox edge",
      },
      {
        "name": "Settings",
        "icon": "preferences-system",
        "command": self.settings_command(),
        "search": "settings control panel preferences system",
      },
      {
        "name": "File Explorer",
        "icon": "system-file-manager",
        "command": ["edulab-open-files"],
        "search": "file explorer files folder thunar home",
      },
      {
        "name": "ONLYOFFICE",
        "icon": "onlyoffice-desktopeditors",
        "command": ["desktopeditors"],
        "search": "onlyoffice office word writer spreadsheet presentation",
      },
      {
        "name": "Keyboard settings",
        "icon": "preferences-desktop-keyboard",
        "command": self.keyboard_command(),
        "search": "keyboard input method language unikey vietnamese",
      },
      {
        "name": "All apps",
        "icon": "view-app-grid-symbolic",
        "command": self.all_apps_command(),
        "search": "all apps applications appfinder",
      },
    ]

    terminal = first_command([["xfce4-terminal"], ["gnome-terminal"], ["x-terminal-emulator"]])
    if terminal:
      entries.insert(
        4,
        {
          "name": "Terminal",
          "icon": "utilities-terminal",
          "command": terminal,
          "search": "terminal console shell command",
        },
      )

    seen = {entry["name"].lower() for entry in entries}
    for entry in scan_desktop_apps():
      if entry["name"].lower() in seen:
        continue
      seen.add(entry["name"].lower())
      entries.append(entry)

    return entries

  def clear_apps_list(self):
    for child in self.apps_list.get_children():
      self.apps_list.remove(child)

  def find_entry(self, name):
    for entry in self.app_entries:
      if entry["name"] == name:
        return entry
    return None

  def pack_entry(self, entry, suggested=False):
    if entry:
      self.apps_list.pack_start(self.app_button_from_entry(entry, suggested), False, False, 0)

  def populate_apps(self, query):
    query = query.strip().lower()
    self.clear_apps_list()

    if query:
      results = [
        entry
        for entry in self.app_entries
        if query in entry["name"].lower() or query in entry["search"]
      ]
      self.current_results = results
      self.apps_list.pack_start(self.section_label("Search results"), False, False, 0)
      if results:
        for entry in results[:16]:
          self.pack_entry(entry)
      else:
        self.apps_list.pack_start(label("No results"), False, False, 8)
      self.apps_list.show_all()
      return

    self.current_results = []
    self.apps_list.pack_start(self.section_label("Recently added"), False, False, 0)
    self.pack_entry(self.find_entry("ONLYOFFICE"))

    self.apps_list.pack_start(self.section_label("Most used"), False, False, 0)
    for name in ["Browser", "Settings", "File Explorer", "Terminal"]:
      self.pack_entry(self.find_entry(name))

    self.apps_list.pack_start(self.section_label("Suggested"), False, False, 0)
    self.pack_entry(self.find_entry("Keyboard settings"), True)
    self.pack_entry(self.find_entry("All apps"))
    self.apps_list.show_all()

  def on_search_changed(self, entry):
    self.populate_apps(entry.get_text())

  def on_search_activate(self, _entry):
    if self.current_results:
      launch(self.current_results[0]["command"])

  def tile(self, name, icon_name, command, css_class="tile", width=120, height=90):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(button, "tile")
    if css_class != "tile":
      add_class(button, css_class)
    button.set_size_request(width, height)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
    box.set_halign(Gtk.Align.CENTER)
    box.set_valign(Gtk.Align.CENTER)
    box.pack_start(icon(icon_name, 34), False, False, 0)
    text = label(name, 0.5)
    box.pack_start(text, False, False, 0)
    button.add(box)
    button.connect("clicked", lambda *_: launch(command))
    return button

  def build_tiles(self):
    wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    wrapper.set_border_width(18)
    wrapper.pack_start(self.section_label("Pinned"), False, False, 0)

    grid = Gtk.Grid()
    grid.set_row_spacing(2)
    grid.set_column_spacing(2)

    grid.attach(self.tile("Browser", browser_icon_name(), self.browser_command(), "tile-wide", 126, 94), 0, 0, 1, 1)
    grid.attach(self.tile("Settings", "preferences-system", self.settings_command(), "tile-blue2", 126, 94), 1, 0, 1, 1)
    grid.attach(self.tile("File Explorer", "system-file-manager", ["edulab-open-files"], "tile-blue2", 126, 94), 0, 1, 1, 1)
    grid.attach(self.tile("ONLYOFFICE", "onlyoffice-desktopeditors", ["desktopeditors"], "tile-teal", 126, 94), 1, 1, 1, 1)
    grid.attach(self.tile("Keyboard", "preferences-desktop-keyboard", self.keyboard_command(), "tile-purple", 126, 94), 0, 2, 1, 1)
    grid.attach(self.tile("All apps", "view-app-grid-symbolic", self.all_apps_command(), "tile-wide", 126, 94), 1, 2, 1, 1)

    wrapper.pack_start(grid, False, False, 0)
    wrapper.pack_start(Gtk.Box(), True, True, 0)
    return wrapper

  def browser_command(self):
    return first_command(
      [
        ["edulab-browser"],
        ["google-chrome-stable"],
        ["google-chrome"],
        ["chromium"],
        ["chromium-browser"],
        ["firefox"],
      ]
    ) or ["xdg-open", "about:blank"]

  def settings_command(self):
    return first_command(
      [
        ["edulab-open-settings"],
        ["xfce4-settings-manager"],
        ["cinnamon-settings"],
        ["gnome-control-center"],
      ]
    ) or ["xdg-open", os.path.expanduser("~/.config")]

  def keyboard_command(self):
    return first_command(
      [
        ["xfce4-keyboard-settings"],
        ["ibus-setup"],
        ["cinnamon-settings", "keyboard"],
        ["gnome-control-center", "keyboard"],
      ]
    ) or self.settings_command()

  def all_apps_command(self):
    return first_command(
      [
        ["xfce4-appfinder"],
        ["cinnamon-menu-editor"],
        ["gnome-control-center", "applications"],
      ]
    ) or self.settings_command()

  def power_command(self):
    return first_command(
      [
        ["xfce4-session-logout"],
        ["cinnamon-session-quit"],
        ["gnome-session-quit", "--power-off"],
      ]
    ) or ["systemctl", "poweroff"]


def main():
  if "DISPLAY" not in os.environ:
    return 1
  window = StartMenu()
  window.show_all()
  window.present()
  if window.search_entry:
    window.search_entry.grab_focus()
  Gtk.main()
  return 0


if __name__ == "__main__":
  sys.exit(main())
