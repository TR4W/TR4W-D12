# Pointer audit -- what is still DOS/Win32-shaped, and the order to fix it

**Measured 2026-10-16 at `28599599` (branch `contestFactory`, working tree
dirty). NOTHING WAS CHANGED: this is an inventory and a schedule.**

> **STATUS, 2026-10-16 (on top of `7e3c209b`): P0 and P4 are DONE.**
> P0 -- the counter is `tr4w/build/Count-LivePointers.ps1` (self-test, three
> floors; a measurement, not in `Run-Lints`). P4 -- the dead pointer code is
> deleted; what went, and the before/after counts, are under
> [P4 -- what was deleted](#p4----what-was-deleted-2026-10-16). Every oracle
> was unchanged (matrix 187 identical, factory 13, corpus 22/0/4, ADIF
> 12/0/1, unit 360,205/0 plain and checked, heaptrc 13,469); narrowing fell
> 1249 -> 1245 and its ceiling was lowered. **The tables below are the
> 2026-10-16 inventory as measured; rows that P4 removed are marked, not
> renumbered.** Re-measure with the counter before quoting any other row.
>
> **P5 is DONE too** (on top of `5b1f838b`), and **P1 and P2 are DONE** (on
> top of `e19b9f9e`): the thread start and the command table are typed, the
> five 64-bit truncations are gone, and two new lints hold both --
> `Lint-PointerTruncation` and `Lint-TypedCodePointers`. See
> [P1 and P2](#p1-and-p2----typed-code-pointers-and-the-64-bit-truncations-2026-10-16).
> Every oracle unchanged; counter 2,701 -> 2,622.

NY4I, 2026-10-16, after `logdom.pas` turned out to hold a DOS-era hand-built
linked list whose dispose loop read through nil:

> *"audit for other pointer usage that can be updated. Its location is
> immaterial as we are far past not touching things. Or at least schedule them
> for testing so we have an idea what breaks as we go through this."*

The rules this applies are CLAUDE.md's: **if you touch it, it leaves native**;
**no PChar, string pointers, `s[1]` type stuff -- all native FPC/LAZ**;
**prefer a class to a record**; **prefer the FPC/LCL class and justify every
raw call**.

## What this document does NOT repeat

Two categories already have their own audits, with their own counters, and
this one only re-measures them and points there:

| category | the audit | the counter |
|---|---|---|
| `Move` / `FillChar` / `ZeroMemory` | [`64_BIT_TASKLIST.md`](64_BIT_TASKLIST.md), section *P0 -- no Move / FillChar / ZeroMemory* -- every site triaged with an owner, a category and the `ENC`/`BYTES` flags | `tr4w/build/Count-LiveMove.ps1` |
| `PChar` / `PAnsiChar` / `PWideChar` | [`64_BIT_TASKLIST.md`](64_BIT_TASKLIST.md), section *P0 -- the PChar-family removal* | `tr4w/build/Count-LivePChar.ps1` |
| ShortString `@X[1]` handed to a C-string consumer | [`SHORTSTRING_BOUNDARY_AUDIT.md`](SHORTSTRING_BOUNDARY_AUDIT.md) (2026-07; most of its sites are gone with `CFGCA`, `uCAT`'s ini writes and the C-string shim -- re-run its scan before using its list) | its own regex |
| an integer smuggled through `TObject` (`uFlowGrid`), and `TLVItem` as a parameter carrier | [`WIN32_ARTIFACT_SWEEP.md`](WIN32_ARTIFACT_SWEEP.md) -- the worked example | none |

---

## (d) Live and latent defects found -- read these first

Each is evidence-backed; where liveness is uncertain the section says so and
says how to settle it. **None of these fails a build or a test today.**

### D1. `logdom` -- the nil walk that started this. IN PROGRESS, not mine

`DomQTHTableObject` (36 bucketed `PrefixRec` linked lists, `New`/`Dispose`) is
being converted to `TDomQTHTable` over a `TObjectDictionary` by another agent;
the working tree already carries the change and
`test/unit/uTestDomQTHTableReload.pas`. Listed so it is not scheduled twice.

*Observed while measuring:* `tr4w/test/unit/uTestDomQTHTableReload.pas` is
currently **LF** (201 bare LF, reported by the CRLF hook). It is the other
agent's file and was not touched here; it needs CRLF before it is committed.

### D2. `tCreateThread` starts ten thread bodies through the WRONG calling convention -- FIXED (P1)

> **Settled by disassembly, 2026-10-16, and it was WORSE than the paragraph
> below expected.** `tWorkerThreadTrampoline` (`TF.o`, FPC 3.2.2 i386) does
> have an EBP frame -- but it pops its two SEH records **by ESP**
> (`pop %edx; add $0xc,%esp; mov %edx,%fs:(%eax)`, twice) and restores
> EBX/ESI/EDI with `pop` **before** `mov %ebp,%esp`. A target returning with
> a plain `ret` (confirmed for `tDoABeep`) left ESP four bytes low, so on
> every such thread's EXIT the trampoline (1) wrote the pushed thread
> parameter -- nil -- into `FS:[0]`, the head of the thread's exception
> chain, and (2) restored EBX, ESI and EDI from the wrong slots, before
> handing back to the RTL's thread epilogue. It "worked" because nothing
> after that point raised. Fixed at the type; see P1 below. After the fix,
> `tDoABeep` returns with `ret $0x4`.

`TF.tCreateThread` takes `lpStartAddress: TTR4WThreadStart`, and
`TTR4WThreadStart = Pointer` (`TF.pas:213`). The trampoline casts it to

```pascal
TWorkerProc = function(aParameter: Pointer): DWORD; stdcall;   (* TF.pas:922 *)
```

and calls `start.Proc(start.Parameter)` (`TF.pas:945`). Because the parameter
is an untyped `Pointer`, **the compiler checks nothing**, and ten of the
fourteen targets do not have that signature:

| target | declared as | call site |
|---|---|---|
| `CWThreadProc` | `procedure;` (register) | `uCWKeyerCPU.pas:83` |
| `tDoABeep` | `procedure;` | `logk1ea.pas:1618` |
| `tPaddleFootSwitchThreadProc` | `procedure;` | `MainUnit.pas:7741` |
| `tDVPPlayThreadproc` | `procedure;` | `LogSend.pas:103` |
| `ConnectThread` | `procedure;` | `uNet.pas:1136` |
| `RunSyncThread` | `procedure;` | `uNet.pas:1498`, `uServerLogForm.pas:349` |
| `CreateConnectionAndSendReportToGetScores` | `procedure;` | `uGetScores.pas:102` |
| `NTPStartupCheck` | `procedure;` | `uSynTime.pas:362` |
| `wkReadThreadProc` | `procedure;` | `uWinKey.pas:453` |
| `wkOpen` | `function: boolean;` | `uProgramMain.pas:2732` |

Correct already: `TelnetThreadProc`, `YCCCReadThreadProc`,
`YCCCWriteThreadProc` (`function(Pointer): DWORD; stdcall`), and `BeginPolling`
(`procedure(rig: RadioPtr); stdcall` -- parameter right, no result).

**What goes wrong, on i386:** the caller pushes one 4-byte argument and, being
`stdcall`, expects the callee to pop it with `ret 4`. A parameterless
`register` procedure returns with a plain `ret`, so the stack pointer is 4
bytes off when control returns to `tWorkerThreadTrampoline`. **It works today
only if that trampoline addresses its locals through a frame pointer and
restores ESP with `leave`** -- which is likely (it has locals and a
`try/except`) but is a property of the optimiser, not of the code. On x86_64
there is one calling convention and the mismatch is harmless.

**How to settle it:** disassemble `tWorkerThreadTrampoline` in a release
`tr4w_fpc.exe` (`objdump -d --disassemble=...`) and confirm an `EBP` frame and
a `leave` before `ret`. **Whatever that shows, the fix is the same** and the
compiler becomes the oracle: declare the parameter `TWorkerProc` (or move each
body to a `TThread` descendant) and let every wrong target fail to compile.

### D3. 64-bit pointer truncation is NOT at zero -- FIXED (P2)

> **Confirmed and fixed, 2026-10-16.** `objdump -p` on the x86_64-win64
> `tr4w_fpc.exe` reports `ImageBase 0000000100000000` -- above 4 GB -- so
> every one of the three MMTTY sites WOULD have handed RichEdit a truncated
> address. All five sites are fixed (P2 below) and `Lint-PointerTruncation`
> fails the build on a sixth.

[`64_BIT_TASKLIST.md`](64_BIT_TASKLIST.md) records *"pointer truncation --
casts: 0, DONE"*. That scan looked for `Pointer(Integer(`/`Pointer(Cardinal(`.
It could not see the opposite direction -- **a pointer narrowed to `integer`
to fit a message parameter**:

| site | code | live? |
|---|---|---|
| `uMMTTY.pas:253` | `SendMessage(..., EM_SETCHARFORMAT, SCF_SELECTION, integer(@MMTTY.mmttyCF))` | **yes**, whenever MMTTY is used, Windows only |
| `uMMTTY.pas:384` | `SendMessageA(h, EM_REPLACESEL, integer(False), integer(@MMTTY.mmttyTwoBytes))` | **yes**, every received RTTY character |
| `ui/lcl/uMMTTYForm.pas:237` | `SendMessage(..., EM_SETCHARFORMAT, ..., integer(@MMTTY.mmttyCF))` | **yes** |
| `uNet.pas:1491`, `uNet.pas:1504` | `ShowLogCompare(integer(s))`, `s: PLogFileInformation`, cast back at `uLogCompareForm.pas:238` | **no** -- unreachable since `ProcessServerLogInfo` forces `IdenticalLogs := True` (`uNet.pas:1460`) |

`MMTTY` is a unit-level global, so its address lies in the image. If the
x86_64 image is based above 4 GB -- **believed to be FPC's Win64 default; check
with `objdump -p tr4w_fpc.exe | rg ImageBase`** -- every one of the three live
sites hands RichEdit a truncated pointer. Win32 is unaffected. Nobody has run a
64-bit TR4W, so this has never been seen.

Fix: `LPARAM(@...)` (the LCL's `LPARAM` is `PtrInt`), and give `ShowLogCompare`
a `PLogFileInformation` parameter instead of an `lParam`. A comment-aware lint
for `(integer|longint|cardinal|dword|longword)\s*\(\s*@` is exact for the
`@` form and cheap -- see packet P2.

### D4. The CPU keyer's CW buffer can be written through nil -- latent

`logk1ea.CWBuffer: CWBufferPtr` is allocated lazily, by `New(CWBuffer)`, in
`Dit`, `Dah`, the third element routine and `AddStringToCWBuffer`
(`logk1ea.pas:822, 845, 883, 1504`), and **never disposed**.
`AddCharacterToCWBuffer`'s arms for `' '`, `'^'` and the control characters
(`logk1ea.pas:1320-1470`) write `CWBuffer^[CWBufferEnd]` **without** that
check, and `TCWKeyerCPU.SendChar` (`uCWKeyerCPU.pas:115`) calls
`AddCharacterToCWBuffer` directly.

So the **first** character a session sends through the DTR/RTS keyer, if it is
a space, `^` or a control character and arrives through `SendChar` (autosend)
rather than a message, writes to address 0. Likelihood is low -- autosend
normally starts with a callsign's first letter, which calls `Dit`/`Dah` --
but nothing guarantees it. **Not confirmed on hardware.** A fixed array field
of `K1EAKeyer` removes both the nil and the leak (packet P7).

### D5. `logname.pas` is NOT COMPILED, and two audits count it -- DELETED (P4)

`tr4w/src/trdos/logname.pas` (1,791 lines, `unit LogName`) is named in **no**
`uses` clause anywhere -- not `tr4w.lpr`, not the server, not a test (measured
by the orphan scan in the appendix; `rg -w LogName` finds only its own `unit`
line). It is tracked in git and nothing builds it.

It is 227 of this audit's 1,154 dereferences and 13 of its
`New`/`Dispose`, and `64_BIT_TASKLIST`'s Move triage routes 12 `logname`
"insert/delete shifts" to `file-formats`. **All of that is dead code.** Its
`NameDictionary.Abort` also disposes five arrays without setting any of them to
nil, so a second `Abort` would double-free -- moot while nothing calls it.
Recommendation: delete the file (packet P4). The same scan also reports
`src/radioFactory/uRadioManager.pas` and `src/uExternalLoggerManager.pas` as
named in no `uses` clause -- out of this audit's scope, noted so it is not lost
(CLAUDE.md section 7 describes `uExternalLoggerManager` as carrying the
implementation). **Checked in P4 and DELETED too**: each was named only by a
commented-out line in `tr4w.lpr` and `uProgramMain`'s `uses`, so neither was
ever compiled; CLAUDE.md section 7 and the `integrations` agent are corrected.

### D6. Three more DOS linked lists that nothing fills -- dead, one dangling -- DELETED (P4)

| list | evidence it is dead | latent defect |
|---|---|---|
| `logdupe` visible dupe sheet: `VDEntry` / `FirstVDEntry` (`logdupe.pas:156-160`, built in `DupeAndMultSheet.AddCallToVisibleDupeSheet`, `:816`) | `AddCallToVisibleDupeSheet` has **no caller** (`rg -i`) | `DupeInit` (`:1529`) disposes the chain and **does not set `FirstVDEntry := nil`**; `NumberChar := NumberString[1]` reads a stale byte for a call with no digit; `Callsign: string[6]` truncates 7-character roots |
| `logwind` DOS band map: `BandMapEntry.NextEntry`, `BandMapFirstEntryList[Band, Mode]` (`logwind.pas:180-209, 518`) | **no `New` anywhere and no assignment except the unlink in `DecrementBandMapTimes`**, whose only call is commented out (`:2061`); the `GoToNext*BandMapFrequency` routines in `logsubs2` that walk it have **no caller** | none while empty; `SetUpBandMapEntry` checks nil |
| `logscp` `InitialPartialList` (`PartialCallListEntry`) and the merge list (`FirstMergeDataListEntry`) | no `New(PartialCallListEntryPtr)` anywhere; `AddRecordToMergeList` has **no caller** | the merge list, if it were used, is never disposed |

The real band map is `uBandmap` / `uSpots` / `uBandMapForm`. Deleting these
is packet P4, and the compiler is its oracle.

### D7. `PInteger(@Call[1])^` reads past a short call's length -- semantic, not a crash

`uTelnet.pas:1981, 1988`, `uBandmap.pas:212, 216`, `uSpots.pas:297` compare the
first four bytes of a ShortString callsign with `tCQAsInteger = $202F5143` /
`tNEWAsInteger` (`VC.pas:2471-2472`). For a call shorter than four characters
the comparison includes **stale bytes beyond the length** -- inside the
allocation, so no fault, but the answer depends on what was there before.
Replace with `Copy(Call, 1, 4) = ...` after pinning the current answers in
`uTestDXSpotParse` (packet P12).

### Known and already documented -- listed so nobody re-reports them

* `QTCDataArray` has two allocation sites: `LogCfg.pas:347` (`New`, not
  zeroed, no nil check) and `logstuff.EnsureQTCDataArray` (`:1061`, zeroed).
  `logstuff.pas:1036-1058` records why the first is left alone. Startup runs
  `SetUpGlobalsAndInitialize` once (`uProgramMain.pas:2343`), so the
  double-`New` leak does not occur today; a contest-owned table removes the
  question (packet P13).
* The four `Move`/`FillChar` defects found by the 2026-09-18 triage are
  fixed (`64_BIT_TASKLIST.md`).

---

## (a) Totals, and the command behind every number

**Scope:** `Get-TR4WPascalFiles -Root tr4w` from `tr4w/build/PascalSource.psm1`
(which already skips `include\` -- vendored Indy and Log4D --, `backup`,
`target`, `build-out`, `dcu`), additionally skipping `graphify-out` and
`__history`. That is `tr4w/src`, `tr4w/tr4wserver`, `tr4w/test`,
`tr4w/tools` and `tr4w/build`: **817 files**. `.claude/worktrees/` is outside
`tr4w/` and is never scanned.

**Reader:** `Get-PascalCodeOnlyText -BlankStrings` -- comments and string
literal contents blanked, `{$...}` directives kept. Every count below is a
match against that text, **never a raw grep**.

### The two existing counters, re-run

| measure | command | 2026-10-16 | last recorded |
|---|---|---:|---|
| live `PChar`-family mentions | `pwsh -File tr4w/build/Count-LivePChar.ps1 -Detail` | **71 across 18 units** (46 in `src`, 25 in tests) | 44 in `src`, 69 tree-wide (2026-09-16) |
| live `Move` / `FillChar` calls | `pwsh -File tr4w/build/Count-LiveMove.ps1` | **464 across 111 units** (`FillChar` 364, `Move` 100) | 387 (2026-09-18) |

**The Move count ROSE by 77**, and the rise is new code, not newly found old
code: `test/unit/uTestContestFactory.pas` alone carries 44, and new contest
classes add more (`uContestALRSUA1DZCup.pas` 5). The rule in
`64_BIT_TASKLIST.md` is `:= Default(T)`, and nothing enforces it. That
counter had no ceiling; packet P15 (2026-10-17) added `$MOVE_CEILING` to
`Count-LiveMove.ps1` and runs it as `Count-LiveMove -Gate` from `Run-Lints.ps1`.

### The new counter: `Measure-Pointers.ps1` -- committed as `Count-LivePointers.ps1` (P0)

~~Not checked in.~~ **Committed 2026-10-16 as
`tr4w/build/Count-LivePointers.ps1`** with the appendix's rules verbatim:

```
pwsh -NoProfile -File tr4w/build/Count-LivePointers.ps1             # the table
pwsh -NoProfile -File tr4w/build/Count-LivePointers.ps1 -Rule C3-deref -Detail
pwsh -NoProfile -File tr4w/build/Count-LivePointers.ps1 -Out hits.tsv
pwsh -NoProfile -File tr4w/build/Count-LivePointers.ps1 -SelfTest
```

It counts a built-in fixture with a known, non-zero count for **every one of
the 22 rules** before it reports anything, and refuses to report if any rule
is off, if `src\MainUnit.pas` was not scanned, or if the tree total is zero.
Its columns are `src`, `server` (the `tr4w/tr4wserver/` directory -- the
server's unit `tr4wserverUnit.pas` lives in `src`), `test` and `other`
(`build`, `tools`). It is a measurement: not in `Run-Lints`, no ceiling. The
table below is the audit's original reading; the P4 section has the
committed counter's before/after.

| rule | what it matches | src | test | other | total |
|---|---|---:|---:|---:|---:|
| C1-ptrtype-decl | `X = ^Y;` type declarations | 91 | 0 | 0 | **91** |
| C1-link-field | a `Next`/`Prev`/`Left`/`Right`/`Parent`/`Child`/`Link` field of pointer type | 12 | 1 | 0 | **13** |
| C2-heap | `GetMem` `FreeMem` `ReallocMem` `AllocMem` `StrAlloc` `GlobalAlloc` ... | 9 | 0 | 0 | **9** |
| C2-new-dispose | `New(` / `Dispose(` | 79 | 5 | 0 | **84** |
| C3-pointer-cast | `Pointer(` | 7 | 2 | 0 | **9** |
| C3-int-of-ptr | an integer type applied to `@x`, `Pointer(..)`, `Self`, `Sender` or a `...Ptr`/`P...` name | 11 | 5 | 0 | **16** |
| C3-typed-ptr-type | `PByte` `PInteger` `PCardinal` `PWord` ... `PtrInt` `PtrUInt` | 181 | 29 | 0 | **210** |
| C3-addr-of | `@identifier` | 387 | 101 | 3 | **491** |
| C3-deref | postfix `^` | 1,127 | 15 | 12 | **1,154** |
| C3-inc-dec-ptr | `Inc`/`Dec` of a `P...`/`...Ptr` name (**over-matches**; see below) | 41 | 10 | 0 | **51** |
| C3-untyped-param | an untyped `var`/`const`/`out` parameter | 35 | 3 | 0 | **38** |
| C3-memcmp | `CompareMem` `CompareByte` `IndexByte` ... | 2 | 1 | 0 | **3** |
| C3-s1 | `@x[1]` / `@x[0]` | 21 | 5 | 0 | **26** |
| C5-tobject-cast | `TObject(` | 7 | 1 | 0 | **8** |
| C5-objects | `.Objects[`, `AddObject(`, `InsertObject(` | 33 | 2 | 0 | **35** |
| C5-tag | `.Tag` | 70 | 0 | 0 | **70** |
| C5-lparam | `lParam` / `wParam` as a type or name | 40 | 0 | 0 | **40** |
| C5-data | `.Data :=` and friends | 16 | 3 | 0 | **19** |
| C6-object-type | `= object` (old-style object) | 12 | 0 | 0 | **12** |
| C6-ptr-named | any identifier ending `Ptr` | 562 | 32 | 0 | **594** |
| C7-proc-type | `= procedure` / `= function` types | 96 | 7 | 0 | **103** |
| C7-pointer-word | the bare type `Pointer` (not a cast) | 70 | 5 | 2 | **77** |

**How to read the big rows.** `C3-deref`, `C3-addr-of` and `C6-ptr-named`
are *where to look*, not work items: 227 of the dereferences are in the
uncompiled `logname.pas` (D5), and 363 of the 594 `...Ptr` names are
`ActiveRadioPtr` (159), `RadioPtr` (115) and `InactiveRadioPtr` (89) -- one
design decision, packet P11. `C3-inc-dec-ptr` over-matches integer indices
that happen to start with `p`; read by hand, **only four sites walk a real
pointer**: `uCRC16.pas:79`, `uNetFraming.pas:155`, `utils/uSHA256.pas:203`,
and `uCRC32` (an untyped `const data` walked inside). Every other row is
small enough that the tables below list it in full.

### Supporting scans (appendix has both)

| question | command | answer |
|---|---|---|
| which units does no `uses` clause name? | `pwsh -File Find-OrphanUnits.ps1` | `trdos/logname.pas`, `radioFactory/uRadioManager.pas`, `uExternalLoggerManager.pas` |
| which old-style objects carry a VMT? | the object-profile one-liner in the appendix | `TCallsignsList` (3 virtual), `TSortedStringList` (2), `TDXSpotsList` (2); the other nine have none. All three have `constructor Init` and are `Init`-ed (`uCallsigns.pas:743`, `uMults.pas:308-309`, `uSpots.pas:1013`) |
| records with methods | the advanced-record one-liner in the appendix | `TComPortInfo` (`ComPortEnumerator.pas:109`), `TTCICommand` (`uTCIProtocol.pas:85`), `TStopwatch` (`uLCLFormHelpers.pas:366`) |

---

## (b) The items, by category

**Oracle key.** *UT* = a named unit test in `tr4w/test/unit`. *MATRIX* =
`tr4w/test/contest-matrix/run-contest-matrix.sh`. *CORPUS* = the golden corpus
(`export-d12-corpus.sh`; ADIF + Cabrillo of 13 logs -- **blind to the screen,
to CW and to the network**). *FACTORY* = `test-contest-factory.sh`. *BENCH* =
nothing automated; needs a [`BENCH_QUEUE.md`](BENCH_QUEUE.md) entry.
*COMPILER* = a deletion or a typing change that the compiler proves by itself.

### Category 1 -- hand-built linked lists

| # | where | what | live? | native replacement | risk | oracle |
|---|---|---|---|---|---|---|
| 1.1 | `trdos/logdom.pas` `PrefixRec` x 36 buckets | domestic QTH aliases | live | `TObjectDictionary` -- **IN PROGRESS** (D1) | high (every QSO party) | UT `uTestDomQTHTableReload`, MATRIX, CORPUS |
| 1.2 | `trdos/zonecont.pas:42-50`, `AddDomesticCountry` `:156`, `DomesticCountryCall`, `ClearDomesticCountryList` `:255` | domestic COUNTRY list -- DX vs domestic for every domestic contest | **live, scoring-critical** | **DONE (P5)**: `TDomesticCountryList` over a `TList<AnsiString>`, the unit's global `DomesticCountries`; `uContestMatrix.CaptureDomesticCountries` reads `DomesticCountries.IDs[]` | high | MATRIX (reads the list), CORPUS, FACTORY, UT `uTestContestFactory` (stubs the call), `uTestContestSession` |
| 1.3 | `trdos/logstuff.pas:252-258`, `EnumHelloDAT` `:1222`, `SendSalutation` `:1143` | `HELLO.DAT` per-country greeting | live **only when `HELLO.DAT` exists** (not shipped); loaded once (`LogCfg.pas:478`), never freed; `Greeting: string[6]` truncates a `Str20` (check D7 before calling that a regression) | `TStringList` `Values[]` | low | **none** -- write a UT first |
| 1.4 | `trdos/logdupe.pas:156-160`, `:816`, `DupeInit` `:1529` | visible dupe sheet | **dead** (D6) | **DELETED (P4)** | none | COMPILER |
| 1.5 | `trdos/logwind.pas:180-209, 491-518`, `DecrementBandMapTimes` `:1935`, the `Next*EntryIn*BandMap` walkers `:2425-2715`, `GetRecordForBandMapCursor` `:2893`; `logsubs2.pas:1313-1380` | DOS band map | **dead** (D6) | **DELETED (P4)** | none | COMPILER |
| 1.6 | `trdos/logscp.pas:80-86, 121-127`, `AddRecordToMergeList` `:2605`, the partial-list clear `:1430` | SCP merge list, partial-call list | **dead** (D6) | **DELETED (P4)** | none | COMPILER |
| 1.7 | `trdos/logname.pas` | name database | **not compiled** (D5) | **DELETED (P4)** | none | COMPILER |

### Category 2 -- manual heap

| # | where | what | live? | native replacement | risk | oracle |
|---|---|---|---|---|---|---|
| 2.1 | `trdos/logk1ea.pas:498-503`, `New(CWBuffer)` x 4 | CPU keyer element ring | live (CPU / YCCC keyer) | a fixed `array` field of `K1EAKeyer` -- no heap, no nil (D4) | medium (keys the radio) | **none** for the buffer; write a UT that feeds `AddCharacterToCWBuffer` and reads the ring, then BENCH (DTR/RTS keying) |
| 2.2 | `trdos/logscp.pas:305-400` `CellBufferObject.Initialize`/`GoAway`: `New(Buffer1..3)` in POST mode, `GetMem(Buffer1, NumberBytes)` otherwise; `New/Dispose(CallsAlreadySaved)` `:1170/1273`, `:2382/2469`; `New/Dispose(SCPIndexArray)` `:1949/2975` | the TRMASTER cell buffer | live (SCP, initial-exchange lookup) | `TBytes` / dynamic arrays sized by `SetLength`; one allocation strategy instead of two | medium -- **two allocators for one pointer**, chosen by `MaximumMemoryToUse`; `GoAway` must pick the matching free | MATRIX (opens `MATRIX-TRMASTER.DTA`, emits `initialexchange.trmaster.*`); **partial-call SCP itself has no UT** |
| 2.3 | `uCallsigns.pas:426`, `uSortedStringList.pas:261` `ReallocMem(FList, ...)` | hand-rolled growable arrays inside old-style objects | live (`CallsignsList` partials; `mo.PrfList`/`DomList` multipliers) | `array of T` + `SetLength`, or `specialize TList<T>` | medium | `uSortedStringList`: UT `uTestMults`, `uTestHostAreaRule`, `uTestOffBandCredit`, MATRIX, CORPUS. `uCallsigns`: UT `uTestStringCompare`, `uTestOffBandCredit` (partial) |
| 2.4 | `trdos/postunit.pas:1346/1351` (`ScoreByHour`), `:2027/2034` (`QSOsByCountryByBand`), `:3340/3345`, `:3440/3447` (`tGenerateSummaryPortionOfCabrilloFile`) | temporary report arrays, `New` ... `Dispose` with **no `try/finally`** | live | a local dynamic array or class instance | low | the Cabrillo summary: CORPUS. The two reports: **none** |
| 2.5 | `trdos/logstuff.pas:1068`, `trdos/LogCfg.pas:347` | `QTCDataArray` | live (WAE) | a dynamic array owned by the contest | low | **none** for QTC; `docs/QTC_BENCH_HANDOFF.md` is the bench script |
| 2.6 | `uSettingsModel.pas:5727, 5832, 7058, 7166` `FreeMem(props)` | frees `GetPropList`'s result | live | **keep** -- `TypInfo.GetPropList` allocates and the caller frees; that is the RTL's contract. Add the comment | none | UT `uTestSettingsModel`, `uTestAllSettings` |
| 2.7 | `uCAT.pas:107, 128, 153` `Dispose(P...DiscoveredRadio(list[i]))`; `uK4Discovery.pas:227`, `radioFactory/uFlexDiscovery.pas:281`, `uIcomNetworkDiscovery.pas:151` `New(Radio)` | discovery results as `^record` in a `TList` | live | `specialize TObjectList<TDiscoveredX>` with `OwnsObjects` | low | UT `uTestFlexDiscovery`; K4 and Icom discovery: **none** -> BENCH |
| 2.8 | `uIcomNetworkTransport.pas:2611/2621/2653` (`PSeqBufEntry`), `radioFactory/uRadioHamLibDirect.pas:762/885` (`PHLCommand`) | per-radio queues of `^record` | live | `specialize TQueue<T>` / `TList<T>` of records | medium (Icom LAN is unproven on the bench) | UT `uTestIcomTeardown` (Icom, partial), `uTestHamLibIDs` (ids only); BENCH |
| 2.9 | `uMainThread.pas:126/140` (`PPendingCall`), `ui/lcl/uMainForm.pas:2294/2327/2354` (`PElementWork`), `uGetServerLog.pas:206/230` (`PSyncProgress`), `TF.pas:437/473/943/1005` (warning text, worker start) | cross-thread handoff through `Application.QueueAsyncCall`'s single `PtrInt` | live | **keep, it is the LCL's API**: `QueueAsyncCall` carries one `PtrInt`. `uMainThread.pas:82` already says so. The agent memory `fpc-queue-purges-its-own-callback` is why `TThread.Queue` is not the substitute | none | UT `uTestStatusAndNotice`, `uTestWSJTXThreading` |

### Category 3 -- pointer arithmetic, casts, untyped buffers

The `Move`/`FillChar` half of this category is triaged in full in
`64_BIT_TASKLIST.md`; re-measured at 464 above.

| # | where | what | live? | native replacement | risk | oracle |
|---|---|---|---|---|---|---|
| 3.1 | `uMMTTY.pas:253, 384`, `ui/lcl/uMMTTYForm.pas:237`, `uNet.pas:1491, 1504` | pointer narrowed to `integer` | see D3 | **DONE (P2)**: `LPARAM(@x)`; `ShowLogCompare` takes `PLogFileInformation` | **high on Win64** | `Lint-PointerTruncation` (P2); MMTTY is BENCH |
| 3.2 | `uNet.pas:421-699` (12 overlays: `StationStPtr := @NetBuffer[Bufindex]` and the rest), `tr4wserverUnit.pas:642-716` (4 overlays) and `:691, 697, 703, 1287` (`XPtr(@ServerBuffer[...])^`) | a wire message read by laying a packed record over the receive buffer | live, multi-op | a decoder that reads each record from a `TBytes` slice with its length checked -- **the bytes stay identical, the overlay goes** (CLAUDE.md: *the contract is the encoding, not the type*) | high for multi-op; **ask NY4I first** -- the new multi-station protocol may replace these messages, and refactoring a protocol about to be retired is waste | UT `uTestNetFraming` covers FRAMING only; per-message decode pins must be written FIRST; then BENCH (two stations + `tr4wserver`) |
| 3.3 | `uTelnet.pas:1981, 1988`, `uBandmap.pas:212, 216`, `uSpots.pas:297` | `PInteger(@Call[1])^` 4-byte pun | live | string comparison (D7) | low | UT `uTestDXSpotParse`, `uTestSpotAge` -- add short-call pins first |
| 3.4 | `uWinKey.pas:370` `PCardinal(@wkREADBuffer[0])^ := 0`; `tr4wserverUnit.pas:1173` `PInteger(@ServerBuffer[0])^ = 542393671 {'GET '}` | integer puns on byte buffers | live | index the bytes / compare a 4-byte `Copy` | low | WinKeyer: BENCH. Server: **none** |
| 3.5 | untyped buffer parameters: `uCRC16.GetCRC16X25`, `uCRC32.GetCRC32`, `uSHA256.SHA256Update`, `uNetFraming.NextNetMessage`, `uNet.SendToNet`, `uNetClient.Send`, `uServerNet.SendToClient`/`HexOf`, `tr4wserverUnit.sSend`, `uWinKey.wkSend`/`wkSendAdminCommand`/`wkWriteRaw`, `uIcomNetworkTransport.SendRawPacket`/`BytesToHexStr`, `utils_text.BinToHexStr`, `utils_file.sWriteFile`/`tWriteFile`/`sReadFile` (35 in `src`) | `const data; Count` | live | `const data: array of Byte` / `TBytes` -- an open array carries its bounds (CLAUDE.md strings table). Byte I/O stays byte I/O | medium (wire and serial bytes) | UT `uTestCRC32`, `uTestSHA256`, `uTestNetFraming`, `uTestWebSocketFraming`, `uTestIcomCIV`; WinKeyer and `tr4wserver`: BENCH |
| 3.6 | `uProcessCommand.pas:261` `scFileName[length(scFileName) + 1] := #0` | hand-written C terminator on a ShortString | live | delete -- its last C-string consumer, `FileExists(@scFileName[1])` at `:416`, is inside a `{ }` comment (the comment-aware reader does not see it; a plain `rg` does), and every live use passes the ShortString itself | low | **none** |
| 3.7 | `ui/lcl/uLogGrid.pas:1045, 1054, 1093` `@FCache[i mod CACHE_ROWS]` | a pointer into an array of records, returned to callers | live | return the index, or make the cache entry a class | low -- dangles only if `FCache` is resized while a caller holds one; check before converting | UT `uTestLogRepository` (data), screen is BENCH |
| 3.8 | `MainUnit.pas:8986` `CompareMem(@RescoredBefore, @RescoredRXData, SizeOf(ContestExchange))` | byte compare of two records | live | **keep for now**: it is a deliberate "did anything change" that includes padding; the same rule as `RadioStatusRecord`'s `BYTES` flag | -- | CORPUS / rescore baseline |
| 3.9 | `ui/lcl/uAltPForm.pas:189` `row.Data := Pointer(PtrInt(aKey + 1))` | integer in a `TListItem.Data` | live | see 5.4 | -- | -- |

### Category 4 -- PChar, PAnsiChar, PWideChar

`Count-LivePChar.ps1` reports **71 live mentions across 18 units**; every one
was read. The header of that script says the 2026-09-16 audit found every
mention to be a foreign-API declaration or call. That still holds for `src`
(46): no new habit has crept in. Two are flagged because an FPC class exists.

| unit | n | verdict |
|---|---:|---|
| `uHamLibDirect.pas` | 14 | **boundary** -- HamLib's C ABI and `fopen` for its debug file |
| `radioFactory/uRadioHamLibDirect.pas` | 5 | **boundary** -- `rig_set_conf` values, `fopen` |
| `uKeychainWindows.pas` | 5 | **boundary** -- `CREDENTIALW` fields, `CredReadW`/`CredDeleteW` |
| `ui/lcl/uEmbeddedTranslations.pas` | 5 | **boundary** -- `FindResource`, `EnumResourceNames` callback |
| `ComPortEnumerator.pas` | 3 | **boundary** -- SetupAPI W entry points |
| `uDXLabPathfinder.pas` | 2 | **boundary** -- DDE |
| `uUILanguage.pas` | 2 | **boundary** -- `GetUserPreferredUILanguages`, `CFStringGetCString` |
| `utils/uOpenSSLLoader.pas` | 2 | **boundary** -- `fpSymlink` has no string overload in FPC 3.2.2 |
| `utils/uPlatformFonts.pas` | 2 | **boundary** -- `AddFontResourceW` |
| `utils/uTLSTrust.pas` | 2 | **boundary** -- OpenSSL `X509_check_host` |
| `uYCCCSO2R.pas` | 1 | **boundary** -- SetupAPI |
| `utils/uHostName.pas` | 1 | **boundary** -- `GetComputerNameW` |
| `utils/uAudio.pas` | 1 | **boundary**, Windows arm of a platform split (`sndPlaySoundA`) |
| `uProgramMain.pas:1256` | 1 | **boundary, but an FPC class exists**: `CreateMutexA` for single-instance. The agent memory `single-instance-should-use-fpc-class` records the catch (the FPC default id is the file name only) |
| tests: `uTestFormatTranslation.pas` | 20 | **keep** -- it calls `msvcrt` `sprintf` as an independent oracle for format strings |
| tests: `integration/uSimProcess.pas` | 3 | **habit** -- `CreateProcess` + `WriteFile`; `TProcess` does both |
| tests: `integration/tr4w_radio_bench.lpr:238` | 1 | **habit** -- `SysUtils.GetEnvironmentVariable(Name)` returns a string |
| tests: `uTestDXSpotParse.pas:184` | 1 | **habit** -- reads a ShortString field as a C string to test it; compare the field |

**The `src` figure is 46 against 44 recorded on 2026-09-16.** The two are not
attributed here; the unit list above is complete, so a diff against that
audit's list finds them.

### Category 5 -- pointers and integers carrying an identity

| # | where | what | native replacement | oracle |
|---|---|---|---|---|
| 5.1 | `ui/lcl/uFlowGrid.pas:165, 205` (`TagAt`, `AddObject(aCall, TObject(aTag))`), callers in `uCallsigns`, `uMaster`, `logedit` | **the worked example in `WIN32_ARTIFACT_SWEEP.md` -- still present** | `TRemainingMult` and friends in `Objects[]` with `OwnsObjects` | **none** (UI) -- BENCH the dupe sheet, SCP/master and remaining-mults windows |
| 5.2 | `ui/lcl/uLogSearchForm.pas:395-522` | band and mode stored as `TObject(PtrInt(Ord(x)) + 1)` in combo items, `+1` so 0 can mean "any" | a typed array parallel to the items, or `ItemIndex - 1` against the list the form built | **none** -- BENCH the log search window |
| 5.3 | `ui/lcl/uTelnetForm.pas:796, 1025, 1072` | each console line's `TelnetStringType` as `TObject(PtrUInt(Ord(aKind)))` | the `TStringGrid`/model shape the band map already uses; or a parallel `array of TelnetStringType` | UT `uTestTelnetTrace` (the ring, not the colours) -- BENCH the colours |
| 5.4 | `ui/lcl/uAltPForm.pas:189, 253, 270` | a function-key number in `TListItem.Data`, `+1` | a typed field the view owns | **none** -- BENCH Alt-P |
| 5.5 | `uEditMessage.ShowEditMessage(const aMessage: lParam)` (`uEditMessage.pas:99`, `ui/lcl/uEditMessageForm.pas:456`), `ShowLogCompare(const aInitParam: lParam)` (`uLogCompare.pas:73`, `ui/lcl/uLogCompareForm.pas:225`) | a dialog's Win32 `lParam` kept as the parameter type after the dialog became an LCL form; one of them carries a pointer (D3) | `ShowLogCompare(aInfo: PLogFileInformation)` -- **DONE (P2)**. `ShowEditMessage(aRow: integer)` -- still open: it carries a row number, not a pointer, so it truncates nothing | COMPILER |
| 5.6 | `uMainWindowProc.pas:605` `ApplyLoadedParks(LPARAM(aParks))`, `uPOTAParks.pas:582` | a `TStringList` passed as `LPARAM` between two units of ours | `ApplyLoadedParks(aParks: TStringList)` | UT `uTestContestPOTA` (contest, not the download); COMPILER |
| 5.7 | `.Tag` (70): 44 in `ui/lcl/uPrefsForm.pas` | Preferences navigation dispatches by `Tag` | **a recorded decision** (agent memory `prefs-designed-form-and-nav-tags`; `uPrefsForm.pas:1519` explains why) -- not a target | -- |
| 5.8 | `Objects[]` holding real objects: `uCabrilloHeader`, `uGridLookup`, `uRadioConfigStore`, `uWinManagerForm` | genuine object ownership through `TStringList.Objects` | **already native** -- listed so nobody "fixes" them | -- |
| 5.9 | MMTTY RichEdit subclassing (`uMMTTY.pas:174, 398-410`, `OldMMTTYRichEditProc: Pointer`) | Win32 window-procedure replacement | the `WIN32_ARTIFACT_SWEEP` RICHED32 row | BENCH |

### Category 6 -- old-style `object` types and `^record` plumbing

| # | type | where | VMT? | native replacement | oracle |
|---|---|---|---|---|---|
| 6.1 | `RadioObject` + `RadioPtr` (`ActiveRadioPtr` 159, `RadioPtr` 115, `InactiveRadioPtr` 89 mentions) | `trdos/logradio.pas:168, 439` | no | a class (`RadioPtr` uses become plain references; `@Radio1` becomes `Radio1`). **The largest single item in this audit** | UT `uTestRadioStatus`, `uTestCWKeyer`, `uTestStatusAndNotice`, `uTestTCIServer`; BENCH one rig per verified protocol family |
| 6.2 | `DupeAndMultSheet` (`Sheet`) | `trdos/logdupe.pas:165` | no | a class | MATRIX, CORPUS, FACTORY |
| 6.3 | `EditableLog` (`VisibleLog`, 101 mentions) | `trdos/logedit.pas:70` | no | a class | MATRIX, UT `uTestLogRepository`; screen BENCH |
| 6.4 | `CallDatabase` (`CD`), `CellBufferObject` | `trdos/logscp.pas:94, 131` | no | classes, with 2.2 | MATRIX (TRMASTER initial exchange) |
| 6.5 | `K1EAKeyer` (`CPUKeyer`) | `trdos/logk1ea.pas:159` | no | a class, with 2.1 | BENCH |
| 6.6 | `PacketObject` (`Packet`) | `trdos/logpack.pas:71` | no | a class -- **check first whether TNC packet is still a feature** | none |
| 6.7 | `MultsObject` (`mo`) | `uMults.pas:50` | no, but holds two `TSortedStringList` that DO | a class | UT `uTestMults`, MATRIX, CORPUS |
| 6.8 | `TSortedStringList` | `uSortedStringList.pas:63` | **yes** | `TStringList` with `Sorted`, or `specialize TList<T>` (with 2.3) | as 6.7 |
| 6.9 | `TCallsignsList` | `uCallsigns.pas:76` | **yes** | a class (with 2.3) | UT `uTestStringCompare`, `uTestOffBandCredit`; Alt-D screen BENCH |
| 6.10 | `TDXSpotsList` (`SpotsList`) | `uSpots.pas:66` | **yes** | a class | UT `uTestDXSpotParse`, `uTestSpotAge` (partial); band map BENCH |
| 6.11 | `NameDictionary` | `trdos/logname.pas:167` | no | **DELETED (P4)** with the file (D5) | COMPILER |
| 6.12 | `^record` type declarations with **one** mention in `src`/`tr4wserver`/`test` -- the declaration itself (`rg -c -i -w`, raw): `RememberHeap`, `OldInt08Vector`, `OldInt0BVector`, `FourBytesPtr`, `BufferTypePtr`, `PDayTable`, `PPortType`, `TMessageStatePtr`, `DataBaseEntryRecordPtr`, `PMenuRecord`, `SocketPtr`. Two mentions (declaration plus one use, possibly a dead variable): `EntryPointerListPtr`, `SCPIndexArrayPtr`, `MultiMessageListPointer`, `ReminderArrayPointer`, `SharedMemoryPointer`, `RealTimeMessagePointer`, `StringPointer`, `MultiMessage`, `FourBytePtr` | `VC.pas`, `tree.pas`, `logscp.pas`, `logstuff.pas`, `logwind.pas`, `logdvp.pas`, `logk1ea.pas`, `logedit.pas`, `uMenu.pas`, `tr4wserverUnit.pas` | -- | **DONE (P4)**: all deleted except `SCPIndexArrayPtr`, `ReminderArrayPointer` and `StringPointer`, which have a live use (`SCPIndexArray`, `Reminders`, `ExchangeTemplateList`). See the P4 section | COMPILER |
| 6.13 | `ContestExchangePtr` (4), `ContestExchangeArrayPtr` (5), the network `...Ptr` types | `VC.pas:2026-2440` | -- | follow 3.2 and the log-store work; `ContestExchangeArrayPtr` at `tr4wserverUnit.pas:1287` is pinned by `TestRecordArrayStrideIsOneRecord` | UT `uTestLogBinaryFile` |
| 6.14 | `uCTYDAT.PrefixRecPtr` (`ctyAddNewPrefixRecord(pr: PrefixRecPtr; ...)`) | `uCTYDAT.pas:194, 287, 363` | -- | `const pr: PrefixRec` | UT `uTestCTYDAT` |

### Category 7 -- procedure variables and untyped code pointers

Typed procedural types (`C7-proc-type`, 103) are **already native** -- the
compiler checks their signatures -- and 33 of them are `of object`. They are
not work. The items are the **untyped** ones:

| # | where | what | native replacement | oracle |
|---|---|---|---|---|
| 7.1 | `TF.pas:213` `TTR4WThreadStart = Pointer`; 15 live `tCreateThread` call sites | **D2** -- ten wrong signatures nothing checks | **DONE (P1)**: `TTR4WThreadStart` is the procedural type; every target has its shape | COMPILER + `Lint-TypedCodePointers`, then BENCH: CPU keyer, WinKeyer open, DVP, multi-op connect and sync, NTP, Get Scores |
| 7.2 | `uProcessCommand.pas:66` `caAddress: Pointer`, cast at `:270` to `procedure` | the CW-memory command table | **DONE (P1)**: `caAddress: TCommandHandler`; all 81 rows were already parameterless procedures | COMPILER + `Lint-TypedCodePointers` |
| 7.3 | `uCFG.pas:1294` `Proc: Pointer` | declared, **never used** (`TAdditionalProc` beside it is the typed form) | **DELETED (P4)** -- and so were `TAdditionalProc` and the label `AdditionalProc`, which were unused too | COMPILER |
| 7.4 | `TF.pas:100` `TEnumLinesFunc = procedure(Line: PShortString)`; 10 callers of `EnumerateLinesInFile` | a callback that receives a POINTER to a ShortString and edits it in place | `procedure(var Line: ShortString)` now, `const Line: string` once the callbacks stop editing it | the callbacks load `.dom`, dupe, CFG, intercom, telnet and stations files: MATRIX, CORPUS, UT `uTestDomQTHTableReload` |
| 7.5 | `trdos/logscp.pas:116, 550` `GetNextEntryAddress(var EntryAddress: Pointer)` | hands out a pointer into the cell buffer | an index into the buffer | MATRIX |
| 7.6 | `uRadioPolling.pas:95, 113` `TRadioStatusTraceProc`/`TRadioStatusPublishedProc = procedure(rig: RadioPtr ...)` | typed, but on `RadioPtr` | follows 6.1 | UT `uTestRadioStatus` |
| 7.7 | `uIcomNetworkTransport.pas:1017-1051` `FreeObjectThread(Obj: Pointer)` + `BeginThread(..., Pointer(Socket), ...)` | an object freed on a thread passed as `Pointer` | **keep**: `BeginThread`'s parameter is `Pointer` by RTL contract; add the comment | UT `uTestIcomTeardown` |

---

## (c) The schedule

Ordered by **(crash or defect risk) x (blast radius)**, then by how cheaply the
oracle proves it. **A packet marked TEST FIRST must not start until the named
test exists and passes against the OLD code** -- otherwise the test is written
against the new code and proves nothing. A packet marked BENCH needs a
[`BENCH_QUEUE.md`](BENCH_QUEUE.md) entry in the same commit as the change.

Owners follow CLAUDE.md's routing table.

| order | packet | items | why here | oracle that tells us what broke | gate before starting | owner(s) |
|---:|---|---|---|---|---|---|
| **P0** | Commit the counter -- **DONE 2026-10-16** | appendix scripts as `tr4w/build/Count-LivePointers.ps1` (+ `-SelfTest`, a floor, and a refusal to report if `src\MainUnit.pas` was not scanned -- the `Count-LiveMove` pattern) | every later packet is measured by it | its own fixture -- all 22 rules exact | none | build-release |
| **P1** | Type the thread start and the command table -- **DONE 2026-10-16**, see below | 7.1, 7.2, 7.3 | D2 is undefined behaviour on **every** worker-thread start, and the fix makes the compiler enumerate the wrong ones | COMPILER; checked UT run (`Build-Tests.ps1 -Checked -Run`); then BENCH each thread's feature | disassemble `tWorkerThreadTrampoline` first and record what it shows (D2) | cw-keying, multi-op-network, integrations |
| **P2** | 64-bit truncations + a lint -- **DONE 2026-10-16** (the lint is `Lint-PointerTruncation.ps1`), see below | 3.1, 5.5 | D3: three live sites crash RichEdit on Win64; the lint stops a fourth | a new `Lint-PointerToInteger.ps1` in `Run-Lints.ps1` (comment-aware, `integer\|longint\|cardinal\|dword\|longword` applied to `@`); x64 COMPILER for the typed parameter | none | build-release, integrations, multi-op-network |
| **P3** | `logdom` | 1.1 | D1 | UT `uTestDomQTHTableReload`, MATRIX, CORPUS | **IN PROGRESS** -- do not duplicate | contest-scoring |
| **P4** | Delete the dead pointer code -- **DONE 2026-10-16**, see below | 1.4, 1.5, 1.6, 1.7, 6.11, 6.12, 7.3 | removes ~250 dereferences, two dangling-pointer shapes and a whole uncompiled unit, at **zero** behaviour risk | COMPILER + full build + UT + CORPUS + MATRIX (a deletion that compiles cannot change behaviour, but run them) | none; **fix `64_BIT_TASKLIST.md`'s `logname` rows and CLAUDE.md's TRDOS table in the same commit** | contest-scoring, file-formats, dx-cluster, lcl-ui |
| **P5** | `zonecont` domestic country list -- **DONE 2026-10-16**, see below | 1.2 | live and scoring-critical, but the oracle is the strongest in the tree | MATRIX (change `uContestMatrix.pas:502` with it), CORPUS, FACTORY, UT `uTestContestFactory` / `uTestContestSession` | none | contest-scoring, contest-factory |
| **P6** | CPU keyer buffer | 2.1, 6.5 | D4 nil write + leak | **TEST FIRST**: a UT that feeds `K1EAKeyer.AddCharacterToCWBuffer` (incl. `' '` first) and reads the element ring; then BENCH DTR/RTS keying | write the UT | cw-keying |
| **P7** | SCP cell buffer | 2.2, 6.4, 7.5 | two allocators for one pointer; live on every partial-call lookup | MATRIX covers the TRMASTER initial-exchange path only. **TEST FIRST**: a UT over the shipped-format fixture (`contest-matrix/MATRIX-TRMASTER.DTA`) asserting partial-call results for a handful of keys | write the UT | file-formats |
| **P8** | Old-style lists with a VMT | 2.3, 6.7, 6.8, 6.9, 6.10 | objects with a VMT are where `SizeOf` and `FillChar` go wrong (CLAUDE.md, the `0xC0000005` story) | `uSortedStringList`/`MultsObject`: UT `uTestMults` + MATRIX + CORPUS. `TCallsignsList`, `TDXSpotsList`: **TEST FIRST** (partials list; spot store add/age/remove) | write the two UTs | contest-scoring, dx-cluster |
| **P9** | Identity in `Objects[]` / `Data` / `lParam` | 5.1, 5.2, 5.3, 5.4, 5.6 | the `WIN32_ARTIFACT_SWEEP` pattern; display-only, so low crash risk but invisible breakage | **no automated oracle** -- each conversion writes its typed-payload test with the change (the sweep doc's own rule) AND a BENCH entry per window | none | lcl-ui |
| **P10** | Small puns and terminators | 3.3, 3.4, 3.6, 6.14 | low risk, easy to pin | **TEST FIRST** for 3.3 (short-call pins in `uTestDXSpotParse`); `uTestCTYDAT` for 6.14; 3.4 and 3.6 BENCH | write the 3.3 pins | dx-cluster, cw-keying, multi-op-network, file-formats |
| **P11** | `RadioObject` -> class | 6.1, 7.6 | the largest item (363 pointer mentions) and the widest blast radius; every radio | UT `uTestRadioStatus` / `uTestCWKeyer` / `uTestStatusAndNotice` / `uTestTCIServer`, then BENCH one rig per verified family (`RADIO_BENCH_STATUS.md`) | P1 done (`BeginPolling` takes `RadioPtr`) | radio-factory, cw-keying |
| **P12** | Untyped byte buffers -> open arrays | 3.5 | correct today; this is the "byte I/O stays byte I/O, the pointer goes" rule | UT `uTestCRC32`, `uTestSHA256`, `uTestNetFraming`, `uTestWebSocketFraming`, `uTestIcomCIV`; WinKeyer + server BENCH | none | serial-port-io, multi-op-network, tci-interface, cw-keying |
| **P13** | Heap temporaries and queues | 2.4, 2.5, 2.7, 2.8 | leaks on exception, `^record` in `TList` | CORPUS (Cabrillo summary); UT `uTestFlexDiscovery`, `uTestIcomTeardown`; the two post-contest reports and K4/Icom discovery are BENCH; QTC per `QTC_BENCH_HANDOFF.md` | none | file-formats, radio-factory, contest-scoring |
| **P14** | Wire overlays | 3.2, 6.13 | correct today, high blast radius, and possibly superseded | **TEST FIRST**: a decode pin per message type (bytes in, fields out) against the current overlay; then two-station BENCH | **SKIPPED -- NY4I, 2026-10-16: "skip P14, the new protocol replaces it."** The V1 wire overlays are left as they are and retire with the protocol | multi-op-network |
| **P15** | Ratchet the Move counter | -- | 387 -> 464 in four weeks, all new `FillChar` | **DONE 2026-10-17:** a `$MOVE_CEILING` in `Count-LiveMove.ps1`, ratcheting down, wired into `Run-Lints.ps1` as `Count-LiveMove -Gate` (fixture first, fails closed under file and count floors) | none | build-release |
| **P16** | Remaining `src` `...EnumLines` callback | 7.4 | touches six loaders; do after P3 and P5, which own two of them | MATRIX, CORPUS, UT `uTestDomQTHTableReload` | P3, P5 | contest-scoring, settings-config |

**Packets with NO automated oracle today** -- each needs its test written first
or a bench entry: **P6** (CPU keyer), **P7** (SCP partials), **P8** (call and
spot lists), **P9** (every window), **P10** (3.4, 3.6), **P11** (keying and
polling), **P13** (reports, K4/Icom discovery), **P14** (every network message).

### P4 -- what was deleted, 2026-10-16

Every deletion was checked first with a case-insensitive whole-word `rg -i -w`
over **all** of `tr4w/` (src, tr4wserver, every `.lpr`, test, tools, build) and
the repository's `tools/`, plus `.lpi`, build scripts and include directives
for the unit files. A routine went only when every reference was its own
declaration, its own body, or another routine on this list.

| what | where | why it was dead |
|---|---|---|
| `logname.pas` (whole unit, `NameDictionary`, `FourBytePtr`) | `src/trdos/` | named in no `uses` clause, `.lpi` or include anywhere (D5) |
| `uRadioManager.pas`, `uExternalLoggerManager.pas` (whole units) | `src/radioFactory/`, `src/` | named only by commented-out lines in `tr4w.lpr` and `uProgramMain`'s `uses`; those lines went too |
| `VDEntry`, `VDEntryPointer`, `FirstVDEntry`, `NumberVDCalls`, `DupeAndMultSheet.AddCallToVisibleDupeSheet`, `DupeInit` + the unit's initialization call | `logdupe` | the method had no caller and was the only writer of `FirstVDEntry`; `DupeInit` only walked that always-nil chain |
| `BandMapEntry`, `tr4wBandMapEntry`, `BandMapEntryPointer`, `BandMapFirstEntryList`, `BandMapCursorData`, `BandMapBlinkingCallRecord`, `BandMapTotalCalls`, `SetUpBandMapEntry`, the four `Next*EntryIn*BandMap` walkers, `GetRecordForBandMapCursor`, `DecrementBandMapTimes`, `BandMapExpandedString` | `logwind` | a closed island: the three `GoToNext*BandMapFrequency` (`logsubs2`) had no caller, and everything else was reached only from them or from each other. `UpdateBlinkingBandMapCall` is live (footswitch) and **stays**; only its `if BandMapBlinkingCallRecord <> nil` block went -- that global was never assigned, so the block never ran |
| `GoToNextMultBandMapFrequency`, `GoToNextDisplayedBandMapFrequency`, `GoToNextMultDisplayedBandMapFrequency` | `logsubs2` | no caller |
| `UpdateBandMapDupeStatus`, `RememberHeap` | `logedit` | the only call was commented out; the field had one mention |
| `DataListEntryPointer`/`Record`, `PartialCallListEntryPtr`/`Type`, `FirstMergeDataListEntry`, `InitialPartialList`, `LastPartialList`, `EntryPointerList`, `AddRecordToMergeList`, `BlowAwayFirstLettersList` | `logscp` | no `New` for the partial list, no caller for the merge list. `BlowAwayFirstLettersList` WAS called (`NewTwoLetters`); its loop never ran, so only its `InitialPartialCall := ''` was kept, inline, with a comment |
| `MultiMessageMemoryRecord`, `MultiMessageListArrayType`, `MultiMessageListPointer`, `MultiRememberBuffer`, `First`/`LastMultiMessage`, `MultiRetryTime`, `MultiMessageBufferSize`, `CheckForLostMultiMessages` | `logstuff` | `CheckForLostMultiMessages` had no caller and was the only reader; the buffer was never allocated and its indices never written |
| `EntryPointerListType`/`Ptr`, `TMessageStatePtr`, `DataBaseEntryRecordPtr` | `VC` | one mention each, or used only by a field deleted above |
| `PDayTable`/`TDayTable`, `FourBytesPtr`, `PPortType`, `BufferType`/`BufferTypePtr` | `tree` | declaration only |
| `OldInt0BVector`, `OldInt0CVector`, `OldInt08Vector` (DOS interrupt vectors), `RealTimeCWElementRecords`, `RealTimeMessageType`, `RealTimeMessagePointer`, `RealTimeCWMessageArrayType` | `logk1ea` | declaration only |
| `DVPSharedMemory`, `SharedMemoryPointer` | `logdvp` | declaration only (its one variable was already commented out) |
| `PMenuRecord` | `uMenu` | declaration only |
| `SocketPtr` | `tr4wserverUnit` | declaration only |
| `MultiMessage` | `logwind` | its one variable was already commented out |
| `Proc: Pointer`, `TAdditionalProc`, label `AdditionalProc` | `uCFG.CheckCommand` | declared, never used (7.3) |

Also: the `logwind.pas`/`SetUpBandMapEntry` row of
`tools/contest-rules-inventory/judgements.py`. Regenerating
`CONTEST_RULES_OUTSIDE_FACTORY.md` changes only line numbers and the file count
(453 -> 450) -- same 23 rows, same 24 contests.

**Left for their owners, not deleted here:** three resourcestrings whose only
user went -- `TC_FINDINGZEROENDVISIBLEDUPESHEETLIST`,
`TC_PLEASECHECKMULTINETWORK`, `TC_POSSIBLEDATALOSSMULTINETWORK` (`uTR4WStrings`,
`lang/tr4w_consts_eng.pas`, the `.po` catalogues). Removing a resourcestring
moves the catalogue harvest, which is `i18n`'s call.

**Measured with `Count-LivePointers.ps1`**, at `7e3c209b` and after:

| rule | before | after |
|---|---:|---:|
| C1-ptrtype-decl | 91 | 68 |
| C1-link-field | 11 | 5 |
| C2-new-dispose | 80 | 55 |
| C3-deref | 1,145 | 823 |
| C3-inc-dec-ptr | 50 | 42 |
| C5-data | 19 | 17 |
| C6-object-type | 12 | 11 |
| C6-ptr-named | 581 | 552 |
| C7-proc-type | 111 | 110 |
| C7-pointer-word | 77 | 69 |
| every other rule | unchanged | unchanged |
| **all hits** | **3,144** (821 files) | **2,719** (818 files) |

`logname` alone was 227 of the 322 dereferences. `Count-LiveMove`: **469 ->
457** (exactly `logname`'s 12; `64_BIT_TASKLIST.md` is updated).
`Count-LivePChar`: 71, unchanged. Narrowing conversions **1249 -> 1245**
(ceiling lowered in `Build-App.ps1`); range warnings 3; heaptrc unfreed blocks
13,469, unchanged.

### P5 -- the domestic country list, 2026-10-16

`trdos/zonecont.pas`'s hand-built list (`DomesticCountryRecord` with a
`NextRecord` field, `FirstDomesticCountryRecord`, `New` per add after a walk to
the tail, `Dispose` per entry on clear) is a class now:
`TDomesticCountryList` over a `TList<AnsiString>`, created in the unit's
`initialization`, freed in its `finalization`, global `DomesticCountries`. The
three free routines (`AddDomesticCountry`, `ClearDomesticCountryList`,
`DomesticCountryCall`) keep their signatures and delegate, so none of their
twenty-odd call sites changed. `GEmptyDomesticListReported` became the list's own latch
(`ClaimEmptyReport`); the unused `tAddDomesticCountryString` went.

**The semantics kept, read from the old code** (the class header states them):
insertion order; duplicates appended (UKEI adds `GM` twice); ASCII upper-case on
add (`TF.strU`); an EXACT, case-sensitive compare (an `AnsiString` holds the
ShortString bytes, so no code-page conversion enters the compare); stored as
the first six characters (`string[6]`); an empty ID stored, and matching a call
whose CTY ID is empty; an empty list logs once and answers False ("DX"), and the
CTY lookup is still skipped for an empty list; only `Clear` resets -- it empties
AND re-arms the once-only log -- and `FoundContest` still APPENDS, so a second
`CONTEST` without a `.cfg` read accumulates, as it always did.

**The one reader outside the unit**, `uContestMatrix.CaptureDomesticCountries`,
iterates `DomesticCountries.IDs[]` and builds the identical line.

**Pinned by `uTestDomesticCountryList`** (31 checks): order and duplicates;
case and width; the empty ID; `Clear` emptying, re-arming the report and a
reload after it; an add without `Clear` accumulating; and the free routines
reaching the live list (restored after).

**Oracles:** matrix 187 identical **without re-freeze**, and every fresh record
byte-identical to a run of the pre-change binary; the matrix run's slice of
`tr4w.log` holds **109** "domestic country list is EMPTY" lines before and 109
after; factory 13 identical; corpus 22/0/4, exit 0; ADIF round trip 12/0/1;
unit 360,236 / 0 failed, plain and `-Checked`; heaptrc unfreed 13,469,
unchanged; narrowing 1245, range 3; 44 lints. **The corpus is blind to scoring
and the matrix says "same", not "right"** -- the list decides DX vs domestic in
every domestic contest, so this deserves a real-contest look.

**`Count-LivePointers.ps1`**, at `5b1f838b` and after:

| rule | before | after |
|---|---:|---:|
| C1-ptrtype-decl | 68 | 67 |
| C1-link-field | 5 | 4 |
| C2-new-dispose | 55 | 52 |
| C3-deref | 823 | 810 |
| every other rule | unchanged | unchanged |
| **all hits** | **2,719** (818 files) | **2,701** (819 files) |

What is left in `zonecont` under `C6-ptr-named` is `CharPtr`, an `integer` in
`GetNumber` -- which, like `ClubCall` and `LastLocateQTH`, has no reader
anywhere in the tree. Not deleted here; noted for a dead-code pass.

### P1 and P2 -- typed code pointers and the 64-bit truncations, 2026-10-16

**P1. `TF.TTR4WThreadStart` is `function(aParameter: Pointer): DWORD;
stdcall` -- the shape the trampoline always called -- instead of `Pointer`.**
`TWorkerProc`, its private twin, is gone. **Typing the parameter was not
enough by itself, and that is the finding worth keeping:** in
`{$MODE Delphi}`, `@Routine` is an UNTYPED pointer, and FPC 3.2.2 accepts it
for a procedural parameter without checking the signature, with or without
`{$T+}`. Measured with a three-line probe -- `Take(@Bad)` compiles, `Take(Bad)`
is *"Incompatible type for arg no. 1"*. The first build after typing the
parameter was green with all ten wrong targets still in place. So every call
site now names its routine bare, and **`Lint-TypedCodePointers`** fails the
build on an `@` put back (it reported 96 on `e19b9f9e`: 15 thread starts and
81 command rows).

With the `@` dropped, the compiler rejected `tPaddleFootSwitchThreadProc`
(`MainUnit.pas:7741`) first -- FPC stops at the first unit in error, so the
rest were fixed from the D2 table and then confirmed by a clean build, which
type-checks all fifteen call sites. **What changed per target:**

| target | was | now |
|---|---|---|
| `CWThreadProc`, `tDoABeep`, `tPaddleFootSwitchThreadProc` (`logk1ea`) | `procedure;` | the thread shape, `Result := 0` |
| `tDVPPlayThreadproc` (`logdvp`, both the Windows body and the off-Windows stub) | `procedure;` | the same |
| `ConnectThread` (`uNet`), `RunSyncThread` (`uGetServerLog`), `CreateConnectionAndSendReportToGetScores` (`uGetScores`), `NTPStartupCheck` (`uSynTime`), `wkReadThreadProc` (`uWinKey`) | `procedure;` | the same |
| `wkOpen` (`uWinKey`) | `function: boolean;`, started directly | **unchanged** -- `MainUnit` also calls it directly -- and started through a new `wkOpenThreadProc` |
| `BeginPolling` (`uRadioPolling`) | `procedure(rig: RadioPtr); stdcall` -- stack right, exit code garbage | the thread shape; it reads `RadioPtr(aParameter)` |
| `TelnetThreadProc`, `YCCCReadThreadProc`, `YCCCWriteThreadProc` | already right | only the `@` at the call site went |

**The command table (7.2):** `caAddress` is `TCommandHandler = procedure`;
the 81 rows name their handler bare, and the compiler accepted every one --
**no row had a wrong signature.** The dispatch site assigns with no cast.

**P2.** The five sites in D3: `LPARAM(@MMTTY.mmttyCF)` (twice) and
`LPARAM(@MMTTY.mmttyTwoBytes)` with `WPARAM(False)`; `ShowLogCompare` takes
`const aInfo: PLogFileInformation` in `uLogCompare` and `uLogCompareForm`, so
`uNet` passes `s` with no cast, and `uLogCompare` no longer needs `LCLType`.
**`Lint-PointerTruncation`** fails on a cast to `integer`, `longint`,
`cardinal`, `longword`, `dword`, `word`, `smallint`, `shortint` or `byte` of
an address (`integer(@x)`), of `Pointer(...)` or `Self`, or of a name the same
file declares with a pointer type. It reads code only, carries a fixture (7
hits, 11 non-hits) and three floors, and scans all of `tr4w` -- on
`e19b9f9e` it reports exactly the five D3 sites, and nothing else. The
"pointer truncation: 0" row in `64_BIT_TASKLIST.md` is corrected.

**Oracles:** matrix 187 identical **without re-freeze**; factory 13
identical; corpus 22/0/4, exit 0; ADIF round trip 12/0/1; unit 360,236 / 0
failed, plain and `-Checked`; heaptrc unfreed 13,469, unchanged, 0
corruption reports; narrowing 1245, range 3; **46 lints** (44 + the two new).
`tr4wserver` builds. x86_64-win64 compiles and links, 0 errors, at the same
ceilings. **No thread and no MMTTY path has an automated oracle** -- each is
in `BENCH_QUEUE.md`.

**`Count-LivePointers.ps1`**, at `e19b9f9e`, after P1, after P2:

| rule | before | after P1 | after P2 |
|---|---:|---:|---:|
| C3-addr-of | 495 | 399 | 399 |
| C3-pointer-cast | 9 | 8 | 8 |
| C3-int-of-ptr | 20 | 20 | 17 |
| C7-proc-type | 110 | 111 | 111 |
| C7-pointer-word | 69 | 89 | 89 |
| every other rule | unchanged | unchanged | unchanged |
| **all hits** | **2,701** | **2,625** | **2,622** |

`C7-pointer-word` RISES by 20, and should: it is the `aParameter: Pointer`
of each thread body and declaration. That `Pointer` is the RTL's
`BeginThread` contract, the same reason 7.7 keeps one -- the untyped part
that went is the CODE pointer, which the compiler now checks.

---

## Appendix -- the scripts, so every number above can be re-run

### `Measure-Pointers.ps1` (the C1-C7 table)

Shape: `Import-Module tr4w\build\PascalSource.psm1`; for each file from
`Get-TR4WPascalFiles -Root tr4w` not under `graphify-out` or `__history`,
match each rule below against `Get-PascalCodeOnlyText -Path $f -BlankStrings`,
map the match index to a line number, and write
`rule<TAB>file<TAB>line<TAB>match<TAB>source line` to a TSV. Then group by
rule. The rules, verbatim (.NET regex):

| rule | pattern |
|---|---|
| C1-ptrtype-decl | `(?im)^\s*(\w+)\s*=\s*\^\s*(\w+)\s*;` |
| C1-link-field | `(?i)\b(\w*(?:Next\|Prev\|Previous\|Left\|Right\|Parent\|Child\|Link\|Sibling)\w*)\s*:\s*(\^\s*\w+\|\w*Ptr\b\|\w*Pointer\b\|P[A-Z]\w*)` |
| C2-heap | `(?i)(?<![\w.])(GetMem\|FreeMem\|ReallocMem\|ReAllocMem\|AllocMem\|StrAlloc\|StrDispose\|StrNew\|GlobalAlloc\|GlobalFree\|LocalAlloc\|LocalFree\|VirtualAlloc\|HeapAlloc\|HeapFree\|GetMemory\|FreeMemory)\s*\(` |
| C2-new-dispose | `(?i)(?<![\w.])(New\|Dispose)\s*\(` |
| C3-pointer-cast | `(?i)(?<![\w.])Pointer\s*\(` |
| C3-int-of-ptr | `(?i)(?<![\w.])(Integer\|Cardinal\|LongInt\|LongWord\|DWORD\|DWord\|NativeInt\|NativeUInt\|PtrInt\|PtrUInt\|SizeInt\|SizeUInt\|Int64\|QWord)\s*\(\s*(@\|Pointer\s*\(\|Self\b\|Sender\b\|\w*(Ptr\|P\|Pointer)\s*\))` |
| C3-typed-ptr-type | `(?i)(?<![\w.])(PByte\|PWord\|PInteger\|PCardinal\|PLongInt\|PLongWord\|PDWORD\|PSmallInt\|PShortInt\|PBoolean\|PSingle\|PDouble\|PInt64\|PQWord\|PPointer\|PByteArray\|PWordArray\|PIntegerArray\|PtrUInt\|PtrInt)\b` |
| C3-addr-of | `(?i)(?<![\w.@])@\s*[A-Za-z_]` |
| C3-deref | `(?i)[\w\])]\s*\^` |
| C3-inc-dec-ptr | `(?i)(?<![\w.])(Inc\|Dec)\s*\(\s*(P\w*\|\w*Ptr\|\w*Pointer)\s*[,)]` |
| C3-untyped-param | `(?i)[(;]\s*(?:var\|const\|out\|constref)\s+\w+(?:\s*,\s*\w+)*\s*(?=[;)])` |
| C3-memcmp | `(?i)(?<![\w.])(CompareMem\|CompareByte\|CompareWord\|CompareDWord\|FillByte\|FillWord\|FillDWord\|IndexByte)\s*\(` |
| C3-s1 | `(?i)@\s*\w+(\.\w+)*\s*\[\s*(1\|0)\s*\]` |
| C5-tobject-cast | `(?i)(?<![\w.])TObject\s*\(` |
| C5-objects | `(?i)\.Objects\s*\[\|\bAddObject\s*\(\|\bInsertObject\s*\(` |
| C5-tag | `(?i)\.Tag\b` |
| C5-lparam | `(?i)\b(lParam\|wParam\|LPARAM\|WPARAM)\b` |
| C5-data | `(?i)\.Data\s*:=\|\bTNode\b\|\.Data\s*\)` |
| C6-object-type | `(?i)=\s*(packed\s+)?object\b` |
| C6-ptr-named | `(?i)\b\w+Ptr\b` |
| C7-proc-type | `(?i)=\s*(reference\s+to\s+)?(procedure\|function)\b` |
| C7-pointer-word | `(?i)(?<![\w.])Pointer\b(?!\s*\()` |

(In the table `\|` is a literal `|` escaped for Markdown.)

**Known imprecision, stated so nobody trusts a row further than it goes:**
`C3-inc-dec-ptr` matches integer indices named `p...`; `C3-deref` counts a
`^` in a type declaration too; `C6-ptr-named` counts every mention, not every
type; `C3-untyped-param` caught one typed parameter split across two lines
(`logdupe.pas:1417`). The per-category tables were built by **reading** the
hits, not by trusting the regex.

### `Find-OrphanUnits.ps1`

For every file from `Get-TR4WPascalFiles`, take `unit <Name>;` from the
code-only text, and collect every name in every `uses ... ;` clause (dropping
`in '...'`). Report each unit whose name is in no clause.

### One-liners

```powershell
# old-style objects: methods, virtuals, constructors
Import-Module tr4w\build\PascalSource.psm1
$t = Get-PascalCodeOnlyText -Path <file> -BlankStrings
[regex]::Matches($t, '(?is)(\w+)\s*=\s*(packed\s+)?object\b(.*?)\n\s*end\s*;')
   # then count \bvirtual\b, \bconstructor\b, \b(procedure|function)\b in group 3

# records with methods
[regex]::Matches($t, '(?is)\b(\w+)\s*=\s*(packed\s+)?record\b((?:(?!\brecord\b|\bend\s*;).)*)\bend\s*;')
   # keep those whose body matches \b(procedure|function|constructor|property)\b
```

**Liveness claims in this document were made with `rg -i -w` over `tr4w/src`,
`tr4w/tr4wserver`, `tr4w/test` and `tr4w/tr4w.lpr`, excluding `backup`** --
case-insensitive because Pascal is (CLAUDE.md, *Naming*). A claim of "no
caller" is a statement about those trees at `28599599`; re-check before
deleting.
