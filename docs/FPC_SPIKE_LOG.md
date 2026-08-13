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

## The hard one, priced -- `uSettingsRegistry`

The unit flagged as the one that would NOT follow the easy pattern, because its `Own` constructors
capture a one-element dynamic array specifically to give a setting storage with no object behind it.

**Result: compiles clean under FPC 3.2.2 (815 lines). Delphi still builds. 3,795 tests pass.**
**About 45 minutes**, including two self-inflicted mis-steps -- a duplicated `type` keyword, and one
scripted replacement that silently no-op'd because its pattern was not converted to CRLF.

| Change | Detail |
|---|---|
| `TFunc<T>` / `TProc<T>` -> 6 method-pointer types | `TBoolGetter`, `TBoolSetter`, ... |
| `TProc` (`OnApply`) -> `TSettingApplyProc` | `procedure of object` |
| 3 cell classes | `TBoolCell`, `TIntCell`, `TStringCell` -- ~45 lines |
| `TSettingBase` owns its cell | `FOwnedCell` + destructor + `OwnCell` -- ~15 lines |
| 4 `Own` bodies rewritten | 3 lines each |
| Test globals -> `TSettingsProbe` | ~40 references, scripted |
| `RegisterLegacySetting` | **no change** -- `TLegacySetting` was already a class |

### The captured array was a cell object with the object left out

That is the whole finding. `Own` held a one-element array so the closure had something outliving the
call -- which is a cell object missing its object. Putting the object back gives the same lifetime
and the same single value, and now there is something a method pointer can point at. The setting
owns the cell it creates, so a self-storing setting still cleans up after itself exactly as the
captured array did.

**This is a better design than the closure**, for the same reason the rotator change was: it names
the owner of the state instead of implying it. That `RegisterLegacySetting` needed no change at all
is the confirmation -- the parts of this unit that were already objects were already portable.

### Revised estimate for the remaining 5 units

Both priced units came in cheap AND improved the code, and they were deliberately the smallest and
the hardest. Three shapes now cover everything seen:

- **captures nothing** -> a named function (free)
- **captures one object** -> a method on it (cheap, clearer)
- **captures a value with no owner** -> a cell object (cheap, clearer)

The remaining five -- the radio registry's self-registration closures, `TProcessMsgRef`, and the
`uSettingsBinding` / `uSettingsDeclarations` call sites -- are all the first two shapes.
**Estimate: half a day for the lot**, and the result is code worth having under Delphi.

**The anonymous-method blocker should be struck from the risk list.** It was the #1 technical risk in
the SWOT; measured twice, it is a day of mechanical work that improves the design.

## Cross-compilation -- measured, and then made moot

The installed FPC has `ppcx64.exe` only, `x86_64-win64` units only, and no cross binutils: **it
cannot cross-compile anything today.** Adding a target needs three things, and only the first is
FPC's -- a cross-compiler binary, cross binutils, and the target's system libraries.

- **Linux from Windows: practical.** glibc/crt objects are freely redistributable and `fpcupdeluxe`
  automates the chain.
- **macOS ARM from Windows: the worst available path.** It needs Apple's licence-restricted SDK
  copied off a Mac, a Mach-O linker, and signing -- Apple Silicon will not execute an unsigned
  binary, and `codesign` is macOS-only.
- **A GUI app is harder than the spike.** Cross-compiling the test suite is the easy case: a console
  program with no widget dependencies. The eventual Lazarus app additionally needs the target's GUI
  libraries (GTK dev files, Cocoa frameworks). A successful cross-compile of the spike would NOT
  prove the app cross-compiles.

**Made moot 2026-08-12:** NY4I has self-hosted CI runners for **macOS, Windows, Linux and Raspberry
Pi**. So the answer is native builds per platform, no cross toolchain, no SDK smuggling, no signing
gymnastics -- and the spike's Linux/macOS legs have somewhere to run as soon as the Windows leg is
green. Build the toolchain nobody has to assemble.

**The RPi runner is worth noting on its own:** ARM Linux desktop is a target Delphi does not reach at
all, FMX Linux or not. It is the first item in this whole exercise that moved TOWARD Lazarus on
capability rather than governance.

## STEP 4 REACHED -- TR4W tests RUN under FPC

```
FPC 3.2.2 :  PASSED: 111  FAILED: 0
Delphi 12 :  PASSED: 111  FAILED: 0     (same two suites)
```

`spike/fpc_tests.pas` is a reduced driver linking the RotatorFactory and
SettingsRegistry suites -- the two whose dependencies are proven to compile. It
uses **the same source files the Delphi build uses**: no forked copies, no
conditional defines added to force a pass.

**Identical counts, not merely "it ran".** This is the first behavioural evidence
in the exercise; everything before it was compile-time.

### What it does and does not prove

**Does:** the test framework, the rotator factory and the settings registry
behave identically on a different compiler, a different string model
(`-Mdelphi` = 8-bit `string`) and a different word size (x86_64 vs Win32).
That last point is quietly significant -- these suites are the first TR4W code
proven to work as **64-bit**.

**Does not:** touch the contest engine, `ShortString`-heavy code, the fixed-column
parsers, or anything doing file or byte I/O -- which is where the string-model
risk actually lives. 111 assertions out of 3,795.

### The closure work is finished

Every anonymous method in `tr4w/src` is gone. The only `reference to` / `TFunc<`
/ `TProc<` matches remaining are the comments explaining their removal.

| Site | Converted to | Sites |
|---|---|---:|
| `TRadioCtor` | plain procedure pointer + named unit-level constructors | **101** |
| `TRotatorSendProc`, `TRotatorFactoryProc` | `of object` / plain pointer | 6 |
| `uSettingsRegistry` getters/setters/`OnApply` | 6 method-pointer types + 3 cell classes | 4 types |
| `uPrefsForm.ForEachNavItem` | `TNavItemVisit = ... of object` + 2 visitor methods | 2 |

Delphi builds throughout; **3,795 tests, 0 failures** after every step.

**Two corrections to this log's earlier estimate**, both in the cheaper
direction:

- **`TProcessMsgRef` was never a closure** -- it is already
  `procedure (sMessage: string) of object`. Listing it among the seven
  anonymous-method users was wrong.
- **The 101 radio registrations were the bulk of the count but the least of the
  work** -- every one captured nothing, so a single scripted pass converted them.
  The estimate of "half a day for the remaining five" was high; it took about an
  hour.

## STEP 6 -- INDY COMPILES. The big dependency risk is retired.

```
FPC 3.2.2, vendored Indy 10.6.3.3, unmodified:
   109,486 lines compiled, 0 errors
```

This was the item that would have forced "bigger changes" (NY4I): Indy carries the
network radios, the DX cluster, TCI's WebSocket transport, the external loggers
and tr4wserver. A failure here meant replacing the networking layer wholesale.

**It did not fail.** The vendored copy already contains FPC support -- 136 `FPC`
references in `IdCompilerDefines.inc` -- and it built with nothing but search
paths. No patching, no upstream swap, no Synapse/lNet migration.

Worth noting against §9 item 4: NY4I's research said the community recommends the
upstream Indy over the RAD-Studio-supplied one. That may still be the right long
-term call, but it is now an *option* rather than a *prerequisite*.

### What stands between here and the whole test suite

With Indy passed, `uFactoryRadioBase` gets as far as **`VC.pas`, which fails on
exactly two lines** -- the same idiom found on day one:

```
VC.pas(774,114)  Incompatible types: got "Array[0..2] Of Char" expected "PChar"
VC.pas(2637,160) Incompatible types: got "Array[0..4] Of Char" expected "PChar"
```

A typed-constant record field declared `PChar`, initialised from a `char` array
constant. Delphi converts implicitly; FPC does not.

**The two are NOT equally easy, and that matters:**

- **`CQPChar` (line 774) is trivial** -- one use, in that record. Replace with a
  literal.
- **`tr4w_ClassName` (line 2637) is not a drop-in.** It is consumed as an ARRAY
  in two other places: `@tr4w_ClassName[3]` (`uAbout`) and
  `CopyMemory(@tr4w_ClassName, ..., length(tr4w_ClassName))` (`uTrayBalloon`).
  Retyping it to `PChar` fixes `VC.pas` and silently breaks the `CopyMemory` --
  `@` would take the address of the pointer, and `length()` of a `PChar` is not
  the string length. **This constant registers the main window class**, so an
  error here means the main window does not create.

  The fix is small (retype, then `tr4w_ClassName` + `StrLen(...)` at the
  `CopyMemory` site, which is arguably a correctness fix in its own right) but it
  is load-bearing Win32 and deserves its own careful pass rather than being
  tacked onto a spike. **Deliberately not done here.**

### Revised risk picture

| Was | Now |
|---|---|
| Anonymous methods -- #1 risk | **Gone.** ~1 hour, improved the design |
| Indy -- would force "bigger changes" | **Gone.** Compiles unmodified |
| Dotted unit names -- broad | **Trivial.** Both compilers take the short form |
| `VC.pas` PChar idiom | **2 sites.** One trivial, one needs care |
| Inline asm | Unchanged -- already slated for removal |
| **String model, `ShortString`, byte I/O** | **Still entirely untested** |

Every *dependency* risk has now been retired. What remains is the one that was
always going to be hardest to see: **runtime behaviour under a different string
model**, which no compile proves and which the golden corpus is the right oracle
for.

## STEP 7 -- `VC.pas` compiles under FPC. The next blocker is the asm.

```
FPC 3.2.2, VC.pas:   9,677 lines compiled, 0 errors
Delphi 12:           full /t:Build green, 3,795 tests, corpus 22/0/4
```

The type foundation of the whole program is now portable, and the change is
smaller than the log predicted: **`tr4w_ClassName` did not need to become a
`PChar`.** Making it a plain string constant satisfies both compilers, because
every consumer wanted a `PChar` all along and the array form only ever worked
through Delphi's implicit decay.

```pascal
tr4w_ClassName = 'TR4W';          // was: array[0..4] of Char = ('T','R','4','W',#0)
```

That sidesteps the trap flagged in step 6 -- retyping to `PChar` would have made
`@tr4w_ClassName` take the address of the *pointer* -- by removing the array
rather than repointing it.

### Two real defects fell out of the two consumer sites

Neither is reachable today, and neither was findable by grep; both surfaced only
because the retype forced the sites to be read.

- **`uAbout.pas` asked OpenGL to read 1,024 bytes** (16 x 16 x RGBA) starting
  three characters into a five-character constant -- a ~1,014-byte overread.
  Dead: `OGLVERSION` is `False`, so the About menu is a `MessageBox`. Now `nil`,
  which is what the call was really getting minus the out-of-bounds read.
- **`uTrayBalloon.pas` moved five raw bytes of UTF-16 into an ANSI field**, so the
  balloon title was `"T"`. A D7-to-D12 port regression: `Char` was `AnsiChar` when
  that line was written. Its two neighbouring copies were unbounded as well --
  a 255-character `Hint` ran **191 bytes past `szTip`** into the rest of the
  global `IconData`. All three are now bounded, NUL-terminating `StrPLCopy`.
  Every caller of this unit is commented out, so this is latent, not live.

### The next blocker is inline assembly, as forecast

With `VC.pas` clear, `uFactoryRadioBase` reaches `utils_text.pas` and stops on
x86-32 asm against an x86_64 compiler (`Unknown identifier "EDI"`, ~50 errors).

**Not a new finding and not a toolchain argument** -- the asm is slated for
removal under either toolchain, and `utils_text` and `uCRC32` are precisely the
two asm units that already have tests, so replacing them is verifiable
byte-exact. They are now also the *only* thing between the spike and a much
larger slice of the suite, which promotes them from "cheapest first move" to
"the next move".

`spike/fpc-compile.ps1` is the harness, checked in so the next measurement is one
command rather than a reconstructed command line.

## STEP 8 -- the inline assembly, counted properly and then removed

### The count was wrong, and wrong in the helpful direction

A raw grep says **40 `asm` blocks across 23 units**. Blanking Pascal comments
first says **19 live blocks across 7 units**; the other 49 hits are text sitting
inside `{ }` or `(* *)`. Two were verified by hand (`LOGK1EA`'s `INT $F1`,
`uCallsigns`' comparison) rather than trusted to the classifier.

That reclassification is the difference between a daunting job and a bounded one.

### Removed so far

| Unit | Blocks | What it was |
|---|---:|---|
| `utils_text` | 2 | `StrComp`, `StrUpper` -- now Pascal, characterization-tested first |
| `uCRC32` | 3 | now the RTL's CRC-32, no algorithm of our own |
| `JCTRL2` | 1 | `asm xor ebx,ebx end;` -- a register clobber with no effect |
| `MainUnit` | 6 | the custom memory manager (below) |
| `BeepUnit` | 2 | PC-speaker port I/O (below) |

`uStrSearch` had already been converted under Issue #997; its only remaining
blocker was `System.AnsiStrings`, and **that is the one dotted name this log got
wrong**. `System.SysUtils` and `System.Classes` drop their prefix because FPC has
`sysutils` and `classes`. FPC has **no `AnsiStrings` unit at all** -- it ships the
classic `strings` instead. Checked in the FPC unit directory, not assumed.
`uStrSearch` now owns the two routines it borrowed and has no uses clause.

### Two things worth more than the assembly they were written in

**The custom memory manager in `MainUnit` never ran and could not have been
right.** Each hook opened with `add esp,12 / pop PreviousProcAddress /
sub esp,16` to reach up the stack for the caller's return address -- assuming the
Delphi 7 frame layout, in a function that also carried a `try/except` whose SEH
record lives on that same stack. Its handler called `wsprintfA` and
`showwarning` from inside a `GetMem` callback that had fired *because allocation
failed*. And `SetNewMemMgr` was only ever called under `{$IF tDebugMode}`, which
is `False`. Deleted.

**`BeepUnit`'s `Sound()` executed privileged instructions.** `IN`/`OUT` on ports
`$42`/`$43`/`$61` fault from user mode on any NT Windows; they last worked on
Windows Me. Nothing supported reached them -- `LOGK1EA`'s two calls sat behind
`WindowsOSversion = VER_PLATFORM_WIN32_WINDOWS`, and `tree.pas`'s `Dit`/`Dah`
were not in that unit's interface and had no callers. Deleted along with the
dead Windows 9x branches, so the sidetone path no longer asks what OS it is on.

**`NoSound` was NOT deleted**, and this is the cautionary half. It has five live
callers, four of them in TRDOS, and they call it **without parentheses** -- so a
`NoSound\s*\(` search finds none of them. Its body was already inside the same
Windows 9x guard, so it has always been a no-op on supported systems; it is now
an explicit one. NY4I's rule earned its keep here: *check that the code is still
referenced, especially in TRDOS.*

### Still open in `BeepUnit`, and it is a decision rather than a translation

`ntBeep` drives `\Device\Beep` by IOCTL. On Windows 10/11 `beep.sys` is commonly
disabled and most machines have no PC speaker, so `CreateFile` fails, `hBeep`
stays invalid, and **every beep silently does nothing**.

`Windows.Beep` is the documented modern replacement and does synthesize through
the sound card -- but it **blocks for the duration**, while the IOCTL returns
immediately and `LOGK1EA` does its own `tCWSleep` afterwards. Swapping it in
would double every CW element. The real answer is a sidetone on its own thread
(waveOut/XAudio2), which is also the only version that survives leaving Win32.

### The count was ALSO wrong because it only looked at `.pas`

`tr4w.dpr` carried one of the largest live blocks in the tree and a `.pas`-only
search missed it entirely (NY4I caught this). `tr4w/build/Count-LiveAsm.ps1` is
now checked in: it blanks comments first and scans `.pas`/`.dpr`/`.dpk`/`.inc`,
so the number is reproducible instead of re-derived by hand each time.

### `tr4w.dpr` -- the four event handles

`CreateEvent` x4 built by hand: push four zeros, call, then `sub esp,16` before
each subsequent call to walk ESP back over stack bytes the stdcall epilogue had
already popped. It worked, but it opened with `mov ebx,0` -- **clobbering EBX
without saving it**, in the startup path, where the compiler may be holding a
local. Same defect shape as the `JCTRL2` one-liner, in live code. It also checked
no result: a failed `CreateEvent` left a 0 handle and every later
`WaitForSingleObject` failed silently forever. Now four Pascal calls and an
error log.

### `MainUnit` is asm-free

`GetCPU` was `db 0fh,31h` -- a raw RDTSC opcode as bytes. Beyond not assembling
64-bit, RDTSC is per-core (a migrating thread can read it going **backwards**)
and its tick rate is not a documented constant. Now `QueryPerformanceCounter`.

`DeviceIoControlHandler` was a **kernel-mode driver dispatch routine pasted into
a user-mode application** -- ~160 lines switching on `IOCTL_READ_PORTS` /
`IOCTL_WRITE_PORTS` with raw LPT base arithmetic. Nothing called it, and it could
not have worked: both `READ_PORT_UCHAR` and `WRITE_PORT_UCHAR` were commented
out, so the read path stored a hard-coded `0`. Real LPT access goes through
DLPortIO/inpout32, which is untouched.

### `DLPortIO` -- an error message that had already rotted

The `wsprintf` shim in `NoDLPortioMessage` did `call SysErrorMessage`. **TF's
`SysErrorMessage` was deleted during the D12 port**, so that call now resolves to
`SysUtils.SysErrorMessage`, which returns a managed UTF-16 string -- pushed
straight into `wsprintf` as a `%s`, and leaked. Now Pascal concatenation.

### Verifying code that a normal build never compiles

`{$IF SERVERDEBUG}` and `{$IF K6VVA_WK_DEBUG}` are both `False`, so anything
inside them is invisible to the compiler and **a rewrite there cannot be checked
by building normally**. Flipping each switch on and building is cheap, and it
paid twice:

- `tr4wserverUnit`'s debug writer converted cleanly (verified by building
  `tr4wserver.dproj` with the switch on -- note it is NOT in `tr4w.dproj`, so
  building the app proves nothing about it). Three latent defects came out with
  the assembly: a **`Time` local that was never assigned** yet formatted by the
  leading `%s`; a `stored` CHARACTER count passed to `WriteFile`, which takes
  BYTES, over a `WideChar` buffer; and an unbounded `wsprintf` of a
  caller-supplied string into a fixed 256-element buffer.
- **`uWinKey`'s `K6VVA_WK_DEBUG` facility does not compile at all** and has not
  for a long time: `AddStringToTelnetConsole` is called with one argument where
  it takes two, `CID_TWO_BYTES` is never declared, `DirectionChar`/`ClassName`
  are `PChar` assigned from `PAnsiChar`, `tOpenFileForWrite` is qualified
  `Tree.` but lives in `utils_file`, and `wkDebugBuffer` is
  `array[0..63] of Char` while the format string alone is longer than 64
  characters. It is also **superseded**: the live path immediately above it is a
  proper Log4D `logger` call doing the same job. Left alone pending a decision
  to delete the facility outright -- its 2 asm blocks are inside a `False`
  switch, so they neither compile nor block anything.

### `TF.pas` -- the harness was not needed, because nothing called them

`_Pow10` and `ValExt` were ~350 lines of assembly carrying two Borland RTL
internals, and the standing note said converting them needed a golden harness
because a CTY.DAT lat/lon regression silently corrupts every beam heading.

**Nothing calls them.** `uCTYDAT` moved to the RTL `Val` intrinsic under Issue
#1033, and the only other references (in `uCFG`) were already commented out;
`_Pow10` was called from nowhere but `ValExt`. The safe conversion was a
deletion. Checked before removing rather than after -- the harness would have
been real work spent proving the equivalence of dead code.

### Remaining live blocks: 2

Both in `uWinKey`, inside the `False` `K6VVA_WK_DEBUG` switch, in a facility that
does not compile and is superseded by Log4D. **The tree is otherwise free of
inline assembly.**

## STEP 9 -- the string model, measured. It is a genuine fork.

With `TF.pas` clear, `uFactoryRadioBase` was compiled in BOTH modes. They
disagree, and in the way that matters:

| Mode | `string` is | Result |
|---|---|---|
| `-Mdelphi` | 8-bit `AnsiString` | **Indy compiles.** `TF.pas` fails on 2 sites |
| `-MdelphiUnicode` | UTF-16, same as D12 | **Indy does NOT compile** -- 7 errors in `IdGlobal.pas` |

**This corrects step 6 of this log.** "Indy compiles unmodified" is true *only in
8-bit mode*. Under `-MdelphiUnicode` the vendored 10.6.3.3 fails on
`GetChars(...PChar...)` vs `PWideChar` signature mismatches and three
`Typecast has different size (1 -> 2)` assignments. Indy's FPC support targets
FPC's native 8-bit world.

The two options are therefore no longer "one is riskier" -- each breaks something
real:

- **`-MdelphiUnicode`** keeps `string` semantics identical to D12, the lowest
  migration risk across 152k lines of our own code, but **costs the vendored
  Indy**, which carries the network radios, the DX cluster, TCI and tr4wserver.
  That reopens NY4I's note that the community recommends UPSTREAM Indy over the
  RAD-supplied copy: it may be a prerequisite rather than an option.
- **`-Mdelphi`** keeps Indy and is idiomatic for Lazarus, but silently redefines
  every `string` in the tree, and every `PChar(s)` handed to a `...W` API becomes
  a type error. `TF.pas`'s two failures are exactly that shape -- and they are
  *diagnosed*, which is the good case. The dangerous half of this class is the one
  D12 already taught us: a bare buffer passed to a generic Win32 name that
  compiles silently.

**Neither is a blocker; both are a bill.** This is the measurement the decision
needed, and no amount of argument would have produced it.

### The corpus gate needs a 32-bit FPC first

The corpus runs `tr4w.exe <contest>.CFG /EXPORT` over **D7-written binary `.dat`
logs** and byte-diffs the output. This install has `ppcx64` ONLY. A 64-bit build
changes record padding and pointer width, and `tr4w.dproj` pins `-$A8` alignment
on top, so a 64-bit FPC build would not read those logs equivalently. **`ppc386`
is a prerequisite for the gate, not a detail** -- an fpcupdeluxe install, but it
has to happen before any corpus result under FPC means anything.

