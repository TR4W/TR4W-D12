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

| gate | source doc | first measure | now | state |
|---|---|---|---|---|
| PChar-family in live code | 751 raw mentions | 578 in 69 files | **396** | in progress |
| pointer truncation | 2 named P0s | 4 sites, 2 units | **0** | **DONE** |
| live `asm` blocks | "much disabled… confirm each" | 0 | **0** | **DONE** |
| `Move`/`FillChar`/`ZeroMemory` | not in the source doc | 348 | **347** | open (new rule) |
| toolchain | i386 only | i386/win32 | i386/win32 | open |

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
| `9d627433` | the three C `long` types become `clong` (not a 64-bit item -- see below) | 412 |
| _this one_ | VC.pas scalar constants; the `HeaderTagText` facade deleted | **396** |

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

### P0 — the PChar-family removal, 396 live (was 578)

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
| `postunit.pas` | 36 | Cabrillo/ADIF writers |
| `MainUnit.pas` | 29 | |
| `uAnsiStr.pas` | 28 | **delete the unit** once its callers are gone; it is a second string library |
| `TF.pas` | 28 | façade GONE; what remains returns a PAnsiChar into a shared global |
| `uctydat.pas` | 21 | CTY.DAT parsing — real byte work, may keep bounded byte arrays |
| `VC.pas` | 18 | was 34; the scalar constants are done, the spelling TABLES and record fields remain |
| `uHamLibDirect.pas` | 14 | a real C ABI boundary; was 20 before the three offset helpers went |
| `logdvp.pas`, `tr4wserverUnit.pas`, `tree.pas` | 15 each | |

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

### P0 — no `Move` / `FillChar` / `ZeroMemory`, 348 sites (NY4I, 2026-09-14)

Not in the source document; added because byte I/O being legitimate does not
make `Move` legitimate. Expect three outcomes per site, and the split matters
more than the count:

1. **A record or buffer clear** → initialise the fields, or use a typed record
   that starts zeroed. Most of the 348.
2. **A string copy** (`Move(src[1], dst[1], n)`) → plain assignment. The
   compiler converts and truncates correctly; the pointer version has already
   caused two crashes with no exception text.
3. **Genuine byte framing** (CI-V, Yaesu binary, the network records) → a
   `TBytes` or `array of Byte` with indexing. The bytes stay exact; what goes
   is the address arithmetic.

### P1 — everything downstream of a toolchain

- [ ] Install an FPC with `ppcx64`/Win64 RTL and a Lazarus LCL for
  `x86_64-win64`. **Nothing below can start until this exists** — and note the
  macOS box is currently blocked on exactly this class of problem (two
  incomplete FPC installs), so verify the LCL matches the RTL before trusting
  it.
- [ ] `build/Find-Toolchain.ps1` to describe the requested `$Cpu-$Os` rather
  than treating x86_64 as categorically invalid.
- [ ] Architecture-specific output directories — `build-out/app-x86_64-win64`
  must share no `.ppu`, `.o` or staged DLL with `app-i386-win32`.
- [ ] x64 `sqlite3.dll` and the Hamlib dependency closure, with the PE machine
  type asserted in a test rather than only reported to the operator.
- [ ] Wire and persisted layouts: `ContestExchange`, `TLogHeader`,
  `uNetFraming`. Assert field widths and offsets; decide explicitly whether a
  Win32 and a Win64 peer may talk to each other.

---

## The ordering rule, which is the most important line in the source document

> *"using `NativeInt` to make old PChar/offset code compile would turn obvious
> compile failures into architecture-dependent memory bugs."*

Remove the pointer arithmetic **before** moving pointer width, not after. A
compile error is a gift; a silently-wrong offset is a bench session.
