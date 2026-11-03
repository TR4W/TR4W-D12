# The panadapter: the K4 spectrum stream, and the pure-LCL window that shows it

**Status: DESIGN, not yet implemented.** Written 2026-08-25, after capturing the
real stream off NY4I's K4 and before any TR4W source was touched.

**Method note.** The wire format in section 1 was **measured**, not read off a
spec and not inferred from TR4QT's decoder. `tools/k4panwatch.py` captured 2706
packets over 75 s from the K4 at 192.168.73.108:9201 and checked every structural
claim independently. That matters because the only prior description available
was a *reading* of TR4QT's C++ (`src/radio/K4PanadapterReader.cpp`), and three of
the things that reading implied turned out to be wrong or incomplete — see §2.

The capture tool is kept, and 30 packets of it are frozen at
`tr4w/test/unit/fixtures/k4pan-sample.bin` so the decoder can be unit-tested with
no radio present. `python tools/k4panwatch.py --replay <file>` re-runs the checks.

---

## 1. The wire format, as measured

**Transport.** Plain TCP on **CAT port + 1**. The K4's CAT default is 9200
(`uRadioElecraftK4.pas:966` registers it), so the panadapter is 9201.

Three facts established by capture, each of which changes the code:

* **The stream is unsolicited.** Connect and packets arrive. No enable command
  exists or is needed. Measured by connecting and sending literally nothing.
* **No keepalive is required.** 75 s of total silence, zero stalls. This is the
  *opposite* of the CAT port, which drops silent clients after 10 s — the reason
  `TK4Radio.Connect` polls `PING;` every second. **TR4QT's 4-byte `"PING"`
  keepalive on the pan port is unnecessary; do not port it.**
* **~36 packets/s in total, ~12/s per pan** — about 150 KB/s. That rate is a
  design input for §4 and §6; it is not a trickle.

**Frame: 4162 bytes, fixed.** 64-byte header + 4096 payload + 2-byte CRC.
Over 2706 packets: **0 CRC failures, 0 resyncs, 0 sequence gaps.**

| Bytes | Field | Encoding |
|---|---|---|
| 0–3 | sync marker | `FF FE 01 00` |
| 4 | version | binary, = 2 |
| 5 | sequence | binary, **per pan**, wraps at 256 |
| 6 | pan ID | ASCII |
| 7–12 | **span** in Hz | ASCII (`192000`, `003000`) |
| 13–23 | centre in Hz | ASCII (`00003534390`) |
| 24–28 | noise floor ×10 | ASCII, signed (`-1259` = −125.9 dB) |
| 29–62 | reserved | **always zero — verified on every packet** |
| 63 | header checksum | makes bytes 0..63 sum to 0 mod 256 |
| 64–4159 | 2048 samples | **signed big-endian int16, ÷10 = dB** |
| 4160–4161 | CRC-16 | big-endian, over bytes 0..4159 |

CRC-16 is the nibble-table reflected-0x8408 variant, init `0xFFFF`, final
complement (table in `tools/k4panwatch.py`, and in TR4QT credited to Elecraft's
own K4LanExample). **There is no CRC-16 anywhere in TR4W today** — `uCRC32.pas`
is a zlib wrapper for CRC32 and unrelated, and `utils/networkmessageutils.pas`
has no CRC at all. This is new code and gets its own pin test.

Displayed span is `centre ± span/2`. Pan A at `192000` gives 3.438390–3.630390 MHz
for a centre of 3.534390 — which matches the axis labels in NY4I's screenshot.

### 1.1 Three pans arrive on one socket, interleaved

This is the single most important thing the capture found. In 75 s:

| pan | packets | span | samples | noise-floor field |
|---|---:|---|---|---|
| A | 902 | 192 kHz | −150.0 … −106.6 dB | ≈ −126 |
| B | 902 | 192 kHz | −160.0 … −105.9 dB | ≈ −125 |
| Y | 902 | **3 kHz** | **−2.0 … +19.4 dB** | **≈ 0 … +2** |

A and B are the two main receivers; **Y is the 3 kHz mini-pan** (Z, the second
mini-pan, was not active during the capture and has not been observed).

Two consequences:

1. **The sequence counter is per pan.** A global gap check reports constant false
   gaps. The capture tool checks per pan and reports zero.
2. **The mini-pan is on a different value scale entirely.** Pan Y's samples sit
   around 0…+19 dB with a noise floor near 0, where pan A sits at −150…−106 with
   a floor near −126. Any fixed dB window that renders one renders the other as
   a solid block of single colour.

---

## 2. What TR4QT does, and the three things not to copy

TR4QT's acquisition is `src/radio/K4PanadapterReader.cpp` — a `QTcpSocket`, a
resync loop, and a parser. The framing logic is sound and this design follows it.
Three things around it should not come across.

**2.1 It runs on the GUI thread.** Its own header says *"This class should be
moved to a worker thread"* (`K4PanadapterReader.h:36`) and nothing ever does —
there is no `moveToThread` in the tree. So 150 KB/s of parsing and CRC runs on
the UI thread. TR4W already has the right habit (a reading thread per radio) and
should start threaded.

**2.2 `PanadapterDataModel` is dead code.** It is a proper mutex/queue buffer
between reader and renderer, `PanadapterWindow` constructs it
(`PanadapterWindow.cpp:55`) — and never references it again. Packets go straight
from reader to renderer. We need the buffer it describes; we should not port the
class that was never wired up.

**2.3 The waterfall's dB window is hard-coded and wrong for this radio.**
`WaterfallImageProvider.cpp:56` computes `maxDb = -20.0f + refLevel` with an
80 dB range, i.e. a fixed −100…−20 dB window. Every pan-A sample we measured
(−150…−106) falls **below** that floor and clamps to the darkest colour. That is
not a theory: the waterfall in NY4I's screenshot is solid black, and this
explains why. It is also why the window has two separate reference sliders — the
second one exists to drag a mis-centred window back over the data.

**The fix is to scale from the packet's own noise-floor field**, which the K4
sends for exactly this purpose and which tracks each pan's scale independently.
That gives a sane default on pan A, pan B *and* the mini-pan with no user
intervention, and the ref-level control then does what it should: trim a display
that is already roughly right.

---

## 3. Where the data enters TR4W: the source seam

**Decision (NY4I, 2026-08-25): define the seam now, K4 the only implementer.**
Icom network radios and Flex both have spectrum, neither is in scope today, and
neither format is verified. Build the joint, not the machinery.

> **UPDATE 2026-08-26 -- THE SEAM HAS A SECOND IMPLEMENTER, AND IT HELD.**
> Network Icoms now produce spectrum through this same joint; see
> [`ICOM_SPECTRUM_DESIGN.md`](ICOM_SPECTRUM_DESIGN.md). `uPanadapterForm`
> needed **no Icom code at all**, which is the only real test of whether a seam
> was drawn in the right place. Two things did move out of the window and into
> the radio, because both were K4 rules living one layer too high and both
> would have been silently wrong for the second radio:
>
> * **`PrimarySpectrumSourceId`** -- `uRadioPanelForm` held
>   `K4_MAIN_PAN_SOURCE = 'A'` and handed it to every radio. An Icom's scope id
>   is a number, so that constant would have opened a panadapter that connected,
>   streamed, decoded and drew nothing, with no error anywhere.
> * **`StepSpectrumSpan(direction)`** -- section 14.1's one-kHz trim is a K4
>   rule. An Icom snaps to one of eight rungs, so a kHz step never crosses a gap
>   midpoint and both buttons are inert. The window now asks for a detent and
>   the radio decides what one is.
>
> The Icom differs from everything in section 1 in three ways worth knowing
> before reading on: it rides the **ordinary CI-V link** with no side channel
> and no new thread; it sends **uncalibrated display units, not dB**, so
> section 2.3's noise-floor reference has to be *synthesised* from the sweep's
> own levels; and its sweep is **divided into 11 or 15 segments over a serial
> link**.

Two hooks already exist in the tree marking where the others would land:
`uRadioIcomBase.pas:1635` — `$27: // Bandscope data — pushed unsolicited by
radio, not used` — and `uRadioFlexAPI.pas:43`, which already tracks `FPanHandle`
for SmartSDR.

The seam is the shape TR4W already uses for radio traits, so the window never
asks which radio it is talking to (CLAUDE.md's hard rule for the factory):

* a **capability flag**, `rcSpectrum`, in `TRadioCapabilities`;
* a **neutral frame record** that names no vendor:

```pascal
TSpectrumFrame = record
   SourceId    : string;      // 'A','B','Y' for the K4 -- opaque to the window
   CentreHz    : Int64;
   SpanHz      : Int64;
   NoiseFloorDb: Single;      // the source's own reference -- see 2.3
   BinCount    : Integer;     // 2048 for the K4; NOT a constant
   Bins        : TSingleArray;// dB
   Sequence    : Integer;
end;
```

`BinCount` is a field and not a constant on purpose: 2048 is a K4 number, and
baking it in is the corner we were asked to avoid.

The radio publishes frames through a callback the base class declares and the
window subscribes to. `TK4Radio` sets `rcSpectrum` and implements it; every other
radio simply does not declare the capability, and the menu item greys out.

### 3.1 Three questions, deliberately kept apart

NY4I, 2026-08-25: *"it seems logical to let the class factory for the radio
specify it supports a spectrum over CAT/Ethernet but then it is up to our program
to determine if we will support that feature."* That is the
capability-versus-config split `rcCWByCAT` already documents, and it separates
three things an earlier draft of this design had merged into one:

| question | who answers | where |
|---|---|---|
| Can this **model** produce spectrum at all? | the driver | `rcSpectrum` in the constructor |
| Can **this connection** deliver it? | the driver | `SpectrumAvailable` (virtual) |
| Will **TR4W** offer the feature? | the program | beside `IsCWByCATActive`, `MainUnit` |

The middle one has to be separate from the first because a constructor cannot
answer it: `TRadioFactory` assigns `serialPort` *after* the instance exists
(`uRadioFactory.pas:154`, `:206`), and `NoPort` is `portType`'s zero value
(`VC.pas:46`), so a capability computed in the constructor would read "network"
for a serial K4 and claim a panadapter that cannot exist.

The third is separate because the transport restriction is a fact about the
*radio*, while "we only support spectrum over the network" is a decision about
*TR4W*. They coincide today and will not always: the K4 serves its stream on a
TCP port, but **Icom pushes `$27` bandscope frames down plain CI-V — a serial
link** — and `uRadioIcomBase.pas:1635` already receives and discards them. So
`rcSpectrum` says nothing about transport; each driver's `SpectrumAvailable`
does.

Nothing in the radio layer decides whether a window opens. That belongs in
`MainUnit` where the operator's setting can be ANDed in, and it arrives with the
window in step 4 — writing it now, with no window and no setting to consult,
would be machinery ahead of a consumer.

---

## 4. Threading — and why `TReadingThread` is NOT reused

The first instinct was to reuse the existing per-radio reading thread, because
`TReadingThread` already advertises exactly the right feature set
(`uFactoryRadioBase.pas:226-227`):

```pascal
fixedFrameLength: integer;      // >0: fixed-length frames, no terminator
frameValidator:   TFrameValidator;  // fails -> drop ONE byte, retry alignment
```

That is precisely a 4162-byte frame with a sync/checksum/CRC validator. **It does
not apply.** Reading the implementation rather than the declaration:

* the whole `fixedFrameLength` block (`:2333-2376`) lives inside the **serial**
  branch, operating on `FSerialBuffer`;
* `:1369` assigns `rt.fixedFrameLength := Self.SerialFixedFrameLength` only in
  the serial connect path;
* the **network** branch is one line — `cmd := FConn.IOHandler.ReadLn(Self.readTerminator)`
  (`:2442`) — a terminator read with no fixed-frame mode at all.

`ReadLn` on binary spectrum data would split frames on whatever byte the
terminator happens to be and mangle the rest. So fixed-frame framing is
**serial-only today**, and the network path cannot carry this stream as it
stands.

That leaves two routes, and the choice matters:

| | |
|---|---|
| **A. Extend `TReadingThread`'s network branch** to mirror the serial fixed-frame logic | Touches the class every one of the 100 radios depends on for its CAT link, to serve one radio's side-channel. A regression here breaks all of them. |
| **B. A dedicated `TSpectrumReadingThread`** owned by `TK4Radio`, on its own socket | **Recommended.** No change to the shared CAT path. |

**Take B**, and not only for blast radius — the two jobs have genuinely
different requirements. CAT is low-rate terminated text where a `string`-based
`TProcessMsgRef` (`uFactoryRadioBase.pas:27`) is fine. Spectrum is 150 KB/s of
binary frames, where `Copy`/`Delete` churn on a `string` buffer for every one of
36 packets a second is the wrong container, and the natural hand-off is a record,
not a `string`.

The rest follows TR4W's existing radio-thread conventions: the thread owns the
socket, reconnects with the established backoff, and hands frames to the UI
through the callback seam. **`TThread.Queue` must not be used** — it purges its
own callback in FPC; use `Synchronize`, which is exempt.

A bounded queue sits between thread and window, with **drop-oldest** on overflow.
At 12 frames/s per pan a stalled UI must never grow an unbounded backlog, and for
a spectrum display the newest frame is the only one that matters.

---

## 5. The window: pure LCL, no Win32, no HWND

**Decision (NY4I, 2026-08-25): "please ensure you do not use any win32 or hwnd
code at all" / "Yes pure LCL only".**

This rules out most of the band map's plumbing, which is LCL-designed but still
opened the legacy way. What may and may not be reused:

| | |
|---|---|
| `CreateTR4WBandMapWindow: HWND` returning `Form.Handle` (`uBandMapForm.pas:874`) | **NO** — returns an HWND |
| a branch in `OpenTR4WWindow` (`MainUnit.pas:5506`) | **NO** — stores `WndHandle: HWND`, ends in `SetWindowPos` |
| `ShowModalOverWin32Parent` (`uLCLFormHelpers.pas:429`) | **NO** — `Windows.EnableWindow`; also irrelevant, this window is modeless |
| ~~`OwnFormByMainWindow`~~ `LeaveFormUnowned` | **OK** — HWND-free. Since issue #1 (2026-10-29) the panadapter has NO owner form, so the main window can be raised above it; `OwnFormByMainWindow` is for modal dialogs only |
| `TWindowLayoutStore` (`uWindowLayoutStore.pas`) | **OK** — name-keyed JSON; HWND appears only in a comment about the record it replaced |

So: a plain `TForm` descendant with a `.lfm`, shown with `Show`/`Hide`, geometry
persisted by name through `TWindowLayoutStore`, opened by a path that never
produces a handle. The window is a *subscriber* — it holds no socket and knows
no IP address. (TR4QT's window re-parses the radio profile itself to find the
host; with the seam in §3 that duplication does not arise.)

---

## 6. Rendering

This introduces **the first raster drawing surface in TR4W.** There is no
`TPaintBox`, no `TBitmap`, and no `BitBlt`/`ScrollDC` anywhere in `src` today;
all existing custom painting is grid `OnDrawCell` (the band map's is the richest,
`uBandMapForm.pas:505-649`). So there is no in-tree precedent to follow, and the
closest portable reference is TR4QT's CPU path, `WaterfallImageProvider.cpp`,
whose approach ports directly:

* a **256-entry RGB lookup table** per palette, rebuilt only when the palette
  changes — never a per-pixel gradient computation;
* **nearest-neighbour decimation** of 2048 bins onto the pixel width;
* **scroll by one row with a single move** of the pixel buffer, then write only
  the new top row.

In LCL that is a `TBitmap` with `RawImage`/`ScanLine` access (or `TLazIntfImage`)
blitted into a `TPaintBox` — *not* per-pixel `Canvas.Pixels`, which would be
hopeless at this rate. The spectrum trace is an ordinary polyline on the canvas.

**Scale from `NoiseFloorDb`, not from constants** — §2.3. Default the window to
roughly `[floor − 10 dB, floor + 60 dB]` and let the ref control trim it; the
exact defaults are a bench-tuning question, not a design one.

**Repaint on a timer, not per frame.** Frames arrive at ~12/s per pan; the
display should coalesce whatever has arrived and repaint at a fixed rate, so a
burst cannot drive the paint path.

---

## 7. v1 scope

Agreed with NY4I 2026-08-25. **In:** spectrum trace, waterfall, the five
palettes, the ref/averaging/waterfall-range/pause controls, **click-to-tune**
(left = VFO A, right = VFO B) and the **DX spot overlay**. **Out of v1:** the
sub-receiver / dual-pan window.

Note the interaction with §1.1: "Pan A only" is a *display* choice, and the
socket still carries A, B and Y. The reader must therefore route by pan ID into
the model rather than discard — dropping two-thirds of the stream at the parser,
as TR4QT does, is what makes adding pan B later a rework instead of a setting.

Two couplings to design when we reach them, both of which reach outside this
window: click-to-tune has to nominate a radio (SO2R and the interlock both have
opinions about which), and the spot overlay must re-filter whenever centre or
span changes.

---

## 8. Order of work

1. **DONE — the decoder, with its pin test.** `uSpectrumTypes` +
   `uK4Spectrum` + `uCRC16`, driven from
   `tr4w/test/unit/fixtures/k4pan-sample.bin`. Pure: no socket, no UI, no radio.
   The fixture holds all three sources so the scale difference in §1.1 is
   covered, and the CRC is pinned to its published check value (`$906E`) as well
   as to the capture.
2. **DONE — the seam.** `rcSpectrum` + `SpectrumAvailable` +
   `OnSpectrumFrame`/`PublishSpectrumFrame` on `TFactoryRadioBase` (§3, §3.1).
3. **DONE — `TK4SpectrumThread`** and `TK4Radio`'s second socket (§4), plus
   `StartSpectrum`/`StopSpectrum`/`SpectrumStreaming`/`SpectrumLinkUp`.
4. **DONE (window) / OPEN (menu)** — `uPanadapterForm` (`.lfm` + `.pas`), a pure
   LCL designed form: spectrum trace, frequency axis, link status. Opened by
   `ShowPanadapterWindow`, which produces no handle and registers nothing in the
   legacy window table.

   **Two pieces of step 4 are deliberately NOT done yet**, and neither is a
   detail:

   * **The menu item.** TR4W's menu is a compiled Win32 resource: `res/Tr4w.rc`
     built into per-language `.RES` files that are checked in as binaries, with
     captions coming from language constants. Editing it means regenerating a
     checked-in binary that every menu in the program depends on, and it
     collides with the `resourcestring` I18N work arriving from another
     worktree. That is its own change, not a rider on this one.
   * **The program-layer decision from §3.1** (`ActiveSpectrumRadio` /
     `IsSpectrumActive` beside `IsCWByCATActive`). It has no consumer until the
     menu exists, and writing it now would be an unused function whose only
     caller is hypothetical. It lands with the menu.

   Until then the window is driven by `tr4w/test/bench/bench_panadapter.lpr`,
   which opens it through the real `ShowPanadapterWindow` against a real radio
   and **writes a PNG of the result** — because "the trace is flat / clipped /
   upside down / absent" is not something a frame counter can tell you.

   **Bench result, 2026-08-25** — pan A (192 kHz) and pan Y (3 kHz) both render
   correctly from the same code, with the mini-pan's live signal visible at
   centre. That pair is the evidence for §2.3: the two are on completely
   different dB scales, and scaling from each frame's own reported noise floor
   is what lets one renderer serve both.
5. **DONE — the waterfall, the five palettes, and the scale control.**

   **Scaling now follows the radio's own model** (§10.1): reference at the
   bottom, scale upward, 80 dB default — the same `#REF` + `#SCL` pair the K4
   uses, taken from the packet's noise floor so it still needs no CAT link. The
   scale is adjustable over the K4's own 10..150.

   **The waterfall stores dB, not pixels.** TR4QT's `WaterfallImageProvider`
   scrolls a bitmap and writes coloured pixels, which bakes the palette and the
   scale into the history: change either and the old rows keep the old colours,
   leaving a seam across the display. Keeping decimated dB values instead
   (~450 KB) means a palette or scale change re-renders the whole waterfall.
   **Verified on the bench** by switching palette half way through a run — the
   entire history re-coloured, no seam:
   `tr4w/test/bench/wf_noseam.png`.

   A second, subtler version of the same bug: the waterfall stores dB
   **relative to each row's own noise-floor reference**, not absolute dB. Storing
   absolute dB and colouring against the newest reference re-tinted the whole
   history whenever the noise floor moved — a band change painted a green band
   across everything above it. Evidence: `tr4w/test/bench/wf_rel.png`.

   Those two PNGs are the only bench snapshots kept (NY4I, 2026-08-25); the other
   ten from the render loop were dropped as superseded. Nothing compares them
   automatically — they are a record of two colour artifacts that a written
   description conveys badly, not a golden master.

   Bench-found and fixed, neither visible by reading: Fire-Ice originally
   started at full blue and flooded the display, because at an 80 dB scale the
   noise floor sits at t≈0.1..0.3 and every palette must stay dark through
   there. And LCL's `TTimer` publishes no `Left`/`Top`, which `lintlfm` caught
   before it could break streaming at runtime.

6. **DONE (drawing) / OPEN (real spot data)** — click-to-tune, the cursor
   readout, **both VFOs on one pan**, and the DX spot overlay.

   * **Click-to-tune** verified against the radio: a click at 25% width landed
     70 Hz from prediction, which is the rig's tuning step. Left tunes VFO A,
     right tunes VFO B. The CW offset is a pure function in `uSpectrumTypes`
     with its own tests; `CWPitchHz` defaults to 0 because **nothing in TR4W
     knows the receiver's CW pitch** — see §11.
   * **Both VFOs on one pan** (NY4I, 2026-08-25), as QK4 does: markers, RIT
     applied, passbands from the rig's filter width. Colours match QK4's
     exactly — A `#00BFFF`, B `#00FF00` — verified at the pixel level. Needs
     the CAT link, since the stream carries the pan's centre and not where each
     VFO is tuned.
   * **The frequency axis is DRAWN**, not laid out in labels. Three fixed-
     position `TLabel`s bunched at the left when the window was widened, and
     the middle one went on claiming to be the centre frequency while sitting
     nowhere near it. Ticks land on round numbers (1/2/5 × a power of ten) with
     decimals following the step, so the 3 kHz mini-pan still reads.
   * **Spots come through `uPanadapterView`**, a procedure-variable seam shaped
     like `uBandMapView` — so the window still depends on nothing but
     `uSpectrumTypes`, `uFactoryRadioBase` and the seam. **The real provider is
     not written**; the bench installs a synthetic one to exercise the drawing.
   * **Band-plan headers: dropped** (NY4I, 2026-08-25). QK4 draws them, but they
     are ITU-region dependent — QK4 carries a per-user `iaruRegion` setting for
     it — so they are their own piece of work, not a rider here.

---

## 11. What is NOT done

* ~~**The menu item.**~~ **Partly done, 2026-08-26.** The window is reachable
  from the **Spectrum button on the radio panel** (`OpenPanadapterForSlot`), and
  reopened at start-up if it was open at shutdown (§13.1). What is still missing
  is the **Windows-menu entry and an accelerator**, and that is blocked on the
  menu work rather than on this: a `tw_` window reads its caption back out of
  its menu item, so it cannot become one until that coupling goes. See
  `docs/MENU_ACTIONLIST_PLAN.md` §3.
* **The real spot provider** behind `uPanadapterView`.
* **CW pitch.** There is none anywhere in the radio factory, and `Config.CWTone`
  is TR4W's SIDETONE, not the receiver's pitch. Until that is settled
  click-to-tune is exact on SSB/data and a pitch off on CW. NY4I's call: leave
  it at 0 rather than guess.
* ~~**The golden-master corpus has not been run** on this branch.~~ Run
  repeatedly since, green (22/0/4) — it is one of the four gates every
  panadapter commit passes.
* **Outside this work:** freeing a radio whose CAT link is still open
  access-violates; `Disconnect` first and it does not. That is in
  `TFactoryRadioBase`, which all 100 radios inherit.

Steps 1 and 2 are provable by unit test. From step 3 on nothing is provable by
code review, which is why `tr4w/test/bench/bench_k4spectrum.lpr` exists: it
drives `TK4Radio` against a real K4 and fails if it decodes nothing.

**Bench result, 2026-08-25, K4 at 192.168.73.108** — 20 s, **729 frames, 243
from each of A/B/Y, 36–38 frames/s, link up throughout**. Centre, span and noise
floor matched `tools/k4panwatch.py` exactly on all three sources. That agreement
is the useful part: two independent implementations, one Python and one Pascal,
reading the same radio. Unlike the serial bench there is no simulator here, so
this is evidence about the radio rather than self-consistency.

## 9. Open questions

* **Pan Y's scale.** We measured that it differs; we have not established *what*
  it is (dB above its own floor? an AGC-relative unit?). Scaling from the
  reported floor sidesteps needing to know, but the axis labelling on a mini-pan
  cannot be honest until someone does.
* **Pan Z** has never been observed. Presumed the second mini-pan.
* **Does the K4 accept more than one connection to 9201?** Untested. It matters
  if the operator also runs Elecraft's own client.
* **What changes the span?** The K4 was left alone during the capture, so the
  span field never varied. The window must handle it changing mid-stream.

---

## 10. The K4's own display settings — measured, and deliberately not used

NY4I asked whether the waterfall colours should come from the radio. They do
not, and that is now a decision rather than an oversight.

The K4 **does** publish its display settings on the CAT port as `#` commands.
TR4QT sees them and discards them (`K4Radio.cpp:249`).

**UPDATED 2026-08-26: TR4W's driver now handles exactly one of them, `#SPN`,
and the rest are still dropped.** See section 14 -- the span had to be read
because the +/- buttons must step from what the RIG is set to, not from what
the frame happens to be drawing. The title of this section still holds for the
other 24: the waterfall colours, reference level and dB scale remain TR4W's,
deliberately.

**UPDATED 2026-11-02: the display reports are PARSED AND STORED, still NOT
DRAWN** (stages 1-2 of the K4 display-state work; see 10.3). `#REF`, `#REF$`,
`#SCL`, `#WFH`, `#HWFH`, `#WBS`, `#HWBS`, `#AVG`, `#FPS` and `#AR` are decoded
by `uK4DisplayReport` and held on the radio (`SpectrumRadioState`). Nothing the
panadapter draws has changed.

**UPDATED 2026-11-03: the window FOLLOWS `#WFH`, `#WBS` and `#WFC`** (the LCD
waterfall height, colour range and colour mode), and nothing else. See 10.5.
`#WFC` is now parsed and asked.

**UPDATED LATER 2026-11-03: the window also follows `#REF`** (the trace's
bottom is the rig's reference, and each new waterfall row is stored against
it), **the K4's blue tone has a palette of its own**, and **a reconnect keeps
the picture** -- the radio holds what it last reported. `#SCL` is carried but
NOT drawn: the scale slider's fate is NY4I's decision. See 10.6.

**QK4 is the better reference here, and by a distance.** NY4I pointed at
`c:\projects\qk4\src\models\radiostate\spectrumdisplaystate.cpp`, which parses
**25** of these commands with a documented range apiece, and
`src/controllers/spectrumcontroller.cpp`, which shows what it does with them.
`tools/k4catwatch.py` now queries QK4's full list; every one was answered
(measured 2026-08-25):

| command | value | meaning | QK4 range |
|---|---|---|---|
| `#REF` / `#REF$` | `-126` / `-125` | reference level, Main / Sub | −200..60 (Programmer's Reference D12, per QK4 at `485a7c15`; was recorded here as −200..50) |
| `#SCL` | `80` | **dB scale (display range)** | 10..150 |
| `#SPN` / `#SPN$` | `100000` | display span, Hz | 1..999999 |
| `#WFC` | `1` | **waterfall colour scheme** | **0..4** |
| `#WFH` / `#HWFH` | `50` / `50` | waterfall height, % | 0..100 |
| `#AVG` | `2` | averaging | 1..20 |
| `#WBS` / `#HWBS` | not captured | waterfall colour range, LCD / external | 5..30 |
| `#FPS` | `12` | frames per second | 1..30 (was recorded as 12..30) |
| `#MP` / `#MP$` | `0` / `-1` | mini-pan enable, Main / Sub | bool |
| `#DPM` / `#HDPM` | `0` / `0` | dual-pan mode, LCD / external | 0..2 |
| `#DSM` / `#HDSM` | `1` / `1` | display mode, LCD / external | 0..1 |
| `#PKM` | `0` | peak hold | 0/1 |
| `#FRZ` | `0` | freeze | 0/1 |
| `#FXT` / `#FXA` | `0` / `1` | fixed tune / mode | 0/1, 0..4 |
| `#VFA` / `#VFB` | `2` / `2` | VFO cursor | 0..3 |
| `#AR` | `1206+041` | AutoRef | *see below* |
| `#NB` / `#NBL` | `0` / `8` | DDC noise blanker / level | 0..2, 0..14 |

### 10.1 What this changes

**`#WFC` is 0..4 — five colour schemes.** That answers the original question
concretely, and explains TR4QT's five palettes: they are the K4's five. If TR4W
ever wants to match the rig, the mapping is a five-entry table and nothing more.

**`#REF` + `#SCL` *is* the K4's vertical scaling model**, and it is the same
shape as the one invented in §2.3 without knowing that. The radio reads
ref = −126 with scale = 80 dB; `uPanadapterForm` uses noise floor − 10 with a
70 dB window. Since AutoRef is on, `#REF` equals the noise floor the stream
already carries — **so TR4W can match the radio's scaling exactly without ever
reading CAT**, simply by using the packet's noise floor as the reference and 80
dB as the range. That is a step-5 decision, not a change to make blind.

**`#WFH50`** says the radio splits its own display half spectrum, half
waterfall; QK4 uses 0.35 for the spectrum. Both are useful defaults for step 5.

### 10.1a The RADIO states the display numbers, not the window (2026-11-02)

The default scale (80 dB), its slider range (10..150), the margin under the
reference (10 dB) and the waterfall's share of the height (0.5) were constants
in `uPanadapterForm` -- K4 numbers applied to every radio. They are now a
`TSpectrumDisplayDefaults` record (`uSpectrumTypes`, no LCL) returned by the
virtual `TFactoryRadioBase.SpectrumDisplayDefaults(sourceId)`:

- **base**: `SpectrumDisplayDefaultsNone` -- all zero and NOT valid, so a driver
  that declares `rcSpectrum` and forgets to state its numbers is caught;
- **`TK4Radio`**: the old constants, `LevelsCalibrated = True`, one record for
  pans A, B and Y;
- **`TIcomRadio`** (gated on `rcSpectrum`): the SAME numbers, because that is how
  the window had always drawn an Icom, `LevelsCalibrated = False`. They are a copy
  owned by the Icom family, so tuning the Icom display later is an Icom edit.

The window reads the record in `AttachRadio`. The slider is reset to the radio's
default and range only on the first attach or when the SCALE RANGE (default,
min, max) differs from the one in force (`SpectrumScaleRangeDiffers`) -- attach
runs on every reshow and profile change, and a K4 and an Icom state the same
scale while differing in `LevelsCalibrated`, so switching between them keeps
the operator's slider exactly as before.

**The designed form carries no scale** (NY4I, 2026-11-02): the `.lfm` slider has
the LCL's default range, no position, `Enabled = False`, and the label reads
`-- dB`. The first attach therefore always sets the radio's range and default
and enables the slider (`SpectrumScaleNeedsReset`, pure and unit tested); a
refused attach disables it again, so it never steps from an invented value.
The Y mini-pan stays on the K4's shared record (NY4I, same day).
An invalid record is refused with an ERROR and a red status, never drawn with
borrowed numbers. `LevelsCalibrated` has no reader yet -- it is there for a dB
label that can say "relative" on an uncalibrated source.

Pinned by `uTestSpectrumDisplayDefaults`, which walks the registry: every
`rcSpectrum` radio states a valid record AND exactly the pre-move constants (the
no-pixel-change proof; a deliberate change updates that pin), every other radio
states the neutral one. The five palettes stayed in the window: they are TR4W's
own, only their COUNT echoes `#WFC`. (Since 2026-11-03 the radio's `#WFC`
selects one of them by tone -- 10.5.)

### 10.2 Two things that do NOT line up — do not build on either

**`#MP` reads 0 (mini-pan Main off) while pan `Y` is streaming.** TR4QT asserts
`'Y'`/`'Z'` are the mini-pans, and pan Y's 3 kHz span centred near VFO A
certainly looks like one. But QK4 sends `#MP$0;` explicitly to *"Disable
Mini-Pan B streaming"*, so `#MP` does appear to gate streaming — and it reads 0
here while the data flows. Either `#MP` governs the radio's own screen rather
than the network stream, or `Y` is not the mini-pan. **Unresolved.**

~~**QK4's `#AR` handler would ignore this radio.**~~ **Resolved upstream.**
QK4's handler did expect 12 characters ending `'A'`/`'M'`, against an invented
format; QK4 `485a7c15` (`docs/k4-protocol-quirks.md` section 13, measured on a
K4D 2026-10-19) fixed it to the radio's real form `#ARaadd±oom`, 11
characters, last character `1` (auto) or `0` (manual) -- exactly what this
radio answered (`#AR1206+041`). `uK4DisplayReport` reads that form. The
lesson stands: a working reference implementation is evidence, not authority.

**`#SPN` (100 kHz) versus the stream's 192 kHz remains open.** QK4 does not
settle it: it feeds the packet's `sampleRate` into `updateSpectrum()` *and*
`#SPN` into `setSpan()`, then uses `panadapter->span()` for spot-overlay
frequency mapping (`spectrumcontroller.cpp:1020`).

Two of those are useful corroboration rather than inputs:

* **`#FPS12` independently confirms the frame rate.** It was measured at ~12
  per pan from packet arrival timing; the radio says 12. Two unrelated methods
  agreeing is worth more than either alone.
* **`#REF` tracks the packet's noise-floor field** (−126 against −125.5
  measured at the same moment) because AutoRef is on. **So the reference level
  is already in the stream**, which is why §2.3's scaling needs no CAT link.

**Decisions (NY4I, 2026-08-25):** ~~TR4W keeps **its own palette** — a large
monitor and the rig's small screen suit different schemes, and the window stays
decoupled from CAT.~~ **Reversed 2026-11-03 (NY4I): the window follows the
K4's `#WFC`, `#WFH` and `#WBS` -- see 10.5.** ~~The window renders the **full 192 kHz** the stream carries.~~
**Reversed for the K4 on 2026-11-03 (NY4I approved crop-to-`#SPN`)**: the main
pan is drawn at the radio's own span, centred, because the full frame carries
about 40 bins of padding at each end that drew as a flat line at the bottom of
the plot. See 10.4. The window itself did not change.
~~And the `#` commands are **not parsed** for now~~ -- **superseded 2026-11-02**:
they are parsed and stored, not drawn (10.3). The stream still provides
centre, span and noise floor, so nothing was blocked; the parse is groundwork
for the window following the radio's front panel.

### 10.3 Stages 1-2: the radio's display reports, parsed and owned by the radio (2026-11-02)

NY4I approved a staged design: the panadapter will later follow REF, SCALE,
waterfall height, averaging and the rest as the operator changes them at the
K4. **Stages 1 and 2 add parsing and radio-owned state ONLY** -- no change to
what the window draws, no command that changes the radio, nothing on the Icom
path.

- **Stage 1 -- `uK4DisplayReport`** (radio factory, pure, no LCL, the
  `uElecraftIF` pattern). `ParseK4DisplayReport(msg, var state)` decodes
  `#REF<v>` (main) and `#REF$<v>` (sub), −200..60; `#SCL` 10..150 (one value
  for both receivers); `#WFH`/`#HWFH` 0..100 %; `#WBS`/`#HWBS` 5..30; `#AVG`
  1..20; `#FPS` 1..30; and `#ARaadd±oom` (averaging 01..20, debounce, signed
  offset −8..+8 dB, `1`/`0`). Leading zeros are accepted and not required --
  which the radio sends is not known. A malformed or out-of-range value
  returns False and changes NOTHING. `#SPN` stays where it was;
  `#HREF`/`#HREF$` are deliberately not read (they are pushed beside `#REF`
  under AutoRef and must not be mistaken for it).
- **Stage 2 -- `TSpectrumRadioState`** (`uSpectrumTypes`, vendor-neutral): a
  `Has` flag per value, plus a `Generation` that moves on EVERY accepted report
  (a repeat included), ~~and on every reset~~ (no reset since 2026-11-03,
  10.6), never back to 0. The virtual
  `TFactoryRadioBase.SpectrumRadioState(sourceId)` answers "nothing known"; the
  Icoms and the Flex inherit it. `TK4Radio` records reports on the reading
  thread under its own `FDisplayStateLock` and returns them by value: source
  `A` = main, `B` = sub, anything else (the `Y`/`Z` mini-pans) unknown.
  ~~Cleared at the top of every `Connect`~~ -- **held across a reconnect since
  2026-11-03** (NY4I; 10.6), so a value stands until the radio reports a new
  one. At link-up it asks
  `#REF;#SCL;#AR;#WFH;#WBS;#WFC;#AVG;` (`#WFC` since 2026-11-03, 10.5) on a
  line of its own beside `#SPN;` --
  **reads only**, and pinned so: a client `#REF` value freezes AutoRef, and
  `#AR0;` resets it.

**Open, and in `docs/BENCH_QUEUE.md`:** whether the radio PUSHES `#SCL`,
`#WFH`, `#WBS` and `#AVG` on a front-panel change (the quirks doc confirms it
for `#AR` and, under AutoRef, `#REF`); whether a bare `#REF;` read is as
harmless to AutoRef as it should be; the range of the `#AR` debounce field
(QK4's command table says 4..9, the radio has sent `01` and `06`); and
whether the sub receiver's REF should be asked too (`#REF$;` is not asked
today).

Pinned by `uTestK4DisplayReport` (the parser), `uTestSpectrumRadioState` (the
radio and a registry walk) and
`uTestRadioSocketNoRead.Test_DisplayStateAskedOnConnect_ReadsOnly`.

**~~One genuinely open discrepancy.~~ RESOLVED 2026-08-26.** `#SPN` reported
**100 kHz** while the stream reported **192 kHz**, measured within seconds of
each other, and this section called it unexplained.

The two are simply **different quantities**, and both are correct:

| | |
|---|---|
| `TSpectrumFrame.SpanHz` | what is being **drawn** — the width of the data in this packet |
| `#SPN` | what the rig's display is **set to** |

So **step from `#SPN`, draw from the frame.** Getting that backwards is what
made the span buttons behave randomly on 2026-08-26: they stepped from the
frame's 384 kHz while the rig sat at 368 kHz, so the first press appeared to
jump. It also explains the mini-pan, which this section flagged as odd: `#SPN$`
reads 100000 while pan Y streams 3 kHz because the sub-receiver's *display
setting* and the mini-pan's *stream* were never the same number.

**And the rig CLAMPS and tells you.** Asking `#SPN500000` returns `#SPN368000`
— a request outside range is not an error, it is a different answer, so read
the reply rather than assuming the request took.

"Draw from the frame" still holds, with one change since 2026-11-03: for the
K4's main pan, the frame the window gets is the one the RADIO has cut to
`#SPN` (10.4). The window still draws exactly what it is handed.

### 10.4 The K4 main pan is cropped to `#SPN` by the radio (2026-11-03)

**Why.** A K4 frame is 2048 bins at a fixed frame width the radio chooses to
cover `#SPN`. Measured in the 2026-11-02 span sweep (`k4pan-tiers.bin`,
`#SPN` set to 5k, 10k, 20k, 40k, 80k, 150k, 190k, 250k and 368k):

| `#SPN` | frame width |
|---|---|
| 5000, 10000 | 24 kHz |
| 20000 | 48 kHz |
| 40000, 80000 | 96 kHz |
| 150000 | 192 kHz |
| 190000, 250000, 368000 | 384 kHz |

Every frame wider than 24 kHz carries a **fixed number of pad bins** at each
end: a plateau of about 40 at the frame floor (−150, −160, −168 or −174 dB,
depending on the pan and the width), then 2-3 bins of roll-off. The median is
43 on the left and 42 on the right. The worst seen is 49 on the left and 46 on
the right, both at 384 kHz; at 48, 96 and 192 kHz it is 42 and 41. The
2026-08-25 capture (`k4pan-sample.bin`, 192 kHz) agrees: bins 0..38 and
2010..2047 are at least 8 dB below the frame median on all 20 A/B frames.
Drawn in full, that pad was a flat line at the bottom of the plot at both
edges, and the axis showed a span wider than the operator had set. QK4 draws
only the `#SPN` window, centred. NY4I approved doing the same (option ii,
2026-11-03).

**Where the code lives. In the radio, not in the window.** `TK4Radio.HandleSpectrumFrame` (spectrum
thread) passes every frame except source `A` through unchanged. For source `A`
it calls `uSpectrumTypes.SpectrumCropCentred(frame, FSpectrumSpanHz,
K4_EDGE_GUARD_BINS, FCropBins, cropped)` and publishes the result. The window,
the axis, click-to-tune and the waterfall are unchanged and draw what they
receive. `DecodeK4Frame` still decodes the wire exactly as sent.

- **Only pan A.** `#SPN` is the main pan's span. `#SPN$` (the sub's) is not
  tracked, so B is never cropped with A's number. Y and Z pass through.
- **Unknown `#SPN` (0), or `#SPN` not narrower than the frame:** the frame
  passes through whole.
- **Exact, not approximate.** Bin i of the crop has the same `SpectrumBinHz`
  as bin (i + first) of the original, to the Hz. That requires a kept count n
  with n × SpanHz divisible by 2 × 2048. n is the multiple of that step
  NEAREST 2048 × `#SPN` / frame width: 8 bins at 192 kHz, 4 at 384 kHz, 64 at
  24 kHz, which is **750 Hz at every K4 width**. So the drawn span is within
  375 Hz of `#SPN` (5000 draws 5250, 20000 draws 20250, 250000 draws 249750).
  The new SpanHz is exactly n × width / 2048, and CentreHz is unchanged.
- **`K4_EDGE_GUARD_BINS = 49`** (the worst pad observed). n never exceeds
  2048 − 2 × 49. This matters only at the top of a width. A plain crop to
  `#SPN 368000` keeps 1964 bins and leaves up to 7 pad bins visible. Guarded,
  it keeps 1948 bins, and **the 368 kHz maximum draws 365.25 kHz**. Every other
  measured span crops far inside the guard, so the guard does nothing there
  and needs no special case.
- **Frames at the old width.** The radio changes frame width 1-3 frames after
  it reports a new `#SPN`. A frame at the old width is cropped against its
  OWN SpanHz, so it stays self-consistent. Going UP, the new span is wider
  than the old frame, which passes through whole for those 1-3 frames, pad
  included. **Caveat, measured in the same sweep:** after `#SPN 5000`, sweep
  frames 192 and 195 have a 24000 header but 48 kHz bins. They keep the
  42/42 pad, and the carrier sits at bin 1018-1020 as in the 48 kHz frames,
  not at 1014-1015 as in the 24 kHz frames that follow. So the header can
  change about two frames BEFORE the content. Such a frame is drawn
  mislabelled, cropped or not. That predates the crop, and the crop does not
  fix it. One of those frames is in `k4pan-tiers-sample.bin`.
- **Threads and memory.** `FSpectrumSpanHz` is written on the reading thread
  and read once per frame on the spectrum thread with no lock. It is an
  aligned Integer, so the read is atomic. `FCropBins` is touched only on the
  spectrum thread and is resized only when n changes. The published frame's
  `Bins` IS that buffer, which the `TSpectrumFrameProc` contract allows: the
  subscriber copies what it keeps. `TfrmPanadapter.AcceptFrame` does `Move`
  the bins into `FShareBins` under its lock.

**The Span label.** `ShowSpan` prefers `FRadio.SpectrumSpanHz` (`#SPN`), on
purpose: it names the number the +/- buttons step. The axis now shows the
cropped span. The two agree to within 375 Hz, except at the guard-capped
maximum (label 368, axis about 365). This was **left as it is**. Labelling
the drawn span instead would make the buttons look broken near the top: 366,
367 and 368 kHz all draw 365.25 kHz, so pressing a button would often leave
the label unchanged. A label that moves with every press is the lesser
mismatch.

**Open: the waterfall mixes spans.** History rows carry no span or centre.
`EnsureWaterfall` clears them only when the bitmap changes size. Before this
change, a `#SPN` change that crossed a width already drew rows of the old
span under the new axis as if they lined up. Now every 1 kHz press changes
the drawn span, so it happens more often. Proposed fix, not built: clear the
history in `HandleRefreshTimer` when `FRenderSpanHz` changes. Do not clear on
a centre change; following the VFO is the existing behaviour.

Pinned by `uTestK4SpectrumCrop`:
- arithmetic, continuity, pass-through and buffer reuse;
- the radio: A only, unknown `#SPN`, frames at the old width;
- both captures: the pad is where it was measured, and no crop the K4 can be
  asked for keeps any of a frame's own edge pad;
- that the guard is needed at 368 kHz.

The 14-frame `k4pan-tiers-sample.bin` is cut from the sweep by
`tools/k4pan_tier_fixture.py`.

### 10.5 The window follows the K4's LCD waterfall: height, colour range, colour mode (2026-11-03)

NY4I saw a K4's waterfall height change on the rig and not in TR4W. **This is
the first time the window reads the radio's display state.** Before this,
nothing above the factory read `SpectrumRadioState`. ~~That includes `#SCL` and
`#REF`: the window scales from its own slider and each frame's noise floor, and
it still does.~~ **`#REF` is followed since later the same day (10.6); `#SCL` is
carried and not drawn.** The window follows **`#WFH`, `#WBS` and `#WFC` from the
LCD ONLY** (NY4I). The external monitor's `#HWFH`, `#HWBS` and `#HWFC` reach no
window, and `#HWFC` is not decoded at all.

**`#WFC`, plain.** The manual writes the LCD form as `#WFC$`. NY4I confirmed on
the radio that it answers `#WFC`, so `uK4DisplayReport` parses `#WFC` (0..4,
both receivers, like `#WFH`/`#WBS`), and `K4_DISPLAY_QUERIES` is now
`#REF;#SCL;#AR;#WFH;#WBS;#WFC;#AVG;`. The queries are still reads only.

**The seam.** `TSpectrumRadioState` is in the radio's own units (percent,
5..30, 0..4), so the window does not read it. A new virtual,
`TFactoryRadioBase.SpectrumLiveDisplay(sourceId)`, returns a vendor-neutral
`TSpectrumLiveDisplay` (`uSpectrumTypes`):
- **`WaterfallShare`**: 0..1 **inclusive**. 0 is trace only and 1 is
  waterfall only. `TSpectrumDisplayDefaults.WaterfallFraction` must lie
  strictly inside that range; a live value may not.
- **`ColourFloorOfScale`**: the palette's bottom sits this fraction of the
  scale below each row's reference.
- **`Palette`**: a `TSpectrumPaletteTone`, one of gray, colour, teal, blue or
  sepia.

Each value has its own `Has` flag. The base returns nothing. `TK4Radio` runs
its receiver record through the pure function `uK4DisplayReport.K4LiveDisplay`,
so pan A uses main, pan B uses sub, and the Y mini-pan gets nothing and keeps
the defaults. `SpectrumDisplayDefaults` and its pin are **unchanged**.

**The colour-range mapping is QK4's, and it is a fit, not a fact.** QK4 at
`485a7c15` (`src/dsp/waterfallgeometry`, `colorWindowFor`, and its README)
uses this:

    floor = REF - SCALE x WBS / 40, span = SCALE

That was fitted to photos of one K4D (2026-10-30, WWV, AutoRef, `#WBS` 14,
SCALE 25/50/80). QK4 states that the `#WBS` term is unverified, because every
photo was taken at 14. The manual says only that a higher WTR CLRS uses
brighter colours. TR4W's waterfall already colours each row against its own
noise floor, which is REF under AutoRef, over one scale. So the K4 states
`ColourFloorOfScale = WBS / 40` (`K4_COLOUR_FLOOR_DIVISOR`), and the window's
waterfall margin becomes that fraction times its own scale. **The trace is
untouched**: it keeps `RefMarginDb`. One anchor makes this easy to check: at
`#WBS` 5 and the 80 dB default scale, the floor is exactly 10 dB, the margin
the window has always used. At 14 it is 28 dB, which is markedly brighter.

**The scale in that formula is TR4W's slider, not the rig's `#SCL`.** The
window still does not follow `#SCL`. So a rig at SCALE 50 and TR4W at 80
colour differently at the same `#WBS`. "Unchanged at 5" holds only with the
slider at 80. Following `#SCL` is a separate decision, and it is the open fork
in 10.6: QK4's colour window uses the RIG's scale, and making TR4W's do the
same decides what the slider is for. The REF in it IS the rig's now (10.6).

**This recolours differently from QK4.** QK4 stores each row's palette position
as it was when captured, so a `#WBS` change recolours only new rows. TR4W keeps
dB and recolours the whole history, as its scale slider always has. The
difference is deliberate.

**Palettes, mapped by name, not reordered.** The rig's 0..4 is gray, color,
teal, blue, sepia. The window's combo is Heat Map, Grayscale, Sepia,
Blue-Green, Fire-Ice, and that order is kept: the combo index is what
`bench_panadapter` drives, and the radio's numbering belongs to the radio.
`PanadapterPaletteForTone` maps gray to Grayscale, colour to Heat Map, teal to
Blue-Green and sepia to Sepia. ~~It maps **blue to Fire-Ice PROVISIONALLY**.~~
**Blue now maps to a sixth palette, Blue** (NY4I, later 2026-11-03; 10.6), and
Fire-Ice stays as the operator's own choice that no radio tone selects. The
2026-08-25 decision that "TR4W keeps its own palette" (10.2) is **reversed**.

**How it reaches the window.** The window does this on every refresh tick
(50 ms), frame or no frame:
- `ApplyLiveDisplay` asks the radio, which takes a brief lock inside the K4.
- It applies a value **only when it differs from the one last applied**. A
  K4 under AutoRef pushes `#REF` several times a second, and each push moves
  `Generation`. Gating on `Generation` would re-colour the whole history on
  every push, and would undo the operator's combo choice every second.
- An unknown value resolves to the defaults exactly: 0.5 and `RefMarginDb`.
  That covers a radio that reports nothing and a K4 that has not answered
  since it was built. ~~and the reset at each reconnect~~ -- there is no reset
  any more: a reconnecting K4 holds its values (10.6). The pure resolvers are
  `SpectrumWaterfallShare` and `SpectrumWaterfallColourMarginDb`.
- The palette is the exception: unknown leaves it alone. The operator's combo
  choice stands until the radio reports a **different** scheme.
- Attach forgets what was last applied, so a first report equal to a default
  still applies. A palette the RADIO chose is also dropped back to the
  default on attach (10.6), so a new radio never inherits it.

**What happens to the history:**
- **Colour range or colour mode**: `RenderWaterfall` re-colours every stored
  row from its dB, as the scale slider and the palette combo already do. No
  row is lost and there is no seam.
- **Height**: `EnsureWaterfall` now **keeps the newest rows that fit** when only
  the height changes. Before, every resize cleared the history. A shrink
  drops the oldest rows. A width change still clears, because rows cannot be
  rescaled horizontally. This also means a window dragged taller or shorter
  keeps its history now. At 0 % the bitmap is left alone, since nothing
  draws it. At 100 % the trace is skipped but the VFO markers and the cursor
  still cross the waterfall; before, they were skipped with the trace. Issue
  #159 (history across a span change) is untouched.

Pinned by `uTestK4DisplayReport` (the `#WFC` parse, `#HWFC` refused, the
translation), `uTestSpectrumRadioState` (LCD only, unknown resolves to the
defaults, the anchors above, the tone mapping, and a registry walk in which
every fresh radio claims no live display) and
`uTestRadioSocketNoRead.Test_DisplayStateAskedOnConnect_ReadsOnly`.

### 10.6 Blue tone, `#REF` followed, and the picture held across a reconnect (later 2026-11-03)

NY4I decided the three items 10.5 left open and said to **do what QK4 does**.
QK4 was read at `origin/development` `485a7c1` (2026-11-01); its checked-out
branch at the time did not contain the waterfall commits.

**1. The blue tone. QK4 HAS NO PALETTE TO COPY.** It draws ONE colour table
for every `#WFC` value (`src/dsp/rhi_utils.h`, `generateWaterfallColorLUT`,
used by both `panadapter_rhi.cpp` and `minipan_rhi.cpp`), and `#WFC` only
labels a popup button (`displaypopupwidget.cpp`: `"WTR GRAY" .. "WTR SEPIA"`).
So TR4W's sixth palette, **Blue** (`PALETTE_BLUE` = 5, appended so the combo's
0..4 and `bench_panadapter` keep their meaning), is **TR4W's own design**:
Sepia's tone curve with the hue moved to blue -- `b = 300t, g = 220t^2 + 30t,
r = 150t^3`, clamped. It starts at black like every palette here, blue leads
at every entry, no channel ever falls, and it ends at a pale blue-white
(150, 250, 255). `sptBlue` maps to it; no tone maps to Fire-Ice. The table is
now a pure function, `uPanadapterForm.PanadapterPaletteColour(palette,
index)`, so `uTestSpectrumRadioState.Test_PaletteTable_BlueTone` pins it
without a form. Whether it looks like the rig's own blue is a bench question.

**QK4's one table against TR4W's Heat Map -- reported, not changed.** QK4's
is black up to 0.10, then dark blue (b 0..51) to 0.25, royal blue (b 153) at
0.40, blue-cyan (g 128, b 255) at 0.55, green at 0.70, yellow at 0.85, red at
1.0. TR4W's Heat Map has no black run (b 0..40 to 0.25), reaches b 160 with
g 30 at 0.40 and full cyan (g 255, b 255) at 0.55, then the same green,
yellow and red. QK4's is the table its colour window was fitted against
(photos of a K4D, 2026-10-30), and TR4W now uses the same window formula, so
NY4I may want QK4's table for "colour". Gray, teal and sepia have no QK4
counterpart at all. None was repainted.

**2. `#REF` is followed; `#SCL` is carried and waiting on a decision.**
`TSpectrumLiveDisplay` gains `HasRef`/`RefDb` and `HasScale`/`ScaleDb`, both
counted by `SpectrumLiveDisplayKnowsNothing`. `K4LiveDisplay` fills them per
receiver: `#REF` for pan A, `#REF$` for pan B, the one `#SCL` for both. The Y
mini-pan still gets nothing (its levels sit near 0 dB in this stream, so the
main receiver's REF would be wrong for it). The policy is two pure functions
in `uSpectrumTypes`:
- `SpectrumTraceFloorDb` -- the trace's bottom is REF **exactly** when the
  radio states one (QK4 `updateDbRangeFromRefAndScale`: `minDb = refLevel`,
  `maxDb = refLevel + scale`), else the noise floor less `RefMarginDb`, as
  before. **Under AutoRef that drops the 10 dB margin**: the noise sits on the
  bottom edge, as on the rig and in QK4.
- `SpectrumReferenceDb` -- what a waterfall row is stored against: REF when
  stated, else the frame's noise floor. The colour window then IS QK4's
  `colorWindowFor`, `REF - SCALE x WBS / 40` over one SCALE.

**A REF change re-colours NO history, and that is QK4's behaviour for the same
reason.** Each row keeps the reference it was captured with, so a new REF
reaches new rows only. QK4 `da384ee` made the same choice after its bench
(2026-10-30) found that a live re-colour flashed the whole waterfall on every
~1 dB AutoRef step. REF is therefore not a trigger in `ApplyLiveDisplay` at
all; the trace reads it on the next paint. **A colour-range or scale change
still re-colours the whole history** in TR4W, where QK4 recolours only new
rows (`capturedByteFor`) -- the deliberate difference 10.5 records.

TR4W's bins are on `#REF`'s scale as far as is measured: this stream carries
real dB (int16 / 10) and its own noise floor read -125.5 against `#REF -126`
(10.2). QK4's byte stream needed a measured 162 dB offset; TR4W's does not.

**THE FORK -- what the slider is when the rig states a scale.** QK4's scale
control (Shift + wheel) **sends `#SCL<n>;` to the radio**
(`SpectrumController::adjustScaleFromWheel`, 5 dB a step) and draws only the
rig's scale; there is no client-side scale. TR4W's slider is local and the K4
display path has been reads-only. So "follow `#SCL`" decides the slider:
- **(a) QK4 parity.** The slider writes `#SCL`; the rig's report drives the
  trace and the colour window. The first CAT WRITE on this path, and it moves
  the rig's own screen.
- **(b) No write.** The rig's `#SCL` sets the slider whenever it CHANGES; the
  operator's slider stands until the rig reports a different scale -- the rule
  the palette already follows. TR4W can then differ from the rig until the next
  knob turn.
- **(c) Disabled.** While the rig states a scale the slider is greyed out and
  follows it.
- **(d) An offset.** The drawn scale is the rig's `#SCL` plus the slider's
  delta from its default, so the operator can widen or narrow TR4W's picture
  relative to the rig's while still following every change made at the rig.
  The slider would then need to show a signed delta, not a dB range.
**Nothing is built for any of them yet.** The trace height and the colour
window still use the slider, so 10.5's "the scale in that formula is the
slider" still holds. Recommended: (b), because it changes nothing the operator
did not touch and adds no write; (a) if NY4I wants TR4W to drive the rig's
display.

**`#REF$` is not asked at connect** (unchanged): QK4 learns the sub's REF from
the radio's `RDY` state dump, which TR4W does not send. Under AutoRef the K4
pushes it; with AutoRef off pan B keeps the noise-floor scaling until the sub's
REF is changed at the rig. Adding `#REF$;` to `K4_DISPLAY_QUERIES` would be a
read and is allowed; it is left for the bench.

**3. A reconnect keeps the picture (NY4I).** `TK4Radio.Connect` no longer
clears the display state, and `ResetK4DisplayState` is deleted -- nothing
called it any more. A value stands until the radio reports a new one, and the
connect-time queries ask for one. The window was never told about a reconnect
-- nothing on the link-down path detaches or re-attaches it (the only
re-opener, `uPanadapterRestore`, runs once from start-up and opens each slot at
most once) -- so holding the state in the radio is the whole fix.

**Where TR4W departs from QK4, deliberately:** a reconnect holds (QK4 resets
REF, SCALE and the colour range); a SCALE or `#WBS` change re-colours the
whole history (QK4: new rows only); and with `#WBS` unknown the waterfall keeps
`RefMarginDb` = 10 dB, where QK4's `colorWindowFor` assumes `#WBS` 14 (28 dB
at SCALE 80). **QK4 does the opposite**: its
`PanadapterRhiWidget::clear()` puts REF, SCALE and the colour range back to
its defaults at the end of a session ("show the default, not the last
radio's") and keeps only the split. TR4W follows NY4I's decision, not QK4's.

**A different radio never inherits.** A radio switch is a different
`TK4Radio` -- a profile change and Reset Radio Ports both rebuild -- which
starts from `K4DisplayStateUnknown`. In the window, attach still forgets what
was last applied, which costs a held picture nothing: re-attaching the SAME
radio gets its values back on the first refresh tick, before the first frame
is drawn. A palette the radio chose (`FPaletteFromRadio`) goes back to the
default on attach; one the operator chose stays. **Known gap, reported not
fixed:** a profile change or Reset Radio Ports on the same K4 builds a new
object, so the window shows the defaults until the rebuilt radio answers its
connect queries (how long that looks is a bench question).

Pinned by `uTestK4DisplayReport.Test_LiveDisplay_CarriesRefPerReceiverAndSharedScale`
and, in `uTestSpectrumRadioState`: `Test_K4_ReconnectHoldsTheLastSession`,
`Test_PaletteTable_BlueTone`, `Test_VerticalReference_RadioOrNoiseFloor`,
`Test_Window_FirstReportEqualToDefault_TakesEffect`,
`Test_Window_ReconnectHolds_FreshReportReplaces` and
`Test_Window_RadioSwitch_InheritsNoRadioPalette` (the last three on a real,
unshown `TfrmPanadapter`).

## 12. Handoff: what lands on `fpc`, not here

Decided with NY4I on 2026-08-25 while merging this branch down. None of it is
started; all of it belongs on the main branch because it touches files the
panadapter deliberately does not.

### 12.1 Two ways in, and the button should come first

**A button on the radio panel, then a Windows-menu item.** The panel is an LCL
form since `8bd9560e`, so a button there is pure LCL -- no `.rc` resource, and
therefore no collision with the `resourcestring` I18N work arriving from the
other worktree. That is the whole reason to do it first; the menu is blocked on
I18N and the button is not.

The button is also the better control on its merits: it belongs to the radio
whose spectrum it is, so with two radios there is no question which one a click
means, and it can HIDE ITSELF when `SpectrumAvailable` is False rather than
offering an option that silently does nothing. A greyed menu item cannot say
"this K4 is on serial, so there is no stream" -- a button that is simply absent
on a serial K4 and present on a network one says it without words.

The Windows-menu item follows once I18N settles, for operators who work from
the menu and for keyboard access.

### 12.2 The program-layer gate goes with them

Three things must agree before a window opens: `rcSpectrum` (the model can),
`SpectrumAvailable` (this connection can), and the operator's setting (we
want to). The radio answers the first two. The third needs an
`IsSpectrumActive` in `MainUnit`, beside the existing `IsCWByCATActive`, so the
question is asked in ONE place rather than at each entry point -- otherwise the
button and the menu item will eventually disagree.

### 12.3 Configuration: one item, and two things that are not config

**Wanted: an enable/disable per radio.** `csJSON` from the start, since the
radio stores are all JSON already. An operator on a slow link, or one who does
not want a second socket open, needs to be able to say no. This is the third
gate above.

**Not config: palette and dB scale.** They are per-display preferences and
belong with the window layout, not with the radio.

**Not config, and worth refusing: the port.** It is CAT port + 1 by PROTOCOL,
not by convention. Exposing it buys nothing and invites a support case that
opens with someone having typed 9202.

Note that nothing here is required for the stream to work: it is unsolicited,
and the display scales off the packet's own noise floor with no CAT query at
all. The enable flag is about operator choice, not about making it function.

### 12.4 The spot provider still needs its threading re-derived

`uPanadapterView` is nil and the real provider is unwritten. The agreed shape
is to lift the band map's display filters out of `BuildVisibleSpots` into a
shared `SpotPassesDisplayFilters`, with each window keeping its OWN scope test
(the band map by band, the panadapter by the frequency range of the current
frame) -- so a spot outside the displayed span is excluded by the range, and
mode/dupe/CQ/WARC/mults-only follow the band map's settings unconditionally.

**Do not couple that to whether the band map window is open.** Those settings
are globals kept live by the radio poller regardless of any window, so
"follow it when open" and "always follow it" are the same behaviour today --
and only the second one is defined when it is closed. Making a closed window
silently change what a different window shows is a hidden mode.

**The threading evidence expired during this merge.** The analysis that every
`AddSpot` caller runs on the main thread rested on `uTelnet` posting a window
message and `uNet` using `WSAAsyncSelect`; `70e6bedf`, `05ff356f` and
`00e9a987` removed all three. The conclusion may well still hold -- re-derive
it on merged code before writing the provider, do not carry it forward.

## 14. The display controls (2026-08-26)

Added after the first bench session and NOT covered above; recorded here
because none of it is visible from the sections that describe the wire format
and the rendering.

### 14.1 Span, and the radio API behind it

`+` and `-` step the K4's span, as QK4's do. Measured on QK4 first rather than
invented: **each press changes the rig's span by one step**, and the rig's
display follows -- this is not a zoom of the received data, it is a command to
the radio.

Two things on `TFactoryRadioBase` carry it, so no caller has to know it is a K4:

| | |
|---|---|
| `SetSpectrumSpan(aHz)` | virtual; the base does nothing |
| `SpectrumSpanHz` | virtual; the base returns 0 |

`TK4Radio` sends `#SPN%d;` clamped to the documented 1..999999, and
`SpectrumSpanHz` returns what the rig last reported. `StartSpectrum` asks
`#SPN;` at connect, because **the radio pushes on change but not on connect** --
without that ask, nothing knows the span until the operator happens to touch the
rig.

`StepSpan` steps from `FRadio.SpectrumSpanHz`, never from the frame. See §10.2
for why that distinction is the whole ballgame.

**The `#` branch in `ProcessMessage` is a prerequisite, not a detail.**
`TK4Radio.ProcessMessage` dispatches on the first TWO characters, and every K4
extended command is `#` plus a THREE-letter name -- so `#SPN`, `#REF`, `#SCL`
and the rest all arrived as `#S`, `#R`, `#A` and matched no arm. They were not
failing loudly; they were logged as "VFO A message received #SPN368000" and
discarded. An explicit `#` branch now sits above the two-character dispatch,
which is where any future one hangs off.

**A control that cannot act says why.** Both buttons used to `Exit` in silence
when there was no radio or no known span, which is indistinguishable from a dead
control -- the reason was findable only by grepping the CAT log for a command
never sent. They write the reason into the span label instead.

### 14.2 Where the axis sits, and the dB scale

The frequency axis is drawn **between the spectrum and the waterfall**, as QK4
does it (NY4I, 2026-08-26: "notice on QK4 how the frequencies are listed between
the panadapter and the waterfall"). It was at the bottom. `PlotLayout` is the
one place that decides the four bands -- spectrum height, axis top, waterfall
top, waterfall height -- so the three drawing routines cannot disagree about
where they are.

The spectrum carries **horizontal grid lines and a dBm scale** down its left
edge (`DrawDbScale`), from the same `NoiseFloorDb`-relative range §6 describes.
Decimals on the frequency labels follow the tick step and are floored at three,
so a 3 kHz mini-pan still reads.

### 14.3 The caption names the radio

`Panadapter - Radio 1 K4D-278`, built the same way the radio panel builds its
own: the localized label, plus the rig name **only when it differs** -- because
`RadioName` is initialised to that same label and would otherwise read
"Radio 1 Radio 1" on a station with no radio configured. On an SO2R station a
bare "Panadapter" cannot say whose spectrum it is, which is the one thing the
title has to answer.

## 13. One panadapter per radio (2026-08-26)

An SO2R station with two K4s gets **two windows**, indexed by the radio panel's
own slot: `ShowPanadapterWindow(FSlot, ...)`. Before this, a single global form
meant opening the second panadapter **silently stole the first** -- `AttachRadio`
detaches whatever is already attached, so Radio 1's window would simply start
drawing Radio 2.

**Almost nothing had to change, and that is the point.** All ~61 form fields --
the waterfall bitmap, the frame lock, the palette LUT, the dB history -- were
already per-instance, and each `TK4Radio` already owns its own spectrum thread
on its own socket (CAT port + 1, derived from *that* radio's `radioPort`). Only
three things were singletons:

| was | now |
|---|---|
| `TR4WPanadapterForm: TfrmPanadapter` | `GPanForms: array[1..2]` + `PanadapterForm(aSlot)` |
| `FBoundsRestored: boolean` (unit global) | a form field, restored once per window |
| `LAYOUT_NAME = 'Panadapter'` | `LayoutName` -> `'Panadapter1'` / `'Panadapter2'` |

The layout key is the one that would have failed quietly: two windows writing
the same row in `settings/tr4w.json` means the last to close wins, and the
other window's position is lost every run.

Slot numbering is deliberately the **same 1/2 as the radio panels and the dupe
sheets** (`uRadioPanelForm.SlotOf`), not a new scheme.

`FreePanadapterWindow(aSlot)` exists so the bench harness cannot free a form
and leave a dangling pointer in `GPanForms`.

**MEASURED 2026-08-26** -- this section previously parked the cost as "not
provable by code review". It has now been measured on NY4I's station: two K4s,
both panadapters open, a local mock DX cluster running, sampled with `pslist -d`
over a 433 s window.

| | CPU over 433 s | share of TR4W |
|---|---:|---:|
| main / UI thread | 52.8 s -- 12.2% of one core | **93%** |
| both K4 spectrum receivers (port 9201) | 2.67 s | 4.7% |
| both radio pollers | 0.81 s | 1.4% |
| **total** | **56.8 s -- 13.1% of one core** | ~0.8% of a 16-core machine |

**Receiving and decoding two spectrum streams is nearly free.** The whole
budget is DRAWING, and it sits on the one thread that also has to stay
responsive for typing and keying -- which is the argument for
`docs/migration_interim_artifacts/DISPLAY_STATE_MODEL_PLAN.md`, not against a second panadapter.

**The 13% is an UPPER BOUND.** The sample was taken with trace logging on: the
UI thread wrote ~9,500 log lines in those seven minutes (~22/s), and its kernel
time runs 2:1 over user (35.3 s vs 17.5 s) -- log file I/O is kernel time.
Painting and logging cannot be separated from that dump. The cheap next
measurement is the same window with `DEBUG LOG LEVEL = INFO`.

**Still not measured:** whether a second K4 is reachable on its own address on
a station that has not been set up that way. That is not a code question
either.

### 13.1 Window layout and open state

Bounds used to be written in **`HandleClose` alone**. An operator who moved the
window and then quit TR4W with it open saved *nothing* -- which is how a
carefully placed panadapter came back in the top-left corner every run (NY4I,
2026-08-26).

The panadapter is not a `tw_` window, so `FindAndSaveRectOfAllWindows` cannot
see it and it has to answer for itself. It does that by **riding MainUnit's
existing autosave** rather than growing a timer of its own:

- `PanadapterLayoutChanged` joins the 5-second tick's dirty check.
- `SavePanadapterLayout` is called from `SaveTR4WPOSFILE`, which gives it the
  save-at-exit backstop for free.

Two mechanisms writing one file is how drift starts, so there is only one.

**`visible` is real state, not a formality.** `SaveCurrentBounds` takes it
explicitly: `HandleClose` passes `False`, because closing the window *is* the
operator saying they do not want it next time; the autosave passes the live
`Visible`.

`uPanadapterRestore` reads that back at start-up and reopens what was open.
It is **its own unit**, not a corner of `uRadioPanelForm`: a helper class with
an `OnTimer` handler inside a designed form's unit reads to `Lint-FormEvents`
as an unwired form handler, and more to the point this is a start-up policy,
not a window.

**Why it retries rather than firing once.** "Was it open last time" is answered
from disk instantly; "can this radio stream spectrum yet" is not --
`SpectrumAvailable` stays False until the polling thread has connected and the
K4 has answered, which on a cold start is seconds away and on a rig that is
switched off never comes. So it tries immediately, then every 2 s, stops the
moment both slots resolve, and **expires after 60 s saying so in the log**. A
silent expiry would be indistinguishable from a broken feature.

**The legacy key.** Slot 1 falls back to the old single `Panadapter` row for
both position and open state, so upgrading does not quietly discard what the
operator had.

### 13.2 Start-up ordering: the main window goes first

`OpenOtherWindows` used to restore every tool window and only then show the
main one -- all **before `Application.Run`**. A window does not paint until
something pumps its messages, so every millisecond spent constructing a
restored tool window was a millisecond the main window sat unpainted. The
tool windows appeared; the main window trailed them.

Measured 2026-08-26, per window:

| window | ms |
|---|---:|
| BandMap / FunctionKeys / Master / RemMults / Radio1 / Radio2 | 14-27 each |
| **Telnet** | **1741** |

Telnet's cost was `TelnetAddHostItem` doing an `Items.IndexOf` before every
`Items.Add` over the 726 lines of `TRCLUSTER.DAT`. Two multipliers, neither
visible in the source: the duplicate check made it O(n^2), and on the Win32
widget set a `TComboBox`'s `Items` **proxy the native control**, so each
`IndexOf` is a sweep of `CB_GETLBTEXT` round trips and each `Add` relays the
control out -- roughly a quarter-million control messages to fill one
drop-down. The pre-conversion dialog did a bare `CB_ADDSTRING` with no dedupe;
this was conversion damage (`00e9a987`). It now de-duplicates in memory against
a sorted list and writes the control once inside `BeginUpdate`/`EndUpdate`.

**But the slow window was the symptom.** The ordering made *any* future slow
window a main-window delay, silently -- so the ordering changed too. NY4I:
*"wouldn't you create the window then have the telnet thread run after the
window is up?"*

- `OpenOtherWindows` now shows the main window and **queues** the rest through
  `Application.QueueAsyncCall`, which runs them on the main thread at the first
  idle inside `Application.Run` -- after the main window has painted.
- Not a worker thread: these are windows, and windows belong to the thread that
  owns the loop. The Telnet *connect* was already off-thread and never blocked
  (thread created in ~1 ms); only the UI work was slow.
- `RestoreToolWindows` re-asserts `tCallWindowSetFocus` when it finishes,
  because showing a window can take focus and the restore now runs *after* the
  caret was placed.
- `StartPanadapterRestore` queues its first attempt for the same reason.
- Both queued calls are dropped with `Application.RemoveAsyncCalls` before their
  owner object is freed, so an exit before the first idle cannot leave the LCL
  holding a method pointer into freed memory.

**The loop now reports itself.** `OpenOtherWindows` logged nothing, which is
why a 1.7 s stall showed up as a silent gap that could not be attributed
without a rebuild. Each window is timed: `>= 200 ms` at Info, the rest at
Trace.
