"""Refresh existing station illustrations without editing radio or logger settings."""

import time

from pywinauto import Desktop
from pywinauto.controls.win32_controls import ComboBoxWrapper

from session import capture


def capture_station(app, main, output, journal):
   journal.perform("open Preferences", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible", timeout=10)
   bounds = prefs.rectangle()
   trees = [c for c in prefs.descendants(class_name="Window")
      if c.is_visible() and c.rectangle().height() > 300
      and c.rectangle().width() < 250 and c.rectangle().left < bounds.left + 200]
   if len(trees) != 1:
      raise RuntimeError("Preferences navigation tree is not unique")
   journal.perform("focus Preferences navigation", trees[0].set_focus)
   journal.perform("select Hardware Radios", lambda: trees[0].type_keys("{HOME}{DOWN}{LEFT}{RIGHT}"))
   edit = prefs.child_window(title="Edit...")
   journal.perform("wait for radio library", lambda: edit.wait("visible enabled", timeout=10))
   journal.perform("capture saved K4 profile", lambda: capture(prefs, output / "k4-profile.png"))
   journal.perform("inspect selected radio", edit.click_input)
   editor = app.window(title="Radio")
   editor.wait("visible", timeout=10)
   journal.perform("show radio Network tab", lambda: editor.child_window(class_name="SysTabControl32").select("Network"))
   journal.perform("capture saved network parameters", lambda: capture(editor, output / "k4-network.png"))
   journal.perform("cancel radio inspection", lambda: editor.child_window(title="Cancel").click_input())
   editor.wait_not("visible", timeout=10)
   journal.perform("close Preferences without changes", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   radio = app.window(title="Radio 1 Elecraft K4")
   if not radio.exists(timeout=0) or not radio.is_visible():
      journal.perform("open Radio 1 status", lambda: main.menu_select("Windows->Radio 1"))
   radio.wait("visible", timeout=10)
   journal.perform("capture live radio status", lambda: capture(radio, output / "k4-radio.png"))
   journal.perform("capture main after radio status", lambda: capture(main, output / "k4-connected-main.png"))
   capture_cluster(app, main, output, journal)


def set_bandmap_filter(bandmap, label, enabled, journal):
   journal.perform("focus bandmap for " + label, bandmap.set_focus)
   journal.perform("open bandmap display controls", lambda: bandmap.right_click_input(
      coords=(bandmap.rectangle().width() - 30, 100)))
   popup = Desktop(backend="win32").window(class_name="#32768")
   matches = [item for item in popup.menu().items() if item.text().split("\t")[0] == label]
   if len(matches) != 1:
      raise RuntimeError("Bandmap display control not unique: " + label)
   original = matches[0].is_checked()
   if original != enabled:
      journal.perform("set " + label + " to " + str(enabled), matches[0].click_input)
      bandmap.right_click_input(coords=(bandmap.rectangle().width() - 30, 100))
      verified = [item for item in popup.menu().items() if item.text().split("\t")[0] == label]
      actual = verified[0].is_checked() if len(verified) == 1 else None
      bandmap.type_keys("{ESC}")
      if actual != enabled:
         raise AssertionError(label + " did not change to " + str(enabled))
   else:
      journal.perform("dismiss unchanged display menu", lambda: bandmap.type_keys("{ESC}"))
   return original


def capture_cluster(app, main, output, journal):
   prefs = app.window(title="TR4W Preferences")
   cluster = app.window(title="DX Cluster")
   if not cluster.exists(timeout=0) or not cluster.is_visible():
      journal.perform("open cluster console", lambda: main.menu_select("Windows->DX Cluster"))
   cluster.wait("visible", timeout=10)
   journal.perform("size cluster console", lambda: cluster.move_window(x=40, y=80, width=900, height=450))
   journal.perform("focus cluster console", cluster.set_focus)
   journal.perform("inspect saved cluster settings", lambda: cluster.click_input(coords=(620, 46)))
   prefs.wait("visible", timeout=10)
   journal.perform("capture saved NC7J settings", lambda: capture(prefs, output / "nc7j-settings.png"))
   journal.perform("cancel cluster settings inspection", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   combos = sorted([c for c in cluster.descendants(class_name="LCLComboBox") if c.is_visible()],
      key=lambda c: c.rectangle().left)
   hosts = ComboBoxWrapper(combos[0].handle)
   named = [value for value in hosts.texts()[1:] if "NC7J" in value and "dxc.nc7j.com:7373" in value]
   if len(named) != 1:
      raise RuntimeError("Expected one saved NC7J host")
   journal.perform("select saved NC7J host", lambda: hosts.select(named[0]))
   journal.perform("focus cluster before connecting", cluster.set_focus)
   journal.perform("connect saved cluster", lambda: cluster.click_input(coords=(56, 46)))
   journal.perform("allow cluster login", lambda: time.sleep(5))
   journal.perform("request recent spots", lambda: cluster.click_input(coords=(545, 46)))
   journal.perform("allow incoming cluster spots", lambda: time.sleep(15))
   journal.perform("capture received spots", lambda: capture(cluster, output / "nc7j-connected.png"))
   bandmap = app.window(title="Bandmap")
   if not bandmap.exists(timeout=0) or not bandmap.is_visible():
      journal.perform("open bandmap", lambda: main.menu_select("Windows->Band Map"))
   journal.perform("size bandmap", lambda: bandmap.move_window(x=40, y=80, width=600, height=400))
   originals = {}
   try:
      for label in ("BAND MAP ALL BANDS", "BAND MAP ALL MODES"):
         originals[label] = set_bandmap_filter(bandmap, label, True, journal)
      journal.perform("allow display update and incoming spots", lambda: time.sleep(10))
      journal.perform("capture bandmap with all bands and modes", lambda: capture(bandmap, output / "nc7j-bandmap.png"))
   finally:
      for label, enabled in originals.items():
         set_bandmap_filter(bandmap, label, enabled, journal)
