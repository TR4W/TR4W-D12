#!/usr/bin/env python3
"""
TR4W golden-master diff (D7 vs D12) -- the CENTRAL Phase-1 oracle.

The D7 export is ground truth.  The one question that matters for the D12
port is: does the D12 build's .adi / .cbr match the D7 reference
BYTE-FOR-BYTE, after normalizing away the only legitimately volatile bits
(program version string + export timestamp)?  A passing diff means the
whole pipeline -- record read, field derivation, exchange formatting,
score summation, tag ordering, spacing, line endings -- is unchanged.
Any real difference (a changed field, a dropped QSO, a scoring delta)
shows up in the diff without modeling a single contest rule.

Volatile surface (normalized to a placeholder in BOTH files, nothing else):
  ADIF     - "Created by TR4W version <ver> on <timestamp>" comment line
           - <CREATED_TIMESTAMP:NN>VALUE          (export time)
           - <PROGRAMVERSION:NN>VALUE             (version; NN also shifts)
  Cabrillo - "CREATED-BY: <ver>" line

Files are read as latin-1 (byte-preserving) so CRLF/LF and any stray
high-bit byte differences remain visible -- they are signal, not noise.

Usage:
    golden_diff.py <ref_file> <candidate_file>        # diff one pair
    golden_diff.py --selftest <corpus_dir>            # validate the
                                                        normalizer on the
                                                        D7 refs (no D12
                                                        export needed)
Exit codes:
    0  identical after normalization  (or all self-tests passed)
    1  differences found              (or a self-test failed)
    2  usage / file error
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

PLACEHOLDER = "<NORMALIZED>"


def normalize_adif(text):
    text = re.sub(r"Created by TR4W version [^\r\n]*",
                  "Created by TR4W version " + PLACEHOLDER, text)
    text = re.sub(r"<CREATED_TIMESTAMP:\d+>[^\r\n]*",
                  "<CREATED_TIMESTAMP:N>" + PLACEHOLDER, text)
    text = re.sub(r"<PROGRAMVERSION:\d+>[^\r\n]*",
                  "<PROGRAMVERSION:N>" + PLACEHOLDER, text)
    return text


def normalize_cabrillo(text):
    return re.sub(r"CREATED-BY:[^\r\n]*", "CREATED-BY: " + PLACEHOLDER, text)


def kind_for(path):
    ext = Path(path).suffix.lower()
    if ext == ".adi":
        return "adif"
    if ext in (".cbr", ".log"):
        return "cabrillo"
    # Fall back on content sniff.
    head = Path(path).read_text(encoding="latin-1")[:64]
    return "cabrillo" if head.startswith("START-OF-LOG") else "adif"


def normalize(path, text):
    return normalize_adif(text) if kind_for(path) == "adif" \
        else normalize_cabrillo(text)


def read_latin1(path):
    return Path(path).read_bytes().decode("latin-1")


def diff_pair(ref_path, cand_path):
    """Return (identical, unified_diff_text)."""
    ref_n = normalize(ref_path, read_latin1(ref_path))
    cand_n = normalize(cand_path, read_latin1(cand_path))
    if ref_n == cand_n:
        return True, ""
    diff = difflib.unified_diff(
        ref_n.splitlines(keepends=True),
        cand_n.splitlines(keepends=True),
        fromfile=f"D7-ref  {Path(ref_path).name}",
        tofile=f"D12-cand {Path(cand_path).name}",
        n=2,
    )
    return False, "".join(diff)


# ---------------------------------------------------------------------------
# Self-test: prove the normalizer absorbs EXACTLY version+timestamp and
# nothing else, using only the D7 references (no D12 export required).
# ---------------------------------------------------------------------------

def _fake_other_build(text, kind):
    """Simulate the same log exported by a different build at a different
    time: rewrite version + timestamp only."""
    t = text.replace("4.149.0", "4.201.3")
    if kind == "adif":
        t = t.replace("20260705 141459", "20250101 000000")
        t = re.sub(r"on [A-Za-z]{3}-\d\d-\d{4} \d\d:\d\d:\d\d",
                   "on Jan-01-2025 00:00:00", t)
    return t


def _mutate_body(text, kind):
    """Change one byte of actual QSO content (after the header) so a real
    difference MUST be detected."""
    if kind == "adif":
        marker = "<EOH>"
        idx = text.upper().find(marker)
        cut = idx + len(marker) if idx >= 0 else 0
    else:
        cut = text.find("QSO:")
        cut = cut if cut >= 0 else 0
    head, body = text[:cut], text[cut:]
    # Flip the first ASCII letter in the body to a digit-safe different letter.
    for i, ch in enumerate(body):
        if ch.isalpha():
            repl = "Z" if ch.upper() != "Z" else "Q"
            return head + body[:i] + repl + body[i + 1:]
    return text  # nothing to mutate (shouldn't happen)


def selftest(corpus_dir):
    d = Path(corpus_dir)
    refs = sorted(list(d.glob("*/ref.adi")) + list(d.glob("*/ref.cbr")))
    if not refs:
        sys.stderr.write(f"no ref.adi/ref.cbr under {corpus_dir}\n")
        return 2
    failures = 0
    for ref in refs:
        kind = kind_for(ref)
        orig = read_latin1(ref)
        norm = normalize(ref, orig)

        # B: version/timestamp invariance -- must normalize equal.
        fake = _fake_other_build(orig, kind)
        assert fake != orig, f"fixture unchanged for {ref}"
        b_ok = normalize(ref, fake) == norm

        # C: content sensitivity -- must normalize UNequal.
        mut = _mutate_body(orig, kind)
        c_ok = (mut != orig) and (normalize(ref, mut) != norm)

        tag = f"{ref.parent.name}/{ref.name}"
        if b_ok and c_ok:
            print(f"  OK    {tag:<34} (version-invariant + content-sensitive)")
        else:
            failures += 1
            why = []
            if not b_ok:
                why.append("version/timestamp NOT absorbed")
            if not c_ok:
                why.append("content change NOT detected")
            print(f"  FAIL  {tag:<34} {'; '.join(why)}")
    print(f"\n{len(refs) - failures}/{len(refs)} self-tests passed.")
    return 0 if failures == 0 else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("a", help="ref file, OR corpus dir with --selftest")
    ap.add_argument("b", nargs="?", help="candidate file")
    ap.add_argument("--selftest", action="store_true",
                    help="validate the normalizer against the D7 refs")
    args = ap.parse_args()

    if args.selftest:
        sys.exit(selftest(args.a))

    if not args.b:
        sys.stderr.write("need two files (or --selftest <dir>)\n")
        sys.exit(2)

    identical, diff = diff_pair(args.a, args.b)
    if identical:
        print(f"IDENTICAL (after normalization): {Path(args.a).name}")
        sys.exit(0)
    sys.stdout.write(diff)
    sys.stderr.write(f"\nDIFFERENCES found in {Path(args.a).name}\n")
    sys.exit(1)


if __name__ == "__main__":
    main()
