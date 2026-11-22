# Digital sub-modes: record the real mode (design proposal)

Status: PROPOSAL, nothing implemented. Raised by NY4I on issue 45 (2026-11-22).
Not scheduled; this document exists so the question is answered once.

## The current model

A QSO carries two mode fields (`ContestExchange` in `VC.pas`):

* `Mode: ModeType` -- the SCORING mode: `CW`, `Phone`, `Digital` (and `NoMode`).
* `ExtMode: ExtendedModeType` -- what the operator actually used: `eFT8`, `eFT4`,
  `eRTTY`, `ePSK31`, `eData`, `eJTTY`, `eFT2`, `eCW_R`, `eUSB`, ...

Every digital QSO is `Mode = Digital`, whatever it was. `ExtMode` was added as a
band-aid so the true mode could be kept (and exported) without changing the main
mode from `Digital` to a sub-mode, which would have touched every contest's
scoring, the totals grid and the reports.

Where each half is read:

* Scoring, dupe checking, multiplier tracking, the QSO totals grid, Cabrillo
  category rules and every contest class ask `Mode` (CW / Phone / Digital).
* ADIF export (`uADIF.ResolveADIFModeSubmode`) and the N1MM XML broadcast
  (`uN1MMMode`) read `ExtMode`; `Digital` with `eNoMode` is written as RTTY.
* The Edit QSO window shows the extended mode.
* Import (`uADIF.GetADIFMode` / `GetADIFSubMode`) fills both.

## The problem

1. A record whose mode is not understood has no honest value. Today it becomes
   `Digital` with no extended mode, which exports as RTTY -- a statement the
   operator never made. (Issue 45's listener falls back to `Digital` / `eData`
   and logs a warning for the same reason.)
2. Two fields that must agree are a standing source of drift: a QSO can be
   `Digital` with `ExtMode = eSSB` if any writer forgets the pair. The tables in
   `uADIF` keep them consistent only for the modes someone listed.
3. Every new mode (FT2, JTTY, FST4) needs a row in more than one table and the
   place that decides "this is digital" is spread over those tables.
4. NY4I's observation: the operator thinks "FT8"; the program stores `Digital`
   plus a footnote.

## Options

### A. Keep the pair, make the mapping a single table (smallest)

One `array[ExtendedModeType]` giving the scoring mode, and an invariant:
`Mode` is DERIVED from `ExtMode` whenever `ExtMode <> eNoMode`.

* Pro: no data change, no migration, no scoring change.
* Pro: removes drift (problem 2) and the unknown-mode hole (problem 1) if
  `eNoMode` stays "scoring mode only".
* Con: the stored `Mode` is still `Digital`; a reader that wants the real mode
  still reads the second field.

### B. Store the real mode; scoring asks a category (NY4I's proposal)

`Mode` holds FT8, FT4, RTTY, ...; a function `ScoringModeOf(Mode)` returns
CW / Phone / Digital, and everything that scores, dupes, totals or reports calls
it. `ExtMode` shrinks to the sideband / reverse detail (`USB`, `LSB`, `CW-R`).

* Pro: the real mode is the mode. Edit QSO, grids and exports read one field.
* Pro: new modes are one row in one table.
* Con: every place that compares `Mode` today (the contest classes, the dupe
  sheet's per-mode tables, the band-mode totals arrays dimensioned by
  `ModeType`) must switch to the category, or it breaks silently: a QSO whose
  mode is `FT8` falls out of the Digital column. Many arrays are indexed by
  `ModeType`, so the compiler will flag some and miss others.
* Con: the binary wire format (multi-op network, older `.TRW` logs) and the
  SQLite `mode` column carry the small enumeration; older peers would see an
  unknown value.

### C. Keep `Mode` as the category and make the real mode a first-class column

Add `real_mode` (text, ADIF MODE/SUBMODE) beside `mode`; `ExtMode` is derived
from it.

* Pro: additive; old readers ignore the new column.
* Con: a third representation of the same fact unless `ExtMode` is retired.

## Recommendation

Do A now (it is cheap and removes the drift), and treat B as the direction only
after a survey. B is the right end state, but its cost is not the change itself
but finding every consumer of `Mode` that means "the scoring category". That
survey is the first step: list every read of `.Mode` and every
`array[ModeType]`, classify each as category or real mode, and see whether the
category-only readers can be switched mechanically (rename the field so the
compiler finds them all, as was done for other frozen enums).

If B is taken, do it in this order, each step shippable on its own:

1. `ScoringModeOf` and the survey; no behaviour change.
2. Rename the scoring field (`Mode` -> `ScoringMode`) so the compiler lists every
   reader; repoint them.
3. Introduce the real mode as the stored field behind a migration.
4. Retire `ExtMode`.

## Migration and risks

* SQLite: a new column or a re-meaning of `mode` is a schema bump with a
  migration; existing logs must open unchanged and round-trip byte-identically
  through the corpus (the corpus references are frozen D7 output and are never
  regenerated).
* Multi-op network: the packet carries `Mode` and `ExtMode`; a protocol bump
  and a compatibility rule for older stations are required.
* Dupes: a dupe is per band and per scoring mode. FT8 then FT4 on one band is a
  dupe in most contests and not in a few; the rule must stay in the contest
  class, not in the mode table.
* Reports and Cabrillo: all digital modes still print as `DG` / `RY` per the
  rules of each contest; that mapping moves from "Mode = Digital" to
  "ScoringModeOf(Mode) = Digital".
* Tests: the per-contest export pins and the corpus are the net; B needs a new
  pin that every real mode maps to the category its contest scores it in.
* Unknown modes: whichever option is chosen, an unrecognised ADIF mode needs one
  defined answer (today `Digital` plus a warning in the inbound listener and
  `NoMode` in file import); this should be decided once, in the single table.
