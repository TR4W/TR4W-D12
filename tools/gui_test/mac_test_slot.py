"""Temporarily occupy the approved test path; caller must hold pilot.lock."""

from contextlib import contextmanager
import json
from pathlib import Path
import subprocess
import uuid

from evidence import file_digest


def helper_identity(root, helper, record_name):
   record = json.loads((root / "artifacts" / record_name).read_text())
   if file_digest(helper / "Contents/MacOS/tr4w-gui-pilot") != record["executable_sha256"]:
      raise RuntimeError("Approved helper differs from its recorded build: " + str(helper))
   return record


@contextmanager
def staged_bundle(root, replacement=None):
   stage = root / "app/TR4W.app"
   if replacement is None:
      yield
      return
   replacement = Path(replacement).resolve(strict=True)
   area = (root / "app").resolve(strict=True)
   if stage.is_symlink() or stage.resolve().parent != area:
      raise RuntimeError("Test slot is not a direct bundle under the staged app directory")
   if replacement == stage.resolve() or stage.resolve() in replacement.parents:
      raise RuntimeError("Replacement must be independent of the occupied test slot")
   if not (replacement / "Contents/MacOS/tr4w").is_file():
      raise RuntimeError("Replacement has no TR4W executable")
   subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(stage)], check=True)
   subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(replacement)], check=True)
   if subprocess.run(["/usr/bin/pgrep", "-x", "tr4w"], capture_output=True).returncode == 0:
      raise RuntimeError("A TR4W process already exists")
   original_sha = file_digest(stage / "Contents/MacOS/tr4w")
   token = uuid.uuid4().hex
   parked = area / ("TR4W-release-" + token + ".app")
   used = area / ("TR4W-used-" + token + ".app")
   stage.rename(parked)
   try:
      subprocess.run(["/usr/bin/ditto", str(replacement), str(stage)], check=True)
      yield
   finally:
      # Preserve both complete bundles. Never remove or rebuild the original.
      if stage.exists():
         stage.rename(used)
      parked.rename(stage)
      if file_digest(stage / "Contents/MacOS/tr4w") != original_sha:
         raise RuntimeError("Restored release executable hash mismatch")
      subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(stage)], check=True)
