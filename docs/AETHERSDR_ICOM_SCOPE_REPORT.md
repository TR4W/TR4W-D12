# Upstream report: AetherSDR Icom backend — measurements from an IC-9700 and an IC-7760

> ## BEFORE SUBMITTING: strip the internal notes
>
> This file is submission-ready **except** for blocks marked
> `[INTERNAL — REMOVE BEFORE SUBMISSION]`. They exist because the reasoning
> behind this report is worth keeping on our side, and losing it to keep the
> file pasteable would be the wrong trade.
>
> Find every one with:
>
> ```
> grep -n "INTERNAL — REMOVE BEFORE SUBMISSION" docs/AETHERSDR_ICOM_SCOPE_REPORT.md
> ```
>
> Delete each marked block **including this one** — it is an internal
> instruction and has no business in an upstream issue. The grep above finds it
> too, which is the intended behaviour and not a false positive.
>
> Then paste. Nothing else needs editing.

**Everything in the body below rests on one of exactly two things:**

1. **measurements taken from our own radios**, over Icom's own RS-BA1 network
   transport, with the raw captures available; or
2. **AetherSDR's own source**, quoted back at it.

**No third-party project is cited anywhere in the body, deliberately.**
AetherSDR keeps an explicit clean-room boundary — `IcomProtocol.h` states that
kappanhang (MIT) is used for the transport and wfview (GPL-3) *"ONLY as a
read-only specification for field names and offsets, never as source"*. A report
that quoted a GPL-licensed implementation at them would be asking them to look
at a license they have fenced off, and would rightly be closed unread. Hardware
facts measured off a rig carry no such problem: they are observations, not
anyone's creative work — which is the same standing `IcomModels.h` already
claims for its own table.

> **[INTERNAL — REMOVE BEFORE SUBMISSION]**
> TR4W's own engineering record, `ICOM_SPECTRUM_DESIGN.md`, *does* cite a third
> implementation (HamLib) — legitimately, and only for the CI-V payload, never
> for the RS-BA1 transport. Provenance for our code and admissibility upstream
> are different questions. That file answers the first; this one answers the
> second. Keep them apart, and never merge a paragraph from there into here.

---

## Method

Captured with `tr4w/test/bench/bench_icomscope.lpr`, which connects over Icom's
RS-BA1 UDP transport (ports 50001/50002), enables the scope with `$27 $10` and
`$27 $11`, and writes every raw `$27 $00` payload to a file **before decoding**,
so the capture is evidence about the radio rather than a record of what our
decoder made of it.

Raw captures available on request: 592 payloads from the IC-9700 and 9 from the
IC-7760, each stored as a 2-byte little-endian length followed by that many
bytes of raw `$27 $00` payload.

Date: 2026-08-26.

---

## Finding 1 — the IC-7760 is a 689-point radio, and is absent from `kModels`

**This is the substantive one.**

`IcomModels.cpp`'s `kModels` has no IC-7760 row, so `modelForCivAddress()`
returns `nullptr` for it and `unknownModel()` applies — which sets
`hasScope = false`, and the backend therefore declines to stream spectrum from a
radio that streams it perfectly well.

Measured over LAN:

| | |
|---|---|
| LAN payload | **704 bytes** |
| header | 15 bytes (`3 + 1 + 5*2 + 1`, matching `firstDivisionHeader()`) |
| **points** | **689** |
| division / max | `01` / `01` — whole sweep in one frame, as over WLAN generally |
| mode byte | `00` (centre) |
| header cross-check | centre 1.816195 MHz, span ±2.5 kHz — where the rig was tuned and what its display showed |
| sweeps | 9 observed |

`704 − 15 = 689`, which is the same arithmetic `IcomScope.cpp` uses, and it puts
the IC-7760 in the **689-point class alongside the IC-7610 and IC-785x rows**,
not the 475-point majority.

**The level range is NOT measured and should not be taken from this report.**
Every sample in our capture was zero — the rig's scope was not showing signal at
the time — so we can only report a lower bound of 0. `200` would be the natural
inference from the other two 689-point rows, but it is an inference and we did
not observe it. Marking a new row `verified = false` on that basis would match
what `IcomModels.h` already says about unverified data.

**Suggested row shape** (level range flagged as unverified):

```cpp
{
    // IC-7760 — 689 points MEASURED over LAN (704-byte payload, 15-byte
    // header). Level range inferred from the other 689-point models and NOT
    // observed: the capture was taken with the rig's scope idle.
    0x??, "IC-7760", /*receivers*/ 2, /*vfos*/ 2,
    /*hasNetwork*/ true, /*hasWifi*/ false,
    /*hasScope*/ true, 689, 200, 15,
    kFreqBytes,
    true, 200.0,
    /* tuning range */ ...,
    /*verified*/ false,
},
```

We have deliberately left the CI-V address as `0x??`: our transport reads it
from the RS-BA1 capabilities packet rather than assuming it, so we never had to
hardcode one and would rather not state a number we did not verify.

> **[INTERNAL — REMOVE BEFORE SUBMISSION]**
> The address *is* recoverable if we want to state it: the bench log's
> "Radio: <name>, CI-V address=$xx" line comes straight from the RS-BA1
> capabilities packet. Decide before filing whether to include it — offering it
> makes the suggested row directly usable, withholding it keeps every number in
> the report something we measured rather than transcribed.

---

## Finding 2 — a mistyped worked example in `CivCodec.h`

Verifiable entirely within your own repository; no external reference needed.

The endianness note above `kFreqBytes` reads:

> `//       14.250000 MHz -> 00 60 25 14 00`

Decoded least-significant-pair-first, as the surrounding text correctly
describes, those bytes are `00 14 25 60 00` = **14,256,000 Hz** — 6 kHz off. The
correct encoding of 14.250000 MHz is:

```
00 00 25 14 00
```

`encodeFreq()` itself is right; this is only the comment. It matters because
that line is the worked example a reader copies when checking their own
decoder — we caught it by hand-typing the byte sequence into a unit test as a
literal rather than round-tripping it through our own encoder, and the test
failed on its first run.

---

## Finding 3 — a question, not a claim: is payload byte `[0]` really fixed?

`IcomScope.cpp` documents offset 0 as:

> `//   data[0]      0x00, fixed`

and `feed()` never reads it.

**We cannot contradict that from our own measurements**, and we are not trying
to. On both radios tested — an IC-9700 and an IC-7760, **both of which have two
scopes** — byte `[0]` was `0x00` on every one of the 601 payloads we captured.
So our evidence is consistent with your comment.

The reason we raise it anyway: both rigs were streaming a single scope at the
time, and we have not yet been able to get either to stream Main and Sub
simultaneously. If that byte *is* a scope selector on dual-scope models, then a
decoder that ignores it would interleave two sweeps into one trace whenever both
are active — and the symptom would look like corrupt spectrum rather than a
decode bug, which is a bad failure to debug from.

**Question for you:** does the IC-705's CI-V Reference Guide describe that byte
as reserved/fixed, or does it name it? Your IC-705 row is the one model you have
verified against Icom's own documentation, so you are better placed to answer
this than we are. If the guide calls it fixed for a single-scope radio, the
question becomes whether the dual-scope guides differ.

We have chosen to carry it through as an opaque per-source identifier on our
side, because our display layer already needed one for a different radio that
multiplexes several spectra onto one connection. That is a design convenience,
not evidence about Icom.

---

## What we are not reporting

For completeness, so you know what we did *not* find:

* **Nothing about the RS-BA1 transport.** Our UDP implementation is
  independent, and we found no discrepancy with the packet shapes and cadences
  described in `IcomProtocol.h`.
* **The centre-mode half-width.** Your `feed()` computes
  `startHz = a - b; endHz = a + b`, treating span as a half-width. Our
  measurements agree: the IC-9700 reported ±10 kHz and displayed 20 kHz, the
  IC-7760 reported ±2.5 kHz and displayed 5 kHz. **No change needed** — we
  mention it only because it is the one place a reader might suspect an
  off-by-two, and it is correct as written.
* **The BCD division counters.** We saw only `01`/`01` over LAN, so we cannot
  independently confirm the multi-division path either way.
