#!/usr/bin/env python3
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk


WIDTH = 310
HEIGHT = 128
TASKBAR_HEIGHT = 40


CSS = b"""
window {
  background: #202020;
}

.root {
  background: #202020;
  color: #f3f3f3;
  border: 1px solid rgba(255, 255, 255, 0.18);
}

.row {
  border: 0;
  border-radius: 0;
  padding: 9px 12px;
  background: transparent;
  color: #f3f3f3;
}

.row:hover {
  background: rgba(255, 255, 255, 0.12);
}

.code {
  color: #ffffff;
  font-weight: 700;
  font-size: 13px;
}

.name {
  color: #ffffff;
  font-size: 13px;
}

.sub {
  color: #c8c8c8;
  font-size: 11px;
}
"""


def current_engine():
  try:
    result = subprocess.run(
      ["ibus", "engine"],
      check=False,
      text=True,
      stdout=subprocess.PIPE,
      stderr=subprocess.DEVNULL,
    )
  except OSError:
    return ""
  return result.stdout.strip()


def switch_engine(engine):
  try:
    subprocess.run(["ibus", "engine", engine], check=False)
  except OSError:
    pass
  Gtk.main_quit()


def add_class(widget, class_name):
  widget.get_style_context().add_class(class_name)


def text_label(text, css_class, xalign=0):
  item = Gtk.Label(label=text)
  item.set_xalign(xalign)
  add_class(item, css_class)
  return item


class InputMenu(Gtk.Window):
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

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    root.set_border_width(8)
    add_class(root, "root")
    self.add(root)

    engine = current_engine().lower()
    root.pack_start(
      self.row("ENG", "English (United States)", "US", "xkb:us::eng", "unikey" not in engine),
      False,
      False,
      0,
    )
    root.pack_start(
      self.row("VIE", "Vietnamese", "Vietnamese Unikey", "Unikey", "unikey" in engine),
      False,
      False,
      0,
    )

    self.position_window()

  def row(self, code, name, sub, engine, active):
    button = Gtk.Button()
    button.set_relief(Gtk.ReliefStyle.NONE)
    add_class(button, "row")

    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    box.pack_start(text_label(code, "code"), False, False, 0)

    names = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    names.pack_start(text_label(name, "name"), False, False, 0)
    names.pack_start(text_label(sub, "sub"), False, False, 0)
    box.pack_start(names, True, True, 0)

    if active:
      box.pack_start(text_label("selected", "sub", 1), False, False, 0)

    button.add(box)
    button.connect("clicked", lambda *_: switch_engine(engine))
    return button

  def position_window(self):
    screen = Gdk.Screen.get_default()
    monitor = screen.get_primary_monitor()
    if monitor < 0:
      monitor = 0
    geometry = screen.get_monitor_geometry(monitor)
    x = geometry.x + geometry.width - WIDTH - 10
    y = geometry.y + geometry.height - HEIGHT - TASKBAR_HEIGHT - 8
    self.move(max(x, 0), max(y, 0))

  def on_key_press(self, _widget, event):
    if event.keyval == Gdk.KEY_Escape:
      Gtk.main_quit()
      return True
    return False


def main():
  if "DISPLAY" not in os.environ:
    return 1
  window = InputMenu()
  window.show_all()
  window.present()
  Gtk.main()
  return 0


if __name__ == "__main__":
  sys.exit(main())
