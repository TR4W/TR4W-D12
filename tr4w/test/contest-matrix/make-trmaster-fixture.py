"""make-trmaster-fixture.py -- writes the contest matrix's call-history file.

   python tr4w/test/contest-matrix/make-trmaster-fixture.py

Reads trmaster-fixture.txt beside this script and writes MATRIX-TRMASTER.DTA
beside it, through tr4w/tools/trmaster/trmaster_codec.py -- the same writer
build_trmaster.cmd uses for the shipped file, so the fixture is the format the
program reads, not a second encoder's idea of it. The result is read back and
compared field by field before the script reports success.

matrix-lib.sh copies the .DTA into each run's scratch directory as
MATRIX-TRMASTER.DTA -- deliberately NOT named TRMASTER.DTA, so the program's
own file resolution (FCONTEST.SetUpFileNames) never picks it up and no section
before the matrix's initialexchange section can see it. uContestMatrix opens it
there and only there (M11 S0c; plan finding F17).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "trmaster"))
import trmaster_codec   # noqa: E402

SOURCE = os.path.join(HERE, "trmaster-fixture.txt")
TARGET = os.path.join(HERE, "MATRIX-TRMASTER.DTA")


def read_source(path):
   calls = {}
   with open(path, encoding="ascii") as f:
      for raw in f:
         line = raw.strip()
         if line == "" or line.startswith("#"):
            continue
         parts = line.split("|")
         call = parts[0].strip().upper()
         fields = {}
         for part in parts[1:]:
            name, value = part.split("=", 1)
            name = name.strip()
            if name not in trmaster_codec.FIELD_TO_TAG or name in ("Hits", "Speed"):
               raise SystemExit("unknown or binary field %r for %s" % (name, call))
            fields[name] = value.strip()
         if call in calls:
            raise SystemExit("%s appears twice" % call)
         calls[call] = fields
   if not calls:
      raise SystemExit("no calls in %s" % path)
   return calls


def main():
   calls = read_source(SOURCE)
   size = trmaster_codec.write_dta(TARGET, calls)
   back = trmaster_codec.read_dta(TARGET)
   if back["end_offset"] != back["file_size"]:
      raise SystemExit("end offset %d != file size %d" % (back["end_offset"], back["file_size"]))
   for call, fields in calls.items():
      got = back["calls"].get(call)
      if got is None:
         raise SystemExit("%s did not read back" % call)
      for name, value in fields.items():
         if str(got.get(name, "")) != value:
            raise SystemExit("%s %s read back as %r, wrote %r" % (call, name, got.get(name), value))
   print("wrote %s: %d calls, %d bytes, read back identical" % (TARGET, len(calls), size))
   return 0


if __name__ == "__main__":
   sys.exit(main())
