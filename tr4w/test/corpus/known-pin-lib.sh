#!/bin/bash
#
# A KNOWN DIFFERENCE IN ONE ARTIFACT, PINNED LINE FOR LINE -- the ONE
# implementation, sourced by run-golden-diff.sh (the export oracle) and
# test-adif-roundtrip.sh (the import round trip). Q54/Q76, 2026-10-16.
#
# A set may carry <set>/known.<kind>.diff: comment lines ('#', the first is
# the reason shown) and then EXACTLY the changed lines of that artifact -- the
# '-' REFERENCE lines and the '+' CANDIDATE lines, without ---/+++ headers or
# context. The artifact is KNOWN only when its changed lines are those and no
# others; anything more, less or different is a FAIL, and so is a pin whose
# difference has gone (the caller tests identity first and fails a stale pin).
#
# WHY ONE FILE: the two oracles must agree on what a pin means. Two copies of
# "the same" matcher drift, and a pin that one oracle accepts and the other
# rejects is a pin nobody can trust.
#
# THE CANONICAL FORM, so the diff TOOL does not matter: every '-' line in file
# order, then every '+' line in file order. golden_diff.py (difflib) and GNU
# `diff -u` agree on which lines changed but may cut them into hunks
# differently; collecting each side whole removes that. Carriage returns are
# dropped on both sides; trailing spaces are kept -- they are content.
#
# ORIENTATION IS FIXED: '-' is the reference, '+' the candidate. A caller
# whose own diff runs the other way must call it reference-first.
#
# A CALLER THAT NORMALISES ITS VIEW (the round trip drops some tags from both
# files before comparing) passes the same normaliser as a filter, and it is
# applied to the pinned lines too -- so a pin is always written as the full
# artifact lines and matched in whatever view the oracle compares.

# The changed lines of a unified diff (on stdin), in canonical form.
pin_canonical() {
   local all
   all=$(tr -d '\r' | grep -E '^[-+]' | grep -vE '^(---|\+\+\+) ')
   printf '%s\n' "$all" | grep -E '^-'
   printf '%s\n' "$all" | grep -E '^\+'
}

# The pinned lines of a pin file, as written (comments removed).
pin_lines() {
   tr -d '\r' < "$1" | grep -vE '^#'
}

# The reason a pin gives: its first comment line, without the '#'.
pin_reason() {
   tr -d '\r' < "$1" | grep -E '^#' | head -1 | sed -E 's/^#[[:space:]]*//'
}

# pin_matches <pin file> <unified diff text, reference first> [filter]
# True when the diff's changed lines are exactly the pinned ones. [filter] is
# a command (a function name is fine) reading lines on stdin, applied to the
# pinned lines before they are compared; default: none.
pin_matches() {
   local pin="$1" diffText="$2" filter="${3:-cat}"
   local got want
   got=$(printf '%s\n' "$diffText" | pin_canonical)
   want=$(pin_lines "$pin" | $filter | pin_canonical)
   [ -n "$want" ] && [ "$got" = "$want" ]
}
