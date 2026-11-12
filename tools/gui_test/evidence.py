"""Fail-closed build/bitness checks and flushed action evidence for GUI tests."""

import hashlib
import json
import os
import re
import shutil
import struct
import sys
import traceback
import zlib
from datetime import datetime, timezone
from pathlib import Path


def pe_info(path):
   data = Path(path).read_bytes()
   if data[:2] != b"MZ":
      raise ValueError("Not a Windows PE executable")
   offset = struct.unpack_from("<I", data, 0x3C)[0]
   if data[offset:offset + 4] != b"PE\0\0":
      raise ValueError("Invalid PE signature")
   machine, count, _, symbols, symbol_count, optional_size, _ = struct.unpack_from(
      "<HHIIIHH", data, offset + 4
   )
   bits = {0x14C: 32, 0x8664: 64}.get(machine)
   if bits is None:
      raise ValueError(f"Unsupported machine type: {machine:#x}")
   strings = symbols + symbol_count * 18
   sections = offset + 24 + optional_size
   for index in range(count):
      section = sections + index * 40
      name = data[section:section + 8].rstrip(b"\0")
      if name.startswith(b"/"):
         start = strings + int(name[1:])
         name = data[start:data.index(b"\0", start)]
      if name != b".gnu_debuglink":
         continue
      size, raw = struct.unpack_from("<II", data, section + 16)
      payload = data[raw:raw + size]
      end = payload.index(b"\0")
      crc_offset = (end + 4) & ~3
      return {"bits": bits, "debug_name": payload[:end].decode("ascii"),
              "debug_crc32": struct.unpack_from("<I", payload, crc_offset)[0]}
   return {"bits": bits, "debug_name": None, "debug_crc32": None}


def file_digest(path, crc=False):
   value = 0 if crc else hashlib.sha256()
   with Path(path).open("rb") as stream:
      for block in iter(lambda: stream.read(1024 * 1024), b""):
         if crc:
            value = zlib.crc32(block, value)
         else:
            value.update(block)
   return value & 0xFFFFFFFF if crc else value.hexdigest()


def preserve_generated_file(source, destination, previous_mtime_ns):
   source = Path(source)
   before = source.stat()
   if before.st_mtime_ns == previous_mtime_ns:
      raise RuntimeError("Export file was not rewritten by this command: " + str(source))
   data = source.read_bytes()
   after = source.stat()
   if before.st_mtime_ns != after.st_mtime_ns or before.st_size != after.st_size:
      raise RuntimeError("Export file changed while collecting evidence")
   Path(destination).write_bytes(data)
   return {"source": str(source), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
      "previous_mtime_ns": previous_mtime_ns, "mtime_ns": after.st_mtime_ns}


def require_matching_bitness(executable_bits):
   python_bits = struct.calcsize("P") * 8
   if executable_bits != python_bits:
      raise RuntimeError(
         f"Refusing native UI automation: {python_bits}-bit Python vs "
         f"{executable_bits}-bit application. No UI actions were started."
      )
   return python_bits


def preserve_build(exe, evidence_root):
   exe = Path(exe)
   info = pe_info(exe)
   require_matching_bitness(info["bits"])
   if not info["debug_name"]:
      raise RuntimeError("Executable has no GNU debug link; do not start a crash-prone test")
   debug = exe.parent / info["debug_name"]
   if file_digest(debug, crc=True) != info["debug_crc32"]:
      raise RuntimeError("Debug symbols do not match the executable's debug-link CRC32")
   source = exe.parent / "source-provenance.json"
   provenance = json.loads(source.read_text(encoding="utf-8-sig"))
   sha = file_digest(exe)
   certified = provenance.get("SourceClean") and re.fullmatch(
      r"[0-9a-f]{40}", provenance.get("SourceRevision") or ""
   )
   selected_binary = (
      provenance.get("ProvenanceKind") == "user-selected-existing-binary"
      and provenance.get("SourceSHA256") == sha
      and bool(provenance.get("SourceExecutable"))
      and provenance.get("SourceRevision") is None
      and provenance.get("SourceClean") is False
   )
   if not certified and not selected_binary:
      raise RuntimeError("Certified source or an explicitly identified existing binary is required")
   archive = Path(evidence_root) / "builds" / sha
   archive.mkdir(parents=True, exist_ok=True)
   for item in (exe, debug, source):
      target = archive / item.name
      if target.exists():
         if file_digest(target) != file_digest(item):
            raise RuntimeError(f"Refusing to overwrite different archived evidence: {target}")
      else:
         shutil.copy2(item, target)
   metadata = {
      "sha256": sha, "application_bits": info["bits"],
      "python_bits": struct.calcsize("P") * 8, "python": sys.version,
      "debug_crc32": f"{info['debug_crc32']:08X}",
      "debug_sha256": file_digest(debug), "archive": str(archive),
      "source": provenance,
   }
   (archive / "manifest.json").write_text(json.dumps(metadata, indent=3), encoding="utf-8")
   return metadata


class StepLog:
   def __init__(self, path):
      self.path = Path(path)
      self.path.parent.mkdir(parents=True, exist_ok=True)

   def write(self, action, state, detail=None):
      event = {"utc": datetime.now(timezone.utc).isoformat(),
               "action": action, "state": state, "detail": detail}
      with self.path.open("a", encoding="utf-8") as stream:
         stream.write(json.dumps(event) + "\n")
         stream.flush()
         os.fsync(stream.fileno())

   def perform(self, name, action):
      self.write(name, "before")
      try:
         value = action()
      except BaseException:
         self.write(name, "error", traceback.format_exc())
         raise
      self.write(name, "after")
      return value
