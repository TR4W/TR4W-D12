"""Build the native macOS permission/automation bridge once at a stable path."""

import hashlib
import argparse
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile


def require_unapproved(status):
   # Native NSNumber permission results may be JSON false or numeric zero.
   # Missing/unknown values still refuse replacement.
   for key, label in (("accessibility", "Accessibility"), ("screen_recording", "Screen Recording")):
      if status.get(key) not in (False, 0):
         raise SystemExit("Refusing to replace an approved or unknown " + label + " identity")


def main():
   if sys.platform != "darwin":
      raise SystemExit("Build on mac-ci with its system Python and Xcode command-line tools")
   source = Path(__file__).with_name("mac_pilot.m")
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--replace-unapproved", action="store_true")
   parser.add_argument("--variant", choices=("runner", "ax-probe", "runner-next"), default="runner")
   args = parser.parse_args()
   root = Path.home() / "tr4w-gui-test"
   probe = args.variant == "ax-probe"
   next_runner = args.variant == "runner-next"
   display_name = "TR4W AX Probe" if probe else ("TR4W GUI Runner" if next_runner else "TR4W GUI Pilot")
   app = Path.home() / "Applications" / (display_name + ".app")
   status_name = "mac-ax-probe-preflight.json" if probe else ("mac-runner-next-preflight.json" if next_runner else "mac-preflight.json")
   identity_name = "mac-ax-probe-build.json" if probe else ("mac-runner-next-build.json" if next_runner else "mac-runner-build.json")
   bundle_id = "net.tr4w.gui-pilot.ax-probe" if probe else ("net.tr4w.gui-pilot.runner" if next_runner else "net.tr4w.gui-pilot")
   if app.exists():
      if not args.replace_unapproved:
         raise SystemExit("Refusing to replace the permission-bearing app. Review its existing build before rebuilding: " + str(app))
      subprocess.run(["/usr/bin/open", "-W", "-n", str(app), "--args", "--preflight"], check=True, timeout=20)
      status = json.loads((root / "artifacts" / status_name).read_text())
      require_unapproved(status)
   for name in ("jobs", "artifacts", "app", "runs"):
      (root / name).mkdir(parents=True, exist_ok=True)
   app.parent.mkdir(parents=True, exist_ok=True)
   with tempfile.TemporaryDirectory(prefix="tr4w-mac-pilot-") as temporary:
      bundle = Path(temporary) / app.name
      executable = bundle / "Contents/MacOS/tr4w-gui-pilot"
      executable.parent.mkdir(parents=True)
      metadata = {
         "CFBundleIdentifier": bundle_id,
         "CFBundleName": display_name,
         "CFBundleDisplayName": display_name,
         "CFBundleExecutable": executable.name,
         "CFBundlePackageType": "APPL",
         "CFBundleVersion": "1",
         "CFBundleShortVersionString": "0.1",
         "TR4WPreflightFilename": status_name,
         "LSMinimumSystemVersion": "14.0",
         "NSHighResolutionCapable": True,
         "NSScreenCaptureUsageDescription": "Capture the isolated TR4W test window as GUI regression evidence.",
      }
      (bundle / "Contents/Info.plist").write_bytes(plistlib.dumps(metadata))
      subprocess.run(["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra",
         "-Wno-deprecated-declarations", "-mmacosx-version-min=14.0",
         "-DTR4W_AX_PROBE=" + ("1" if probe else "0"),
         "-DTR4W_RUNNER_NEXT=" + ("1" if next_runner else "0"),
         "-framework", "AppKit", "-framework", "ApplicationServices",
         "-framework", "ScreenCaptureKit", str(source), "-o", str(executable)], check=True)
      subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none",
         "--identifier", metadata["CFBundleIdentifier"], str(bundle)], check=True)
      subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(bundle)], check=True)
      # The temporary bundle is complete and verified before it is installed.
      if app.exists():
         previous = hashlib.sha256((app / "Contents/MacOS/tr4w-gui-pilot").read_bytes()).hexdigest()
         archive = root / "source" / ("unapproved-runner-" + previous[:12] + ".app")
         archive.parent.mkdir(parents=True, exist_ok=True)
         app.rename(archive)
      subprocess.run(["/usr/bin/ditto", str(bundle), str(app)], check=True)
   executable = app / "Contents/MacOS/tr4w-gui-pilot"
   identity = {"app": str(app), "bundle_id": metadata["CFBundleIdentifier"],
      "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
      "executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
      "signature": "ad-hoc; no private signing identity used"}
   (root / "artifacts" / identity_name).write_text(json.dumps(identity, indent=3), encoding="utf-8")
   print(json.dumps(identity, indent=3))


if __name__ == "__main__":
   main()
