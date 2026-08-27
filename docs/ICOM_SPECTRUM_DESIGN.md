# The Icom bandscope: extending the panadapter to CI-V `$27`

**Status, 2026-08-26: RUNNING IN THE PROGRAM.** The panadapter window opens on
a network Icom and draws its spectrum -- confirmed by NY4I in `tr4w.exe`, not
just on the bench. That is the last hop and the one nothing offline could
prove: the bench stops at a subscriber that counts frames, so until this the
render path had only ever been exercised with a K4's 2048 bins and its
radio-reported noise floor. An Icom differs in kind on both counts -- 475 or
689 bins, and a floor derived from a percentile of the sweep itself -- and the
same code drew both.

The decoder, the seam, the driver wiring, the per-model declarations, the pin
tests and the bench harness are in, and an **IC-9700 and an IC-7760 have both
been watched streaming** -- section 11 has the measurements, section 12 the two
pre-existing defects the bench exposed.

**Still unverified: the dB axis, the serial (divided) path, the IC-7760's level
range, and the profile-change lifetime fix** (section 12.5) -- see 11.4.

This document marks each measurement's strength explicitly; section 11.4 lists
what is still open.

Read [`PANADAPTER_LCL_DESIGN.md`](PANADAPTER_LCL_DESIGN.md) first — it defines
the seam and the window this work plugs into, and it is authoritative on
everything the two radios share.

---

## 0. Sources used, and what each one is allowed to say

**Stated up front because it was not, and that caused a real misreading.**

TR4W's Icom bandscope work draws on **three references**, and this document
cites all three by name:

| reference | what it is | what it may be cited for here |
|---|---|---|
| **Icom** | the per-model CI-V Reference Guides | anything — primary, but only the IC-705 and IC-7300MK2 guides were available |
| **AetherSDR** (`c:/projects/AetherSDR`) | a C++ SDR client with an `icom/` backend | the RS-BA1 transport **and** the CI-V payload |
| **HamLib** (`~/projects/Hamlib`) | a rig-control library, `rigs/icom/` | **the CI-V payload ONLY — never the transport** |

**THE HAMLIB RESTRICTION IS NOT A STYLE PREFERENCE.** A networked Icom is two
protocols stacked, and HamLib only touches one of them:

| layer | ours | HamLib |
|---|---|---|
| **RS-BA1 UDP transport** — session handshake, login, token renewal, retransmit, ports 50001/50002/50003 | `src/uIcomNetworkTransport.pas`, **our own** | **nothing at all** |
| **CI-V command plane** — `FE FE <to> <from> <cmd> … FD`, BCD, the `$27 $00` payload | `src/radioFactory/uIcomScope.pas`, `uRadioIcomBase.pas` | `icom_parse_spectrum_frame`, `spectrum_scope_caps` |

Verified rather than assumed: HamLib's Icom backends declare
`RIG_PORT_SERIAL`, carry no RS-BA1 session code, and the strings
`50001`/`50002`/`50003` appear nowhere in `rigs/icom/`. It reaches an Icom down
a cable. **Our UDP transport owes it nothing and no claim about the network
side may rest on it.**

What makes it admissible for the payload is that the `$27 $00` bytes are
identical on both transports — the RS-BA1 stream is a pipe carrying CI-V, not a
different protocol — so HamLib's per-model scope geometry is a fact about the
*radio's scope*, not about how the bytes arrived.

**AND IT MUST NOT APPEAR IN ANYTHING SENT UPSTREAM.** AetherSDR keeps an
explicit clean-room boundary (`IcomProtocol.h`: wfview is used *"ONLY as a
read-only specification … never as source"*), and HamLib is GPL. An issue filed
against them whose prose cites it would be asking them to look at a license
they have fenced off, and would be closed unread — NY4I, 2026-08-26. The
submittable version of our findings is therefore a **separate file**,
[`AETHERSDR_ICOM_SCOPE_REPORT.md`](AETHERSDR_ICOM_SCOPE_REPORT.md), which rests
only on our own measurements and on AetherSDR's own source, and names no third
project at all.

Provenance for *our* code and admissibility *upstream* are different questions.
This document answers the first; that file answers the second. Keep them apart.

---

## 1. What was built, and what was deliberately not

**No panadapter factory.** The joint already existed: `TFactoryRadioBase`
carries `rcSpectrum`, `SpectrumAvailable`, `PublishSpectrumFrame` /
`OnSpectrumFrame`, `StartSpectrum` / `StopSpectrum`, `SetSpectrumSpan` /
`SpectrumSpanHz`, `SpectrumStreaming` / `SpectrumLinkUp`. Icom is the **second
implementer of that seam**, exactly as the K4 is the first. A separate factory
would have duplicated the radio factory's dispatch to no end.

| file | what |
|---|---|
| `src/radioFactory/uIcomScope.pas` | **PURE** decoder: bytes + geometry in, `TSpectrumFrame` out. No socket, no thread, no UI, no globals. |
| `test/unit/uTestIcomScope.pas` | 33 pin tests on that decoder. Synthetic frames, no radio. |
| `test/unit/uTestIcomScopeSeam.pas` | The seam and the per-model declarations, including the exhaustive guard. |
| `test/bench/bench_icomscope.dpr` | Drives a real rig. **A measuring instrument first**, a test second — see §6. |
| `src/radioFactory/uRadioIcomBase.pas` | The wiring: the `$27` arm, the enables, the span, the three gates. |
| the ten network Icom model units | One `DeclareScopeGeometry` each, with its provenance. |

Two additions to the shared seam, both because the second radio exposed
something the first had hidden — §4.

**`uPanadapterForm` needed no Icom code at all**, which is the test of whether
the seam was drawn in the right place. The only change to it was *removing* a
K4 rule that had been living there.

---

## 2. The wire format, and three references that disagree

Offsets are into the CI-V data payload after `$27 $00`.

```
 [0]      scope id            -- NOT a fixed zero.  See below.
 [1]      division index      -- BCD, 01..max
 [2]      division maximum    -- BCD; 01 over LAN, 11 or 15 over USB
when the division index is 1, and only then:
 [3]      scope mode          -- 00 centre, 01 fixed, 02 scrollC, 03 scrollF
 [4..8]   frequency A         -- centre (centre mode) or LOWER edge
 [9..13]  frequency B         -- span   (centre mode) or UPPER edge
 [14]     out-of-range flag
 [15..]   waveform, when this frame is also the LAST division (the LAN case)
for every division after the first:
 [3..]    waveform
```

The 15-byte header is not a magic number: `3 + 1 + 5*2 + 1 = 15`, and Icom's own
IC-7300MK2 CI-V Reference Guide independently states the LAN data length as
**490 bytes**, which is `15 + 475`. Two derivations agreeing is the reason to
trust it.

### 2.1 Which layer this is, and therefore which sources apply

**A networked Icom is TWO PROTOCOLS STACKED, and keeping them apart decides
which reference is admissible for what.** This section is about the second one
only.

| layer | ours | informed by |
|---|---|---|
| **RS-BA1 UDP transport** — session handshake, login, token renewal, retransmit, ports 50001/50002/50003 | `src/uIcomNetworkTransport.pas` | wfview, kappanhang, AetherSDR. Icom documents none of it. |
| **CI-V command plane** — `FE FE <to> <from> <cmd> … FD`, BCD, the `$27 $00` payload | `src/radioFactory/uIcomScope.pas`, `uRadioIcomBase.pas` | Icom's own CI-V Reference Guides, AetherSDR, HamLib |

**HAMLIB HAS NOTHING TO DO WITH THE UDP SIDE AND IS NEVER CITED FOR IT.**
Verified rather than assumed: its Icom backends declare `RIG_PORT_SERIAL`, it
carries no RS-BA1 session code, and the strings `50001`/`50002`/`50003` do not
appear anywhere in `rigs/icom/`. It reaches an Icom down a serial cable. Our
UDP transport is our own and owes it nothing.

**What makes HamLib admissible HERE** is that the `$27 $00` payload is
byte-identical on both transports — the RS-BA1 stream is a pipe that carries
CI-V, not a different protocol. HamLib parses those same bytes off a serial
port in `icom_parse_spectrum_frame`, and publishes per-model scope geometry in
`spectrum_scope_caps`. That is a fact about the RADIO'S SCOPE, not about how
the bytes reached us.

(An earlier draft of this document called these "three references" without
naming the layer, which invited exactly the wrong reading — NY4I, 2026-08-26:
*"This has nothing to do with hamlib. It is our direct connection to the UDP
side."* He is right about the transport, and this table is the correction.)

| source | what it is | standing on the CI-V payload |
|---|---|---|
| **Icom** | the per-model CI-V Reference Guides, quoted by AetherSDR | primary — but only for the IC-705 and IC-7300MK2 |
| **AetherSDR** | `src/core/backends/icom/IcomScope.cpp` | a shipping implementation, clean-room, one model guide-verified |
| **HamLib** | `icom_parse_spectrum_frame` + per-model `spectrum_scope_caps` | a shipping implementation with per-model data — **serial only, and cited only for the payload** |

They agree on the structure. They disagree on four things, and every one of them
is a silent failure rather than a crash.

### 2.2 The disagreements, and which way TR4W went

**Byte [0] is a scope id, not a fixed zero. → HamLib.**
HamLib reads it as a scope/VFO selector (`0 = Main, 1 = Sub`) and keys a
per-scope cache with it. AetherSDR's comment calls it *"0x00, fixed"* and
ignores it. On a single-scope radio the two are indistinguishable — but the
**IC-9700, IC-7610 and IC-7760 all have two scopes**, so ignoring the byte
splices Main and Sub sweeps into one trace, and the result reads as corrupt
spectrum rather than as a decode bug.

This maps onto `TSpectrumFrame.SourceId` with nothing left over: it is exactly
what the K4 uses to keep its A/B/Y pans apart on one socket. So the window
already knows how to handle it, and a Sub-scope window later is a setting rather
than a rework.

*Unverified, and flagged in the source: **which** id is Main. HamLib says 0.
Nothing depends on that being right — `SourceId` is opaque to the window, and
the bench harness reports which ids a rig actually emits.*

**A lower edge can be negative. → AetherSDR.**
The IC-7300MK2 guide documents `$F` in the 1 GHz digit as a sign flag, set when
a wide span sits near the bottom of the tuning range. HamLib uses plain unsigned
`from_bcd` here and would mis-decode it. `uIcomScope` carries its own signed
variant for exactly one nibble in exactly one position — and **does not** relax
`uIcomCIV.IcomBCDToFreq`, which is strict on purpose: an operating frequency is
never negative, and a fabricated one retunes the radio.

**An unknown mode byte is refused, not defaulted. → HamLib.**
AetherSDR falls back to Fixed. HamLib rejects the frame. HamLib is right for a
specific reason: **the geometry depends entirely on the mode.** In centre mode
the second frequency field is a half-width; in every other mode it is an
absolute edge. Guessing wrong yields a sweep confidently placed at the wrong
frequency, which is worse than one that never appears.

**The division counters are BCD. → both, and it is worth restating.**
Division 11 is `$11`, not `$0B`. A binary read works to 9 and then breaks — and
**over LAN the maximum is always 1**, so the defect never fires on the transport
most operators use, and it would ship.

### 2.3 One thing all three had wrong, or at least mistyped

AetherSDR's `CivCodec.h` endianness note gives the worked example
*"14.250000 MHz -> 00 60 25 14 00"*. Decode those bytes least-significant-pair-
first and they are `00 14 25 60 00` = **14,256,000 Hz**. The correct encoding is
`00 00 25 14 00`.

This was caught by `uTestIcomScope` on its first run, because the test types the
bytes by hand rather than round-tripping them through the same arithmetic the
code uses. That is the argument for hand-typed vectors, and it is a small live
demonstration of CLAUDE.md's rule that a working reference implementation is
evidence, not authority.

---

## 3. dB: exactly what is measured and what is estimated

**This is the one genuinely hard design problem, and it has no counterpart on
the K4.** The K4 sends absolute dB *and* its own noise-floor reference in every
packet, and `uPanadapterForm` scales everything off that reference. Icom sends
**uncalibrated display units** — 0..160 on most models, 0..200 on the IC-7610
and IC-785x — and publishes no mapping to absolute power at all.

So the driver has to produce a `NoiseFloorDb`, and the two halves of that have
very different standing.

**The vertical stretch is an ESTIMATE.** Levels convert at a fixed dB-per-unit.
0.5 was not invented — HamLib publishes a signal-strength range per model, and
every published one reduces to exactly that:

| model | points | levels | HamLib dB range | dB/unit |
|---|---:|---:|---|---:|
| IC-7300 family (5 rows) | 475 | 0..160 | −80..0 | 0.5 |
| IC-7610 | 689 | 0..200 | −100..0 | 0.5 |
| IC-785x | 689 | 0..200 | −100..0 | 0.5 |
| IC-R8600 | 475 | 0..160 | −100..0 | 0.625 — HamLib marks it `TODO: to be confirmed` |

It is still an estimate: no bench measurement against a known source backs it,
which is why it is a **field** of `TIcomScopeGeometry` and not a constant.

**THIS IS THE ONE PLACE A HAMLIB NUMBER IS LOAD-BEARING AND UNCORROBORATED.**
Everything else taken from HamLib has since been checked against a radio here —
the 689-point class by the IC-7760 measurement, the selector byte by the
IC-9700's own `$27 $15` reply, the half-width by the centre/span cross-check.
The dB-per-unit has not, and it comes from a project that only ever reads these
radios over a serial cable. It should be treated as the weakest claim in this
document until someone puts a known signal in the passband.

**The floor is MEASURED, from the sweep itself.** `NoiseFloorDb` is the 10th
percentile of that frame's own levels — computed by a 256-bin histogram rather
than a sort, which is O(n), allocation-free, and *exact* (a level is a byte, so
the histogram **is** the distribution). That does on TR4W's side the job the
K4's AutoRef does on the radio's, and it needs no CAT query: a band change, an
attenuator or a different model simply moves the floor and the display follows.

**The two interact well, and that is the point.** Because the reference is
measured and only the stretch is estimated, an error in dB-per-unit shows up as
a display that is *too flat or too contrasty*. It can never park the trace
off-scale — which is precisely the failure a fixed dB window produced on the K4,
where every pan-A sample fell below TR4QT's hard-coded floor and the waterfall
was solid black (`PANADAPTER_LCL_DESIGN.md` §2.3).

**The axis is therefore RELATIVE and must never be labelled dBm.**

---

## 4. Two additions to the shared seam

Both existed as K4 rules living in the wrong place, and both would have been
silently wrong for the second radio.

### 4.1 `PrimarySpectrumSourceId`

`uRadioPanelForm` held `K4_MAIN_PAN_SOURCE = 'A'` and passed it to
`ShowPanadapterWindow` for **every** radio. Correct while the K4 was the only
producer; silently wrong for the second, because an Icom's scope id is a number.

The window filters frames on string equality against that value and nothing
validates it, so the failure is not a wrong caption — it is a panadapter that
**connects, streams, decodes, and draws nothing at all**, with no error
anywhere. That is the worst shape of failure this seam can produce, so it now
has an assertion (`Test_SourceIdMatchesWhatTheDecoderStamps`) rather than a
comment.

The base returns `''` — not `'A'`. A radio with no spectrum names no source, and
the test caught `TIcomRadio` getting this wrong: it answered `'0'` for an
IC-7600, a radio that streams nothing. A plausible id on a radio with no scope
makes a caller's "did I get a source" check pass, which moves the failure from
the place that can report it to a window that never draws.

### 4.2 `StepSpectrumSpan(direction)`

The window used to apply the K4's rule itself — ±1 kHz per press, a fine trim
rather than a zoom. The two families differ in **kind**, not merely in step
size:

* the **K4** accepts any span in Hz and **clamps** what it cannot do, reporting
  what it settled on;
* an **Icom** offers eight discrete spans and **snaps** to the nearest. The
  rungs are spaced by ratios of 2 and 2.5, so a 1 kHz step never crosses a gap
  midpoint and the rig hands back the span it already had. AetherSDR measured
  this as **zoom-out inert at all eight spans and zoom-in working at seven** —
  an asymmetry that reads as "zoom is broken" rather than "zoom is quantised",
  and which no amount of clicking escapes.

A per-radio *step size* could not have expressed snapping, and letting the
window choose between the two behaviours would make it ask which radio it has.
So the window asks for a detent and the radio decides what one is.

The ladder is stated as **total widths** (5 kHz … 1 MHz) because Icom's wire
carries the half-width the front panel shows (`±100k`) while
`TSpectrumFrame.SpanHz` and `SpectrumSpanHz` are totals. Converting once, in one
named place, is what keeps the factor of two from leaking; both references warn
that reversing it is the error people actually make, and it produces a display
right about its centre and wrong by 2× about its extent.

---

## 5. Per-model geometry, and how much each row is worth

Geometry is **declared by the model, guarded by the base** —
`DeclareScopeGeometry` in each model's constructor, never a `case` in a shared
unit. It is deliberately **not** in `TRadioCapabilities`: every Icom subclass
replaces that record's `Flags` wholesale in `DefineCapabilities`, and this
family has already been bitten twice by a value written there being silently
wiped (the TS-850's frame rule, and all fourteen keying Icoms inheriting
`maxLen 0` = "no limit").

| model | points | levels | provenance | strength |
|---|---:|---:|---|---|
| **IC-705** | 475 | 160 | Icom's own CI-V guide (AetherSDR's single `verified` model) | **tier 1** |
| **IC-7300MK2** | 475 | 160 | Icom's own CI-V guide; its 490-byte LAN length confirms the header size independently | **tier 1** |
| **IC-9700** | 475 | 160 | 618 consecutive live frames (AetherSDR); HamLib has nothing | measured, not guide-verified |
| **IC-7610** | 689 | 200 | HamLib `ic7610.c` + AetherSDR, neither guide-verified | two agreeing secondary sources |
| **IC-7850 / IC-7851** | 689 | 200 | HamLib `ic785x.c` + AetherSDR, neither guide-verified | two agreeing secondary sources |
| **IC-905** | 475 | 160 | AetherSDR, marked unverified | **provisional** — and see below |
| **IC-7760** | 475 | 160 | **nothing, anywhere** | **a guess** |
| IC-7600, IC-7700 | — | — | no source lists CI-V wave output; `$27 $00` arrived with the IC-7300 generation | **no `rcSpectrum`** |

**The IC-7760's geometry is published nowhere** — not in HamLib, not in
AetherSDR's table. 475/160 is inherited from the rest of the family purely
because something had to be written, and it may well be 689/200.

It is **declared anyway rather than withheld**, because withholding it would
leave no way to find out: `SpectrumAvailable` refuses a radio with no geometry,
so the Spectrum button would not appear and the rig could not be measured. The
failure mode of guessing low is bounded and visible — `uIcomScope` **truncates
rather than overrunning** (pin-tested), so a 689-point rig draws correctly
across two thirds of the window and flat across the last third. That is a bench
session's first observation, not a crash.

**The IC-905 carries a second, separate hazard**: it uses **six-byte
frequencies above 10 GHz**, and a scope header decoded with five misaligns by
two bytes and yields a plausible-looking wrong centre.
`TIcomScopeGeometry.FreqBytes` exists for that and this radio does not set it
yet, so its scope is right below 10 GHz and must be re-checked above it.

### 5.1 The exhaustive guard

CLAUDE.md rule 9: *a silently-defaulted field reads as a legal zero*, and *write
the exhaustive pin test in the same commit*. A radio that declares `rcSpectrum`
and forgets `DeclareScopeGeometry` has `Points = 0`, which decodes every sweep
into no bins at all — the window opens, the link comes up, frames arrive, and
nothing is ever drawn.

`Test_EveryScopeRadioDeclaresGeometry` walks **every registered model** and fails
if the capability and the geometry disagree **in either direction**. The converse
matters as much: a geometry declared without `rcSpectrum` is a driver that
decodes sweeps nobody can ask for.

`Test_TwoGeometriesExistAndDiffer` is the one that stops the table becoming a
constant. Every other test still passes if someone folds 689/200 into 475/160
and edits the pins to match; that one does not.

---

## 6. The bench harness is a measuring instrument first

`test/bench/bench_icomscope.dpr`, run as:

```
bench_icomscope <model-id> <host> <user> <password> [seconds] [-capture <file>]
bench_icomscope IC9700 192.168.1.50 ny4i secret 30 -capture ic9700-scope.bin
```

**One deviation from the K4 method, deliberately.** The K4 needed
`tools/k4panwatch.py` in Python because nothing in TR4W could receive that
stream. Here TR4W already receives `$27` frames — `uRadioIcomBase` has had a
`$27` arm for months and threw them away. Re-implementing the RS-BA1 handshake,
token renewal and retransmit layer in Python to capture bytes a working
transport already delivers would be ~2,000 lines. **The cost is real and worth
naming: we lose the "two independent implementations agreeing" evidence the K4
capture produced.**

What it reports, and what each is worth:

| | strength |
|---|---|
| **measured points** — level bytes a sweep carried, taken **before** truncation to the declared geometry | **strong.** Over LAN a sweep arrives whole, so this is the point count directly. Disagreement with the declaration **fails the run**. |
| **scope ids seen** | **strong.** Settles the HamLib-vs-AetherSDR argument on byte [0]. |
| **highest level seen** | **weak, and labelled so.** A lower bound, reached only if something strong was in the passband. It can disprove a declared maximum; it cannot confirm one. |
| **centre and span** | cross-check. A span out by exactly 2× means the half-width doubling is inverted — the most likely error here. |

`-capture` writes raw payloads, length-prefixed, **upstream of the decoder**
(`TIcomRadio.OnScopePayload`), so a fixture is evidence about the radio rather
than a record of what this decoder made of it. A fixture taken downstream would
bake in any decode bug and then be used to prove that decoder correct.

Unlike the K4 bench this one **opens the CAT link** — it has to, because the
scope rides CI-V with no side channel. It therefore touches the radio: `$27 $10`
and `$27 $11` on the way in, `$27 $11 00` on the way out. **The scope itself is
left as it was found**, because that is the operator's setting and not the
program's.

---

## 7. Traps that produce silence rather than errors

Collected because each one, hit alone, looks like "the panadapter is broken".

**Both `$27 $10` and `$27 $11` must be on.** Enabling only `$10` turns the scope
on the **radio's own screen** and sends nothing down CI-V. AetherSDR names this
as the number-one "my panadapter is black" cause, and it is a failure with no
error anywhere: the rig looks right, the link is up, no frames arrive. The bench
harness says so by name when it decodes nothing.

**`$15` carries a scope selector; `$10` and `$11` do not.** HamLib puts the
selector byte first on every scope sub-command it implements (`$14` mode, `$15`
span, `$19` reference) on **read** as well as set, while `$10`/`$11` are
whole-function switches taking only 00 or 01. AetherSDR reports that omitting
the selector where it *is* required makes the rig ignore the frame outright —
no NG, no error, the setting simply does not change.

**Framing is safe, and not by luck.** A scope frame can contain neither `$FD`
nor `$FE`: levels top out at 200, BCD digits at `$99`, the sign nibble makes at
most `$F9`, and the mode/division/flag bytes are all small. So the CI-V framer —
which splits on `$FD` and resyncs on `$FE $FE` — cannot be desynchronised by a
490-byte payload, and neither the serial reading thread's terminator split nor
`ProcessCIVMessage` needed changing. Worth having checked rather than assumed.

**`rcSpectrum` was missing from the registry's re-export block.** Model units
`uses uRadioIcomBase, VC, uRadioRegistry` and not `uFactoryRadioBase`, and
Delphi does not re-export enum *members* through a type alias. The K4 unit uses
`uFactoryRadioBase` directly so it never needed the alias; declaring `rcSpectrum`
on an Icom failed with the exact `E2003` the block's own comment describes. The
same trap, eight months apart — which is the argument for the block rather than
for 25 edited headers.

**Threading is inherited, not invented.** `PublishSpectrumFrame` is raised on
the CI-V receive thread, which is precisely the contract `TSpectrumFrameProc`
already declares. The window parks the frame under a lock and repaints on a
timer, so it needed no change. There is **no new thread** in this work.

---

## 8. Variations in the NON-spectrum Icom code, flagged for review

Asked for explicitly, and **none of these were changed** — TR4W is not assumed
to need to match AetherSDR.

**8.1 `ExtractCivFrames` has no cross-datagram buffering.**
`uIcomNetworkTransport.pas:1183` scans **one UDP payload** for `FE FE … FD` and
drops anything that straddles a packet boundary — no FD found, loop ends, bytes
gone. AetherSDR buffers across payloads (`CivStream::feed`) with a 100 ms
partial-frame abandon.

Today this is invisible because CI-V frames are ~11 bytes. **It becomes
load-bearing for scope data**, where the IC-7300MK2 guide states the LAN payload
as 490 bytes. If the RS-BA1 serial stream ever splits a payload, scope frames
would be dropped silently and intermittently — which would look like a flickering
panadapter, not like a transport defect. *Worth deciding deliberately; the
capture will show whether it happens in practice.*

**8.2 CI-V open retry.**
AetherSDR re-sends the serial-stream open every 100 ms until data flows, after
observing a live IC-9700 accept the open and then stream **nothing for 45 s**.
TR4W has something similar at `uIcomNetworkTransport.pas:1728` keyed on
`FLastCivData`. *It looks equivalent; it was not read closely enough to say so,
and given the IC-9700 is the bench rig it is worth confirming rather than
assuming.*

**8.3 HamLib's scope span is `val.i / 2`.** Independent third confirmation of
the half-width convention, from a source that has nothing to do with AetherSDR.
Recorded because §4.2's factor of two is the kind of thing that wants three
witnesses.

**8.4 HamLib's own division indexing looks fragile.**
`data_frame_index = (max_division > 1) ? (division - 2) : (division - 1)` —
so a first division carrying waveform data while `max_division > 1` would
`memcpy` at a **negative offset**. It survives because over USB the header
division carries no waveform (15 bytes exactly, `475/50 → 10 data divisions + 1`).
`uIcomScope` appends conditionally and reaches the same result safely. *Not our
bug; noted because it is the kind of thing that makes a reference implementation
look like a specification.*

---

## 9. What is NOT done

* ~~**Nothing has been verified against a radio.**~~ **SUPERSEDED 2026-08-26** --
  two radios benched and the window confirmed rendering in `tr4w.exe`; see
  section 11. What remains open is listed in 11.4, and it is a much shorter
  list: the dB axis, the serial path, the IC-7760's level range, and the
  profile-change lifetime fix.
* **No fixture exists.** `uTestIcomScope` is entirely synthetic and says so in
  its header. When a capture arrives it gains fixture-driven tests *beside* the
  synthetic ones, not instead of them — no LAN capture can exercise
  multi-division assembly, and no single-scope rig can exercise scope-id
  demultiplexing.
* **The serial path is written, tested and gated shut.** `SpectrumAvailable`
  returns False on a serial link. Icom genuinely can stream over CI-V serial in
  11 or 15 divisions and `uIcomScope` decodes it; what has not happened is
  anyone watching it work, and 30 sweeps a second on a shared serial bus
  alongside tuning commands behaves differently in a contest than on a bench.
  Opening the gate is one line.
* **The dB-per-unit estimate needs a signal generator**, or the S-meter
  (`$15 $02`, which *is* calibrated) with a known signal in the passband.
  Nothing about watching frames arrive can settle it.
* **`$27 $19` (reference level) is not read.** The rig's own scope reference
  shifts its trace; TR4W scales from the sweep's own levels instead, so nothing
  is blocked. Revisit with evidence, the way the K4's 25 `#` commands were.
* **Which scope id is Main** is HamLib's claim and is unconfirmed. If it is
  backwards on some model the window follows the other scope, which a bench
  session sees at once.
* **A Sub-scope window.** Every scope is published, not just the followed one —
  filtering at the driver would make this a rework rather than a setting, which
  is the mistake TR4QT makes by discarding two of the K4's three pans at the
  parser.

### 9.1 The bench plan

NY4I has the **IC-9700 and IC-7760** on the bench now and can install the
**IC-705 and IC-7610**. That set is unusually well chosen:

| rig | what a run settles |
|---|---|
| **IC-9700** | Confirms or refutes AetherSDR's live-capture 475/160 — the only evidence for that model anywhere. Dual-scope, so it also settles the scope-id argument. |
| **IC-7760** | Its geometry is published nowhere. This capture is **new information**. |
| **IC-7610** | The 689/200 counter-example. The pair with the 9700 is the real gate: one rig per **geometry**, not one per family. |
| **IC-705** | The tier-1 control — a known-good geometry to check the harness itself against. |

For each: run `bench_icomscope` with `-capture`, read the MEASURED GEOMETRY
block, correct the driver and `SCOPE_PINS` if it disagrees, and freeze a
trimmed capture as a fixture.

---

## 10. Gates, as of 2026-08-26

| | |
|---|---|
| lints | **23 passed** |
| unit tests | **10447 passed, 0 failed** |
| app build | clean, 6 range warnings at the standing ceiling |
| golden-master corpus | **22 passed, 0 failed, 4 known-divergence** — baseline |
| bench | **not run — no Icom has been watched** |

---

## 11. Bench results, 2026-08-26

Both radios on NY4I's bench, over the RS-BA1 network transport, driven by
`test/bench/bench_icomscope.dpr`.

### 11.1 IC-9700 at 192.168.73.171 — PASS

| | |
|---|---|
| sweeps | **592 in 20 s, a steady ~30/s** |
| **points measured** | **475 — matches the declaration** |
| payload | 490 bytes = 15-byte header + 475 levels |
| scope ids seen | **0 only** |
| divisions | 1 of 1 (whole sweep in one frame, the LAN case) |
| mode | `00` = centre, on every frame |
| centre / span | 147.669700 MHz, ±10 kHz → 20 kHz total |
| levels | 0 while the rig's scope was idle; **0..20 once it was showing signal** |

**The centre tracked the VFO knob while NY4I turned it**, and the half-width
doubling cross-checks: the rig's own `$27 $15` reply said 50 kHz half while the
window drew 100 kHz total.

This confirms AetherSDR's live-capture figure of 475/160 for the IC-9700 — the
only evidence that existed for it, since HamLib carries no spectrum caps for
this model at all.

### 11.2 IC-7760 at 192.168.73.196 — PASS, after correcting the declaration

**THIS IS NEW INFORMATION. The IC-7760's scope geometry is published nowhere** —
not in HamLib, not in AetherSDR's model table.

| | |
|---|---|
| **points measured** | **689 — NOT the 475 that was declared** |
| payload | **704 bytes** = 15-byte header + 689 levels |
| scope ids seen | 0 only |
| divisions | 1 of 1 |
| mode | `00` = centre |
| centre / span | 1.816195 MHz, ±2.5 kHz → 5 kHz total |
| sweep rate | **9 sweeps in 20 s** — far slower than the IC-9700's 30/s |
| levels | all zero (the rig's scope was not showing signal) |

So the IC-7760 belongs to the **689-point class** with the IC-7610 and the
IC-785x, not to the 475-point majority.

**The bench caught the wrong declaration and FAILED the run for it** — *"this
radio sends 689 points, not 475"* — which is the entire reason that check
exists. The driver and `SCOPE_PINS` were corrected to 689 and the re-run passed.

**Its level range is still INFERRED, not measured.** Every sample was zero, so
the bench could only report a lower bound of 0. 200 comes from both other
689-point radios using it in both references — a pairing, not an observation.
Re-run with the scope live and watch "highest level seen".

**The sweep-rate difference is unexplained and is not necessarily a defect:**
the IC-9700's scope was displayed and sweeping while the IC-7760's was not, so
9/s versus 30/s may simply be an idle scope. Re-measure with both rigs in the
same state before drawing any conclusion.

### 11.3 For reporting upstream to AetherSDR

Three things this bench establishes that AetherSDR's `icom/` backend does not
currently reflect. All are offered as measurements rather than corrections —
their model table is explicit about which rows it has verified, and two of
these fall in rows it already marks unverified.

1. **The IC-7760 exists and is a 689-point radio.** It is absent from `kModels`
   entirely, so `modelForCivAddress` returns nullptr and `unknownModel()`
   disables its scope. Measured over LAN: 704-byte payload, 689 points, single
   division, centre mode.

2. **Payload byte [0] is a scope id, not a fixed zero.** `IcomScope.cpp` labels
   it *"0x00, fixed"* and ignores it; HamLib reads it as a scope/VFO selector
   and keys a per-scope cache with it. Only id 0 appeared on either rig here,
   so **this bench does not yet prove HamLib right** — but both rigs are
   dual-scope, and that byte is the natural place for Main/Sub to be
   distinguished. Offered as something worth their attention, not as a defect.

3. **`CivCodec.h`'s worked example is mistyped.** The endianness note gives
   *"14.250000 MHz -> 00 60 25 14 00"*. Decoded least-significant-pair-first,
   those bytes are `00 14 25 60 00` = **14,256,000 Hz**; the correct encoding is
   `00 00 25 14 00`. This is a comment and not code — their `encodeFreq` is
   right — but it is the example a reader copies. It was caught here by a
   hand-typed test vector failing on its first run.

### 11.3a Rendered in the program, 2026-08-26

`bench_icomscope` deliberately stops at a subscriber that tallies frames and
draws nothing, so a green bench says the radio, the transport and the decoder
agree -- and says nothing whatever about the window.

NY4I opened the panadapter on a network Icom in `tr4w.exe` and it drew. That
closes the one gap a harness cannot: the renderer had only ever been fed a K4's
2048-bin frames scaled against a floor the radio reports, and an Icom's frames
are 475 or 689 bins scaled against a floor computed here from a percentile of
the sweep. `BinCount` being a FIELD rather than a constant (see
`uSpectrumTypes`) is what made that work without a second renderer, which was
the point of writing it that way.

**What this does NOT establish:** that the dB axis is right. The trace being
present and plausible is not evidence about 0.5 dB per unit -- an error there
shows as a display too flat or too contrasty, never as an absent one. See 11.4.

### 11.5 The captures are kept

Both runs are frozen beside the K4's, in `tr4w/test/unit/fixtures/`:

| file | what |
|---|---|
| `icom-scope-ic9700.bin` | 592 payloads, 490 bytes each, levels 0..20 (scope live) |
| `icom-scope-ic7760.bin` | 9 payloads, 704 bytes each, levels all zero (scope idle) |

Format: a 2-byte little-endian length, then that many bytes of raw `$27 $00`
payload — captured **upstream of the decoder**, so they are evidence about the
radios rather than a record of what this decoder made of them.

**In `fixtures/`, not `test/bench/`, and that matters.** The bench WRITES to
whatever `-capture` names; a tracked file in its output directory would show as
modified after every run. `fixtures/` is where frozen evidence lives — the same
place `k4pan-sample.bin` sits.

**Nothing reads them yet.** They are kept because the IC-7760's geometry is
published nowhere and this is the only recording of it, and because section 11's
numbers should be checkable rather than merely asserted. Wiring fixture-driven
tests beside the synthetic ones in `uTestIcomScope` is the obvious next step;
note the IC-7760 capture has no signal in it, so it can pin geometry and framing
but says nothing about levels.

### 11.4 Still not established

* **The dB axis.** 0.5 dB per unit remains an estimate, and nothing about
  watching frames arrive can check it. It needs a known signal and the S-meter
  (`$15 $02`, which *is* calibrated) to compare against.
* **The IC-7760's level range** — see 11.2.
* **The serial (divided) path.** `SpectrumAvailable` still refuses it. The
  decoder implements and unit-tests 11- and 15-division assembly; no rig has
  been watched doing it, and neither bench run could reach that path.
* **Whether scope id 0 is Main.** Both rigs emitted only id 0.
* **Why the IC-9700 stopped answering `$27` READ forms** part way through the
  session while continuing to stream wave data normally — its own `$27 $15`
  reply had been arriving minutes earlier. Suspected to be a rig-side CI-V
  transceive/echo setting rather than anything in TR4W, but it is unexplained,
  so it is recorded rather than dismissed.

---

## 12. Two pre-existing defects the bench exposed

**Neither is in the spectrum code.** Both are FPC-migration regressions in the
shared Icom CI-V path, in a family the docs record as verified *under Delphi*
and never re-confirmed under FPC. The bandscope simply happened to be the first
feature that needed the radio to *answer* rather than merely be sent to.

The common cause: `tr4w.inc` turns on the UnicodeStrings modeswitch, so `string`
is UTF-16, while the LCL sets `DefaultSystemCodePage` to **65001 (UTF-8)** —
and a lone byte at or above `$80` is not valid UTF-8, so it decodes to U+FFFD.

### 12.1 `Chr()` corrupted every high CI-V byte on send

FPC's `Chr()` returns an *8-bit* char, so putting one into a `string` runs the
codepage. Measured, both forms in one program:

```
Chr($A2)  literal        ->  U+00A2   correct  (the compiler folds it)
Chr(b)    b: Byte = $A2  ->  U+FFFD   corrupt  (runtime conversion)
```

**Constants hide it**, which is why it survived review: only the *variable*
form is broken. `BuildCIVCommand` builds both address bytes from variables, and
every Icom's address is at or above `$80` (`$A2` IC-9700, `$94` IC-7300, `$98`
IC-7610, `$A4` IC-705), as is the controller's `$E0`. `Byte(Ord(U+FFFD))` is
`$FD` — which is also the CI-V terminator, so the radio received `FE FE FD` and
echoed back a stub. Nothing was ever acknowledged.

Fixed with `CivChr`, a typecast rather than a conversion; all 22 `Chr()` call
sites in `uRadioIcomBase` repointed to it.

### 12.2 The framing constants never matched on receive

Worse, and it masked the first one:

```
Pos(CIV_PREAMBLE1 + CIV_PREAMBLE2, buf) = 0     <- untyped #$FE constants
Pos(CIV_EOM, buf)                       = 0
Pos(Char($FE) + Char($FE), buf)         = 1
```

`ProcessCIVMessage` was reporting *"8 byte(s) in the buffer with no preamble:
FE FE A2 E0 27 11 01 FD"* — for a buffer that plainly starts with the preamble.
An untyped character constant is still 8-bit, so passing one as a string
**parameter** converts it through the codepage and the needle becomes U+FFFD.

**Comparisons were never affected** — `frame[1] <> CIV_PREAMBLE1` and
`frame[Length(frame)] <> CIV_EOM` work with either spelling, because the
compiler widens the constant in a comparison. Only the three `Pos()` calls
broke, which is precisely why every hand-written check around them succeeded
and the frames still went nowhere.

`readTerminator := CIV_EOM` is corrupted by the same conversion, so **this is
not network-only — it reaches serial CI-V too.**

Fixed by declaring the three constants `: Char`.

### 12.3 The bench harnesses do not include `tr4w.inc`

Found while chasing 12.2, and it bit this work directly: **no harness in the
tree includes it** — not `tr4w_unit_tests.dpr`, not `bench_k4spectrum.dpr`, not
this bench until it was added. They therefore compile with an 8-bit `string`
while every unit under `src` uses UTF-16.

For a test that passes ASCII around the difference is invisible. For one that
hands raw protocol bytes to a driver it is not: this bench's probe frames were
built with `Char($FE)` under an 8-bit `Char`, and handing them to `SendToRadio`
converted them through UTF-8 — so every probe went out as
`FFFD FFFD FFFD FFFD 27 12 FFFD` and the radio ignored all of them, which reads
exactly like a radio that does not implement the command.

**A bench for a binary protocol must compile under the same string regime as
the code it exercises, or it is testing a different program.** Only
`bench_icomscope.dpr` was changed here; the same gap remains in the other two
and is worth closing deliberately.

### 12.4 The same shape exists in `uRadioYaesuBinary` — reported, not changed

`TYaesuBinary.SendBytes` (`uRadioYaesuBinary.pas:302`) builds its 5-byte frame
with `Chr(b0) + Chr(b1) + …` from `Byte` **parameters** — the broken form.

NY4I's position (2026-08-26) is that the Yaesu worked after the string
conversions and that this needs testing in the program before anything is
changed. **Nothing was changed.** What can be stated precisely:

* `Chr(b)` with a variable at or above `$80` yielding U+FFFD is *measured*, not
  inferred.
* Whether a given Yaesu frame is affected depends on whether any of its five
  bytes reaches `$80`.
* The **FT-1000MP's main status poll is safe** — `SendBytes($00,$00,$00,$03,$10)`
  (`uRadioYaesuFT1000MP.pas:197`) is entirely below `$80`. That is the command
  behind the frequency and mode display, which is consistent with the radio
  appearing to work.
* The **split-flags read is not**: `SendBytes($00,$00,$00,$01,$FA)` (`:198`)
  carries `$FA`, which would go on the wire as `$FD`.
* BCD frequency bytes (`:323`) exceed `$80` only for digit pairs of 80–99, so
  set-frequency would fail on *some* frequencies and not others.

So "the radio worked" and "there is a latent defect in specific commands" are
both consistent with the evidence. The way to settle it is the bench NY4I asked
for, watching the split-flags read in particular.

### 12.5 The panadapter held a radio it did not own

Found from NY4I's `tr4w.log` on 2026-08-26, after switching a K4 profile to
"FT1000/K3" with the panadapter open:

```
[CRASH] unhandled EAccessViolation in thread (main)
  at  SHOWSPAN,           line 1288 of src/ui/lcl/uPanadapterForm.pas
      UPDATELABELS,       line 1733
      HANDLEREFRESHTIMER, line 980
```

plus six `[Elecraft K4 spectrum] link lost: Access violation` from two K4
spectrum threads still reconnecting to the *old* profile's radios a second
after the switch.

**`FRadio` was non-nil but DEAD.** Every nil guard in the window passed,
because the pointer was not nil — the object behind it had been freed. A
panadapter holds a raw `TFactoryRadioBase` it does not own, and nothing told it
when a profile change destroyed that object.

The hazard was already known one layer down:
`RadioObject.ShutDownRadioInterface` carries the comment *"This prevents the
old thread from accessing freed memory (dangling pointer AV)"*. The panadapter
is a second holder of exactly that kind, added long after that comment was
written.

**The fix, and where it had to go.** `PanadapterRadioGoingAway(ARadio)` in
`uPanadapterForm`, called from `ShutDownRadioInterface` **before** `Disconnect`
and `Free` — while the object is still alive, because the window's teardown
calls `StopSpectrum`, which terminates and *joins* the reading thread, and
neither is possible against freed memory. Doing it after the free is not a
weaker fix, it is an impossible one.

**Two callers, two behaviours, and the difference is not cosmetic:**

| caller | flag | why |
|---|---|---|
| `ShutDownRadioInterface` (profile change) | close | the radio is gone; an empty frame is worse than no window. NY4I: *"if the radio does not support a spectrum scope, those windows should be closed."* |
| `MainUnit` shutdown | **detach only** | closing records `visible=False`, which at exit would silently discard "this window was open" and stop it reopening next run |

`MainUnit` frees the radios directly rather than through
`ShutDownRadioInterface`, so it is a second free site and needed its own call.

**And the Spectrum button now follows the radio.** `UpdateSpectrumButton`
already re-read `tFactoryObject` and asked both gates; nothing *called* it on a
profile change. `RadioPanelsRefreshActive` now runs at the end of
`SetUpRadioInterface` — the one routine every apply path goes through, rather
than each of `CATDlgProc`'s several.

**NOT YET VERIFIED.** The main-thread crash has a confirmed cause and the fix
is at the right layer. The six thread-level AVs are *consistent* with the same
teardown window and should go with it — detaching first means `StopSpectrum`
joins the thread before anything is freed — but that has not been reproduced
since the fix. The test is: K4 profile, panadapter open, switch to FT1000/K3.
