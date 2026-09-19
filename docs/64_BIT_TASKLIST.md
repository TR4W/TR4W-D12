# TR4W Win64 — task list, checked off against the tree

**Source:** `C:\tr4w-d12-codex-64bit\docs\codex\64_BIT_COMPLETION_TASKLIST.md`,
written 2026-09-12 in the codex worktree. This is that plan **re-measured
against `main` on 2026-09-14** and turned into a task list, per NY4I.

**Every number below is measured with the build's own comment-aware stripper**
(`build/PascalSource.psm1`), not by raw grep. The source document said its own
751 was "not a task count" because it counted prose and commented-out code; it
was right, and the live figure is lower.

**NY4I added one acceptance rule on 2026-09-14** beyond the source document:

> *"even as 8 bit io, move, etc should not be a requirement"*

So byte-oriented I/O stays byte-oriented — serial framing is 8-bit **by
design** — but `Move`, `FillChar`, `ZeroMemory` and pointer walking are not how
to express it. Typed byte arrays, open arrays and indexing, with the bytes
still exact.

---

## Where it stands, measured

## THE APP COMPILES AND LINKS FOR x86_64-win64 (2026-09-14)

**This section used to say the toolchain gate was the blocker and that
"nothing below can start until this exists". Both halves were wrong.**

```
.\build\Build-App.ps1 -Cpu x86_64 -Os win64

  errors+fatals : 0
  range warnings: 6 (ceiling 6)
  narrowing string conversions: 1365 (ceiling 1365)
  -> build-out\app-x86_64-win64\tr4w_fpc.exe   10,627,603 bytes, machine 0x8664
```

Narrowing and range warnings are IDENTICAL to the i386 build, which is the
number worth noticing: the 64-bit target is not carrying its own backlog of
string defects.

**IT IS NOT RUNNABLE YET**, and the build says so rather than pretending: it
stops at the DLL stage needing an x86_64 `libeay32.dll` and `ssleay32.dll`
(OpenSSL 1.0.2). SQLite and the whole HamLib set are staged in
`tr4w/redist/x86_64-win64/`. **Compiling is not running, and nobody has
launched a 64-bit TR4W.**

| gate | source doc | first measure | now | state |
|---|---|---|---|---|
| PChar-family in live code | 751 raw mentions | 578 in 69 files | **44 in src, 69 tree-wide** | **AT ITS FLOOR** -- audited line by line 2026-09-16; measure with `build/Count-LivePChar.ps1`, never a raw grep |
| pointer truncation -- casts | 2 named P0s | 4 sites, 2 units | **0** | **DONE** |
| pointer truncation -- **handles in 32-bit storage** | not in the source doc | **not measured** | **0** (4 fixed) | **DONE** |
| live `asm` blocks | "much disabled… confirm each" | 0 | **0** | **DONE** |
| `Move`/`FillChar`/`ZeroMemory` | not in the source doc | 348 (no command; not reproducible) | **387 live** (319 `src`, 68 tests) | **TRIAGED 2026-09-18** -- measure with `build/Count-LiveMove.ps1`; routed per owner in the P0 section below, 4 defects found |
| **toolchain** | i386 only | i386/win32 | **x86_64-win64 BUILDS** | **compiler done; OpenSSL x64 owed** |

### The truncation row had a second class, and the first scan could not see it

The original measurement looked for **casts** -- `Pointer(Integer(x))`,
`Pointer(Cardinal(x))` -- found four, fixed them, and reported DONE. That was
honest for what it asked. It could not find this:

```pascal
  tCW_Event        : Cardinal;      (* assigned from CreateEvent *)
  tCWPaddle_Event  : Cardinal;
  tDVP_Event       : Cardinal;
  procedure tCWSleep(millsec, myEvent: Cardinal);   (* myEvent is a HANDLE *)
```

**A handle STORED in a 32-bit variable has no cast to find.** Measured with
FPC 3.2.2: `System.THandle` and `TThreadID` are 8 bytes on Win64 and 4 on
Win32, `Cardinal` is 4 on both -- so these were correct on i386 by coincidence
and lose the top 32 bits of every event handle on Win64. Silently: the handle
is simply invalid, every wait on it fails, and CW/paddle/DVP timing stops with
no exception and nothing in the log.

It surfaced only because ONE of the four is passed where a pointer-sized
argument is required (`logdvp.pas:769`), so the compiler had to object. The
other three would have been found on a bench.

**Every other handle site in the tree was already correct** --
`module: THandle`, `GHamLibModule: TLibHandle`, `FreeThread/ThreadId:
TThreadID`, `tCreateThread: TThreadID`, uYCCCSO2R's events. 17 assignment
sites checked; 4 were wrong and all 4 were in `logk1ea`.

**A NAIVE SCAN FOR THIS PRODUCES FALSE POSITIVES AND MUST NOT BE SHIPPED AS A
LINT.** Matching a variable NAME against its declaration anywhere in the tree
flagged `H: integer` in `MainUnit` (a rectangle HEIGHT) and `h: integer` in
`uRadioPolling` (a panel slot, documented as such). A scope-aware version is
owed; a name-matching one would be ignored within a week.

**Progress log.** Every step green on 35 lints, the unit tests AND the golden
corpus -- the corpus matters for this work specifically, because `fcontest`,
`cfgdef` and `logdom` build the CTY.DAT, TRMASTER, DOM and log file names that
all thirteen sets open.

| commit | what | PChar after |
|---|---|---:|
| `b10dc8fa` | the four pointer truncations (P0) | 578 |
| `733ce377` | `SetCharBuffer` / `CharBufferText`, 14 file-name sites | 578 |
| `043657a8` | the ShortString-as-buffer idiom, 6 sites | 570 |
| `c51dcc1d` | **the C-sprintf facade deleted** -- 21 overloads, every caller | **412** |
| `9d627433` | the three C `long` types become `clong` (not a 64-bit item) | 412 |
| `7a5a69d6` | VC.pas scalar constants; the `HeaderTagText` facade deleted | 396 |
| `9ded98f7` | `FirstCall` passed as the ShortString it is | **384** |
| `0ed6bad6..07b07d45` | **the x64 build**: toolchain pairing, handle widths, per-arch DLLs | 384 |
| `b2b0ddde` | raw pointers out of every Format argument, plus `Lint-FormatArgs` | 384 |
| `63c1e046` | the band map spot list becomes a dynamic array | 384 |
| `d44e4aba..3aa3f580` | **the C-string shim**: 60 call sites -> 4 | **362** |

---

## DONE — check off

- [x] **§4, remaining live x86 assembly.** **Zero** live `asm` blocks under
  `src/`. The eradication finished before this plan was written; the source
  document was right to suspect the raw search was mostly commented history.
  Guard: `build/Count-LiveAsm.ps1` and the agent memory `asm-eradication-done`.

- [x] **The `uCFG.pas` entry in the P0 PChar row.** 7 live mentions, down from
  a table of 415 rows whose `crCommand` was `PAnsiChar` and whose `crAddress`
  was a bare pointer. `CFGCA`, `CFGRecord`, `CommandsArraySize` and all four
  positional side tables are deleted (2026-09-14), along with every pattern arm
  in `CheckCommand`. What is left is `CheckCommand`'s own `PAnsiChar`
  signature and the ShortString reads around it.

- [x] **The `VC.pas` spelling-table item, partially.** `tr4wColorsSA` is a
  `string` array (2026-09-14), which removed six `string(AnsiString(...))`
  double casts; ten more tables went the same way on 2026-09-13. `VC.pas` is
  still 34, so the row stays open — but the *pattern* is established and the
  remaining tables follow it.

## NOT NECESSARY — document and drop

- [x] ~~**Replace the Win64 LPT loader name with the verified InpOut x64
  DLL**~~ (§6) and ~~**`uIO.pas` in the P1 dependency row**~~.
  **THE PARALLEL PORT IS GONE FROM TR4W** (2026-09-13, NY4I: *"I have
  reconsidered on LPT ports. You can remove all references to them in the
  code"*). `src/uIO.pas` is deleted and there are **0** `InpOut` references in
  the tree. This was the last binding that needed elevation and the last that
  was Windows-only by nature; there is no x64 DLL to verify because nothing
  loads one. The CAPABILITIES stayed — a YCCC box does radio switching and
  stereo over OTRSP — so only the transport went.

- [x] ~~**`uIO.pas` in the "26 LoadLibrary/GetProcAddress sites" audit**~~ —
  same reason.

## OPEN — in the order they should be done

### ~~P0 — four pointer truncations~~ — DONE (`b10dc8fa`)

- [x] **`uHamLibDirect`, 3 sites — DELETED, not widened.** `PAnsiChar(Integer(rig) + PATHNAME_OFFSET)`
  and `PInteger(Integer(rig) + TIMEOUT_OFFSET)` — writing into Hamlib's
  **private** `RIG` structure at hard-coded i386 offsets. Delete
  `RigSetPathname`, `RigGetPathname` and `RigSetTimeout`; `uRadioHamLibDirect`
  already configures pathname, speed, timeout and CI-V address through
  `rig_set_conf`, which is the public API. **Do not "fix" the offsets with
  `NativeInt`** — the layout can change with Hamlib's own version, packing or
  compiler, so a correct-width wrong-offset write is worse than a compile
  error.
- [x] **`tr4wserverUnit:1346`, 1 site — an indexed walk now,** with
  `TestRecordArrayStrideIsOneRecord` pinning the stride on both architectures.
  `Pointer(Cardinal(RescoredRXData) + SizeOfContestExchange)` narrows the
  record pointer to 32 bits on every step of the rescore walk. A typed
  `^ContestExchange` array with an index encodes the stride and the bounds;
  `NativeUInt` merely avoids the truncation. Add a rescore test that touches
  more than one record.

**These four are the whole of it.** A comment-aware scan for
`Pointer(Integer(`, `Pointer(Cardinal(` and `X(ident) +` over `src` and
`tr4wserver` finds ten hits, and six are `GetSCPCharFromInteger(X) + ...` in
`logscp` — string concatenation, not casts.

### P0 — the PChar-family removal: DONE, at 44 in `src` (was 578)

Do it as behaviour-preserving slices with tests, never a global replace:
`PChar` is wide under this tree's Unicode mode and `PAnsiChar` is byte text, so
a mechanical swap changes both encoding and ownership.

**THE FAÇADE IS GONE (`c51dcc1d`)** — 21 `Format` overloads and every caller.
`TF.pas` was 176 of the 578, thirty percent in one unit, and that is what took
the count to 412.

It removed three latent bugs that were not the target: `PAnsiChar` of a
TEMPORARY (four sites), a pointer into a ShortString's characters still live in
the QTC **sender**, and a message formatted into a global buffer and read back
one line later.

**One rule had to be MEASURED because it goes on the air.** The QTC formats use
`%.4u` because `wsprintfA` zero-padded and QTC 7 must send as `0007`. FPC reads
a precision on an integer as a minimum digit count padded with zeros:

    SysUtils.Format('%.4u', [7])  ->  '0007'
    SysUtils.Format('%04u',  [7])  ->  '   7'

so every format string carried over unchanged. The `%04u` variants beside them
were inside a comment block; live, converting them would have put the wrong CW
on the air.

**WHAT IS LEFT IN `TF.pas` IS A DIFFERENT SHAPE.** `inttopchar` and the
date/path helpers still RETURN a `PAnsiChar` into a shared global buffer, so
this slice cannot be "replace the body" — the callers have to stop wanting a
pointer first.

**RE-MEASURED 2026-09-14 — the `TF.pas` row below said ~76 and was wrong; it
is 28.** That figure was carried over from before the façade deletion instead
of being re-counted. Run the comment-aware scan rather than quoting this table
after it has sat for a day.

| unit | live | note |
|---|---:|---|
| `MainUnit.pas` | 26 | |
| `postunit.pas` | 21 | Cabrillo/ADIF writers |
| `TF.pas` | 28 | façade GONE; what remains returns a PAnsiChar into a shared global |
| `uctydat.pas` | 21 | CTY.DAT parsing — real byte work, may keep bounded byte arrays |
| `VC.pas` | 18 | was 34; the scalar constants are done, the spelling TABLES and record fields remain |
| `uHamLibDirect.pas` | 14 | a real C ABI boundary; was 20 before the three offset helpers went |
| `logdvp.pas`, `tr4wserverUnit.pas`, `tree.pas` | 15 each | |

#### The C-string shim: 60 call sites -> 0, AND THE UNIT IS DELETED (2026-09-15)

`uAnsiStr` is gone. Eight of its nine routines had no caller left --
`StrLen`, `StrIComp`, `StrPCopy`, `StrLCopy` and `AppendToBuffer` outright;
`StrComp` because `utils_text` had its own (itself deleted later the same day,
with no production caller); `StrPos`
because only its own tests did. The ninth, `StrPLCopy`, had three sites in
`tr4wserver`, and they are `utils_text.SetCharBufferBytes` now -- a byte-exact
write, NOT `SetCharBuffer`, because one of the three is the multi-op server
password and re-encoding it would change the wire format.

`LclText` -- the one routine in that unit that had nothing to do with C
strings -- moved to `utils_text`, where the tests can reach it.


Every `StrPCopy` / `StrPLCopy` / `StrLCopy` writing a fixed buffer, every
`StrLen` reading one, and both `strpos` searches are gone. The helpers that
replaced them -- `SetCharBuffer`, `CharBufferText`, `CharBufferSlice`,
`CompareCharBuffer` -- now live in `utils_text` **and have tests**, which they
never had in `TF`: that unit pulls the LCL and the config model in behind it,
so it is not in `tr4w_unit_tests.lpr` and none of this could be exercised.

**The four that remained are all done (2026-09-15) -- and three were not what this table said:**

| where | what it turned out to be |
|---|---|
| `uctydat` ReplaceCountry | the "suspected defect" recorded here was WRONG. `@r.Name[1]` steps past the `!` marker the caller has just tested, which is correct. The real defect was the other side: `@ID[1]` on a `string[5]`, which over-reads a five-character id such as `*GM/s`. Fixed in b56e1ef9 -- whose test also found that a CTY.DAT reload wrote past the end of the country table |
| `uctydat` ctyLoadInCountryFile | the REMAINING MULTS search. A note claimed it could not work because `StrPos` resolved to the WideChar variant; it did work, and a test now proves it. Rewritten over an AnsiString in 63c92678 |
| `uctydat` custom-country list | the same routine's `StrComp(@ID[1], ...)` -- the same ShortString over-read. Also 63c92678 |
| `uMessagesList` | the pointer walk is gone; the parser walks a string (see the unit's own note) |

**AND ONE RULE CAME OUT OF THIS THAT IS NOT OBVIOUS.** The CTY prefix table
could NOT be converted to string comparison: uCTYDAT runs over buffers
holding CP1251/CP1250, so
`CharBufferText` (UTF-8) would decode bytes that are not UTF-8 and change
which prefixes match. `CompareCharBuffer` keeps the unsigned byte order and
drops only the pointers -- and is pinned in `uTestUtilsText` by explicit
expected signs, including a CP1251 `$C0` sorting above `Z`. (It was pinned
against `StrComp` until that routine was deleted, with no production caller.)

**Byte data stays bytes. What goes is the pointer arithmetic.** That is NY4I's
rule at the top of this document, and this is the first place it decided the
answer rather than merely describing it.

#### What the VC.pas slice found, which generalises

**FIVE OF THE TWELVE SCALAR CONSTANTS WERE DEAD** — `_RESTARTBIN`, `_LOGFILE`,
`_COM`, `LATEST_CONFIG_FILE` and `OPERATORINFO` were declared and read nowhere
in the tree. Count the callers before converting; deleting beats converting.

**AND THE CONSTANT WAS OFTEN NOT THE PROBLEM.** `CABRILLOSECTION`,
`ERMAKSECTION` and `_COMMANDS` were already wrapped in `string(...)` at EVERY
use site — a pointer created so it could be immediately converted back. The
same held one level up: `uCabrilloHeader.HeaderTagText`'s `aSection`/`aTag`
were `PAnsiChar` only because these constants were, and its three live callers
each spelled out

    if HeaderTagText(SECTION, '_TAG', buf, SizeOf(buf)) > 0 then
       s := string(buf)
    else
       s := '';

which is `HeaderValue(SECTION, '_TAG')` in eleven lines. Both it and
`SetHeaderTagText` (no callers at all) are deleted. **Follow the pointer up to
the function that takes it — the constant is usually the symptom.**

#### THE NARROWING TRAP THIS SLICE HIT, WHICH WILL RECUR

Converting `TWO_STRINGS: PAnsiChar = '%s%s'` to `string` pushed narrowing to
1367 against a ceiling of 1365. The cause is worth knowing because every
format-string constant has it:

> **`SysUtils.Format` has exactly ONE overload** —
> `Function Format(Const Fmt: String; const Args: Array of const): String`
> (`rtl/objpas/sysutils/sysstrh.inc:151`) — and SysUtils is compiled WITHOUT
> `{$MODESWITCH UnicodeStrings}`, so that `String` is an **AnsiString**. FPC
> 3.2.2 ships no UnicodeString counterpart.

So a `string` format constant narrows **at the argument**, before Format runs.
`LclText` cannot fix it for the same reason. The answer is to declare a format
string `AnsiString` — the type its one consumer takes — which converts nothing
and still removes the pointer. **The ceiling did not have to move.**

### P0 — no `Move` / `FillChar` / `ZeroMemory`: COUNTED AND TRIAGED (2026-09-18)

Not in the source document; added because byte I/O being legitimate does not
make `Move` legitimate (NY4I, 2026-09-14). Expect three outcomes per site, and
the split matters more than the count:

1. **A record or buffer clear** → initialise the fields, or use a typed record
   that starts zeroed.
2. **A string copy** (`Move(src[1], dst[1], n)`) → plain assignment. The
   compiler converts and truncates correctly; the pointer version has already
   caused two crashes with no exception text.
3. **Genuine byte framing** (CI-V, Yaesu binary, the network records) → a
   `TBytes` or `array of Byte` with indexing. The bytes stay exact; what goes
   is the address arithmetic.

**THIS TRIAGE ROUTES THE WORK. IT CONVERTS NOTHING.** Each conversion belongs
to the specialist who owns the file, and the `owner` column below is the
routing.

#### The count, and its command

```powershell
.\tr4w\build\Count-LiveMove.ps1            # per file, per routine, raw vs live
.\tr4w\build\Count-LiveMove.ps1 -Detail    # every line, to triage from
.\tr4w\build\Count-LiveMove.ps1 -SelfTest  # the fixture alone
```

| measured 2026-09-18 | calls | files |
|---|---:|---:|
| **live** (comments and string literals stripped) | **387** | 92 |
| of which `src` | 319 | 75 |
| of which tests and test tools | 68 | 17 |
| raw word-bounded grep, same files and names | 740 | 175 |

By routine: `FillChar` 279, `Move` 108 (`System.Move` counts as `Move`).
`ZeroMemory`, `CopyMemory`, `MoveMemory`, `RtlMoveMemory` and friends are
**zero live** — every one of them is in a comment. They are counted anyway so a
new one shows up instead of hiding.

**THE 348 / 347 THIS SECTION CARRIED CANNOT BE REPRODUCED**, and neither can
the roadmap's "~376 raw". Neither had a command beside it, and no Move counter
existed when they were written. The raw grep reports nearly double
(740 against 387), for the reason `Count-LivePChar.ps1` records: this tree
describes its conversions in comments.

The counter uses `PascalSource.psm1` with the new `-BlankStrings` switch, so
`'Move failed'` in a log message is not a call. It does not count `List.Move`
(a method), `MoveTo`, `MoveWindow` or `OnMouseMove`. **It refuses to report a
tree number** unless its built-in fixture (six live calls among comment,
string, method and look-alike traps) counts exactly six, and unless the scan
found `src\MainUnit.pas`. A counter that matched nothing would otherwise report
a clean zero.

`StrPCopy`, `StrPLCopy` and `StrLCopy` are **not** counted here. They copy into
a character buffer, which makes them the PChar audit's concern: remove the
buffer and the call goes with it.

#### What the sites turned out to be

| category | calls | what it becomes |
|---|---:|---|
| (a) record / buffer clear | **253** | `:= Default(T)` for a record, `:= ''` for a ShortString, nothing where the next line overwrites it |
| (b) string copy | **11** | assignment, or `SetString` at a real API boundary |
| (c) genuine byte framing | **57** | `TBytes` with indexing, `Copy`, `Concat`, `Delete` |
| (d) list / queue shift | 19 | `Delete` / `Insert` on a dynamic array, or a `TList` |
| (d) Win32 / C API struct | 13 | **keep**, at the boundary, behind `{$IFDEF WINDOWS}` |
| (d) sentinel fill in a test | 9 | **keep**: a non-zero fill shows what a routine left untouched |
| (d) same-typed array copy | 8 | plain `:=` |
| (d) dead code | 6 | delete |
| (d) type pun | 4 | `Chr(Ord(x))`, or a range-checked enum cast |
| (d) bulk numeric / pixel copy | 4 | `Copy()`, a ring index, or `TLazIntfImage` |
| (d) deliberate layout overlay | 3 | a decision for the log owner, not a mechanical change |

**The expected split did not hold.** String copies are 11 calls, not a
large share: two thirds of the work is (a), and most of that is mechanical.

| owner | calls | (a) | (b) | (c) | (d) |
|---|---:|---:|---:|---:|---:|
| radio-factory | 69 | 30 | 0 | 28 | 11 |
| log-database | 62 | 58 | 1 | 0 | 3 |
| contest-scoring | 59 | 55 | 0 | 0 | 4 |
| file-formats | 52 | 36 | 0 | 0 | 16 |
| multi-op-network | 37 | 18 | 4 | 13 | 2 |
| lcl-ui | 22 | 15 | 2 | 0 | 5 |
| utils (no specialist; tests only) | 21 | 12 | 0 | 0 | 9 |
| settings-config | 15 | 12 | 1 | 0 | 2 |
| cw-keying | 13 | 4 | 0 | 4 | 5 |
| integrations | 10 | 6 | 2 | 2 | 0 |
| serial-port-io | 9 | 3 | 0 | 1 | 5 |
| tci-interface | 9 | 0 | 0 | 9 | 0 |
| dx-cluster | 7 | 4 | 1 | 0 | 2 |
| build-release | 2 | 0 | 0 | 0 | 2 |

#### DEFECTS FOUND BY THE TRIAGE — fix these first, they are not style

These came out of reading each site, not out of a compiler. None of them
fails a build. **Each one should get its fix and a pin test in the owner's
own commit.**

**ALL FOUR FIXED 2026-09-18 (5.0.8)**, each by its owning specialist, and the
descriptions below are kept as the record of what was wrong:

| # | fix | proof |
|---|---|---|
| 1 | `Delete(GClusterQueue, 0, 1)` | heaptrc on the exact pattern: 6 unfreed blocks for 6 events → 0 |
| 2 | the `FillChar` deleted; the per-field clears already covered every path | new leak test failed before (+128,000 bytes / 500 parses), passes after |
| 3 | not patched — **deleted**: the queue had no reader since `3b9cbf33`, so the Icom arm, the model check, the three buffer fields, `AddCommandToBuffer` and `BufToStr` went | the app builds; a radio with no factory object now gets the existing "not sent" error instead of a silent drop |
| 4 | `SetCharBuffer(CurrentOperator, ...)`, the prompt limit raised to `High(CurrentOperator)`. The defect was the **missing terminator** (`W1ABCD` over `VP2E/W1ABC` read back as `W1ABCD1ABC`); a 7+ character call was never truncated, it could not be typed | `Test_SetCharBuffer_OperatorLogin` |

1. **`uTelnet.pas:944-950` — EVERY CLUSTER EVENT LEAKS ITS TEXT.** (dx-cluster)
   `ev := GClusterQueue[0]` takes a counted reference to `Text: AnsiString`;
   the `Move` then overwrites slot 0's pointer **without releasing it**, so
   the count never returns to zero. With one event queued, the `FillChar` of
   slot 0 drops it the same way. The comment beside it guards the double
   free correctly and misses the leak. One string per queued event, which
   means every cluster line, for the whole session. Fix: `Delete(GClusterQueue, 0, 1)`, which finalises
   properly. Confirm with a `-gh` (heaptrc) run of a cluster replay.
2. **`uFlexDiscovery.pas:158` — `FillChar` OVER FIVE `string` FIELDS.**
   (radio-factory) `ParsePacket` is called on every received packet with the
   same `Parsed` record (line 263), so each call zeroes five live string
   pointers without releasing them. The fix is deletion: the six assignments
   after it already clear the record.
3. **`uProcessCommand.pas:433, 460, 488, 516` — AN UNBOUNDED COPY INTO A
   41-BYTE BUFFER THAT NOTHING READS.** (radio-factory) `scFileName` is a
   `ShortString` (up to 255), and `CommandsTempBuffer` is
   `array[0..40] of AnsiChar` inside `RadioObject`. Any SRS argument over 40
   characters writes past it into the rest of the object. `AddCommandToBuffer`
   then copies into `CommandsBuffer`, **which no code anywhere reads** — its
   consumer went with the legacy poller on 2026-08-02. The `Move` at
   `logradio.pas:1501` also starts at the length byte, so it would have
   dropped the last character. Reachable only when an Icom has no factory
   object. Fix: delete the branch and the buffers, and log instead.
4. **`MainUnit.pas:5583, 5595` — THE OPERATOR IS ALWAYS 6 BYTES.** (lcl-ui;
   the value goes on the wire through `uNet.pas:983`) `Move(TempCallstring[1],
   CurrentOperator, 6)` copies into an 11-byte `OperatorType`: a 7+
   character call such as `DL1ABCD` is silently truncated, and a 6-character
   call after a longer one gets **no terminator**, so the old seventh
   character reappears. The same value is logged with every QSO
   (`logdupe.pas:1576`). **Inherited, not a port regression**: D7 has the
   identical `Windows.CopyMemory(@CurrentOperator, @TempCallstring[1], 6)`
   (`C:\TR4W\tr4w\src\MainUnit.pas:4121`). Fix:
   `SetCharBuffer(CurrentOperator, TempCallstring)`, the bounded helper
   `LogCfg.pas:564` already uses on this exact field.

**Latent: harmless today, and wrong in shape.** `FillChar` over a managed
type. Each is safe only because the target happens to start nil:

- `uLogStore.pas:364` — `TLogEntryDeclaration`, eleven `AnsiString`s, as a
  function `Result`. FPC may hand the caller's own variable in as `Result`.
- `uLogImport.pas:111` — `TLogImportResult.Message: string`, same shape.
- `uLogGrid.pas:1077` — a local `array of string`, already nil'd by the
  compiler.
- `uTestRadioStatus.pas:266` — `RadioObject` holds three `string` fields.

Write all four as `:= Default(T)`, or delete them.

**Checked and NOT defects**, so nobody spends time on them again: every Icom
LAN decode is length-guarded (`uIcomNetworkTransport.pas:954` by its
dispatcher at 886); the `logname` shifts use the right multiplier for each
element type; `uKeychainWindows.pas:276` is correct because that unit is
UnicodeStrings; `uSuperCheckPartialFileUpload.pas:224` is correct because that
unit is `-Mdelphi` AnsiString. **That last pair is the trap for a `(b)`
conversion:** the right `SetString` depends on which string type the unit
compiles with, and neighbouring units differ.

#### THE CONTRACT IS THE ENCODING: the `ENC` and `BYTES` flags

**101 calls are flagged `ENC`.** Their bytes leave the process: a packed
record sent raw (`TStationState`, `TParameterToNetwork`, `TIntercomMessage`,
`TSendSpotViaNetwork`, the Icom LAN packets), or a `ContestExchange`, which
`tr4wserver` still writes raw to its log. **Changing the type is free.
Changing the bytes is a compatibility decision** for the owner.

The hazard is concrete, and it hides inside an innocent-looking (a):

- `r := Default(T)` for a **whole record** is expected to match today's
  `FillChar(r, SizeOf(r), 0)` byte for byte: every byte zero, including
  padding and ShortString tails. Pin that with a test that compares bytes
  before relying on it.
- `r.Field := ''` for a **ShortString field** is **not** the same. It writes
  the length byte and leaves the tail as it was, so on a record sent raw,
  stale bytes from the previous content go on the wire. That changes the
  encoding, and it can leak the previous QSO's text to another station.

**5 calls are flagged `BYTES`.** `RadioStatusRecord` is compared by raw byte
scan (`uRadioPolling.pas`, `CurrentStatus` against `PreviousStatus`), so its
clear must stay a whole-record zero. A per-field initialisation leaves padding
unset and turns into phantom status changes.

#### Every live site

Grouped by owner. Every line the counter reports appears exactly once;
coverage was checked mechanically against `Count-LiveMove -Detail`
(387 of 387).

| owner | file | lines | cat | flag | reasoning |
|---|---|---|---|---|---|
| build-release | `src/GetWinVersionInfo.pas` | 230 | d API struct |  | `OSVERSIONINFO` copied into the `...EX` prefix -- Win32-only version probe |
| build-release | `test/integration/uSimProcess.pas` | 101 | d API struct |  | `TStartupInfo` for `CreateProcess` -- bench harness, already on the roadmap as an ungated `uses Windows` |
| contest-scoring | `src/MainUnit.pas` | 923, 978 | a |  | probe `ContestExchange` local -> `:= Default(ContestExchange)` |
| contest-scoring | `src/MainUnit.pas` | 6956, 6989, 7078 | a | ENC | ShortString fields of `var RData` (`ParametersOkay`) |
| contest-scoring | `src/MainUnit.pas` | 7393 | a |  | `DupeInfoCall` -> `:= ''` |
| contest-scoring | `src/MainUnit.pas` | 8623, 8624, 8642, 8643 | a | ENC | QTH fields of the rescored exchange (`tUpdateLog`) |
| contest-scoring | `src/MainUnit.pas` | 8978 | a |  | `RestartInfo` (all 4-byte counters) -> `Default()` |
| contest-scoring | `src/trdos/fcontest.pas` | 1867, 1880 | a |  | `CallString` -> `:= ''` |
| contest-scoring | `src/trdos/logdom.pas` | 211, 212 | a |  | `Str10` -> `:= ''` (the comment beside each already says so) |
| contest-scoring | `src/trdos/logdupe.pas` | 613 | a |  | `ContestExchange` -> `Default()` |
| contest-scoring | `src/trdos/logdupe.pas` | 1073, 1074, 1075, 1083, 1098 | a |  | totals arrays and the QTC table |
| contest-scoring | `src/trdos/logstuff.pas` | 1041 | a |  | QTC table |
| contest-scoring | `src/trdos/logstuff.pas` | 1430, 1432, 1446, 1447, 1473, 1475 | a | ENC | ShortString fields of `RXData` |
| contest-scoring | `src/trdos/logstuff.pas` | 1440, 1441, 3246, 6751, 6752, 6757, 6765, 10175, 10181 | a |  | ShortString locals -> `:= ''` |
| contest-scoring | `src/trdos/logstuff.pas` | 1886, 4188 | a |  | probe `ContestExchange` -> `Default()` |
| contest-scoring | `src/trdos/logstuff.pas` | 3245, 9969, 10002, 10043 | a |  | parser records and scratch buffer -> `Default()` |
| contest-scoring | `src/trdos/logstuff.pas` | 10020 | d array copy |  | same-typed `array[0..31] of AnsiChar` -> `prStrings[i] := TmpBuf` |
| contest-scoring | `src/trdos/logwae.pas` | 143 | a |  | redundant: assigned on the next line; the `13` is a magic `SizeOf(CallString) - 1` |
| contest-scoring | `src/trdos/logwae.pas` | 281 | a |  | QTC send table |
| contest-scoring | `src/uCallsigns.pas` | 359 | d list shift |  | list insert; item is ShortString-only so the shift is safe -> a dynamic array or `TList` |
| contest-scoring | `src/uCallsigns.pas` | 363, 683 | a |  | new list slot / dupe bits |
| contest-scoring | `src/uMults.pas` | 111, 112, 113 | a |  | mult arrays -> `Default()` |
| contest-scoring | `src/uQTCR.pas` | 338 | a |  | `ContestExchange` -> `Default()` |
| contest-scoring | `src/uQTCS.pas` | 307 | a |  | `ContestExchange` -> `Default()` |
| contest-scoring | `src/uSortedStringList.pas` | 143 | a |  | `TotalMults` is a public integer field (the property is commented out) -> `TotalMults := 0` |
| contest-scoring | `src/uSortedStringList.pas` | 156, 250 | d list shift |  | list delete/insert; ShortString-only items, safe |
| contest-scoring | `src/uSortedStringList.pas` | 254, 305 | a |  | new slot / dupe bits |
| cw-keying | `src/trdos/LogSend.pas` | 371 | a |  | `ContestExchange` -> `Default()` |
| cw-keying | `src/trdos/logdvp.pas` | 595, 642, 718 | a |  | DVP message table / buffer / `DXMultiplierString` |
| cw-keying | `src/uWinKey.pas` | 616, 738 | c |  | `TBytes` read -> fixed global buffers; the globals are what goes |
| cw-keying | `src/uWinKey.pas` | 1117 | c |  | untyped `const Buffer` -> `TBytes`; take `TBytes` at the call |
| cw-keying | `src/uYCCCSO2R.pas` | 348 | c |  | HID report buffer |
| cw-keying | `src/uYCCCSO2R.pas` | 466, 476, 496, 548, 549 | d API struct |  | SetupAPI / HID / `OVERLAPPED` structs -- Windows-only transport |
| dx-cluster | `src/uDXSpotParse.pas` | 223, 918 | a |  | line buffer / `TSpotRecord` |
| dx-cluster | `src/uDXSpotParse.pas` | 231 | b |  | bounded copy of the line into a char buffer |
| dx-cluster | `src/uSpots.pas` | 640 | a |  | `TSpotRecord` result |
| dx-cluster | `src/uTelnet.pas` | 945, 949 | d list shift | **DEFECT** | **queue pop over a record holding an `AnsiString`** -- see defects |
| dx-cluster | `src/uTelnet.pas` | 1861 | a |  | `TSpotRecord` |
| file-formats | `src/MainUnit.pas` | 8353, 8358, 8413 | a |  | `CallString` locals in the callsign-list generators |
| file-formats | `src/MainUnit.pas` | 10113 | a |  | a `MAX_PATH` char buffer the next line fills; the global buffer is the artifact, not the clear |
| file-formats | `src/trdos/logname.pas` | 463, 467, 545, 549, 625, 629, 640, 644, 664, 668, 679, 683 | d list shift |  | insert/delete shifts in the name-database arrays; byte counts checked -- x2 `TwoBytes`, x1 `BYTE`, x4 `FourBytes` |
| file-formats | `src/trdos/logscp.pas` | 1446, 3285 | a |  | `DataBaseEntryRecord` / `CellBufferObject` (no VMT) |
| file-formats | `src/trdos/postunit.pas` | 553, 1184, 1341, 1354, 1839, 1840, 2022, 3196, 3382 | a |  | report totals; the pointer derefs size the POINTEE correctly |
| file-formats | `src/trdos/tree.pas` | 1220, 1230 | d type pun |  | enum -> `Char` by copying one byte -> `Chr(Ord(Band))` |
| file-formats | `src/trdos/tree.pas` | 2883, 2896 | d type pun |  | `Byte` -> enum by copying one byte -> a range-checked `BandType(b)` |
| file-formats | `src/uADIF.pas` | 1181 | a |  | `ContestExchange` -> `Default()` |
| file-formats | `src/uLogBinaryFile.pas` | 173, 219, 292 | a |  | `TQSOTime` / header / record before a full `ReadBuffer` |
| file-formats | `src/uctydat.pas` | 634, 970, 1227 | a |  | CTY tables / `QTHRecord` |
| file-formats | `src/uctydat.pas` | 969 | a |  | fills with **-1** (`$FF` bytes -> `Smallint` -1): a loop, not `Default()` |
| file-formats | `test/tools/ctygen/ctygen.lpr` | 72 | a |  | `QTHRecord` |
| file-formats | `test/unit/uTestADIF.pas` | 816, 830, 841, 855, 867, 880, 892 | a |  | `TQSOTime` fixtures |
| file-formats | `test/unit/uTestADIFExchange.pas` | 65 | a |  | `ContestExchange` fixture |
| file-formats | `test/unit/uTestADIFRegression.pas` | 69 | a |  | `ContestExchange` fixture |
| file-formats | `test/unit/uTestCTYDAT.pas` | 851 | a |  | `QTHRecord` fixture |
| file-formats | `test/unit/uTestCabrilloExchange.pas` | 74 | a |  | `ContestExchange` fixture |
| file-formats | `test/unit/uTestLogBinaryFile.pas` | 203 | a |  | `TQSOTime` fixture |
| integrations | `src/uDXLabPathfinder.pas` | 237 | a |  | char buffer |
| integrations | `src/uMMTTY.pas` | 283, 316 | a |  | callsign / call-process state |
| integrations | `src/uMMTTY.pas` | 284 | b |  | bounded by the `cpPos in [3..8]` gate at 266 |
| integrations | `src/uSuperCheckPartialFileUpload.pas` | 224 | b |  | stream -> `AnsiString` (unit is `-Mdelphi`, not UnicodeStrings) -> `SetString` |
| integrations | `src/uSynTime.pas` | 300 | c |  | NTP request; `SetLength` on a fresh local already zeroes it -- the fill is redundant |
| integrations | `src/ui/lcl/uMMTTYForm.pas` | 292 | a |  | `MMTTYObject` (no managed fields) |
| integrations | `src/utils/uSHA256.pas` | 111, 229 | a |  | hash state / padding block |
| integrations | `src/utils/uSHA256.pas` | 201 | c |  | block assembly: byte-level by definition; index rather than walk `p^` |
| lcl-ui | `src/MainUnit.pas` | 5572, 5703 | a |  | `CallString` local -> `:= ''` |
| lcl-ui | `src/MainUnit.pas` | 5583, 5595 | b | **DEFECT** | **hardcoded 6 bytes** into an 11-byte `OperatorType` -- see defects |
| lcl-ui | `src/trdos/logwind.pas` | 1244, 3025, 3713 | a |  | ShortString locals -> `:= ''` |
| lcl-ui | `src/uDialogs.pas` | 111 | a |  | `MAX_PATH` buffer for a Win32 file dialog -- goes with the dialog (`TOpenDialog.FileName`) |
| lcl-ui | `src/uStations.pas` | 427 | d list shift |  | queue pop -> `Delete(GStatusQueue, 0, 1)`; the item is unmanaged, so this one is safe today |
| lcl-ui | `src/ui/lcl/uInputQueryForm.pas` | 171, 172 | a |  | ShortString globals -> `:= ''` |
| lcl-ui | `src/ui/lcl/uLogGrid.pas` | 1077 | a | LATENT | `FillChar` over an `array of string`, harmless only because the local starts nil -- delete |
| lcl-ui | `src/ui/lcl/uLogGrid.pas` | 1232 | a |  | `TTextStyle` -> `style := Canvas.TextStyle`, the LCL way |
| lcl-ui | `src/ui/lcl/uPanadapterForm.pas` | 654, 1066 | d bulk copy |  | `Single` array copy -> `Copy()` |
| lcl-ui | `src/ui/lcl/uPanadapterForm.pas` | 937 | d bulk copy |  | overlapping in-place scroll of the dB history; a ring index removes it |
| lcl-ui | `src/ui/lcl/uPanadapterForm.pas` | 986 | d bulk copy |  | pixel rows via `ScanLine` -> `TLazIntfImage` / `CopyRect` |
| lcl-ui | `src/ui/lcl/uQTCReceiveForm.pas` | 365, 366, 367 | a |  | arrays of `TEdit` references -> `Default()` |
| lcl-ui | `src/ui/lcl/uQTCSendForm.pas` | 404, 405 | a |  | arrays of control references -> `Default()` |
| log-database | `src/MainUnit.pas` | 3734 | a | ENC | note record before `AddRecordToLogAndSendToNetwork` -> `Default()` |
| log-database | `src/domain/uLogNote.pas` | 64, 93 | d layout overlay | ENC | the note text lives in the bytes FROM `Prefix` onward -- a deliberate layout overlay, pinned by `uTestLogNote` |
| log-database | `src/domain/uLogNote.pas` | 83 | a | ENC | clears the same overlay region |
| log-database | `src/trdos/logedit.pas` | 680, 936 | a |  | `ContestExchange` -> `Default()` |
| log-database | `src/trdos/logedit.pas` | 1589, 1645 | a |  | `CallString` result -> `Result := ''` |
| log-database | `src/uEditQSO.pas` | 379, 384, 473, 486, 518, 540, 545, 548, 551, 555, 562, 571, 579, 586, 592, 597, 611, 617, 627, 635, 643, 651, 682 | a | ENC | ShortString / char fields of the edited QSO, cleared before re-parse |
| log-database | `src/uEditQSO.pas` | 690 | b | ENC | bounded copy of the operator into its char field |
| log-database | `src/uLogImport.pas` | 111 | a | LATENT | **record holds `Message: string`** -- see defects |
| log-database | `src/uLogRepository.pas` | 1289, 2112, 2138, 2156 | a | ENC | row -> `ContestExchange` mapper -> `Default()` |
| log-database | `src/uLogSource.pas` | 449, 495 | a | ENC | as above |
| log-database | `src/uLogStore.pas` | 364 | a | LATENT | **record of eleven AnsiStrings** -- see defects |
| log-database | `src/uLogStore.pas` | 1785, 1786 | a |  | ShortString locals |
| log-database | `test/unit/uTestLogNote.pas` | 63, 84, 88, 103, 117, 128, 140 | a |  | test fixtures |
| log-database | `test/unit/uTestLogNote.pas` | 86 | d layout overlay |  | writes through the overlay on purpose, to test it |
| log-database | `test/unit/uTestLogRepository.pas` | 351, 407, 441, 496, 539, 618, 684, 735, 784, 841, 1007, 1132 | a |  | test fixtures |
| multi-op-network | `src/MainUnit.pas` | 5210 | a | ENC | `Str80` inside `TIntercomMessage`, sent raw |
| multi-op-network | `src/tr4wserverUnit.pas` | 539 | a |  | clears a record from its 2nd field by `SizeOf - 4` to keep `clSerialNumber`; assign the fields |
| multi-op-network | `src/tr4wserverUnit.pas` | 1087 | a |  | integer array |
| multi-op-network | `src/uNet.pas` | 636, 846, 1193 | a | ENC | `TStationState` slots -- a record sent raw |
| multi-op-network | `src/uNet.pas` | 786 | c |  | pending bytes -> the legacy `NetBuffer` global the parser reads; the global is what goes |
| multi-op-network | `src/uNet.pas` | 828 | d list shift |  | drop consumed bytes from the front of a `TBytes` -> `Delete(GNetPending, 0, used)` |
| multi-op-network | `src/uNet.pas` | 869 | c |  | append a read to the pending `TBytes` -> `Concat`/`Insert` |
| multi-op-network | `src/uNet.pas` | 901 | a |  | integer array |
| multi-op-network | `src/uNet.pas` | 934 | a | ENC | `ssName` of the wire record |
| multi-op-network | `src/uNet.pas` | 937, 977 | b | ENC | bounded copy of a string into a fixed char field of the wire record |
| multi-op-network | `src/uNet.pas` | 983 | d array copy | ENC | same-typed `OperatorType` arrays -> `ssOperator := CurrentOperator` |
| multi-op-network | `src/uNet.pas` | 1023 | b | ENC | CW message into the wire record; bounded by its `string[CWMessageToNetworkLength]` type |
| multi-op-network | `src/uNet.pas` | 1582, 1583 | a | ENC | ShortStrings inside `TParameterToNetwork`, sent raw |
| multi-op-network | `src/uNetClient.pas` | 148 | c | ENC | password frame; the clear matters because `Result` is managed -> `Result := nil; SetLength(Result, 10)` |
| multi-op-network | `src/uNetClient.pas` | 153, 157 | c | ENC | password bytes onto the wire |
| multi-op-network | `src/uNetClient.pas` | 321 | c |  | decode the ack; length-guarded |
| multi-op-network | `src/uNetClient.pas` | 419 | c |  | untyped `aBuf` -> `TBytes`; take `TBytes` at the call |
| multi-op-network | `src/uProcessCommand.pas` | 775 | a | ENC | `Str80` in the intercom wire record |
| multi-op-network | `src/uServerNet.pas` | 258, 295, 305 | c |  | connection buffer -> the global `ServerBuffer` the legacy parser reads |
| multi-op-network | `src/uServerNet.pas` | 366, 407, 512 | c |  | `TIdBytes` read -> fixed `FBuf`; each read is bounded by `SizeOf(FBuf)` |
| multi-op-network | `src/ui/lcl/uSendSpotForm.pas` | 178 | a | ENC | `vnMessage` of the wire record |
| multi-op-network | `src/ui/lcl/uSendSpotForm.pas` | 186 | b | ENC | bounded copy into the wire record |
| multi-op-network | `src/ui/lcl/uServerLogForm.pas` | 191 | a |  | totals array |
| multi-op-network | `test/unit/uTestNetFraming.pas` | 114, 132, 158, 179, 194 | a |  | test buffer |
| radio-factory | `src/radioFactory/uFlexDiscovery.pas` | 158 | a | **DEFECT** | **five `string` fields** -- see defects |
| radio-factory | `src/radioFactory/uIcomScope.pas` | 909 | a |  | clear a reused `TBytes` -> `Levels := nil; SetLength(...)` (zeroed) |
| radio-factory | `src/radioFactory/uIcomScope.pas` | 964 | c |  | sweep bytes into the level array; bounded by `room` |
| radio-factory | `src/radioFactory/uK4Spectrum.pas` | 303, 318 | c |  | framer ring: compact, then append |
| radio-factory | `src/radioFactory/uK4SpectrumThread.pas` | 235 | c |  | `TIdBytes` -> `TBytes` chunk |
| radio-factory | `src/radioFactory/uRadioHamLibDirect.pas` | 1166, 1176, 1212, 1238, 1272, 1284, 1328, 1348, 1369 | a |  | `THLCommand` -> `Default()` |
| radio-factory | `src/radioFactory/uRadioIcomBase.pas` | 660 | a |  | band-memory integer array |
| radio-factory | `src/rotatorFactory/uRotatorAlfaSpid.pas` | 92 | c | ENC | rotator frame; `Result` is managed -> `Result := nil; SetLength(Result, 13)`. No rotator specialist; nearest owner |
| radio-factory | `src/trdos/logradio.pas` | 914 | d dead code | DEAD | `BufToStr` has **no caller** anywhere -- delete it |
| radio-factory | `src/trdos/logradio.pas` | 1501 | d dead code | DEAD | writes `CommandsBuffer`, which **nothing reads** -- see defects |
| radio-factory | `src/uIcomNetworkDiscovery.pas` | 79 | a | ENC | wire packet -> `Default()`; reserved bytes must stay zero |
| radio-factory | `src/uIcomNetworkDiscovery.pas` | 86 | c | ENC | packed record -> bytes |
| radio-factory | `src/uIcomNetworkDiscovery.pas` | 136 | c | ENC | bytes -> packed record; length-guarded |
| radio-factory | `src/uIcomNetworkTransport.pas` | 554, 1361, 1407, 1432, 1475, 1507, 1540, 1613, 1636, 1662 | a | ENC | outgoing packet -> `Default()`; reserved bytes must stay zero |
| radio-factory | `src/uIcomNetworkTransport.pas` | 570, 1463, 1495, 1527, 1601, 1625, 1648, 1670 | c | ENC | packed record -> wire bytes |
| radio-factory | `src/uIcomNetworkTransport.pas` | 793 | a |  | IP octets |
| radio-factory | `src/uIcomNetworkTransport.pas` | 854, 869 | c |  | `TIdBytes` -> `array of Byte` |
| radio-factory | `src/uIcomNetworkTransport.pas` | 888, 954, 1064, 1106, 1145, 1169, 1178, 1234, 1386, 2120 | c | ENC | wire bytes -> packed record; every one is length-guarded (954 by its dispatcher at 886) |
| radio-factory | `src/uIcomNetworkTransport.pas` | 1193, 1491, 1523, 1558, 1564 | d array copy | ENC | MAC / GUID byte arrays -> array assignment, or a typed MAC field |
| radio-factory | `src/uProcessCommand.pas` | 433, 460, 488, 516 | d dead code | **DEFECT** | **unbounded copy into a 41-byte buffer that nothing reads** -- see defects |
| radio-factory | `src/uRadioPolling.pas` | 826, 827 | a | BYTES | status snapshot -> `Default()`; MUST stay a whole-record zero, the pair is compared by raw byte scan |
| radio-factory | `test/unit/uTestK4Spectrum.pas` | 624 | c |  | fixture bytes |
| radio-factory | `test/unit/uTestRadioStatus.pas` | 62, 121, 122 | a | BYTES | `RadioStatusRecord` fixtures (byte-compared; keep whole-record zero) |
| radio-factory | `test/unit/uTestRadioStatus.pas` | 266 | a | LATENT | `RadioObject` holds three `string`s; harmless only because the local starts nil |
| serial-port-io | `src/ComPortEnumerator.pas` | 310, 648, 658, 679, 703 | d API struct |  | SetupAPI / `DEV_BROADCAST` struct zeroed before `cbSize` is set -- a real Win32 boundary; keep, spell it `:= Default(T)` |
| serial-port-io | `src/ComPortEnumerator.pas` | 515, 558, 559 | a |  | `WideChar` out-buffers the API overwrites; the clear is redundant, the buffer belongs inside the Windows branch |
| serial-port-io | `src/uSerialPort.pas` | 344 | c |  | read buffer -> `TBytes` result; read straight into the result instead |
| settings-config | `src/trdos/LogCfg.pas` | 554 | d array copy |  | same-typed `TFreqMemoryType` arrays -> `FreqMemory := DefaultFreqMemory` |
| settings-config | `src/uCFG.pas` | 578, 579 | a |  | ShortString key/value -> `:= ''` |
| settings-config | `src/uKeychainWindows.pas` | 226 | d API struct |  | `CREDENTIALW` -- Win32 credential API |
| settings-config | `src/uKeychainWindows.pas` | 276 | b |  | UTF-16 blob -> `string` (unit is UnicodeStrings, so the byte count is right) -> `SetString(aValue, PWideChar(...), chars)` |
| settings-config | `src/uNewContest.pas` | 497, 498 | a |  | as above |
| settings-config | `src/uRadioConfigApply.pas` | 833, 834, 1141, 1142, 1184, 1185, 2071, 2072 | a |  | as above |
| tci-interface | `src/uWebSocketClient.pas` | 359, 379 | c |  | byte copies between `TIdBytes` and `TBytes` |
| tci-interface | `src/uWebSocketFraming.pas` | 410, 443 | c |  | fragment reassembly -> `Concat` / `Copy` |
| tci-interface | `src/uWebSocketServer.pas` | 306, 363 | c |  | as above |
| tci-interface | `test/unit/uTestWebSocketFraming.pas` | 144, 148, 183 | c |  | fixture concatenation / fake reader |
| utils (none) | `test/unit/uTestFormatTranslation.pas` | 100, 107, 120, 130 | a |  | test buffer |
| utils (none) | `test/unit/uTestFreqTimeFormat.pas` | 45 | a |  | `SYSTEMTIME` fixture |
| utils (none) | `test/unit/uTestUtilsText.pas` | 592, 599, 616, 623, 627, 669, 675, 684, 689 | d sentinel fill |  | deliberate NON-zero fill (`$7F`, `'Z'`) so a test can see what a routine left untouched -- keep |
| utils (none) | `test/unit/uTestUtilsText.pas` | 693, 712, 713, 765, 766, 782, 783 | a |  | test buffers |

### P1 — everything downstream of a toolchain

- [x] ~~Install an FPC with `ppcx64`/Win64 RTL and a Lazarus LCL~~ — **IT WAS
  ALREADY INSTALLED, TWICE.** `C:\lazarus\fpc\3.2.2` and `C:\fpcupdeluxe\fpc`
  both carry `ppcx64` with a Win64 RTL, and both Lazarus installs carry an
  x86_64-win64 LCL. Nothing had to be provisioned; the plan was blocked on a
  belief.
- [x] **`Find-Toolchain.ps1` — and the real defect was not what this line
  said.** It never "treated x86_64 as categorically invalid": it found a
  toolchain and built. It chose FPC and Lazarus **independently**, so on a
  machine with three FPCs and two Lazaruses it paired fpcupdeluxe's compiler
  with `C:\Lazarus`'s LCL and produced

      Recompiling LCLIntf, checksum changed for
         C:\fpcupdeluxe\fpc\units\x86_64-win64\rtl\system.ppu
      Fatal: Can't find unit LCLIntf

  **which is the macOS failure, verbatim, on Windows** — see the agent memory
  `mac-build-machine`, where it was diagnosed as missing provisioning. It now
  picks a PAIR and PROVES it by compiling a two-line unit that uses LCLIntf:
  0.19s for a good pair, 0.05s for a bad one.
- [x] **The widget set is not the OS.** `Get-SearchPaths.ps1` built
  `lcl\units\$cpu-$os\$os`, which is right for `i386-win32\win32` only
  because the OS name and the widget-set name are the same string there.
  `x86_64-win64\win64` does not exist; the LCL's Windows interface is `win32`
  for both bitnesses.
- [x] Architecture-specific output directories — `build-out/app-x86_64-win64`
  shares no `.ppu`, `.o` or staged DLL with `app-i386-win32`. DLLs come from
  `tr4w/redist/<cpu>-<os>`; only `i386-win32` reads `tr4w/target`.
- [ ] **x64 OpenSSL 1.0.2 — `libeay32.dll` and `ssleay32.dll`. THE ONLY THING
  STANDING BETWEEN THE BUILD AND A STAGED x64 BINARY.** SQLite 3.53.4 and the
  full HamLib 4.7.0 set (including `libgcc_s_seh-1.dll`, which REPLACES the
  32-bit `libgcc_s_dw2-1.dll`) are staged and PE-verified. The build names the
  two missing files explicitly and refuses to stage a partial set.
- [ ] Assert the PE machine type in a TEST, not only in the build's report.
- [ ] Wire and persisted layouts: `ContestExchange`, `TLogHeader`,
  `uNetFraming`. Assert field widths and offsets; decide explicitly whether a
  Win32 and a Win64 peer may talk to each other.

---

## The ordering rule, which is the most important line in the source document

> *"using `NativeInt` to make old PChar/offset code compile would turn obvious
> compile failures into architecture-dependent memory bugs."*

Remove the pointer arithmetic **before** moving pointer width, not after. A
compile error is a gift; a silently-wrong offset is a bench session.
