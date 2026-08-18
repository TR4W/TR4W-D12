# A typed-input corpus: testing the half the current one cannot reach

**NY4I's proposal, 2026-08-17**, prompted by the Phase 3b typing harness working:

> *"If we know the contest which you can set in a file, then you know what the cabrillo and
> adif should look like as well as what should be in the log. You can also use a radio
> simulator (even a TCI simulator) and change frequencies, etc. That makes for a nice
> corpus test suite (not done every time but for regression test)."*

## Why this is worth doing: the gap is structural

The 13 existing sets start from a **log that already exists** — a D7-written `.trw` — and
run `tr4w.exe "<contest>.CFG" /EXPORT`. They prove the **export** half:
`ContestExchange` → ADIF/Cabrillo, byte for byte.

They cannot prove the **entry** half, because nothing in them ever types anything. And the
entry half is precisely what has no other coverage: CLAUDE.md records that the unit tests
link only leaf `src` units, so **`ProcessExchange`, scoring and dupe checking are not
unit-covered** — they need the app's globals booted. Between the two, the path

```
keystroke -> ProcessExchange -> dupe -> multiplier -> score -> log record -> export
```

is tested only at its last arrow.

A typed set would run the whole chain and compare the same two artifacts. It is the same
oracle, aimed one stage earlier.

## What already exists

| piece | where |
|---|---|
| keystroke injection into the running program | `test/ui/Test-Typing.ps1`, proven 2026-08-17 |
| a radio simulator | `tools/radiosim` (Elecraft and others) |
| a TCI radio | TR4W's own TCI server; `docs/TCI_SERVER_DESIGN.md` |
| byte-diff with volatile fields normalized | `test/python/golden_diff.py` — already blanks the version banner and `CREATED_TIMESTAMP` |
| deterministic QSO times | **`HAND LOG MODE`** (`tHandLogMode`, a CFG setting) — it gates the `GetSystemTime` call at `MainUnit.pas:7858` |

## The one hard problem: time

A freshly typed QSO carries the date and UTC of the moment it was typed, so a byte
comparison against a frozen reference fails on every record. Three ways out, and they are
not equal:

1. **Normalize the time fields in `golden_diff.py`.** Cheapest, and it throws away exactly
   what a logger must get right. The header normalization there is defensible because a
   version string is not contest data; a QSO time is.
2. **`HAND LOG MODE`.** TR4W's own mechanism for entering times by hand. The times become
   part of what is TYPED, therefore part of what is ASSERTED. This is the right one.
3. Freeze the clock from outside. Fragile and affects everything else in the process.

## Shape of a set

```
typed/<slug>/
   script.txt      what to type, keystroke by keystroke, times included
   log.cfg         the contest -- this is what makes the expected output knowable
   radio.txt       optional: simulator frequency/mode changes, interleaved
   ref.adi         frozen expected ADIF
   ref.cbr         frozen expected Cabrillo
   ref.trw         optional: the expected binary log
```

## What it would catch that nothing else does

* an exchange-parsing change that alters what gets STORED (today only visible if it also
  changes the export);
* a dupe or multiplier regression on entry;
* band changes driven by the radio, and the mults that depend on them;
* scoring at the moment of logging rather than at export.

## It does not have to wait for the export: the window ITSELF is assertable

NY4I, extending the idea: *"we can verify the score calculations, mults worked, edit form
and more... Add in the cluster simulator you have a nice test suite."*

That is a better oracle than the export for anything that goes wrong DURING entry, because
it fails at the QSO that caused it rather than at the end of the file. The main window
displays all of it, and every element is individually addressable by
`TMainWindowElement` -- `Dump-WindowTree.ps1` already reads their text. Fourteen of the
fifty are directly relevant:

    mweTotalScore        mweRate              mweHourRate
    mweQSONumber         mweCQQSOCounter      mweSPQSOCounter
    mweNewMultStatus     mweMultNeedsHeader   mweQSONeedsHeader
    mweQSOB4Status       mweDupeInfoCall      mweQSOsWithThisStation
    mweBandMode          mweLastQSOTime

So a typed set can assert **after every QSO**: the score advanced by the right points, the
multiplier registered, the dupe flagged, the serial incremented, the band followed the
radio. The export diff at the end then confirms the same facts survived to the file.

### The Edit QSO form

Dialog 46, 78 controls, the densest in the program -- and the ONE converted dialog that can
change log bytes, which is why the migration plan already makes the corpus a real gate for
it. A typed set is what makes that gate meaningful: log a QSO, open Edit QSO, change a
field, save, re-export, diff. Without typed input there is nothing to edit that the test
itself produced.

### The cluster simulator

`c:\projects	est-tools\mockDXCluster` (do not modify it -- it is a shared tool). Feeding
it a fixed spot script exercises the path nothing else covers end to end: telnet transport
-> `uDXSpotParse` -> band map -> click-to-tune -> the callsign arriving in the entry field.
The DX-cluster capture corpus (198,979 real lines) already covers PARSING; this covers what
happens to a spot AFTER it parses.

Note the shape this gives the suite: three simulators standing in for the three things a
contest station is connected to -- a radio (`tools/radiosim` or TCI), a cluster
(mockDXCluster), and an operator (the typing harness). None of them needs hardware.

## Deliberately not run on every commit

NY4I's own framing, and right: it needs a GUI, a simulator and wall-clock time. It belongs
beside the bench tests, not in `FullBuild.ps1`. The per-commit gates stay the unit tests
and the export corpus.

## Status

**Proposed, not built.** Recorded here so it is not lost, and because the typing harness
that makes it possible landed for a different reason (Phase 3b's safety net). Sequence it
after the LCL migration's pivot — driving keystrokes at a program whose input path is
being rewritten would test the scaffolding rather than the engine.
