# Bench test plan — 2026-08-01

Everything below landed on `delphi12` between 2026-07-31 and 2026-08-01. It all
builds clean (`/t:Build`, full 457k-line rebuild), passes 1403 unit tests, and
the golden corpus is at its baseline of 22 passed / 0 failed / 4
known-divergence. **None of that exercises a radio.** This is the list that does.

Ordered by risk: the things most likely to be broken, and most damaging if they
are, come first.

Run with `DEBUG LOG LEVEL = DEBUG` throughout — several checks below are read
off the log rather than the front panel.

---

## 1. CW-by-CAT send — EVERY radio you have

**Why it is first:** `RadioObject.SendCW` no longer has per-family arms. One code
path now serves Elecraft, Kenwood, Flex-over-CAT, Icom and Orion, and three
drivers (Elecraft serial, Kenwood serial, Flex CAT) emit their own `KY` command
for the first time — previously LOGRADIO formatted it and they discarded what
they were handed. If anything CW-related is broken, it is here.

For each radio: F1, a short message, and a long one (over 30 characters).

| Check | Expected |
|---|---|
| Message keys at all | yes |
| Text is correct, no dropped or doubled characters | yes |
| Long message keys **completely** | see §2 |
| `KY` on the wire | `KY <text>;` — note the space |
| Speed change mid-message (Ctrl-F / Ctrl-S) | speed changes, message still completes |

Radios where this is genuinely new: **K3, KX3, K2, TS-570 (and Kenwood
siblings), Flex on a COM port**. The K4 and the Icoms were already emitting
through their drivers, so they are lower risk — but they went through the same
rewrite.

---

## 2. Icom long messages — a fixed truncation

**Was broken:** the Icom arm did `len := Min(msgLen, 28)` and sent only that. It
never looped, so anything past 28 characters was **silently discarded** — no log,
no error. A normal CQ is already past 28.

Send an Icom a CW message comfortably over 28 characters, e.g.

```
CQ CQ TEST NY4I NY4I TEST
```

**Expected:** the whole thing keys, arriving as two `$17` commands rather than
one truncated one. Watch the log for two sends.

---

## 3. Ten-Tec Orion — CW-by-CAT has never worked

**Was broken since Issue 112:** the command was built with
`Format('/%s#13', [Msg])`, and `#13` *inside a quoted string* is the three
literal characters `#`, `1`, `3` — not a carriage return. The radio received
`/X#13` with no terminator and never keyed.

**Expected now:** CW keys. Any CW at all is a pass; this has never worked, so
there is no regression risk — only whether the fix is right.

Needs an Orion. NY4I is sourcing one.

---

## 4. Escape / keyer abort — every CW-by-CAT radio

Each family's abort moved out of LOGRADIO into its driver.

| Radio | Command now sent by | Expected |
|---|---|---|
| K3 / KX3 | `TElecraftSerial.StopCW` | `KY <04>;RX;` — **verified 2026-08-01** |
| K2 | same, `'@'` instead of `#4` | `KY @;RX;` |
| **K4** | `TK4Radio.StopCW` | `KY <04>;RX;` — **see below** |
| TS-570 etc. | `TKenwoodSerial.StopCW` | `KY0;` then `RX;` |
| Flex (CAT) | `TFlexCAT.StopCW` | `ZZSS;` |
| Icom | `TIcomRadio.StopCW` | CI-V `$17 $FF` |

**The K4 is the important one.** Its `StopCW` was sending a bare `Chr(4)+';RX;'`
with **no `KY ` prefix** — not a command the radio recognises. It went unnoticed
because Escape was only ever tested on the K3, which took the legacy path
instead. The K4 was the one radio actually reaching the factory abort, and it was
the broken one. Start a long message and hit Escape.

---

## 5. WinKeyer — latency and startup

Both measured, both should be visible in the log rather than by feel.

**Function-key latency.** With CW-by-CAT active and a WinKeyer merely plugged in
(not the keyer in use), press F1 with the mouse. Compare the timestamps of
`MOUSE CLICK on F1 received` and the following radio TX line.

- Expected: **~25 ms**. Was 383 ms.
- There should be **no `wkSendByte` or `[wkClearBuffer]` at all** in that window.

**Startup.** Restart with the WinKeyer connected and find `[wkClearBuffer]` in
the first second.

- Expected: **~0.4 ms**, and the line appears *before* `Calling tCreateThread
  from WkOpen`. Was up to 1978 ms.

**Regression checks** — these are the paths the latency fix could have broken:

- F1, let it finish, wait, F1 again → both fast, no `[wkClearBuffer]`
- F1, then **Escape** mid-message → `[wkClearBuffer]` **does** fire and keying stops
- Autosend a character, then Escape → same

---

## 6. Frequency, mode, split, DVK — every radio

~900 lines of legacy per-model code were deleted from LOGRADIO, including all of
`SetRadioFreq`'s encoders (12 of the unit's 22 per-model tests lived there). No
behaviour should change for any correctly configured radio — **that is the
point, and also the risk.**

Per radio: band change up and down, QSY by typing a frequency, bandmap or spot
double-click, mode change, split on and off, and a DVK memory if the rig has one.

A failure here looks like a rig that does not move, moves to the wrong mode, or
does not go split. There is **no fallback left** to mask it, so it will fail on
the first try rather than intermittently.

---

## 7. Serial K4 — RIT and XIT

**Was broken:** on a serial K4 the radio window showed no RIT or XIT indicator
and no offset (split was fine). Fixed and verified 2026-07-31; re-check it
survived the later work.

Turn RIT on, spin the offset, then XIT. Network K4 was never affected — the AI
push path already wrote the field the window reads — but it is worth one pass to
confirm both transports.

---

## 8. Misconfiguration now fails loudly

New behaviour, worth seeing once so it is recognisable in the field.

Configure a radio on a connection type it does not support (a serial-only rig set
to Network, say). Previously TR4W silently ran an older code path and the rig
half-worked.

**Expected:** an `ERROR` in the log naming the radio and the port, and the radio
does nothing at all. Inert-and-loud is the intended outcome.

---

## Known NOT covered, and why

- **KX3 / KX2** — no radio here. The KX3 was missing from the Elecraft prosign
  set and keyed *Kenwood* spellings for AR, SK, BT and SN; fixed but unverified.
  Per NY4I the KX2/KX3 differ from the K3 only in the PlayMessage memory keyer.
- **SO2R two-radio CW-by-CAT interlock** — TR4W's SO2R swaps which radio is
  ACTIVE, so sends always take the active path and the interlock is not reached
  by normal SO2R use. It is untested and N4AF owns validating it. Note it is
  asymmetric: the active branch sleeps 500 ms after stopping the other radio and
  the inactive branch does not sleep at all.
- **Icom SO2R interlock** — deliberately still its own code rather than the
  shared `EnsureSoleTransmitter`, because the shared one has that 500 ms sleep
  and the Icom path never did. Routing Icom through it would silently add half a
  second to every SO2R send.

## Still to do (not in this build)

`SendCW` no longer contains anything radio-specific, but it still holds the
CW-by-CAT orchestration itself — the buffer, the terminator and speed-change
trigger, the chunk loop and the busy flag. That is keyer logic living in a radio
object, and it belongs in `TCWKeyerCAT`. That is the CAT repoint, task #21.
