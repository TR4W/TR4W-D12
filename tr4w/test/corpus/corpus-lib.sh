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

# corpus_norm_artifact <file>
# Print an exported .ADI or Cabrillo with the two fields that are REGENERATED
# ON EVERY RUN BY DESIGN reduced to placeholders: the creation timestamp, and
# APP_TR4W_ID -- the per-QSO UUIDv7, minted at import, so the same contact gets
# a different id every time a log is rebuilt.
#
# NOTHING ELSE IS NORMALISED, and that is the whole point: every other byte has
# to match exactly.
#
# ...EXCEPT THE PROGRAM VERSION, added 2026-10-16. It is in three header lines
# (ADIF "Created by TR4W version ...", <PROGRAMVERSION:n>, Cabrillo CREATED-BY)
# and changes on every release bump -- NY4I bumps it every ten answered
# questions -- so without this every bump turned all 13 sets red and forced a
# re-freeze of 26 files that changed nothing but that string. A re-freeze for
# no reason is exactly the noise a real scoring change would hide in. Only
# those three header fields are touched; no QSO line is.
#
# IT LIVES HERE BECAUSE TWO SCRIPTS NEED IT AND A SECOND COPY WOULD DRIFT.
# freeze-rescore-baseline.sh writes the frozen bytes through it and
# test-contest-factory.sh compares fresh output through it, so if the two ever
# disagreed about what is volatile, every set would report a difference that is
# not one -- on the only gate that watches scoring.
corpus_norm_artifact(){
   sed -E 's/(Created by TR4W version ).* on .*/\1VERSION on TIME/;
           s/<PROGRAMVERSION:[0-9]+>TR4W v\.[^ <\r]*/<PROGRAMVERSION>TR4W v.VERSION/;
           s/^(CREATED-BY: TR4W v\.)[^ \r]*/\1VERSION/;
           s/(<CREATED_TIMESTAMP:15>).*/\1TIME/;
           s/<APP_TR4W_ID:32>[0-9a-f]*/<APP_TR4W_ID:32>ID/g' "$1" 2>/dev/null
}

# corpus_fixture_exchange_ids <log.db>
# How many QSO rows of a fixture log carry an exchange id (an ERROR: line when
# the file cannot be read -- which is not "0", so nothing is relaxed by it).
#
# corpus_drop_app_id
# stdin to stdout with every APP_TR4W_ID field deleted, value and separating
# space with it -- the same shape test-adif-roundtrip.sh's strip_tags uses.
#
# WHY BOTH EXIST (2026-10-14, NY4I's ruling on open question F6): a rescore no
# longer MINTS an exchange id for a QSO that has none.  Six fixtures carry no id
# at all, and their frozen rescored.adi still holds an <APP_TR4W_ID:32>ID
# placeholder on every record -- 1,772 of them -- because the legacy rescore
# minted one.  That placeholder records the very behaviour the ruling removed,
# not anything about scoring.  So test-contest-factory.sh sets the field aside
# on BOTH sides, and ONLY for a fixture whose log holds no id: where a log does
# carry ids, whether they survive the rescore is still compared exactly.  The
# same rule test-adif-roundtrip.sh already applies to a minted identity: it is
# ignored only where the reference has none to compare.  The frozen files are
# NOT regenerated.
corpus_fixture_exchange_ids(){
   python - "$1" <<'PY'
import sqlite3, sys
try:
   c = sqlite3.connect('file:' + sys.argv[1].replace('\\', '/') + '?mode=ro', uri=True)
   print(c.execute("SELECT COUNT(*) FROM qso WHERE exchange_id IS NOT NULL "
                   "AND exchange_id <> ''").fetchone()[0])
except Exception as e:
   print('ERROR:%s' % e)
PY
}

corpus_drop_app_id(){
   sed -E 's/<APP_TR4W_ID:[0-9]*>[^<]*//Ig'
}

# ---------------------------------------------------------------------------
# THE CABRILLO .LOG FILES IN tr4w/target ARE NOT OURS (2026-10-17).
# ---------------------------------------------------------------------------
# The scripts that run the app in tr4w/target (test-contest-factory,
# test-rescore, test-adif-roundtrip, freeze-rescore-baseline) used to clean
# up with `rm -f ./*.LOG` -- deleting EVERY Cabrillo export an operator had in
# that folder -- and to take "the" Cabrillo output as `ls ./*.LOG | head -1`,
# which picks an unrelated file whenever one is there. Now:
#
#   corpus_logs_snapshot   once, after cd to the target folder and BEFORE the
#                          first run: remembers which .LOG files exist, and
#                          says so loudly if any do.
#   corpus_new_logs        the .LOG files that appeared since the snapshot.
#   corpus_remove_new_logs deletes those, and only those.
#
# A pre-existing file is never deleted. If a run's Cabrillo has the SAME name
# as a pre-existing one the app overwrites it -- nothing here can prevent that,
# which is why the snapshot names every file it found.
corpus_list_logs(){
   ls -1 ./*.LOG 2>/dev/null | sort
}

corpus_logs_snapshot(){
   CORPUS_LOGS_BEFORE=$(corpus_list_logs)
   if [ -n "$CORPUS_LOGS_BEFORE" ]; then
      echo "NOTE: .LOG files already in $(pwd) are left alone (a run's Cabrillo of the same name would overwrite one):" >&2
      printf '%s\n' "$CORPUS_LOGS_BEFORE" | sed 's/^/   /' >&2
   fi
}

corpus_new_logs(){
   comm -13 <(printf '%s\n' "${CORPUS_LOGS_BEFORE:-}" | sed '/^$/d') \
            <(corpus_list_logs) | sed '/^$/d'
}

corpus_remove_new_logs(){
   corpus_new_logs | while IFS= read -r f; do
      rm -f -- "$f"
   done
}
