#!/usr/bin/env python3
"""
Check every hamlibID TR4W registers against HamLib itself, via `rigctl -l`.

WHY.  test/unit/uTestHamLibIDs pins the registry against the values TR4W has
been shipping.  That catches a transcription slip, but it cannot catch a value
that was ALWAYS wrong -- task #16 found three of those (TS-590, TS-2000, FLEX)
only because someone went looking by hand.  HamLib is the sole authority on what
a rig_model number means, so ask it.

WHY rigctl AND NOT riglist.h.  NY4I's call, and he is right: rigctl reports what
the INSTALLED HamLib actually believes, which is what a running TR4W will talk
to.  Parsing a source checkout describes whatever version happens to be sitting
on disk, which may not be the library in use at all.

  rigctl -l              every model: id, manufacturer, model name, status
  rigctl -m <id> -u      caps dump for one model -- handy for a spot check

Usage:  python check_rig_models.py [path-to-rigctl.exe]
Exit 1 if any registered id is unknown to HamLib.
"""

import os
import re
import shutil
import subprocess
import sys

REPO = r"C:\tr4w-d12"
FACT = os.path.join(REPO, r"tr4w\src\radioFactory")

CANDIDATES = [
    r"C:\projects\hamlib\bin\rigctl.exe",
    r"C:\Program Files\hamlib\bin\rigctl.exe",
]


def find_rigctl(argv):
    if len(argv) > 1:
        return argv[1]
    found = shutil.which("rigctl")
    if found:
        return found
    for c in CANDIDATES:
        if os.path.exists(c):
            return c
    sys.exit("FATAL: rigctl not found. Pass its path as an argument.\n"
             "NOTE the rigctld.exe shipped in tr4w/target is x64 while\n"
             "libhamlib-4.dll and tr4w.exe are x86, so that copy cannot run.")


def hamlib_models(rigctl):
    """id -> (manufacturer, model name)."""
    try:
        out = subprocess.run([rigctl, "-l"], capture_output=True, text=True,
                             timeout=60).stdout
    except Exception as e:
        sys.exit("FATAL: could not run %s -l: %s" % (rigctl, e))

    models = {}
    for line in out.splitlines():
        cols = [c for c in re.split(r"\s{2,}", line.strip()) if c]
        if len(cols) < 3 or not cols[0].isdigit():
            continue
        models[int(cols[0])] = (cols[1], cols[2])
    if not models:
        sys.exit("FATAL: parsed no models from `rigctl -l`.")
    return models


def registrations():
    """(enum, displayName, hamlibID) for every registration carrying an id."""
    # Comments stripped first: a RegisterRadio EXAMPLE inside a doc comment is
    # not a registration.  One such example in uRadioFlexCAT already caused a
    # bad automated edit, so this is not hypothetical.
    out = []
    call = re.compile(
        r"Register(?:HamLibOnly)?Radio(?:ById)?\s*\((?P<body>.*?)\)\s*;", re.S)
    for name in sorted(os.listdir(FACT)):
        if not name.lower().endswith(".pas"):
            continue
        src = open(os.path.join(FACT, name), encoding="utf-8", errors="replace").read()
        src = re.sub(r"\{.*?\}", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
        src = re.sub(r"//[^\n]*", "", src)
        for m in call.finditer(src):
            body = m.group("body")
            if "function" not in body:          # a forward declaration
                continue
            enum = re.match(r"\s*([A-Za-z_]\w*)", body)
            disp = re.search(r"'([^']{2,})'", body)
            if not (enum and disp):
                continue
            # The id sits in DIFFERENT places in the two forms, and the numbers
            # around it are baud rates -- taking "the last integer" silently
            # reported 57600 as a rig_model on the first run of this script.
            #   RegisterHamLibOnlyRadio: displayName, hamlibID, SerialParams(...)
            #   RegisterRadio:           ..., SerialParams(...), hamlibID
            sp = body.find("SerialParams")
            if sp < 0:
                continue
            if "HamLibOnly" in m.group(0):
                seg = body[disp.end():sp]          # between the name and SerialParams
            else:
                close = body.find(")", body.find("(", sp))
                seg = body[close:]                 # after SerialParams(...)
            nums = re.findall(r"(?<![\w.])(\d{1,6})(?![\w.])", seg)
            out.append((enum.group(1), disp.group(1), int(nums[0]) if nums else 0))
    return out


def squash(s):
    return re.sub(r"[^A-Z0-9]", "", s.upper())


def main():
    rigctl = find_rigctl(sys.argv)
    models = hamlib_models(rigctl)
    regs = registrations()

    print("rigctl              : %s" % rigctl)
    print("HamLib models       : %d" % len(models))
    print("TR4W registrations  : %d\n" % len(regs))

    unknown, review, agreed = [], [], 0
    for enum, disp, hid in sorted(regs, key=lambda r: r[2]):
        if hid == 0:
            continue
        hit = models.get(hid)
        if hit is None:
            unknown.append((enum, disp, hid))
            continue
        mfg, model = hit
        ours = squash(disp) + squash(enum)
        # Loose on purpose: 'Elecraft K3' vs Elecraft/K3 should agree, while a
        # TS-590 pointing at an FT-847 should not.
        if squash(model) in ours or squash(mfg) in ours:
            agreed += 1
        else:
            review.append((enum, disp, hid, "%s %s" % (mfg, model)))

    if unknown:
        print("!! NOT OFFERED BY THIS HAMLIB BUILD (%d):" % len(unknown))
        print("   Either the id is wrong, OR the backend exists in riglist.h but is")
        print("   not compiled into the installed library -- which matters just as")
        print("   much, because that is the library TR4W loads.  Check riglist.h to")
        print("   tell the two apart.")
        print("   KNOWN AND EXPECTED: EXPERTTCI/7.  TCI is NOT a HamLib protocol --")
        print("   it is Expert Electronics' own -- and that row is a placeholder")
        print("   awaiting a native TCI driver.  It will flag every run until then.")
        for enum, disp, hid in unknown:
            print("   %-13s %-30s %d" % (enum, disp, hid))
        print()

    if review:
        print("?? NAME MISMATCH (%d) -- review by hand.  Some are legitimate (one" % len(review))
        print("   TR4W entry covering a family, or HamLib naming a rig differently),")
        print("   but a genuinely WRONG id looks exactly like this:")
        for enum, disp, hid, hn in review:
            print("   %-13s %-30s %-7d hamlib: %s" % (enum, disp, hid, hn))
        print()
        print("   Spot-check one with:  %s -m <id> -u" % os.path.basename(rigctl))
        print()

    print("agree: %d   review: %d   not a hamlib model: %d"
          % (agreed, len(review), len(unknown)))
    return 1 if unknown else 0


if __name__ == "__main__":
    sys.exit(main())
