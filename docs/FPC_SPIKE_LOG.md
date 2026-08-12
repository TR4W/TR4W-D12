# FPC spike log

**Branch:** `fpc-spike`, from `config-json` at `76cea17a`.
**Run:** 2026-08-12.
**Rule observed:** nothing in `tr4w/src` was edited. Every `{$IFDEF FPC}` added to force a pass is
a result thrown away, so the numbers below are what the tree actually is.

---

## Step 0 — ground truth

| | |
|---|---|
| Lazarus | 4.8 (NY4I's install, `C:\lazarus`) |
| **FPC** | **3.2.2** — the *stable* release |
| Compiler | `fpc\3.2.2\bin\x86_64-win64\ppcx64.exe` |
| Target OS / CPU | **win64 / x86_64 only** — no 32-bit cross-compiler installed |

Two consequences fall straight out of that last row, before a line is compiled:

- **The only available target is 64-bit.** TR4W is a Win32 program, and D12 explicitly scoped 64-bit
  out. So this spike is *incidentally* also a 64-bit portability test — which is what a macOS
  (Apple Silicon) leg would force anyway, just arriving earlier than planned.
- **x86-32 inline assembly cannot assemble at all** on this compiler.

---

## Step 2 — anonymous methods: **NOT SUPPORTED. This is the blocker.**

Run before the bulk compile precisely so the answer would not be buried, and it was the right call.

```pascal
type TIntProc = reference to procedure(v: integer);
```
```
probe_anon.pas(9,15) Error: Identifier not found "reference"
probe_anon.pas(9,25) Fatal: Syntax error, ";" expected but "TO" found
```

Not a semantic difference — **the syntax is not recognised**. §9 item 1 is therefore settled, and it
settles the opposite way to the first reading: the fpc-announce (May 2022) note is real, but it
describes work in the FPC **development** branch (3.3.x). Lazarus 4.8 ships **3.2.2 stable**, which
does not have it.

**Blast radius: 7 units, and they are the newest and most deliberate code in the tree** —
`uRadioRegistry`'s self-registration closures, `TProcessMsgRef`, `uRotatorControl`'s per-rotator send
closure, `uSettingsRegistry`'s `Own` constructors (which depend specifically on closures capturing a
*variable*, not a value).

Three ways out, none free:

1. **Use an FPC 3.3.x development build.** Gets the feature, at the cost of standing a ten-year
   project on a non-stable compiler — and the contributor argument for Lazarus is partly *about*
   stability and availability.
2. **Rework the 7 units** to interface-based or method-pointer callbacks. Mechanical, testable, and
   arguably an improvement in its own right — but it is real work on the code most recently written.
3. **Wait for the release that carries it.** Unknown date; not a plan.

---

## Step 1 — inline assembly: fails, as expected

`uCRC32.pas` alone: **50 errors**, stopping at the limit.

```
uCRC32.pas(70,16) Error: Invalid reference syntax
uCRC32.pas(71,1)  Error: Unrecognized opcode
uCRC32.pas(72,14) Error: Unknown identifier "EAX"
```

x86-32 assembly against an x86_64 compiler. **Not a finding that changes anything** — the asm is
already slated for eradication under either toolchain, and `uCRC32`/`utils_text` are the two `asm`
units in the test set that are *already covered by tests*, so replacing them is verifiable
byte-exact. They remain the cheapest first move regardless of the toolchain decision.

---

## Step 3 (partial) — what the portable core actually hits

Sampled rather than run whole, because the anonymous-method blocker stops the full project and the
plan forbids editing `src` to get past it.

| Unit | Result |
|---|---|
| `uRadioBand`, `utils_text`, `uDXSpotParse`, `uCallSignRoutines` | all fail identically: cannot load `VC` |
| `VC.pas` itself | **3 errors, all one idiom** |
| `uSettingsRegistry` | `Can't find unit System.SysUtils` |

### The `VC.pas` result is the good news of this spike

Three errors in a 5,000-line unit that is the type foundation of the whole program, and all three
are the *same* construct — a typed-constant record field declared `PChar` being initialised from a
character-array constant:

```pascal
{mweOpMode} (mweName: 'OP MODE'; ... mweText: CQPChar ; ...)
```
```
VC.pas(774,114) Error: Incompatible types: got "Array[0..2] Of Char" expected "PChar"
```

Delphi converts implicitly here; FPC 3.2.2 does not. **Mechanical, three sites, no design
implication.** For the single most Delphi-shaped file in the tree, that is a much better result than
expected.

### Dotted unit names

`System.SysUtils`, `System.Classes` and friends are not resolvable as written. Affects the modern
`u*` units specifically. Well-trodden ground with known mechanisms (unit aliasing / namespace
support), so: **mechanical, but it touches many files** — the cost is breadth, not difficulty.

---

## The string model — and a correction to everything above

NY4I asked whether FPC's native string format differs from Delphi's. It does, measurably, and it
**partially invalidates the runtime reach of this spike**:

| | `SizeOf(s[1])` | `string` is |
|---|---:|---|
| **Delphi 12** | 2 | `UnicodeString` (UTF-16) |
| **FPC `{$MODE DELPHI}`** | **1** | `AnsiString` (8-bit) |
| **FPC `{$MODE DELPHIUNICODE}`** | 2 | `UnicodeString` — matches Delphi |

Everything above was compiled with `-Mdelphi`, which silently redefines every `string` in the tree
from UTF-16 to 8-bit. **The compile-time findings stand** — anonymous methods, asm and the `VC.pas`
idiom do not depend on string width — **but no runtime conclusion may be drawn from that mode**, and
none was, because nothing ran.

### Which mode is right for TR4W is a real decision, not a formality

**`{$MODE DELPHIUNICODE}` — semantics identical to D12.** Lowest migration risk: `string` keeps the
width every line of the tree was written against. Cost: it fights Lazarus, whose LCL is UTF-8 based,
so every UI boundary converts.

**`{$MODE DELPHI}` — 8-bit `string`, idiomatic for Lazarus.** Arguably the better *destination* for
this codebase specifically. The D12 port spent much of its effort fighting UTF-16: the
`GetPrivateProfileString` W-binding that wrote UTF-16 into an `AnsiChar` buffer and made TR4WServer
reject every client, the `PAnsiChar(AnsiString(...))` double-cast audit, the "generic Win32 name
binds to W" trap that no linter can see. That entire class of defect largely evaporates in a byte
world — and the 451 `ShortString` sites, the fixed-column spot parsers and the byte-diffed
ADIF/Cabrillo artifacts all belong to a byte world already.

Cost: flipping `string` from 2 bytes to 1 across 152k lines changes the meaning of `Length`, every
index and every buffer size, and the compiler will mostly not say so. The `src/lang` per-language
codepages (1251/1250/1252) also become live again rather than settled — though `{$CODEPAGE}`, which
Delphi rejects with `E1030`, becomes usable.

**The good news is that this is testable rather than arguable.** The golden corpus byte-diffs ADIF
and Cabrillo across 13 real logs; a string-width error shows up there as a diff, not a shrug. When
the spike gets far enough to run, it should run **both modes** and compare — that comparison is
worth more than either result alone.

---

## Where this leaves the decision

The spike did its job: it converted the last technical unknown into a fact, and the fact is
inconvenient.

**Findings ranked by what they cost:**

1. **Anonymous methods — a genuine blocker on FPC stable.** Not a papercut. Either a development
   compiler or a rework of the 7 newest units. *This is the number the decision needs.*
2. **Dotted unit names — broad but shallow.** Many files, each trivially.
3. **`VC.pas` — three sites, one idiom.** Encouraging.
4. **Inline asm — already committed to removing.** Costs nothing extra.

**What has NOT been established, and must not be inferred from the above:** whether the tests
*pass*. Nothing has run. Everything here is compile-time. The runtime questions the spike was really
for — `ShortString` semantics, `AnsiString` codepage behaviour, the config-file tests' line endings —
are all still open, and they are the ones that fail quietly rather than loudly.

**Honest read.** This does not kill the Lazarus option, but it removes the "and the technical risks
mostly dissolved" comfort from the SWOT's §9 summary. The anonymous-method gap lands on exactly the
code written to make the config and factory work elegant. It is worth pricing option 2 (rework the
7 units) explicitly, because unlike option 1 it produces something the project keeps whichever
toolchain wins.

---

## The rework, priced — `uRotatorControl` + the rotator factory

Done rather than estimated, per the plan. **Result: all 7 rotator units compile clean under
FPC 3.2.2, and Delphi still builds with 3,795 tests passing and no behaviour change.**

| Change | Files | Notes |
|---|---:|---|
| 5 anonymous factory functions → named unit-level functions | 5 | None captured anything; scripted |
| `TRotatorSendProc`: `reference to` → `of object` | 1 | One line |
| `TRotatorFactoryProc`: `reference to` → plain procedure pointer | 1 | One line |
| The one real capture site → a method on `TLiveRotator` | 1 | + a `forward` for `SendToRotator` |
| 2 test closures → a `TWireProbe` object | 1 | |
| `System.` prefixes dropped | 8 files, 10 sites | see below |

**Roughly half an hour, ten files, zero behaviour change.**

### Two findings worth more than the time saved

**The rework improved the code.** `TRotatorSendProc` as `of object` *names the owner* of the state
instead of implying it, and `live.SendBytes` says what the anonymous method's comment had to explain
— that each driver's bytes reach **its own** rotator's port. The registry's factory closures captured
nothing at all, so the anonymous form was buying nothing. This is work worth doing whichever
toolchain wins.

**The dotted-unit-name problem is not a problem.** `tr4w.dproj` already declares `System` as a unit
scope (`<DCC_Namespace>System;…`), so **`uses SysUtils` compiles under Delphi too**. Dropping the
`System.` prefixes satisfies both compilers with **no `{$IFDEF}` anywhere**. FPC's `-FN` flag does
*not* help — it resolves short names to namespaced units, the opposite direction — so the fix is the
source sweep, and the sweep is free. That reclassifies the second-largest category in this log from
"broad but shallow" to "broad and trivial, one mechanical pass".

### What this implies for the other 6 anonymous-method units

`uRotatorControl` was the smallest, so this is a floor rather than an average. The two shapes seen
here cover most of what the others do:

- **Captures nothing** → a named function. Free. (The radio registry's self-registration closures
  look like this.)
- **Captures one object** → a method on that object. Cheap, and clearer.

`uSettingsRegistry` is the one that will not follow the pattern: its `Own` constructors deliberately
capture a *one-element dynamic array* to give a setting storage of its own, with no object to hang a
method on. That needs a small holder class — still mechanical, but it is the one place where the
closure was carrying real design weight rather than convenience. **Price that one next**, not the
easy ones.

1. **Price the rework.** Convert one unit — `uRotatorControl` is the smallest — from a closure to an
   interface or method pointer, and measure. One data point beats an estimate.
2. **Then re-run Step 3** with those 7 units addressed, and get to an actual `PASSED: n FAILED: m`.
   Until a test has *run*, this spike has proved nothing about behaviour.
3. **Only then** Linux and macOS (Steps 5–6). Compiling on Windows first keeps the variables
   separate, and there is no point moving platforms while the dialect question is open.
4. Check whether a 3.3.x build changes item 1, but treat "requires a development compiler" as a
   finding in its own right, not a workaround.
