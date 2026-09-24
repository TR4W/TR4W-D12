#!/usr/bin/env bash
# corpus-lib.sh -- shared path/manifest helpers for the golden-master corpus.
#
# Sourced by export-d12-corpus.sh and pull-d12-candidates.sh so the two agree on
# WHERE a set's working directory is.  They previously each hardcoded the same
# out-of-tree default and had already drifted apart in spelling
# (/c/tr4w-d12/D7-LogFilesForTesting vs /c/TR4W-D12/D7-LOGFILESFORTESTING).
#
# ---------------------------------------------------------------------------
# WHAT THE CORPUS ASSERTS, AND WHAT ITS INPUT IS
# ---------------------------------------------------------------------------
# A GIVEN LOG PRODUCES THE EXPECTED ADIF AND CABRILLO.  The input is the
# tracked log.db beside each manifest.json -- a TR4W SQLite contest log, which
# is what a contest IS in this program.  The expected output is the frozen
# ref.adi / ref.cbr, still D7-produced and NEVER regenerated: that is the half
# of the oracle that is not our own output.
#
# THE D7 INPUT FORMATS WERE RETIRED BY DECISION, 2026-09-24.  Every set used to
# track a log.trw and a log.cfg, and the run began by importing the binary log.
# NY4I:
#
#     "I don't dispute its value to validating our processing today is
#      functionally the same as D7.  My point was we are so far past validating
#      that fact, that we do not need that step anymore.  Instead, the corpus
#      can adopt the testing methodology of comparing a given .db file produces
#      an expected ADIF and Cabrillo file."
#
# and, on the coverage that move gives up:
#
#     "Yes I agree it's remnant allow us to validate .Trw conversion but that
#      becomes a unit test and not the corpus."
#
# So binary-log import is covered by uTestLogBinaryFile / uTestLogImport /
# uTestLogRepository, over the six D7 logs kept as unit fixtures in
# tr4w/test/fixtures/binarylog.  DO NOT put .trw files back here.
#
# log.cfg IS STILL TRACKED and is NOT an input to this oracle.  It is the
# contest definition, and test-adif-roundtrip.sh needs it to create a FRESH
# empty contest of the right type before importing ref.adi.
#
# The export is DESTRUCTIVE -- it deletes the prior .ADI and the Cabrillo .LOG
# from the directory it runs in, and it writes to the log it opens -- so the
# fixture is COPIED into a scratch directory and the tracked file is never the
# one under test.
CORPUS_WORK="${CORPUS_WORK:-build-out/corpus-work}"

# corpus_manifest_get <manifest.json> <dotted.key>
corpus_manifest_get(){
   python -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d[k]
print(d)' "$1" "$2"
}

# corpus_set_dir <slug>
# The directory the app is pointed at for this set.  ALWAYS absolute: the
# exporter builds the exe's argument inside a subshell that has already cd'd to
# tr4w/target, so a path relative to the repo root would resolve against the
# wrong directory (and cygpath cannot shorten a relative path at all).
#
# D12_ROOT IS GONE, 2026-09-24.  It short-circuited staging so the corpus could
# export from a raw D7 log directory instead.  That directory holds a .CFG and a
# .TRW and no .db, so with the fixture now a database it could only ever have
# reported MISS -- a path that cannot work is worse than no path.  Creating a
# NEW set from real contest files is import-set.sh's job and always was.
corpus_set_dir(){
   case "$CORPUS_WORK" in
      /*) ;;
      *) CORPUS_WORK="$PWD/$CORPUS_WORK" ;;
   esac
   # Staged dirs are named by SLUG, which by construction has no spaces.
   printf '%s/%s\n' "$CORPUS_WORK" "$1"
}

# corpus_stage_set <manifest.json> <slug> <dest-dir>
# Copy the tracked log.db in under the contest's ORIGINAL stem -- TR4W derives
# every other name from the stem of the file it is given, so staging it as
# "<CONTEST>.db" keeps the exported .ADI named the way the reference was.
corpus_stage_set(){
   local m="$1" slug="$2" dest="$3" here_dir ocfg stem
   here_dir=$(dirname "$m")
   ocfg=$(corpus_manifest_get "$m" orig.cfg)
   stem="${ocfg%.*}"
   [ -f "$here_dir/log.db" ] || {
      echo "ERROR: $slug is missing its tracked log.db" >&2; return 1; }
   rm -rf "$dest"
   mkdir -p "$dest" || return 1
   cp "$here_dir/log.db" "$dest/$stem.db" || return 1
   # A stale write-ahead log beside a copied database would be replayed into it.
   # There should never be one -- the generator checkpoints -- so remove any
   # that appears rather than carrying it into the run.
   rm -f "$dest/$stem.db-wal" "$dest/$stem.db-shm"
   return 0
}
