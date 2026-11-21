#!/usr/bin/env python3
"""
trmaster_patch.py -- change (or list) what a TRMASTER.DTA holds for ONE call.

A test utility: it makes a patched COPY of a .dta so the program's in-place
TRMASTER reload can be exercised (patch a field, drop the copy over the live
file, see the change appear without a restart).

   trmaster_patch.py <in.dta> <out.dta> --call N4AF --name Howie
   trmaster_patch.py <in.dta> --list-call N4AF
   trmaster_patch.py <in.dta> <out.dta> --call N4AF --section GA --check 99
   trmaster_patch.py <in.dta> <out.dta> --call N4AF --name ""     (removes the field)

Fields: --name --section --check --grid --qth --cqzone --ituzone --foc
        --oldcall --tenten --user1 .. --user5 (strings), --hits --speed (0..255).
Values are stored upper-case-as-given; TRMASTER names are conventionally upper
case, so pass what you want to see.

How it patches: the record(s) for the call are re-encoded (the same call is
stored once per adjacent-character-pair bucket; every copy is replaced), the
other bytes of every bucket are copied through UNTOUCHED, and the 1369 bucket
start offsets plus the end offset (= file size) are recomputed. So every other
call is byte-identical to the input, and a longer or shorter value just moves
the offsets. The input file is never written; <out.dta> must be a different
file. An unknown call exits 1 with a message. The result is re-read with
trmaster_codec.read_dta before the tool reports success.

Format and codec: trmaster_codec.py (the only definition of the format here).
"""

import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import trmaster_codec as tc

# command-line option -> codec field name
OPTION_FIELDS = {
   "name": "Name", "section": "Section", "check": "Check", "grid": "Grid",
   "qth": "QTH", "cqzone": "CQZone", "ituzone": "ITUZone", "foc": "FOC",
   "oldcall": "OldCall", "tenten": "TenTen", "user1": "User1",
   "user2": "User2", "user3": "User3", "user4": "User4", "user5": "User5",
   "hits": "Hits", "speed": "Speed",
}


class PatchError(Exception):
   pass


def clean_value(field, text):
   """Validate a command-line value; returns what encode_record should get."""
   if field in ("Hits", "Speed"):
      try:
         number = int(text)
      except ValueError:
         raise PatchError("%s must be a number 0..255, got %r" % (field, text))
      if not 0 <= number <= 255:
         raise PatchError("%s must be 0..255, got %d" % (field, number))
      return number
   try:
      text.encode("latin-1")
   except UnicodeEncodeError:
      raise PatchError("%s value %r is not representable in the single-byte "
                       "(latin-1) .dta format" % (field, text))
   # The record reader stops a value at the first byte below 32, and a NUL
   # ends the record, so a control character would corrupt the file.
   if any(ord(ch) < 32 for ch in text):
      raise PatchError("%s value must not contain control characters" % field)
   return text


def read_buckets(data):
   """Split a .dta into its 1369 bucket byte strings; validates the header."""
   if len(data) < tc.HEADER_BYTES:
      raise PatchError("too small to be a .dta (%d bytes)" % len(data))
   offsets = struct.unpack_from("<%dI" % tc.HEADER_LONGS, data, 0)
   if offsets[tc.HEADER_BUCKETS] != len(data):
      raise PatchError("end offset %d does not match the file size %d"
                       % (offsets[tc.HEADER_BUCKETS], len(data)))
   buckets = []
   for k in range(tc.HEADER_BUCKETS):
      start = offsets[k]
      stop = offsets[k + 1]
      if not (tc.HEADER_BYTES <= start <= stop <= len(data)):
         raise PatchError("bucket %d has bad offsets %d..%d" % (k, start, stop))
      buckets.append(data[start:stop])
   return buckets


def patch_bucket(bucket, call, changes):
   """Return (new_bucket_bytes, copies_replaced) for one bucket."""
   out = bytearray()
   replaced = 0
   i = 0
   while i < len(bucket):
      found, fields, nxt = tc._decode_record(bucket, i)
      if found == call:
         for field, value in changes.items():
            if value in ("", 0, None):
               fields.pop(field, None)
            else:
               fields[field] = value
         out += tc.encode_record(call, fields)
         replaced += 1
      else:
         out += bucket[i:nxt]
      i = nxt
   return bytes(out), replaced


def patch_bytes(data, call, changes):
   """Return (new_file_bytes, copies_replaced). Raises PatchError if no call."""
   buckets = read_buckets(data)
   total = 0
   for k in range(len(buckets)):
      buckets[k], n = patch_bucket(buckets[k], call, changes)
      total += n
   if total == 0:
      raise PatchError("call %s is not in the file" % call)
   offsets = []
   pos = tc.HEADER_BYTES
   for bucket in buckets:
      offsets.append(pos)
      pos += len(bucket)
   offsets.append(pos)      # end offset == file size
   header = struct.pack("<%dI" % tc.HEADER_LONGS, *offsets)
   return header + b"".join(buckets), total


def list_call(path, call):
   """Print what the file holds for a call; returns the exit code."""
   info = tc.read_dta(path)
   fields = info["calls"].get(call)
   if fields is None:
      sys.stderr.write("trmaster_patch: call %s is not in %s\n" % (call, path))
      return 1
   print("%s  (%d bucket copies)" % (call, len(info["buckets_of"][call])))
   for name in tc.WRITE_ORDER:
      if name in fields:
         print("   %-8s %s" % (name, fields[name]))
   return 0


def build_parser():
   parser = argparse.ArgumentParser(
      description="Patch or list one call's record in a TRMASTER.DTA copy.")
   parser.add_argument("input", help="the .dta to read (never modified)")
   parser.add_argument("output", nargs="?", help="where to write the patched copy")
   parser.add_argument("--call", help="the call whose record to change")
   parser.add_argument("--list-call", metavar="CALL",
                       help="print the fields stored for CALL and exit")
   for option in sorted(OPTION_FIELDS):
      parser.add_argument("--" + option, help="set %s (empty removes it)"
                          % OPTION_FIELDS[option])
   return parser


def main(argv=None):
   parser = build_parser()
   args = parser.parse_args(argv)

   if not os.path.isfile(args.input):
      sys.stderr.write("trmaster_patch: input not found: %s\n" % args.input)
      return 1

   if args.list_call:
      return list_call(args.input, args.list_call.upper())

   changes = {}
   for option, field in OPTION_FIELDS.items():
      value = getattr(args, option)
      if value is not None:
         try:
            changes[field] = clean_value(field, value)
         except PatchError as err:
            sys.stderr.write("trmaster_patch: %s\n" % err)
            return 2
   if not args.call or not args.output or not changes:
      sys.stderr.write("trmaster_patch: need <out.dta>, --call and at least "
                       "one field option (or use --list-call)\n")
      return 2
   if os.path.exists(args.output) and os.path.samefile(args.input, args.output):
      sys.stderr.write("trmaster_patch: refusing to overwrite the input file; "
                       "give a different <out.dta>\n")
      return 2

   call = args.call.upper()
   with open(args.input, "rb") as handle:
      data = handle.read()
   try:
      patched, copies = patch_bytes(data, call, changes)
   except PatchError as err:
      sys.stderr.write("trmaster_patch: %s\n" % err)
      return 1

   with open(args.output, "wb") as handle:
      handle.write(patched)

   # Prove the file we wrote parses with the repo's reader and holds the change.
   info = tc.read_dta(args.output)
   if info["end_offset"] != info["file_size"]:
      sys.stderr.write("trmaster_patch: written file's end offset is wrong\n")
      return 3
   for field, value in changes.items():
      held = info["calls"][call].get(field)
      if value in ("", 0, None):
         ok = held in (None, "", 0)
      else:
         ok = (held == value)
      if not ok:
         sys.stderr.write("trmaster_patch: read-back of %s.%s gave %r, wanted %r\n"
                          % (call, field, held, value))
         return 3
   print("patched %s in %d bucket copies -> %s (%d bytes)"
         % (call, copies, args.output, len(patched)))
   return 0


if __name__ == "__main__":
   sys.exit(main())
