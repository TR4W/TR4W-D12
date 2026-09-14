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

| gate | source doc | measured 2026-09-14 | state |
|---|---|---|---|
| PChar-family in live code | 751 raw mentions | **578** in 69 files | open |
| pointer truncation | 2 named P0s | **4 sites, 2 units** | open, small |
| live `asm` blocks | "much disabled… confirm each" | **0** | **DONE** |
| `Move`/`FillChar`/`ZeroMemory` | not in the source doc | **348** | open (new rule) |
| toolchain | i386 only | `fpc -iTP` = i386, `-iTO` = win32 | open |

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

### P0 — four pointer truncations, two units

- [ ] **`uHamLibDirect`, 3 sites.** `PAnsiChar(Integer(rig) + PATHNAME_OFFSET)`
  and `PInteger(Integer(rig) + TIMEOUT_OFFSET)` — writing into Hamlib's
  **private** `RIG` structure at hard-coded i386 offsets. Delete
  `RigSetPathname`, `RigGetPathname` and `RigSetTimeout`; `uRadioHamLibDirect`
  already configures pathname, speed, timeout and CI-V address through
  `rig_set_conf`, which is the public API. **Do not "fix" the offsets with
  `NativeInt`** — the layout can change with Hamlib's own version, packing or
  compiler, so a correct-width wrong-offset write is worse than a compile
  error.
- [ ] **`tr4wserverUnit:1346`, 1 site.**
  `Pointer(Cardinal(RescoredRXData) + SizeOfContestExchange)` narrows the
  record pointer to 32 bits on every step of the rescore walk. A typed
  `^ContestExchange` array with an index encodes the stride and the bounds;
  `NativeUInt` merely avoids the truncation. Add a rescore test that touches
  more than one record.

**These four are the whole of it.** A comment-aware scan for
`Pointer(Integer(`, `Pointer(Cardinal(` and `X(ident) +` over `src` and
`tr4wserver` finds ten hits, and six are `GetSCPCharFromInteger(X) + ...` in
`logscp` — string concatenation, not casts.

### P0 — the PChar-family removal, 578 live in 69 files

Do it as behaviour-preserving slices with tests, never a global replace:
`PChar` is wide under this tree's Unicode mode and `PAnsiChar` is byte text, so
a mechanical swap changes both encoding and ownership.

**`TF.pas` is 176 of the 578 — 30% in one unit**, and it is the legacy C-string
façade the source document calls out: `Format` overloads, `inttopchar`, the
date/year/path helpers, the buffer walkers. Retiring it is the single biggest
slice and the one with the most callers.

| unit | live | note |
|---|---:|---|
| `TF.pas` | 176 | the C-string façade — do this first |
| `postunit.pas` | 36 | Cabrillo/ADIF writers |
| `VC.pas` | 34 | remaining spelling tables |
| `MainUnit.pas` | 29 | |
| `uAnsiStr.pas` | 28 | **delete the unit** once its callers are gone; it is a second string library |
| `uctydat.pas` | 21 | CTY.DAT parsing — real byte work, may keep bounded byte arrays |
| `uHamLibDirect.pas` | 20 | a real C ABI boundary; shrinks once the three helpers above go |
| `logdvp.pas`, `tr4wserverUnit.pas`, `tree.pas` | 15 each | |

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
