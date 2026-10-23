#!/usr/bin/env bash
# validate-adif-outputs.sh [corpus|roundtrip|matrix|all]
#
# IS THE ADIF TR4W WRITES ACCEPTED BY AN INDEPENDENT VALIDATOR?
#
# Runs K1MU's ADIF validator (tools/adifvalidator, vendored -- see its
# VENDORED.md) over the ADIF the three producers write:
#
#   corpus     build-out/corpus-work/<slug>/*.ADI   export-d12-corpus.sh
#   roundtrip  build-out/adif-validate/roundtrip/   test-adif-roundtrip.sh
#   matrix     the "== export.adif" sections of build-out/contest-matrix-work/fresh/*.matrix
#                                                   run-contest-matrix.sh
#
# Each producer calls this at the end of its own run with its own source,
# because that is the only moment its files exist (the round trip deletes its
# work files as it goes, and the matrix keeps its ADIF inside .matrix records).
# With no argument it checks all three.
#
# WHAT FAILS THE RUN: any "Compliance error" -- the file is not valid ADIF
# (an unknown tag, a MODE not in the enumeration, a SUBMODE of the wrong MODE)
# -- that is not PINNED, and any pin that matches nothing.
#
# THE PINS, known-findings-<source>.txt beside this script: one line per
# excused finding, "<file>|<count>|<message>" exactly as the run reports it
# (the line number is dropped), a "#" comment above each block saying WHY. A
# finding is excused only by its exact line, count included; a pin that no
# longer matches a finding FAILS as stale, so a fixed defect cannot stay
# excused -- the corpus's known.*.diff rule. There is no switch to skip the
# check. Use a pin only for SYNTHETIC INPUT (the matrix feeds every contest
# one fixed table of QSOs, some of which no live entry could produce); a real
# defect is fixed in the exporter.
# WHAT DOES NOT: "Consistency error" findings, which judge DATA the validator
# knows better than the contest does (a zone that does not fit a country, a
# call sign it thinks is odd). They are counted and the distinct kinds listed,
# so a new kind is visible, but they are not this gate's verdict.
#
# IT FAILS CLOSED. A check that passes because it checked nothing is worse than
# no check (CLAUDE.md, "guards must not fail open"). Each of these exits 1 with
# a message: no python, no validator, a requested source with zero files, the
# validator crashing or producing no summary line.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
VALIDATOR_DIR="$REPO_ROOT/tools/adifvalidator"
VALIDATOR="$VALIDATOR_DIR/adifparse.py"
WORK="$REPO_ROOT/build-out/adif-validate"
CORPUS_WORK_DIR="${CORPUS_WORK:-$REPO_ROOT/build-out/corpus-work}"
MATRIX_FRESH="${MATRIX_FRESH_DIR:-$REPO_ROOT/build-out/contest-matrix-work/fresh}"
ROUNDTRIP_DIR="$WORK/roundtrip"

what="${1:-all}"
case "$what" in
   corpus|roundtrip|matrix|all) ;;
   *) echo "validate-adif-outputs: unknown source '$what' (corpus, roundtrip, matrix or all)" >&2; exit 1 ;;
esac

die(){
   echo "validate-adif-outputs: FAIL -- $*" >&2
   exit 1
}

# ---- the interpreter: it must RUN, not merely be found on PATH. A Windows
# store stub for python3 is found and does nothing.
PY=""
for cand in python python3; do
   if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys; sys.exit(0)' >/dev/null 2>&1; then
      PY="$cand"
      break
   fi
done
[ -n "$PY" ] || die "no working python on PATH (tried python, python3)"

[ -f "$VALIDATOR" ] || die "the validator is missing: $VALIDATOR"
[ -f "$VALIDATOR_DIR/adiftags.py" ] || die "the validator's tag tables are missing: $VALIDATOR_DIR/adiftags.py"

native(){
   if command -v cygpath >/dev/null 2>&1; then
      cygpath -m "$1"
   else
      printf '%s\n' "$1"
   fi
}

mkdir -p "$WORK/out" || die "cannot create $WORK/out"
rm -f "$WORK"/out/* "$WORK"/actual-*.txt "$WORK"/pins-*.txt "$WORK"/unexcused-*.txt "$WORK"/stale-*.txt 2>/dev/null

# ---- the file list: "<source> <path>" lines.
LIST="$WORK/files.txt"
: > "$LIST"

if [ "$what" = "corpus" ] || [ "$what" = "all" ]; then
   n0=$(wc -l < "$LIST")
   for f in "$CORPUS_WORK_DIR"/*/*.ADI "$CORPUS_WORK_DIR"/*/*.adi; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in ref.adi|cand.adi|rescored.adi) continue ;; esac
      printf 'corpus %s\n' "$f" >> "$LIST"
   done
   [ "$(wc -l < "$LIST")" -gt "$n0" ] || die "corpus: no ADIF under $CORPUS_WORK_DIR (run export-d12-corpus.sh first)"
fi

if [ "$what" = "roundtrip" ] || [ "$what" = "all" ]; then
   n0=$(wc -l < "$LIST")
   for f in "$ROUNDTRIP_DIR"/*.adi; do
      [ -f "$f" ] || continue
      printf 'roundtrip %s\n' "$f" >> "$LIST"
   done
   [ "$(wc -l < "$LIST")" -gt "$n0" ] || die "roundtrip: no ADIF under $ROUNDTRIP_DIR (run test-adif-roundtrip.sh first)"
fi

if [ "$what" = "matrix" ] || [ "$what" = "all" ]; then
   n0=$(wc -l < "$LIST")
   mkdir -p "$WORK/matrix" || die "cannot create $WORK/matrix"
   rm -f "$WORK"/matrix/*.adi 2>/dev/null
   for m in "$MATRIX_FRESH"/*.matrix; do
      [ -f "$m" ] || continue
      out="$WORK/matrix/$(basename "$m" .matrix).adi"
      # Only the records of the export.adif sections: a line that opens with '<'.
      # Four station variants per contest are concatenated into one file.
      awk '/^== /{ keep = ($0 == "== export.adif" || $0 == "== export.adif\r"); next }
           keep && /^</ { print }' "$m" > "$out"
      if [ -s "$out" ]; then
         printf 'matrix %s\n' "$out" >> "$LIST"
      else
         rm -f "$out"
      fi
   done
   [ "$(wc -l < "$LIST")" -gt "$n0" ] || die "matrix: no ADIF records under $MATRIX_FRESH (run run-contest-matrix.sh first)"
fi

[ -s "$LIST" ] || die "no files to validate"

# ---- run it.
files=0; comp_total=0; cons_total=0; bad_files=""; crashed=""
: > "$WORK/cons-kinds.txt"
declare -A src_files src_comp
src_files=(); src_comp=()

while read -r src f; do
   files=$((files+1))
   base="$(basename "$f")"
   tag="${src}-$(basename "$(dirname "$f")")-$base"
   comp="$WORK/out/$tag.comp.txt"
   cons="$WORK/out/$tag.cons.txt"
   log="$WORK/out/$tag.stdout.txt"
   "$PY" "$(native "$VALIDATOR")" -f "$(native "$f")" -a "$(native "$comp")" -c "$(native "$cons")" > "$log" 2>&1
   rc=$?
   # A validator that crashed, or never reached its summary, has said nothing.
   if [ "$rc" -ne 0 ] || ! grep -q 'Informational: Handled' "$log"; then
      crashed="$crashed $tag(rc=$rc)"
      echo "  CRASH  $src  $base -- the validator did not finish:" >&2
      tail -5 "$log" | sed 's/^/           /' >&2
      continue
   fi
   c=$(grep -c 'Compliance error' "$comp" 2>/dev/null)
   k=$(grep -c 'Consistency error' "$cons" 2>/dev/null)
   c=${c:-0}; k=${k:-0}
   comp_total=$((comp_total + c))
   cons_total=$((cons_total + k))
   src_files[$src]=$(( ${src_files[$src]:-0} + 1 ))
   src_comp[$src]=$(( ${src_comp[$src]:-0} + c ))
   # The findings as pin lines: "<file>|<count>|<message>", line numbers gone.
   grep 'Compliance error' "$comp" | tr -d '\r' | sed 's/^ADIF Compliance error on line [0-9]*: //' \
      | sort | uniq -c \
      | awk -v f="$base" '{ c = $1; $1 = ""; sub(/^ /, ""); print f "|" c "|" $0 }' \
      >> "$WORK/actual-$src.txt"
   grep 'Consistency error' "$cons" | sed 's/^Consistency error on line [0-9]*: //' >> "$WORK/cons-kinds.txt"
done < "$LIST"

# ---- the pins. For each source that ran: what is not excused, and what is
# excused but no longer happens.
unexcused=0; stale=0
echo
for s in corpus roundtrip matrix; do
   [ -n "${src_files[$s]:-}" ] || continue
   actual="$WORK/actual-$s.txt"
   [ -f "$actual" ] || : > "$actual"
   pins="$HERE/known-findings-$s.txt"
   clean="$WORK/pins-$s.txt"
   : > "$clean"
   if [ -f "$pins" ]; then
      grep -v '^[[:space:]]*#' "$pins" | tr -d '\r' | grep -v '^[[:space:]]*$' > "$clean"
   fi
   n_actual=$(wc -l < "$actual")
   n_pins=$(wc -l < "$clean")
   : > "$WORK/unexcused-$s.txt"
   : > "$WORK/stale-$s.txt"
   if [ "$n_pins" -gt 0 ]; then
      grep -Fxv -f "$clean" "$actual" > "$WORK/unexcused-$s.txt"
   else
      cat "$actual" > "$WORK/unexcused-$s.txt"
   fi
   if [ "$n_actual" -gt 0 ]; then
      grep -Fxv -f "$actual" "$clean" > "$WORK/stale-$s.txt"
   else
      cat "$clean" > "$WORK/stale-$s.txt"
   fi
   u=$(wc -l < "$WORK/unexcused-$s.txt")
   t=$(wc -l < "$WORK/stale-$s.txt")
   unexcused=$((unexcused + u))
   stale=$((stale + t))
   printf '  %-10s %4d file(s), %d compliance error(s): %d finding line(s), %d pinned, %d NOT pinned, %d stale pin(s)\n' \
      "$s" "${src_files[$s]}" "${src_comp[$s]:-0}" "$n_actual" "$((n_actual - u))" "$u" "$t"
   if [ "$u" -gt 0 ]; then
      echo "    NOT PINNED (file|count|message):"
      head -40 "$WORK/unexcused-$s.txt" | sed 's/^/      /'
      [ "$u" -gt 40 ] && echo "      ... $((u - 40)) more in $WORK/unexcused-$s.txt"
   fi
   if [ "$t" -gt 0 ]; then
      echo "    STALE PIN -- it matches no finding (remove it from known-findings-$s.txt):"
      sed 's/^/      /' "$WORK/stale-$s.txt"
   fi
done

if [ "$cons_total" -gt 0 ]; then
   echo
   echo "consistency findings (reported, NOT a verdict): $cons_total"
   sort "$WORK/cons-kinds.txt" | uniq -c | sort -rn | head -12 | sed 's/^/    /'
fi

echo
if [ -n "$crashed" ]; then
   echo "=== ADIF validation: FAILED -- the validator crashed on:$crashed ==="
   exit 1
fi
if [ "$files" -eq 0 ]; then
   echo "=== ADIF validation: FAILED -- no file was validated ==="
   exit 1
fi
if [ "$unexcused" -ne 0 ] || [ "$stale" -ne 0 ]; then
   echo "=== ADIF validation: FAILED -- $unexcused unpinned finding line(s), $stale stale pin(s) in $files file(s); see $WORK/out ==="
   exit 1
fi
echo "=== ADIF validation: $files file(s), $comp_total compliance error(s) all pinned, $cons_total consistency finding(s) ==="
exit 0
