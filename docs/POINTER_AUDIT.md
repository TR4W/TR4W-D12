# Pointer audit -- what is still DOS/Win32-shaped, and the order to fix it

**Measured 2026-10-16 at `28599599` (branch `contestFactory`, working tree
dirty). NOTHING WAS CHANGED: this is an inventory and a schedule.**

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

### D2. `tCreateThread` starts ten thread bodies through the WRONG calling convention

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

### D3. 64-bit pointer truncation is NOT at zero

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

### D5. `logname.pas` is NOT COMPILED, and two audits count it

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
implementation).

### D6. Three more DOS linked lists that nothing fills -- dead, one dangling

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
counter prints a number and has no ceiling; packet P15 proposes one.

### The new counter: `Measure-Pointers.ps1`

Not checked in (this audit writes one document only). Its rule table is
reproduced in the appendix so it can be recreated verbatim; **packet P0
proposes committing it as `tr4w/build/Count-LivePointers.ps1`.**

```
pwsh -NoProfile -File Measure-Pointers.ps1 -Repo C:\tr4w-d12 -Out hits.tsv
```

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
| 1.2 | `trdos/zonecont.pas:42-50`, `AddDomesticCountry` `:156`, `DomesticCountryCall`, `ClearDomesticCountryList` `:255` | domestic COUNTRY list -- DX vs domestic for every domestic contest | **live, scoring-critical** | a `TStringList` (or `THashSet<string>`) owned by the unit; **`uContestMatrix.pas:502` walks `FirstDomesticCountryRecord` directly and must change with it** | high | MATRIX (reads the list), CORPUS, FACTORY, UT `uTestContestFactory` (stubs the call), `uTestContestSession` |
| 1.3 | `trdos/logstuff.pas:252-258`, `EnumHelloDAT` `:1222`, `SendSalutation` `:1143` | `HELLO.DAT` per-country greeting | live **only when `HELLO.DAT` exists** (not shipped); loaded once (`LogCfg.pas:478`), never freed; `Greeting: string[6]` truncates a `Str20` (check D7 before calling that a regression) | `TStringList` `Values[]` | low | **none** -- write a UT first |
| 1.4 | `trdos/logdupe.pas:156-160`, `:816`, `DupeInit` `:1529` | visible dupe sheet | **dead** (D6) | delete | none | COMPILER |
| 1.5 | `trdos/logwind.pas:180-209, 491-518`, `DecrementBandMapTimes` `:1935`, the `Next*EntryIn*BandMap` walkers `:2425-2715`, `GetRecordForBandMapCursor` `:2893`; `logsubs2.pas:1313-1380` | DOS band map | **dead** (D6) | delete | none | COMPILER |
| 1.6 | `trdos/logscp.pas:80-86, 121-127`, `AddRecordToMergeList` `:2605`, the partial-list clear `:1430` | SCP merge list, partial-call list | **dead** (D6) | delete | none | COMPILER |
| 1.7 | `trdos/logname.pas` | name database | **not compiled** (D5) | delete the file | none | COMPILER |

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
| 3.1 | `uMMTTY.pas:253, 384`, `ui/lcl/uMMTTYForm.pas:237`, `uNet.pas:1491, 1504` | pointer narrowed to `integer` | see D3 | `LPARAM(@x)`; a typed parameter for `ShowLogCompare` | **high on Win64** | x64 COMPILER does not catch it; a lint does (P2); MMTTY is BENCH |
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
| 5.5 | `uEditMessage.ShowEditMessage(const aMessage: lParam)` (`uEditMessage.pas:99`, `ui/lcl/uEditMessageForm.pas:456`), `ShowLogCompare(const aInitParam: lParam)` (`uLogCompare.pas:73`, `ui/lcl/uLogCompareForm.pas:225`) | a dialog's Win32 `lParam` kept as the parameter type after the dialog became an LCL form; one of them carries a pointer (D3) | `ShowEditMessage(aRow: integer)`, `ShowLogCompare(aInfo: PLogFileInformation)` -- or better, a value | COMPILER |
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
| 6.11 | `NameDictionary` | `trdos/logname.pas:167` | no | **delete** (D5) | COMPILER |
| 6.12 | `^record` type declarations with **one** mention in `src`/`tr4wserver`/`test` -- the declaration itself (`rg -c -i -w`, raw): `RememberHeap`, `OldInt08Vector`, `OldInt0BVector`, `FourBytesPtr`, `BufferTypePtr`, `PDayTable`, `PPortType`, `TMessageStatePtr`, `DataBaseEntryRecordPtr`, `PMenuRecord`, `SocketPtr`. Two mentions (declaration plus one use, possibly a dead variable): `EntryPointerListPtr`, `SCPIndexArrayPtr`, `MultiMessageListPointer`, `ReminderArrayPointer`, `SharedMemoryPointer`, `RealTimeMessagePointer`, `StringPointer`, `MultiMessage`, `FourBytePtr` | `VC.pas`, `tree.pas`, `logscp.pas`, `logstuff.pas`, `logwind.pas`, `logdvp.pas`, `logk1ea.pas`, `logedit.pas`, `uMenu.pas`, `tr4wserverUnit.pas` | -- | delete what the compiler lets you | COMPILER |
| 6.13 | `ContestExchangePtr` (4), `ContestExchangeArrayPtr` (5), the network `...Ptr` types | `VC.pas:2026-2440` | -- | follow 3.2 and the log-store work; `ContestExchangeArrayPtr` at `tr4wserverUnit.pas:1287` is pinned by `TestRecordArrayStrideIsOneRecord` | UT `uTestLogBinaryFile` |
| 6.14 | `uCTYDAT.PrefixRecPtr` (`ctyAddNewPrefixRecord(pr: PrefixRecPtr; ...)`) | `uCTYDAT.pas:194, 287, 363` | -- | `const pr: PrefixRec` | UT `uTestCTYDAT` |

### Category 7 -- procedure variables and untyped code pointers

Typed procedural types (`C7-proc-type`, 103) are **already native** -- the
compiler checks their signatures -- and 33 of them are `of object`. They are
not work. The items are the **untyped** ones:

| # | where | what | native replacement | oracle |
|---|---|---|---|---|
| 7.1 | `TF.pas:213` `TTR4WThreadStart = Pointer`; 15 live `tCreateThread` call sites | **D2** -- ten wrong signatures nothing checks | type the parameter `TWorkerProc`; fix each target; or `TThread` descendants | COMPILER (once typed), then BENCH: CPU keyer, WinKeyer open, DVP, multi-op connect and sync, NTP, Get Scores |
| 7.2 | `uProcessCommand.pas:66` `caAddress: Pointer`, cast at `:270` to `procedure` | the CW-memory command table | `caAddress: TProcedure` -- every row already holds a parameterless procedure | COMPILER |
| 7.3 | `uCFG.pas:1294` `Proc: Pointer` | declared, **never used** (`TAdditionalProc` beside it is the typed form) | delete | COMPILER |
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
| **P0** | Commit the counter | appendix scripts as `tr4w/build/Count-LivePointers.ps1` (+ `-SelfTest`, a floor, and a refusal to report if `src\MainUnit.pas` was not scanned -- the `Count-LiveMove` pattern) | every later packet is measured by it | its own fixture | none | build-release |
| **P1** | Type the thread start and the command table | 7.1, 7.2, 7.3 | D2 is undefined behaviour on **every** worker-thread start, and the fix makes the compiler enumerate the wrong ones | COMPILER; checked UT run (`Build-Tests.ps1 -Checked -Run`); then BENCH each thread's feature | disassemble `tWorkerThreadTrampoline` first and record what it shows (D2) | cw-keying, multi-op-network, integrations |
| **P2** | 64-bit truncations + a lint | 3.1, 5.5 | D3: three live sites crash RichEdit on Win64; the lint stops a fourth | a new `Lint-PointerToInteger.ps1` in `Run-Lints.ps1` (comment-aware, `integer\|longint\|cardinal\|dword\|longword` applied to `@`); x64 COMPILER for the typed parameter | none | build-release, integrations, multi-op-network |
| **P3** | `logdom` | 1.1 | D1 | UT `uTestDomQTHTableReload`, MATRIX, CORPUS | **IN PROGRESS** -- do not duplicate | contest-scoring |
| **P4** | Delete the dead pointer code | 1.4, 1.5, 1.6, 1.7, 6.11, 6.12, 7.3 | removes ~250 dereferences, two dangling-pointer shapes and a whole uncompiled unit, at **zero** behaviour risk | COMPILER + full build + UT + CORPUS + MATRIX (a deletion that compiles cannot change behaviour, but run them) | none; **fix `64_BIT_TASKLIST.md`'s `logname` rows and CLAUDE.md's TRDOS table in the same commit** | contest-scoring, file-formats, dx-cluster, lcl-ui |
| **P5** | `zonecont` domestic country list | 1.2 | live and scoring-critical, but the oracle is the strongest in the tree | MATRIX (change `uContestMatrix.pas:502` with it), CORPUS, FACTORY, UT `uTestContestFactory` / `uTestContestSession` | none | contest-scoring, contest-factory |
| **P6** | CPU keyer buffer | 2.1, 6.5 | D4 nil write + leak | **TEST FIRST**: a UT that feeds `K1EAKeyer.AddCharacterToCWBuffer` (incl. `' '` first) and reads the element ring; then BENCH DTR/RTS keying | write the UT | cw-keying |
| **P7** | SCP cell buffer | 2.2, 6.4, 7.5 | two allocators for one pointer; live on every partial-call lookup | MATRIX covers the TRMASTER initial-exchange path only. **TEST FIRST**: a UT over the shipped-format fixture (`contest-matrix/MATRIX-TRMASTER.DTA`) asserting partial-call results for a handful of keys | write the UT | file-formats |
| **P8** | Old-style lists with a VMT | 2.3, 6.7, 6.8, 6.9, 6.10 | objects with a VMT are where `SizeOf` and `FillChar` go wrong (CLAUDE.md, the `0xC0000005` story) | `uSortedStringList`/`MultsObject`: UT `uTestMults` + MATRIX + CORPUS. `TCallsignsList`, `TDXSpotsList`: **TEST FIRST** (partials list; spot store add/age/remove) | write the two UTs | contest-scoring, dx-cluster |
| **P9** | Identity in `Objects[]` / `Data` / `lParam` | 5.1, 5.2, 5.3, 5.4, 5.6 | the `WIN32_ARTIFACT_SWEEP` pattern; display-only, so low crash risk but invisible breakage | **no automated oracle** -- each conversion writes its typed-payload test with the change (the sweep doc's own rule) AND a BENCH entry per window | none | lcl-ui |
| **P10** | Small puns and terminators | 3.3, 3.4, 3.6, 6.14 | low risk, easy to pin | **TEST FIRST** for 3.3 (short-call pins in `uTestDXSpotParse`); `uTestCTYDAT` for 6.14; 3.4 and 3.6 BENCH | write the 3.3 pins | dx-cluster, cw-keying, multi-op-network, file-formats |
| **P11** | `RadioObject` -> class | 6.1, 7.6 | the largest item (363 pointer mentions) and the widest blast radius; every radio | UT `uTestRadioStatus` / `uTestCWKeyer` / `uTestStatusAndNotice` / `uTestTCIServer`, then BENCH one rig per verified family (`RADIO_BENCH_STATUS.md`) | P1 done (`BeginPolling` takes `RadioPtr`) | radio-factory, cw-keying |
| **P12** | Untyped byte buffers -> open arrays | 3.5 | correct today; this is the "byte I/O stays byte I/O, the pointer goes" rule | UT `uTestCRC32`, `uTestSHA256`, `uTestNetFraming`, `uTestWebSocketFraming`, `uTestIcomCIV`; WinKeyer + server BENCH | none | serial-port-io, multi-op-network, tci-interface, cw-keying |
| **P13** | Heap temporaries and queues | 2.4, 2.5, 2.7, 2.8 | leaks on exception, `^record` in `TList` | CORPUS (Cabrillo summary); UT `uTestFlexDiscovery`, `uTestIcomTeardown`; the two post-contest reports and K4/Icom discovery are BENCH; QTC per `QTC_BENCH_HANDOFF.md` | none | file-formats, radio-factory, contest-scoring |
| **P14** | Wire overlays | 3.2, 6.13 | correct today, high blast radius, and possibly superseded | **TEST FIRST**: a decode pin per message type (bytes in, fields out) against the current overlay; then two-station BENCH | **NY4I decides whether the V1 messages are worth converting before the new multi-station protocol** | multi-op-network |
| **P15** | Ratchet the Move counter | -- | 387 -> 464 in four weeks, all new `FillChar` | a `$MOVE_CEILING` in `Count-LiveMove.ps1`, ratcheting down, wired into `Run-Lints.ps1` | none | build-release |
| **P16** | Remaining `src` `...EnumLines` callback | 7.4 | touches six loaders; do after P3 and P5, which own two of them | MATRIX, CORPUS, UT `uTestDomQTHTableReload` | P3, P5 | contest-scoring, settings-config |

**Packets with NO automated oracle today** -- each needs its test written first
or a bench entry: **P6** (CPU keyer), **P7** (SCP partials), **P8** (call and
spot lists), **P9** (every window), **P10** (3.4, 3.6), **P11** (keying and
polling), **P13** (reports, K4/Icom discovery), **P14** (every network message).

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
