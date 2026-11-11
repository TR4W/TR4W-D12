"""Windows-only Preferences smoke test against an isolated staged TR4W build."""

import argparse
import ctypes
import hashlib
import json
import traceback
from pathlib import Path

from session import capture, describe_windows, launch


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--root", type=Path, default=Path(r"C:\TR4W-Test"))
   args = parser.parse_args()
   root = args.root.resolve()
   run = root / "runs" / "pilot-001"
   output = root / "artifacts" / "pilot-001"
   output.mkdir(parents=True, exist_ok=True)
   exe = root / "app" / "tr4w_fpc.exe"
   settings = run / "tr4w.json"
   database = run / "practice.db"
   for required in (exe, settings, database):
      if not required.is_file():
         raise FileNotFoundError(required)

   ctypes.windll.user32.SetProcessDPIAware()
   result = {
      "executable_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
      "checks": [],
      "passed": False,
   }
   app = None
   try:
      app = launch(root)
      result["pid"] = app.process
      main_window = app.window(title_re=r"TR4W v.*")
      main_window.wait("visible", timeout=30)
      result["title"] = main_window.window_text()
      capture(main_window, output / "main.png")
      result["checks"].append("Main window opened from isolated practice DB")

      main_window.set_focus()
      main_window.type_keys("^j")
      prefs = app.window(title="TR4W Preferences")
      prefs.wait("visible", timeout=15)
      describe_windows(app, output)
      captions = [control.window_text() for control in prefs.descendants()]
      for caption in ("Save and close", "Cancel", "Save"):
         if caption not in captions:
            raise AssertionError(f"Missing Preferences control: {caption}")
      capture(prefs, output / "preferences.png")
      result["checks"].append("Ctrl+J opened Preferences with Save/Cancel controls")

      prefs.type_keys("{ESC}")
      prefs.wait_not("visible", timeout=10)
      result["checks"].append("Escape closed Preferences")
      result["passed"] = True
   except Exception:
      result["error"] = traceback.format_exc()
      if app is not None:
         try:
            describe_windows(app, output)
            app.top_window().capture_as_image().save(output / "failure.png")
         except Exception:
            result["diagnostic_error"] = traceback.format_exc()
   finally:
      if app is not None:
         try:
            # Close only the process this test launched. No QSO is entered.
            app.kill()
         except Exception:
            result["cleanup_error"] = traceback.format_exc()
            result["passed"] = False
      (output / "result.json").write_text(
         json.dumps(result, indent=3), encoding="utf-8"
      )
   print(json.dumps(result, indent=3))
   return 0 if result["passed"] else 1


if __name__ == "__main__":
   raise SystemExit(main())
