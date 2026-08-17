#!/usr/bin/env bash
# corpus-lib.sh -- shared path/manifest helpers for the golden-master corpus.
#
# Sourced by export-d12-corpus.sh and pull-d12-candidates.sh so the two agree on
# WHERE a set's working directory is.  They previously each hardcoded the same
# out-of-tree default and had already drifted apart in spelling
# (/c/tr4w-d12/D7-LogFilesForTesting vs /c/TR4W-D12/D7-LOGFILESFORTESTING).
#
# ---------------------------------------------------------------------------
# Where the corpus gets its inputs
# ---------------------------------------------------------------------------
# Every set's .CFG and binary .TRW are ALREADY IN THE REPO, as the tracked
# log.cfg / log.trw beside each manifest.json -- they are byte-identical to the
# files the frozen D7 references were exported from.  So the corpus stages its
# own inputs into a scratch directory and needs nothing outside the clone.
#
# That matters because the export is DESTRUCTIVE: it deletes the prior .ADI and
# the Cabrillo .LOG from the directory it runs in.  Pointing it at a scratch
# copy means a corpus run can no longer mutate anybody's real log directory,
# and a set can no longer pass on a hand-edited input.
#
# Override with D12_ROOT to export from a raw log directory instead -- that is
# the flow for producing a NEW set (import-set.sh) from real contest logs, where
# the input is by definition not in the repo yet.
CORPUS_WORK="${CORPUS_WORK:-build-out/corpus-work}"

# corpus_manifest_get <manifest.json> <dotted.key>
corpus_manifest_get(){
   python -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d[k]
print(d)' "$1" "$2"
}

# corpus_set_dir <slug> <basename-of-source_dir>
# The directory the app is pointed at for this set.  ALWAYS absolute: the
# exporter builds the exe's argument inside a subshell that has already cd'd to
# tr4w/target, so a path relative to the repo root would resolve against the
# wrong directory (and cygpath cannot shorten a relative path at all).
corpus_set_dir(){
   if [ -n "${D12_ROOT:-}" ]; then
      printf '%s/%s\n' "$D12_ROOT" "$2"
   else
      case "$CORPUS_WORK" in
         /*) ;;
         *) CORPUS_WORK="$PWD/$CORPUS_WORK" ;;
      esac
      # Staged dirs are named by SLUG, which by construction has no spaces.
      # The source_dir basenames do ("2026 ARRL-FD NY4I"), which is why the
      # caller has to shorten them to 8.3 before handing one to the exe.
      printf '%s/%s\n' "$CORPUS_WORK" "$1"
   fi
}

# corpus_stage_set <manifest.json> <slug> <dest-dir>
# Copy the tracked inputs in under their ORIGINAL file names -- TR4W derives the
# log path from the .CFG's own name, so log.cfg/log.trw cannot be used as-is.
# No-op when D12_ROOT is set: that directory is the user's, not ours to write.
corpus_stage_set(){
   [ -n "${D12_ROOT:-}" ] && return 0
   local m="$1" slug="$2" dest="$3" here_dir ocfg olog
   here_dir=$(dirname "$m")
   ocfg=$(corpus_manifest_get "$m" orig.cfg)
   olog=$(corpus_manifest_get "$m" orig.log)
   [ -f "$here_dir/log.cfg" ] && [ -f "$here_dir/log.trw" ] || {
      echo "ERROR: $slug is missing its tracked log.cfg/log.trw" >&2; return 1; }
   rm -rf "$dest"
   mkdir -p "$dest" || return 1
   cp "$here_dir/log.cfg" "$dest/$ocfg" || return 1
   cp "$here_dir/log.trw" "$dest/$olog" || return 1
   return 0
}
