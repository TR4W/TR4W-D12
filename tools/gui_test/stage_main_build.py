"""Snapshot the user-selected main executable and matching symbols before VM tests."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import zipfile

from evidence import file_digest, pe_info

# THE ONE DEFINITION of which app the GUI suite runs by default, and of which guest
# Python drives it. Windows TR4W is x86_64-win64 only, so a plain Build-App.ps1
# writes this path and the guest Python is 64-bit. The two MUST match in bitness:
# pywinauto reads the remote common-control structures, and their layout differs
# between 32 and 64 bit (issue 283). evidence.require_matching_bitness is the
# guard that refuses a mismatch before any UI action; this repo builds no 32-bit
# exe, so one can only arrive through --exe or --python.
DEFAULT_EXE = Path(r"C:\tr4w-d12\build-out\app-x86_64-win64\tr4w_fpc.exe")
GUEST_PYTHON = r"C:\TR4W-Test\.venv-x64\Scripts\python.exe"


def stage(exe, output):
   exe = exe.resolve()
   sha = file_digest(exe)
   info = pe_info(exe)
   debug = exe.parent / info["debug_name"]
   if file_digest(debug, crc=True) != info["debug_crc32"]:
      raise RuntimeError("Main executable and symbols are being rebuilt or do not match")
   destination = output / ("selected-" + sha[:12])
   app = destination / "app"
   app.mkdir(parents=True, exist_ok=True)
   inputs = [exe, debug, exe.parent / "cacert.pem"] + list(exe.parent.glob("*.dll"))
   inputs += [path for path in (exe.parent / "help").rglob("*") if path.is_file()]
   for source in inputs:
      target = app / source.relative_to(exe.parent)
      target.parent.mkdir(parents=True, exist_ok=True)
      if target.exists():
         if file_digest(target) != file_digest(source):
            raise RuntimeError("Refusing to mix different files in an existing snapshot: " + str(target))
      else:
         shutil.copy2(source, target)
   if file_digest(exe) != sha or file_digest(app / exe.name) != sha:
      raise RuntimeError("Main executable changed during snapshot; retry after the build")
   if file_digest(app / debug.name, crc=True) != info["debug_crc32"]:
      raise RuntimeError("Copied symbols do not match the copied executable")
   provenance = app / "source-provenance.json"
   if not provenance.exists():
      provenance.write_text(json.dumps({
         "ProvenanceKind": "user-selected-existing-binary", "SourceExecutable": str(exe),
         "SourceSHA256": sha, "SourceRevision": None, "SourceClean": False,
         "CapturedUtc": datetime.now(timezone.utc).isoformat(),
         "Note": "Build-time source revision is unknown; a current checkout is not build provenance.",
      }, indent=3), encoding="utf-8")
   archive = destination / "app.zip"
   if not archive.exists():
      with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as bundle:
         for path in app.rglob("*"):
            if path.is_file():
               bundle.write(path, path.relative_to(destination))
   return {"sha256": sha, "debug_crc32": f"{info['debug_crc32']:08X}",
      "snapshot": str(app), "archive": str(archive), "vm_root": r"C:\TR4W-Test\bench-main-" + sha[:12]}


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--exe", type=Path, default=DEFAULT_EXE)
   parser.add_argument("--output", type=Path, default=Path("build-out/bench-ui"))
   args = parser.parse_args()
   metadata = stage(args.exe, args.output)
   args.output.mkdir(parents=True, exist_ok=True)
   (args.output / "selected-build.json").write_text(json.dumps(metadata, indent=3), encoding="utf-8")
   print(json.dumps(metadata, indent=3))


if __name__ == "__main__":
   main()
