#!/usr/bin/env python3
"""
TR4W golden-master check (D7 vs D12) -- two gates, per NY4I's guidance.

These files exist to be CONSUMED: Cabrillo goes to contest sponsors, ADIF
goes to other loggers.  Both must be plain ASCII, and the log-derived
records must be reproduced exactly by the D12 build.  So we run two gates:

  1. VALIDITY (the file's purpose): is it well-formed 7-bit ASCII, no NUL /
     control bytes?  This catches D12 wide-string ("UTF-16 written as bytes")
     corruption -- e.g. END-OF-LOG emitted as 45 00 4E 00 ... -- with no
     reference at all.  A sponsor's robot / an ADIF importer would choke on it.

  2. FIDELITY (D7 == D12): do the log-derived records match byte-for-byte?
       ADIF     - whole file minus the volatile header bits (version +
                  export timestamp).  ADIF_VER / PROGRAMID stay as signal.
       Cabrillo - ONLY the QSO: / X-QSO: records.  The header is entrant /
                  settings metadata (CATEGORY-*, OPERATORS, ADDRESS, ...) that
                  legitimately varies between exports, so it is ignored
                  ("ignore the header; the QSO/X-QSO records should be the
                  same" -- NY4I).

Files are read latin-1 (byte-preserving) so NUL/CRLF/high-bit stay visible.

Usage:
    golden_diff.py <ref_file> <candidate_file>
    golden_diff.py --selftest <corpus_dir>
Exit codes:
    0  valid AND identical (or all self-tests passed)
    1  fidelity differences
    2  usage / file error
    3  validity failure (non-ASCII / corruption)
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

PLACEHOLDER = "<NORMALIZED>"


# --- gate 1: validity -------------------------------------------------------

def check_ascii_clean(text):
    """Return (ok, offset, byte, kind).  NUL and non-tab/CR/LF control bytes
    are hard failures (the wide-write corruption signature); a high-bit byte
    (>=0x80) is also flagged since sponsors/Cabrillo want ASCII."""
    for i, ch in enumerate(text):
        c = ord(ch)
        if c == 0:
            return False, i, c, "NUL byte (wide-string-as-bytes corruption)"
        if c < 0x20 and c not in (0x09, 0x0A, 0x0D):
            return False, i, c, "control byte"
        if c >= 0x80:
            return False, i, c, "non-ASCII byte (sponsors/importers want ASCII)"
    return True, -1, -1, ""


def _context(text, offset, span=30):
    lo, hi = max(0, offset - span), min(len(text), offset + span)
    return text[lo:hi].replace("\r", "\\r").replace("\n", "\\n").replace("\0", "\\0")


# --- gate 2: fidelity -------------------------------------------------------

def normalize_adif(text):
    text = re.sub(r"Created by TR4W version [^\r\n]*",
                  "Created by TR4W version " + PLACEHOLDER, text)
    text = re.sub(r"<CREATED_TIMESTAMP:\d+>[^\r\n]*",
                  "<CREATED_TIMESTAMP:N>" + PLACEHOLDER, text)
    text = re.sub(r"<PROGRAMVERSION:\d+>[^\r\n]*",
                  "<PROGRAMVERSION:N>" + PLACEHOLDER, text)
    return text


def cabrillo_records(text):
    """Keep the QSO: / X-QSO: records (what a sponsor scores) PLUS
    CLAIMED-SCORE -- the latter is log/multiplier-derived, so a D12 mult
    regression (e.g. the CompareStringW dupe/mult bug) shows up here.  The
    rest of the header is entrant/settings metadata that legitimately varies
    between exports, so it is dropped."""
    out = []
    for line in text.splitlines():
        u = line.lstrip().upper()
        if (u.startswith("QSO:") or u.startswith("X-QSO:")
                or u.startswith("CLAIMED-SCORE:")):
            out.append(line)
    return "\n".join(out)


def kind_for(path):
    ext = Path(path).suffix.lower()
    if ext == ".adi":
        return "adif"
    if ext in (".cbr", ".log"):
        return "cabrillo"
    head = Path(path).read_text(encoding="latin-1")[:64]
    return "cabrillo" if head.startswith("START-OF-LOG") else "adif"


def fidelity_view(path, text):
    return normalize_adif(text) if kind_for(path) == "adif" \
        else cabrillo_records(text)


def read_latin1(path):
    return Path(path).read_bytes().decode("latin-1")


# --- driver -----------------------------------------------------------------

def check_pair(ref_path, cand_path):
    """Return (validity_ok, fidelity_ok, report_text)."""
    ref = read_latin1(ref_path)
    cand = read_latin1(cand_path)
    lines = []

    # Gate 1 -- validity of the candidate (the D12 output under scrutiny).
    v_ok, off, byte, kind = check_ascii_clean(cand)
    if not v_ok:
        lines.append(
            f"VALIDITY FAIL: {kind} 0x{byte:02x} at offset {off}\n"
            f"    ...{_context(cand, off)}...")

    # Gate 2 -- fidelity of the log-derived records.
    ref_v = fidelity_view(ref_path, ref)
    cand_v = fidelity_view(cand_path, cand)
    f_ok = ref_v == cand_v
    if not f_ok:
        scope = "QSO/X-QSO records" if kind_for(ref_path) == "cabrillo" \
            else "records (header normalized)"
        lines.append(f"FIDELITY FAIL: {scope} differ:")
        lines.append("".join(difflib.unified_diff(
            ref_v.splitlines(keepends=True), cand_v.splitlines(keepends=True),
            fromfile=f"D7-ref  {Path(ref_path).name}",
            tofile=f"D12-cand {Path(cand_path).name}", n=2)))

    return v_ok, f_ok, "\n".join(lines)


# --- self-test --------------------------------------------------------------

def _fake_other_build(text, kind):
    t = text.replace("4.149.0", "4.201.3")
    if kind == "adif":
        t = t.replace("20260705 141459", "20250101 000000")
        t = re.sub(r"on [A-Za-z]{3}-\d\d-\d{4} \d\d:\d\d:\d\d",
                   "on Jan-01-2025 00:00:00", t)
    return t


def _mutate_record(text, kind):
    """Change one byte of an actual QSO record so fidelity MUST fail."""
    anchor = ("QSO:" if kind == "cabrillo" else "<EOH>")
    idx = text.upper().find(anchor)
    cut = idx + len(anchor) if idx >= 0 else 0
    head, body = text[:cut], text[cut:]
    for i, ch in enumerate(body):
        if ch.isalpha():
            return head + body[:i] + ("Z" if ch.upper() != "Z" else "Q") + body[i + 1:]
    return text


def selftest(corpus_dir):
    refs = sorted(list(Path(corpus_dir).glob("*/ref.adi"))
                  + list(Path(corpus_dir).glob("*/ref.cbr")))
    if not refs:
        sys.stderr.write(f"no ref.adi/ref.cbr under {corpus_dir}\n")
        return 2
    fails = 0
    for ref in refs:
        kind = kind_for(ref)
        orig = read_latin1(ref)
        view = fidelity_view(ref, orig)

        # validity: clean ref passes; a NUL injected into it fails.
        clean = check_ascii_clean(orig)[0]
        corrupt = not check_ascii_clean(orig[:20] + "\0" + orig[20:])[0]
        # fidelity: version/timestamp change stays equal; record change differs.
        inv = fidelity_view(ref, _fake_other_build(orig, kind)) == view
        sens = fidelity_view(ref, _mutate_record(orig, kind)) != view

        tag = f"{ref.parent.name}/{ref.name}"
        if clean and corrupt and inv and sens:
            print(f"  OK    {tag:<34} (valid + version-invariant + record-sensitive)")
        else:
            fails += 1
            bad = [n for n, ok in (("valid-clean", clean), ("catches-NUL", corrupt),
                                   ("version-invariant", inv), ("record-sensitive", sens)) if not ok]
            print(f"  FAIL  {tag:<34} {', '.join(bad)}")
    print(f"\n{len(refs) - fails}/{len(refs)} self-tests passed.")
    return 0 if fails == 0 else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("a", help="ref file, OR corpus dir with --selftest")
    ap.add_argument("b", nargs="?", help="candidate file")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        sys.exit(selftest(args.a))
    if not args.b:
        sys.stderr.write("need two files (or --selftest <dir>)\n")
        sys.exit(2)

    v_ok, f_ok, report = check_pair(args.a, args.b)
    if v_ok and f_ok:
        print(f"PASS: {Path(args.a).name} -- valid ASCII and records identical.")
        sys.exit(0)
    sys.stdout.write(report + "\n")
    sys.exit(3 if not v_ok else 1)


if __name__ == "__main__":
    main()
