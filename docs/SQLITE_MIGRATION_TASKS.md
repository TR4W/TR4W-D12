# The log-to-SQLite migration, in order

**The ordered task list, agreed with NY4I 2026-09-01.** The schema and its
reasoning are in [`SQLITE_LOG_SCHEMA_PLAN.md`](SQLITE_LOG_SCHEMA_PLAN.md); the
place this sits among the three big pieces is
[`DOMAIN_LAYER_SEQUENCE.md`](DOMAIN_LAYER_SEQUENCE.md). **This file owns the
ORDER and the exit criteria.** It does not restate the schema.

---

## Why there is a list at all

NY4I, 2026-09-01, on being shown the mapper plan:

> *"My original idea about a QSO class is inexorably linked to the database.
> Having an in-between stop does not buy us anything. So I think the database may
> be more tied to the contest factory than we think, otherwise there is throwaway
> code."*

A fair challenge, and it is the same question that opened the day — can the log
move before the contest factory, or must they go together. Two measurements
decide it.

**THE STORAGE SEAM IS 13 SITES, NOT 430.** `ContestExchange` has 430 references
across 34 units, which is what makes it look inseparable. But those references
*mutate* the record. Only these touch storage:

| | where |
|---|---|
| **8 writes** | `MainUnit` 9005, 10044 · `LOGSUBS2` 590, 2526 · `uEditQSO` 751 · `uNet` 1212, 1395 · `uQTCS` 327 |
| **5 reads** | `LogHandle` readers |

Swapping the file for a database touches thirteen places. That narrowness is the
entire reason storage and the factory separate.

**AND THE THROWAWAY RISK IS REAL BUT AVOIDABLE, BY A DECISION WE HAVE ALREADY
MADE TWICE.** If the QSO object persists itself (Active Record), then mapper code
written as free functions over a record *does* get relocated when the record
becomes a class, and NY4I's instinct is right. With a **repository** it does not:

```pascal
TLogRepository.Save(const aQso: ContestExchange)   { phases A-E }
TLogRepository.Save(const aQso: TContestQSO)       { after the factory }
```

The expensive part -- 71 field decisions, the enum encodings, `TQSOTime` to unix
-- is identical and stays put. What changes is a parameter type.

That is also what TR4QT actually does, which is worth knowing precisely because
it contradicts the instinct above: `struct QSO` (`QSO.h:37`) is a plain **value
type** that does not persist itself, and `QSORepository::saveQSO(QSO&, int)`
saves it. Data Mapper, not Active Record. Section 4e of the schema plan arrives
at the same answer independently, from the aliasing hazard -- a record assignment
copies, a class assignment aliases, and Pascal reports neither.

**Where NY4I is more right than the plan admitted.** The QSO half is independent
of the contest factory. **The configuration half is not.** `EXCHANGE RECEIVED`,
`QSO POINT METHOD` and `DOMESTIC MULTIPLIER` are contest *definition*, and
`FCONTEST.PAS` is what interprets them. Storing them is storage; interpreting
them is the factory. Phase E is drawn on exactly that line.

---

## THE DECISION THIS LIST IS WRITTEN AGAINST

**Repository (Data Mapper), not Active Record.** Phases A to C are written
against it. If it is reversed, they need re-planning rather than adjusting --
so reverse it now or not at all.

---

## Phase A -- build the oracle bridge

**Nothing after this is judgeable without it**, and it is the one genuinely
transitional piece in any ordering: the golden corpus reads binary `.trw` through
the export path, so without an importer the only proof that scoring and Cabrillo
did not move disappears at the moment it is most needed.

| # | task |
|---|---|
| **A1** | **The `ContestExchange` crosswalk -- all 71 fields.** Each mapped to a column, or recorded as not persisted **with the reason**. Not a summary: the list is the deliverable |
| **A2** | **Add the missing columns.** Free right now -- the schema is version 1 and nothing has written a log. It stops being free the day an operator has one |
| **A3** | **The `.trw` importer.** `test\logdump\logdump.lpr` already reads `TLogHeader` + records and is cross-checked against ADIF export by `test\python\verify_adif_export.py`. That is the reader; do not write a second one |
| **A4** | **The exhaustive pin test**, in the same commit as A3: `.trw` -> rows -> `ContestExchange`, field by field |

**Already found missing in A1, before it is even written:** `ceComputerID` (the
multi-op station letter -- it identifies whose QSO a record is and drives the
Cabrillo transmitter digit); `ceXQSO` (**not** the same as `deleted` -- the
contact happened and is kept for the other station's NIL protection but is not
claimed); `ceRecordKind` (`rkQSO`, `rkQTCR`, `rkQTCS`, `rkNote` -- a log record
is not always a QSO); the legacy `ceQSOID1`/`ceQSOID2`; and the four multiplier
flags.

**A4 is not optional and not a formality.** CLAUDE.md rule 9: a silently
defaulted field reads as a legal zero. An undeclared capability, an
uninitialised `maxLen` and a wholesale `DefineCapabilities` override have each
produced exactly this defect in this tree already.

**Exit:** a corpus log imports and the reconstructed `ContestExchange` matches
what `logdump` reads. **No contest-factory work.**

## Phase B -- swap storage

| # | task |
|---|---|
| **B1** | `TLogRepository` -- `Save` / `Load` over `ContestExchange` as a value type |
| **B2** | Repoint the 8 writes and 5 reads |
| **B3** | Keep the corpus runnable across the switch -- export from the database, diff against the same frozen D7 references |

**Exit:** corpus **22 passed / 0 failed / 4 known** with the log in SQLite.
**No contest-factory work.**

## Phase C -- event sourcing, which is the payoff

| # | task |
|---|---|
| **C1** | Store `exchange_sent` per QSO **at log time**, not rebuilt from station globals at export |
| **C2** | Capture the tier-2 entry declaration **at log creation**. This also closes section 12c: a headless export currently ships a Cabrillo file with three `CATEGORY` lines missing and a `CATEGORY-MODE` contradicting the log's own configuration, and `golden_diff.py` cannot see it because it drops header lines |
| **C3** | `MyZone` does double duty for the CQ and ITU zones, and `MY ITU ZONE` is read by no export path. Store the zone that was **sent** |

**Exit:** the four known divergences go green. **Issue #2 closed with no
contest-factory work at all** -- which is the concrete answer to "does the
database have to wait for the factory".

## Phase D -- the editable log

| # | task |
|---|---|
| **D1** | `uLogEdit` and `uLogSearch` as an LCL **virtual list** (`OwnerData` / `OnData`) |

These are the last two hand-built Win32 dialogs and NY4I parked them here on
purpose: *"I suspect those are so coupled to the sqlite database it would be
better to do those two right after the log is moved to a database."* They fall
out of a log that has a model rather than being a project of their own.

## Phase E -- configuration and messages -- the factory boundary

| # | task |
|---|---|
| **E1** | Write `config` + `message` from the current `.cfg` at log creation |
| **E2** | Read them at log open |
| **E3** | `.cfg` becomes **import only** -- the stated goal: *"when done, the .cfg file should not be necessary"* |
| **E4** | **STOP THERE.** Interpretation stays with `FCONTEST.PAS` |

E4 is the whole point of drawing the line here. Storing the contest definition is
storage; deciding what `QSO POINT METHOD = ONE PHONE TWO CW` *means* is the
factory. Fusing the two is how a storage change becomes a contest-engine change.

**And do not derive scope from `crC: 1`.** 29 of the 415 `CFGCA` rows carry it
and it means *"SaveNewContest writes this"*. The shipped `Idaho QSO Party.cfg`
sets `EXCHANGE RECEIVED`, `DOMESTIC MULTIPLIER`, `QSO POINT METHOD`,
`MULT BY BAND` and `CONTEST TITLE` -- **all five are `crC: 0`**.

**Exit:** the `.cfg` is no longer necessary, and `FCONTEST` still owns meaning.

## Phase F -- the contest factory

| # | task |
|---|---|
| **F1** | `ContestExchange` becomes a class. With B1 in place this is a parameter type on the repository, not a rewrite |
| **F2** | Harvest per-contest initial state out of `FCONTEST.PAS`; the `config` table becomes the factory's input rather than a file |
| **F3** | `case Contest of` -> the factory: scoring, multipliers, exchange parsing |
| **F4** | The **sending** half of the rover problem. `MyGrid` is substituted textually into the F-key memories once, at `FCONTEST.PAS:481-482`, so an operator who edits it mid-contest **keeps sending the old grid and exports the new one**. C fixes the export half; only the factory fixes this half |

---

## If the factory is to come earlier

The natural place is **after Phase C**: the log has a model, event sourcing is
fixed, and the corpus is green *and able to see regressions*. D and E can then be
done in factory terms from the start.

**Before Phase A is the one option to refuse.** It starts the largest change in
the program with no oracle -- and the oracle is already known to be partially
blind (`golden_diff.py` never compares the Cabrillo header, section 12c).

---

## What is genuinely throwaway, stated honestly

**The `.trw` importer**, and nothing else. It reads a format we are leaving. It
is also unavoidable in every ordering, because it is how the corpus keeps running
and how an operator's existing logs come across.
