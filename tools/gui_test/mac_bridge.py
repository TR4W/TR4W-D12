"""Send recorded jobs to the approved native Mac helpers."""

import json
import os
from pathlib import Path
import plistlib
import subprocess
import time


def console_status():
   """Read mac-ci console readiness without opening an app or requesting access."""
   data = subprocess.check_output(["/usr/sbin/ioreg", "-n", "Root", "-d1", "-a"], timeout=10)
   root = plistlib.loads(data)
   if isinstance(root, list) and len(root) == 1:
      root = root[0]
   sessions = root.get("IOConsoleUsers", [])
   current = [row for row in sessions if row.get("kCGSSessionUserIDKey") == os.getuid()
      and row.get("kCGSSessionOnConsoleKey") is True]
   session = current[0] if len(current) == 1 else {}
   session_lock = session.get("CGSSessionScreenIsLocked")
   console_lock = root.get("IOConsoleLocked")
   locked = None
   if session_lock is True or console_lock is True:
      locked = True
   elif session_lock is False or console_lock is False:
      locked = False
   status = {"on_console": session.get("kCGSSessionOnConsoleKey"),
      "login_done": session.get("kCGSessionLoginDoneKey"),
      "screen_locked": locked}
   # These observed ioreg fields are checked explicitly. Missing/changed
   # macOS fields mean unknown readiness, never permission to post keys.
   status["ready"] = status["on_console"] is True and status["login_done"] is True and status["screen_locked"] is False
   return status


def wait_for(description, observe, timeout=25):
   deadline = time.monotonic() + timeout
   while time.monotonic() < deadline:
      value = observe()
      if value:
         return value
      time.sleep(0.3)
   raise TimeoutError(description)


class MacBridge:
   def __init__(self, jobs, output, next_runner=False):
      self.jobs = jobs
      self.output = output
      self.counter = 0
      self.next_runner = next_runner
      self.capture_runner = Path.home() / "Applications/TR4W GUI Pilot.app"
      self.runner = Path.home() / ("Applications/TR4W GUI Runner.app" if next_runner else "Applications/TR4W GUI Pilot.app")
      self.probe = Path.home() / "Applications/TR4W AX Probe.app"

   def perform(self, operation, probe=False, capture_runner=False, **fields):
      self.counter += 1
      capture_runner = capture_runner or (self.next_runner and operation == "capture")
      stem = f"{self.counter:03d}-{operation}" + ("-probe" if probe else ("-capture-runner" if capture_runner else ""))
      destination = self.output / (stem + ".json")
      job = {"operation": operation, "output": str(destination), **fields}
      job_path = self.jobs / (stem + ".json")
      job_path.write_text(json.dumps(job), encoding="utf-8")
      selected = self.probe if probe else (self.capture_runner if capture_runner else self.runner)
      # -g preserves target foreground while the accessory helper runs.
      process = subprocess.run(["/usr/bin/open", "-g", "-W", "-n", str(selected),
         "--args", "--job", str(job_path)], capture_output=True, text=True, timeout=30)
      if process.returncode != 0 or not destination.exists():
         raise RuntimeError("Bridge did not produce a result: " + process.stderr)
      observation = json.loads(destination.read_text())
      if observation.get("passed") is False:
         raise RuntimeError("Native " + operation + ": " + observation.get("error", repr(observation)))
      return observation
