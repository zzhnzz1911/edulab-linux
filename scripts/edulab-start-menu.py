#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk, Pango


WIDTH = 650
HEIGHT = 520
TASKBAR_HEIGHT = 40


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

.section-title {
  color: #d8d8d8;
  font-size: 11px;
  font-weight: 600;
  margin-top: 8px;
  margin-bottom: 4px;
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


def launch(command):
  if not command:
    return
  try:
    subprocess.Popen(command, start_new_session=True)
  except Exception:
    pass
  Gtk.main_quit()


def icon(name, size):
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
    rail = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    rail.set_size_request(48, HEIGHT)
    add_class(rail, "rail")

    menu = self.rail_button("open-menu-symbolic", None)
    rail.pack_start(menu, False, False, 10)
    rail.pack_start(Gtk.Box(), True, True, 0)

    home_cmd = ["xdg-open", os.path.expanduser("~")]
    rail.pack_start(self.rail_button("avatar-default-symbolic", home_cmd), False, False, 0)
    rail.pack_start(self.rail_button("emblem-system-symbolic", self.settings_command()), False, False, 0)
    rail.pack_start(self.rail_button("system-shutdown-symbolic", self.power_command()), False, False, 8)
    return rail

  def rail_button(self, icon_name, command):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    button.set_image(icon(icon_name, 18))
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

  def section_label(self, text):
    item = label(text)
    add_class(item, "section-title")
    return item

  def build_apps(self):
    apps = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    apps.set_size_request(230, HEIGHT)
    apps.set_border_width(16)

    apps.pack_start(self.section_label("Recently added"), False, False, 0)
    apps.pack_start(self.app_button("ONLYOFFICE", "onlyoffice-desktopeditors", ["desktopeditors"]), False, False, 0)

    apps.pack_start(self.section_label("Most used"), False, False, 0)
    apps.pack_start(self.app_button("Browser", "web-browser", self.browser_command()), False, False, 0)
    apps.pack_start(self.app_button("Settings", "preferences-system", self.settings_command()), False, False, 0)
    apps.pack_start(self.app_button("File Explorer", "system-file-manager", ["edulab-open-files"]), False, False, 0)
    terminal = first_command([["xfce4-terminal"], ["gnome-terminal"], ["x-terminal-emulator"]])
    if terminal:
      apps.pack_start(self.app_button("Terminal", "utilities-terminal", terminal), False, False, 0)

    apps.pack_start(self.section_label("Suggested"), False, False, 0)
    apps.pack_start(
      self.app_button("Keyboard settings", "preferences-desktop-keyboard", self.keyboard_command(), True),
      False,
      False,
      0,
    )

    apps.pack_start(Gtk.Box(), True, True, 0)
    apps.pack_start(self.app_button("All apps", "view-app-grid-symbolic", self.all_apps_command()), False, False, 0)
    return apps

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

    grid.attach(self.tile("Browser", "web-browser", self.browser_command(), "tile-wide", 126, 94), 0, 0, 1, 1)
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
  Gtk.main()
  return 0


if __name__ == "__main__":
  sys.exit(main())
