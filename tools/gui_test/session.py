"""Shared PID-scoped launch, evidence capture and diagnostics for GUI scenarios."""

import subprocess
import hashlib
import time
from pathlib import Path

from pywinauto import Application


def launch(root, run_name="pilot-001", contest="practice.db"):
   root = Path(root).resolve()
   run = root / "runs" / run_name
   exe = root / "app" / "tr4w_fpc.exe"
   settings = run / "tr4w.json"
   required = [exe, settings]
   if contest:
      required.append(run / contest)
   for path in required:
      if not path.is_file():
         raise FileNotFoundError(path)
   arguments = [str(exe)]
   if contest:
      arguments.append(str(run / contest))
   arguments.extend(["--settings", str(settings), "--lang", "en"])
   return Application(backend="win32").start(
      subprocess.list2cmdline(arguments), work_dir=str(run), wait_for_idle=False
   )


def capture(window, path):
   # Visible does not mean painted: capture only after the opening animation settles.
   previous = None
   deadline = time.monotonic() + 3
   while time.monotonic() < deadline:
      image = window.capture_as_image()
      digest = hashlib.sha256(image.tobytes()).digest()
      if digest == previous:
         image.save(path)
         return
      previous = digest
      time.sleep(0.2)
   raise RuntimeError("Window did not become visually stable for screenshot capture")


def describe_windows(app, output):
   import json

   windows = []
   for window in app.windows():
      item = {"title": window.window_text(), "class": window.class_name()}
      item["controls"] = [
         {
            "text": control.window_text(),
            "class": control.class_name(),
            "handle": control.handle,
            "visible": control.is_visible(),
            "enabled": control.is_enabled(),
            "rect": {
               key: getattr(control.rectangle(), key)
               for key in ("left", "top", "right", "bottom")
            },
         }
         for control in window.descendants()
      ]
      windows.append(item)
   (output / "windows.json").write_text(
      json.dumps(windows, indent=3), encoding="utf-8"
   )
