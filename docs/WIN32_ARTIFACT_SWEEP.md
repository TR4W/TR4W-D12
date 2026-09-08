# The Win32 artifact sweep — writing it the way FPC/LCL would have

**Status: NOT STARTED. Scoped 2026-09-08 (NY4I): _"log it for its own pass. That
is close to a final sweep to weed out the win32 artifacts and update to way it
should be done."_**

## This is a DIFFERENT sweep from the portability one, and the difference matters

[`WINDOWS_DEPENDENCY_SWEEP.md`](WINDOWS_DEPENDENCY_SWEEP.md) asked one question:
**does this compile off Windows?** It is finished — zero ungated `Windows.` or
`HWND` references, and the cross compiler is now walking the dependency chain.

This sweep asks a different one: **is this how you would write it in FPC and the
LCL from scratch?** A Win32 artifact can compile perfectly on every platform and
still be wrong — it is a shape inherited from an API we no longer call, kept
because a conversion mirrored the old code rather than asking what the data was.

**So the two sweeps disagree about what "done" means, and this one is stricter.**
Every example below compiles today, on every target, and none of it would be
written this way by someone starting in Lazarus.

**DO NOT DO THIS WORK DURING A PORTABILITY PASS.** They pull in different
directions: a portability pass wants the smallest change that clears a
compiler error, and this one wants the right shape. Mixing them produces a
diff nobody can review, and it was NY4I who separated them.

## The worked example, in full — because it is the pattern, not an incident

`logedit.pas` builds the remaining-multipliers window like this:

```pascal
frm.Mults.AddItem('', (PtrInt(Word(aIndex)) shl 16) or PtrInt(Word(Ord(rmt))));
```

Follow it through:

| step | what happens |
|---|---|
| `logedit.Add` | packs `(Ord(rmt), aIndex)` — a multiplier KIND and an INDEX — into one integer |
| `TFlowGrid.AddItem` | stores it as `FCalls.AddObject(aCall, TObject(aTag))` |
| `uRemMultsForm.OnGetCellText` | reads it back with `Mults.TagAt(idx)` |
| `RemMultsResolve` | a FUNCTION POINTER, assigned at `uRemMults` initialization, which unpacks it and consults the multiplier tables |

The form's own comment states the constraint honestly: *"the form can answer
neither -- both need the multiplier tables -- so uRemMults supplies this at
initialization. aTag is the packed (type, index) pair."*

**WHY THERE ARE BITS HERE AT ALL: THERE IS NO TYPE FOR THE THING BEING PASSED.**

A remaining multiplier *is* the pair (kind, index) — that pair is its identity.
It exists nowhere as a declared type. It lives only as bits inside a grid row's
`Objects` pointer, travelling through four layers that each hand on an opaque
integer because **no layer has a name for it**.

Each constraint in that chain is inherited rather than real:

- the **packing** exists because a Win32 listbox carried one 32-bit `lParam`
  per item;
- the **`PtrInt`** exists because `TStringList.Objects` wants something
  pointer-sized, so an integer has to masquerade as a `TObject`;
- the **`LoWord`/`HiWord`** exist because the packing does.

Remove the first — which the LCL already did, and nobody noticed — and all
three go.

### And the untyped slot is shared by three unrelated meanings

`TFlowGrid`'s one `PtrInt` carries a different thing in every grid that uses it,
with nothing in the type system saying so:

| caller | stores | reads back as |
|---|---|---|
| `uCallsigns` | `Ord(TempChar)` — a district character | `byte(Calls.TagAt(idx))` |
| `uMaster` | `PtrInt(Ord(aIsDupe))` — a boolean | `Calls.TagAt(idx) <> 0` |
| `logedit` | the packed (kind, index) PAIR | `LoWord(Mults.TagAt(idx))` |

Today nothing stops the dupe sheet reading a multiplier's tag. A typed payload
would make that a compile error.

### The shape it should have

The design ALREADY HAS THE RIGHT SEAM — `RemMultsResolve` is a clean view →
domain callback. Nothing structural has to change; the token just needs to be a
type.

**AND THE IDIOMATIC ANSWER IS THE ONE THE CODE IS ALREADY PRETENDING TO USE**
(NY4I, 2026-09-08: _"another name for this structure in FPC is a TList with an
object attached"_). `TFlowGrid` already stores through
`FCalls.AddObject(aCall, TObject(aTag))` — the `Objects` slot is right there,
holding an integer in a disguise. Put a real object in it and the disguise is
all that goes:

```pascal
type
   TRemainingMult = class
      Kind:  TRemainingMultiplierType;
      Index: Integer;
   end;
```

```pascal
FCalls.AddObject(aCall, TRemainingMult.Create(rmt, aIndex));   { instead of TObject(packed) }
...
mult := TRemainingMult(FCalls.Objects[idx]);                   { instead of LoWord(TagAt(idx)) }
```

**Why this beats the record for THIS codebase:** `TStringList.Objects` already
exists, already takes a `TObject`, and is already what the grid uses — so the
change is the cast and nothing else. A record would mean replacing
`TFlowGrid`'s storage with a `specialize TList<T>` or making the class generic,
which is a bigger edit for the same benefit.

**The one thing it adds is LIFETIME, and it is one property:** set
`OwnsObjects := True` on the list and the items die with it. Get that wrong and
it is a leak per row rather than a wrong answer, which is the better failure of
the two — but it is the thing to check in review.

**A CLASS, NOT A RECORD, AND THAT IS A STANDING PREFERENCE** (NY4I,
2026-09-08: _"I prefer objects to records unless we are going to bring all of
the 80-s back..."_ and, when this doc first listed four exemptions, _"Records
that MUST stay records will require convincing me unless they are interface
parameters."_).

**ONE AUTOMATIC EXEMPTION: an INTERFACE PARAMETER** — a layout defined outside
this code, at the boundary where it is passed. A Win32 API struct such as
`TCharFormatA`, a C library's parameter block, a byte layout another program
reads. There the record IS the contract.

**AND "IT GOES OVER THE WIRE" IS NOT ONE OF THEM.** NY4I, 2026-09-08: _"I
can persist a TContestExchange over the wire in multiple ways. No record
required."_

**THE CONTRACT IS THE ENCODING, NOT THE TYPE.** A record is one way to produce
an encoding, and specifically the DOS/Win32 way: the in-memory layout WAS the
serialization, because you wrote the struct straight to a file or a socket.
That is the artifact — not a reason to keep it. With a serializer the
in-memory type is free.

So the two this document originally waved through do not qualify:

- **`ContestExchange` and the protocol records.** What IS real about them is a
  different question: the ENCODING has deployed readers — existing binary
  `.dat` logs, and older TR4W versions on a multi-op network — so changing the
  BYTES is a compatibility decision with a migration attached. Changing the
  TYPE behind them is not. Keep the two apart; the SQLite log work is where
  the encoding question gets answered.
- **capability sets and flags**, passed by value out of convenience rather
  than contract.

The grid payload here is neither, so it is a class. And the allocation
argument that might otherwise favour a record — a `specialize TList<T>`
allocates nothing per row — does not reach at these sizes: a few hundred
multipliers, built once when the window opens.

Either way the casts, the masks and the 64-bit sign-extension question
disappear together, and the compiler starts checking that the dupe sheet is not
reading a multiplier's payload.

**The stronger version:** these grids are already VIRTUAL — they draw from a
model by row index — so arguably the payload should not be stored per row at
all. `OnGetCellText` could ask the model, which already knows the kind and the
index. That is the same direction as
[`DISPLAY_STATE_MODEL_PLAN.md`](DISPLAY_STATE_MODEL_PLAN.md) and `src/domain/`:
a typed model the view reads, rather than the view being the storage.

## Other artifacts found while doing the portability sweep

Not a survey — these are the ones that surfaced on the way past, so treat the
list as a start rather than an inventory.

| artifact | where | what it should be |
|---|---|---|
| Integer smuggled through `TObject` | `uFlowGrid.AddItem` / `TagAt`, 3 callers | a typed payload, per the worked example above |
| `ExitProcess` instead of `Halt` | `MainUnit`, the shutdown path | **A DECISION, NOT A SWAP:** `Halt` runs finalization sections and `ExitProcess` does not, so something may be relying on them not running. Establish that first |
| The MMTTY output pane is a RICHED32 control | `uMMTTYForm` | **Our display choice, NOT MMTTY's protocol** — MMTTY posts `TXM_CHAR` to the main window and TR4W writes the character itself. Any control with per-character colour would do, and swapping one in removes RICHED32.DLL, `RichEditOperation`, `TCharFormatA` and `MMTTYRichEdit` together. Base LCL has no rich text control, so it needs a package or a custom-drawn pane |
| `Config.CWTone` used as a CW-ENABLED FLAG | `logddx`, `MainUnit`, threaded through `AddStringToBuffer(Msg, Tone)` into the keyer factory | It is no longer a tone — the sidetone was deleted 2026-09-08 — so it is a dead parameter across the keyer API plus a flag wearing a frequency's name. Separate the two |
| `wsprintfBuffer` | tree-wide | A shared global text buffer, which is a 1990s idiom and not a Windows dependency (that was established and closed). It is an artifact of the same era |
| `PChar` / `PAnsiChar` outside real transports | CLAUDE.md sizes it at **920 mentions across 112 units** (2026-09-01) | NY4I's standing rule: each is either a genuine transport boundary that keeps its `PChar` AND gains a comment saying why, or it is a habit. Re-measure before quoting the number |
| `ShortString` as the TRDOS currency | `src/trdos/` | Not to be swept casually — it is the core's currency and CLAUDE.md's string rules govern. Listed so nobody mistakes its absence here for approval |

## How to find more, and how not to

**The signals are structural, not textual.** A grep will not find these, because
they contain no Windows identifier — the packed tag names nothing from any
Windows unit, which is exactly why it survived a `Windows.` sweep untouched.

Look for:

- **an integer that means two things** — any `shl 16`, `LoWord`, `HiWord`, or a
  value described in a comment as "packed";
- **a cast to `TObject` that is not an object** — `TObject(someInteger)`;
- **a comment that explains a CONSTRAINT rather than a decision** — "the form
  cannot answer this", "one slot per item", "the caller supplies this at
  initialization". A constraint that is no longer imposed is an artifact;
- **a function pointer assigned at unit initialization** to break a cycle the
  type system could break instead;
- **a parameter that every caller passes the same value to**, or ignores.

**And what NOT to trust:** the golden corpus is BLIND to all of it. Every item
above is display or plumbing, and the corpus compares exported ADIF and
Cabrillo — it will stay green through a change that breaks the multiplier
window completely. The unit tests do not cover these units either. **That means
each item wants either a test written with the change, or a bench check,** and
that cost is part of the estimate rather than an afterthought.
