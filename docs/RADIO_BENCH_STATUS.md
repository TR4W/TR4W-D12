# Radio bench-test status

Which factory radios have actually been tested against hardware, by whom,
and when.  **Generated** by `tools/bench-status/bench_status.py` from the
radio registry, so a newly added radio appears here automatically as
untested rather than being forgotten.  Re-running the script PRESERVES
every hand-written Tested / By / Notes cell -- it only rebuilds the radio
list.

Fill in a row when a report comes back.  `Tested` is a date (YYYY-MM-DD);
leave it `-` for untested.  Put what was actually exercised in `Notes` --
"connects" and "CW, split and RIT verified" are very different claims.

**Why this matters here:** the legacy radio path is kept only until bench
coverage makes its deletion safe (see `docs/tr4w-migration-strategy.md`).
This table is the gate on that decision.

| Radio | Enum | Tested | By | Notes |
|---|---|---|---|---|
| Elecraft K2 | K2 | - | - |  |
| Elecraft K3 | K3 | 2026-07-31 | NY4I | CW-by-CAT send verified (KY padded to 22). Escape-stops-CW failed, fixed 163723a, RETESTED OK. WinKeyer keying verified same day; function-key latency 383 ms -> 25 ms after 3b93fb6. 2026-08-01: StopCW moved out of LOGRADIO into TElecraftSerial ('KY <04>;RX;') and re-verified, Escape included. 2026-08-01: interrupting CW VERIFIED WORKING -- a function key pressed during a message now aborts and the new message keys, including a 1-character one (F9 '?'). Needed three separate fixes: the TX/PTT sighting latch (a poll declared the message finished 168-272 ms in), the CWByCAT_Sending guard on the abort (an idle radio was aborted before every message), and a 75 ms settle delay after 'RX;'. NOTE the RX is REQUIRED -- ^D alone does not stop plain CW ("use with CW-to-DATA") -- and padding does NOT substitute for the delay, because the K3 trims trailing fill rather than keying it. 2026-08-01: re-verified after the CAT repoint (edc9cbf) moved the whole CW-by-CAT send out of RadioObject.SendCW into uCWKeyerCAT.CWByCATSend -- function keys still key correctly. 2026-08-01: startup command VERIFIED across all three cases -- at TR4W start, on Reset Radio Ports, and after a radio POWER CYCLE. The power-cycle case needed 92eebec: the command was going out 153 ms after the rig's first CAT byte, which the radio accepted on the port and silently dropped. A rig that answers IF; is not yet a rig that will act on anything, so the send now waits STARTUP_COMMAND_SETTLE_MS (2000) after the link comes up. 2000 ms is unmeasured but sufficient on this K3.  2026-08-04 (K3S, USB serial): CW-by-CAT and CW SPEED SYNC both VERIFIED after the capability/framing rework. This is the bench evidence for 4a7f9833, which moved the frame rule (22 chars, padded) and the prosign dialect off uCWFraming's InterfacedRadioType table and onto TElecraftSerial as declared capabilities -- the K3 pad-to-22 is the bench-derived quirk that rework most risked losing, and it survived. Also covers a9e77155, which repointed the rcCWByCAT / rcCWSpeedSync gates at the radio object (RadioObject.HasCapability) instead of a model-keyed registry lookup. Tested on a K3S, which uses the K3 registration. **2026-08-09, TCI server bench (K3S):** frequency, mode, split and PTT all driven from WSJT-X over TCI. Unkey latency was ~250 ms and traced NOT to TR4W's command path (0-2 ms to the wire) but to backlog in the RADIO's input buffer from unpaced polling -- the cost is **per command (~100-170 ms during transmit), not per byte**, established with a standalone harness that did not involve TR4W. Two changes followed: poll flow control (one outstanding request, released on 30 ms quiescence with a timeout backstop) and **auto-info AI2, now the default for all Elecraft serial radios**, which dissolves the trade-off entirely -- VFO B stays tracked during transmit AND unkey came back at 221 ms. Note the K3 manual's "IF responses are suppressed during VFO movement", and that `IF;` vs `TQ;` for the T/R poll is still undecided. **2026-08-11, power-cycle recovery: ~5 s, and this radio HID A REAL DEFECT.** A K3 in AI2 recovers from a power cycle because it volunteers data on power-up -- the reading thread hears it without TR4W asking. That masked a bug in the SHARED send path where a stale `Disconnecting` flag made TR4W discard every poll after a reopen (see the FT-1000MP row). **Set this radio to AI0 and it fails exactly like the FT-1000MP** -- which is how the diagnosis was confirmed before the fix. Worth remembering when a fault "cannot be reproduced on the K3": auto-info may be hiding it. |
| Elecraft K4 | K4 | 2026-07-31 | NY4I | Split: FT1; alone is sufficient (RX always VFO A). CW-by-CAT in use. SERIAL: RIT/XIT indicators and offset were blank (ParseIFCommand wrote only the legacy scalars, not the per-VFO copy the window reads) -- fixed and retested OK. CW by serial port (COM6, K4 serial 2) verified via the CPU keyer. NETWORK retested same day and unaffected, confirming the AI push path (RT/XT/RO) writes the per-VFO fields itself. |
| Elecraft KX3 | KX3 | - | - |  |
| Expert TCI (HamLib bridge) | EXPERTTCI | - | - |  |
| Flex 6000+ | FLEX | 2026-07-29 | NY4I | SERIAL (ZZ CAT): connect, freq/mode, split, VFO B, independent RIT/XIT, 200 ms poll. NETWORK: discovery (VITA-49). CW-by-CAT NOT yet exercised. |
| FLRig (HamLib bridge) | FLRIG | - | - |  |
| HamLib (any supported rig) | HAMLIBANY | - | - |  |
| Icom IC-7000 | IC7000 | - | testers | As IC706: split and TX status not readable (BenchProvenDivergences). |
| Icom IC-705 | IC705 | - | - |  |
| Icom IC-706 | IC706 | - | testers | Split and TX status NOT readable -- bench-proven (uTestIcomRegistry.BenchProvenDivergences). Date/tester not recorded. |
| Icom IC-706MkII | IC706II | - | testers | As IC706: split and TX status not readable (BenchProvenDivergences). |
| Icom IC-706MkIIG | IC706IIG | - | testers | As IC706: split and TX status not readable (BenchProvenDivergences). |
| Icom IC-707 | IC707 | - | - |  |
| Icom IC-7100 | IC7100 | 2026-08-04 | NY4I | Direct CI-V (not HamLib). CW-by-CAT sends. **Interrupting CW VERIFIED WORKING** after 7309eb69. Before it, F9 pressed 1.05 s into an F1 message neither stopped F1 nor keyed until F1 finished -- the log showed no StopCW at all, because `SendFunctionKeyMessage` skipped `FlushCWBuffer` outright for any radio declaring `rcCWFlushDisruptsTiming` (every Icom, family-wide; ny4i Issue 145). That skip predated the 2026-08-01 K3 fix that made the abort conditional on `CWByCAT_Sending`, so the timing problem it worked around was already gone at its source. **This also proves the abort byte:** `$17 $FF` -- the raw byte, as the D7 legacy path and HamLib's `icom_stop_morse` both send -- does stop the keyer, so the manual's "FF" needs no ASCII reading. **2026-08-05, same radio, all VERIFIED:** (1) plain F1 keys clean -- "the CW sent by the Icom 7100 sounded 100% accurate" -- which cleared `rcCWFlushDisruptsTiming` for retirement (0de1e8ac). (2) **Band-segment interrogation works**: `$1E 00` returns 13 (BCD) and `$1E 01 <nn>` returns each segment, decoding to the exact US band plan -- 1.8/3.5/5.255/7.0/10.1/14.0/18.068/21.0/24.89/28.0/50/144/430-450 MHz. **Alt-B now goes 2 m -> 70 cm** instead of sending 222.100 MHz to a radio without 222 (ad255f4a). (3) **`$02` is receiver-section relative**, proven by reading it on both: 30 kHz..199.999999 MHz on 20 m, 400..470 MHz on 70 cm -- so it reports the current section's tuning span, NOT a band plan, and is deliberately not used as the coverage source. (4) **No XIT**: `$21 $02` NAKed once a second forever; HamLib agrees (`rigctl -m 3070 -u` -> "Can get XIT: N"). Declared `HasXIT := False`; all five XIT paths guarded. (5) A leftover K3 startup command (`KY <;`) was putting five non-CI-V bytes on the bus at every connect -- an Icom now refuses to send a startup command that is not a CI-V frame (30f48554). **2026-08-09, TCI server bench:** WSJT-X over TCI drives frequency, mode and PTT correctly. Getting there fixed a **pre-existing CI-V defect unrelated to TCI: Icom PTT had never keyed.** `CIV_SUBCMD_TX = #$00` / `CIV_SUBCMD_RX = #$01` were being sent as the *whole* `$1C` payload, so the radio received `1C 00` (read TX status) and `1C 01` (read ATU status) -- two harmless READS. `$1C` needs a subcommand **and** a data byte: `CIV_PAYLOAD_PTT_ON = #$00#$01`, `CIV_PAYLOAD_PTT_OFF = #$00#$00`. Also fixed here: `tPTTVIACAT` keyed `ActiveRadio` regardless of which trx the caller addressed, so a TCI client on radio 2 keyed radio 1. |
| Icom IC-718 | IC718 | 2026-07-21 | NY4I | Extensive: mode=NON fixed, CW speed 6..60, per-VFO mode label, set-mode without filter byte, split set-only, TX status unreadable. 2026-07-31: CI-V bus-collision fix (mode display), transceiver-ID $19 logging. |
| Icom IC-7200 | IC7200 | - | - |  |
| Icom IC-725 | IC725 | - | - |  |
| Icom IC-726 | IC726 | - | - |  |
| Icom IC-728 | IC728 | - | - |  |
| Icom IC-729 | IC729 | - | - |  |
| Icom IC-7300 | IC7300 | - | - |  |
| Icom IC-7300MK2 | IC7300MK2 | - | - |  |
| Icom IC-735 | IC735 | - | - |  |
| Icom IC-736 | IC736 | - | - |  |
| Icom IC-737 | IC737 | - | - |  |
| Icom IC-738 | IC738 | - | - |  |
| Icom IC-7410 | IC7410 | - | - |  |
| Icom IC-746 | IC746 | - | - |  |
| Icom IC-746PRO | IC746PRO | - | - |  |
| Icom IC-756 | IC756 | - | - |  |
| Icom IC-756PRO | IC756PRO | - | - |  |
| Icom IC-756PROII | IC756PROII | - | - |  |
| Icom IC-756PROIII | IC756PROIII | - | - |  |
| Icom IC-7600 | IC7600 | - | - |  |
| Icom IC-761 | IC761 | - | - |  |
| Icom IC-7610 | IC7610 | - | - |  |
| Icom IC-765 | IC765 | - | - |  |
| Icom IC-7700 | IC7700 | - | - | **Network link added 2026-08-14, UNTESTED and expected to stay that way for a while.** It had been registered `[rlSerial]` with port 0 while every other network Icom carried `[rlSerial, rlNetwork], 50001, True` -- an oversight (NY4I), found because the credentials work forced the whole network set to be written down. It now matches its siblings and declares credentials. NY4I: *"I have to find an Icom 7700. Not very much used anymore."* So the option is available and consistent, not verified -- and Icom LAN is unproven on **every** model, not just this one. |
| Icom IC-775 | IC775 | - | - |  |
| Icom IC-7760 | IC7760 | - | - |  |
| Icom IC-78 | IC78 | - | - |  |
| Icom IC-7800 | IC7800 | - | - |  |
| Icom IC-781 | IC781 | - | - |  |
| Icom IC-7850 | IC7850 | - | - |  |
| Icom IC-7851 | IC7851 | - | - |  |
| Icom IC-905 | IC905 | - | - |  |
| Icom IC-910 | IC910 | - | - |  |
| Icom IC-9100 | IC9100 | - | - |  |
| Icom IC-9700 | IC9700 | - | - |  |
| Icom IC-970D | IC970D | - | - |  |
| Kenwood TS-140 | TS140 | - | - |  |
| Kenwood TS-2000 | TS2000 | - | - |  |
| Kenwood TS-440 | TS440 | - | - |  |
| Kenwood TS-450 | TS450 | - | - |  |
| Kenwood TS-480 | TS480 | - | - |  |
| Kenwood TS-570 | TS570 | 2026-07-30 | NY4I | Split via FR0;FT1; and split preserved at startup. Serial power-cycle recovery. |
| Kenwood TS-590 | TS590 | - | - |  |
| Kenwood TS-690 | TS690 | - | - |  |
| Kenwood TS-850 | TS850 | - | - |  |
| Kenwood TS-870 | TS870 | - | - |  |
| Kenwood TS-890S | TS890 | - | - |  |
| Kenwood TS-940 | TS940 | - | - |  |
| Kenwood TS-950 | TS950 | - | - |  |
| Kenwood TS-990S | TS990 | - | - |  |
| N3FJP ACLog (HamLib bridge) | ACLOG | - | - |  |
| Ten-Tec Omni VI (CI-V) | OMNI6 | - | - |  |
| TCI (ExpertSDR / Thetis / AetherSDR) | TCI (string id) | 2026-08-03 | NY4I | **First native TCI radio; also the factory's proof-of-concept for a wholly new radio type.** Tested against AetherSDR. WORKING: connect + init burst, frequency/mode tracking, RIT offset (after the poll repair), split detection at startup, split on/off/on cycle, and the refusal path for an operator-created split. THREE SERVER-SIDE GAPS FOUND, none ours: (a) split is expressed as a second RECEIVER carrying tx_enable:true, NOT split_enable -- set and read use different fields; (b) rit_offset is broadcast ONLY on a client SET and in the init burst, never when changed on the radio's own UI (confirmed in AetherSDR's source: TciServer.cpp wires only the *_enable family, comment says rit_offset is 'out of scope') -- worked around by GETting it once a second while RIT/XIT is on; (c) a client cannot remove an operator-created split slice at all (AetherSDR issue #3715, per-slice ownership is proposed not implemented) -- TR4W now says so instead of pretending. NOT TESTED: CW-by-CAT (cw_macros grammar is [VERIFY]), the independence of rit/xit offsets, ExpertSDR2 and Thetis (only AetherSDR was available). |
| Ten-Tec Orion | ORION | - | - |  |
| TRX-Manager (HamLib bridge) | TRXMANAGER | - | - |  |
| Yaesu FT-100 | FT100 | - | - |  |
| Yaesu FT-1000 | FT1000 | - | - |  |
| Yaesu FT-1000MP | FT1000MP | 2026-08-09 | NY4I | **First bench proof of the Yaesu BINARY family** (previously listed unproven in CLAUDE.md). Frequency read had been working; PTT and TX state had never been exercised. Two defects fixed. (1) **PTT was never sent at all** -- `TYaesuBinary` had no PTT frame, so `tPTTVIACAT` silently did nothing; added `PTTFrameOn`/`PTTFrameOff` virtuals with the per-model pairs ($0F/$0F here, $08/$88 on the FT-817 group). (2) **TX state was never read back**, so TR4W showed receive while the rig transmitted and a TCI client was told the same lie. NY4I supplied the status-flag spec (send `00 00 00 01 $10`, test bit 7 of status byte 1); rather than add a third command to a FIXED-FRAME protocol with no delimiters -- where a wrong reply length misaligns every frame and takes frequency with it -- it was measured with `tools/yaesuprobe.py` at 4800 8N2, and the answer was better than the plan: the 6-byte `$FA` block **already polled for split** carries the same bit. Receiving `01 20 30 00 00 00`, transmitting `C1 20 30 00 02 00`. No new command, no frame-length change, no added latency. **Bit 7, NOT `$FA` byte 4 bit 4:** byte 4 moved 00->02 in the capture, i.e. it reports transmit *we* caused by CAT, while bit 7 reports transmit however it started -- front panel and foot switch included. The probe's two known-answer commands returned exactly 32 and 6, matching the driver, which is what made its answer for the unknown command trustworthy. VERIFIED by NY4I: keys and unkeys from WSJT-X over TCI, and the display now follows the radio. **2026-08-11, POWER-CYCLE RECOVERY -- and the defect it exposed.** With TR4W running, switching the radio off turns the callsign magenta (correct: it means "not answering") and switching it back on used to NEVER recover -- only Reset Radio Ports brought it back. Root cause was NOT Yaesu-specific: the reading thread sets a `Disconnecting` flag on a dropped link, and only `Connect` and `OnRadioConnected` ever cleared it -- **not `ReopenSerialPort`**. So `MaintainSerialLink` reopened the port on its backoff (six times in the 2026-08-11 log, all succeeding) and `SendToRadio` then discarded every poll: `[SendToRadio] Ignoring command - radio is disconnecting`, 688 times. The port was fine; nothing was allowed to talk to it. Reset Radio Ports works because it runs `Connect`. Fixed by clearing the flag on a successful reopen. **WHY IT SHOWS HERE AND NOT ON A K3 OR IC-7100:** the defect is in the SHARED send path, but a radio that VOLUNTEERS data on power-up -- an Elecraft in AI2, an Icom in transceive -- is heard by the reading thread without TR4W asking, so it recovers regardless. The FT-1000MP is strictly polled and says nothing until asked. Confirmed by prediction BEFORE the fix: NY4I set a K3 to AI0, power-cycled it, and it failed identically. Those two radios were MASKING the bug, not avoiding it. **MEASURED RECOVERY TIME, and it is the RADIO, not TR4W.** After the fix: K3 ~5 s, FT-1000MP ~12 s from switch-on to the frequency reappearing. Ruled out by log: in the 2.59 s of silence after the final reopen, TR4W polled **42 times** at ~200 ms intervals and the FT-1000MP answered nothing; the first byte then completed a valid 38-byte frame in 97 ms with no resync cost. So the extra time is the FT-1000MP's own CAT interface waking up -- a 1990s rig booting its CAT board is simply slower than a K3 -- plus wherever in the retry cycle the operator switched on. The reopen backoff cap was lowered 30 s -> 5 s in the same session (a reopen costs 112 ms, measured, so rationing it to once per 30 s bought nothing), which bounds TR4W's share at ~5 s. **~12 s on this radio is expected and is not a defect to re-investigate.** **2026-08-31, RE-CONFIRMED UNDER FPC -- and it was broken, which is the point of re-confirming.** The panel rotated through invented frequencies while the rig sat on one. `TYaesuBinary.SendBytes` built its 5-byte frame with `Chr()`, and under `{$MODESWITCH UnicodeStrings}` with the LCL setting `DefaultSystemCodePage` to UTF-8 a lone byte >= `$80` is not valid UTF-8: it decodes to U+FFFD and the transport writes `$FD`. So the split/flags poll `00 00 00 01 $FA` went out as `00 00 00 01 $FD`, the radio ignored the unknown opcode and answered nothing, and the fixed-frame reader -- still expecting 32+6 = 38 -- took the missing 6 bytes from the NEXT cycle and decoded every frame 6 bytes further out of phase. Every other byte in both poll commands is < `$80`, which is why exactly one was wrong. Fixed with `Char()`, a typecast that consults no codepage. **This is the same root cause fixed for Icom CI-V on 2026-08-26** (see the `CivChr` header in `uRadioIcomBase`); the Yaesu path never got the same treatment. **It is also a pure FPC regression:** the 2026-08-09 proof above was obtained under Delphi, which has no UTF-8 `DefaultSystemCodePage`, so nothing was wrong then and nothing in the build could have caught it -- only a radio on the bench. Reproduced in isolation before the fix: at codepage 1252 `Chr($FA)` gives U+00FA, at 65001 it gives U+FFFD, and `Char($FA)` gives U+00FA at both. |
| Yaesu FT-1200 | FT1200 | - | - |  |
| Yaesu FT-2000 | FT2000 | - | - |  |
| Yaesu FT-450 | FT450 | - | - |  |
| Yaesu FT-710 | FT710 | - | - |  |
| Yaesu FT-736R (via HamLib) | FT736R | - | - |  |
| Yaesu FT-747GX | FT747GX | - | - |  |
| Yaesu FT-757GXII (via HamLib) | FT757GXII | - | - |  |
| Yaesu FT-767 | FT767 | - | - |  |
| Yaesu FT-817 | FT817 | - | - |  |
| Yaesu FT-818 | FT818 | - | - |  |
| Yaesu FT-840 | FT840 | - | - |  |
| Yaesu FT-847 | FT847 | - | - |  |
| Yaesu FT-857 | FT857 | - | - |  |
| Yaesu FT-890 | FT890 | - | - |  |
| Yaesu FT-891 | FT891 | - | - |  |
| Yaesu FT-897 | FT897 | - | - |  |
| Yaesu FT-900 | FT900 | - | - |  |
| Yaesu FT-920 | FT920 | - | - |  |
| Yaesu FT-950 | FT950 | - | - |  |
| Yaesu FT-990 | FT990 | - | - |  |
| Yaesu FT-991 | FT991 | - | - |  |
| Yaesu FTDX-10 | FTDX10 | - | - |  |
| Yaesu FTDX-101 | FTDX101 | - | - |  |
| Yaesu FTDX-3000 | FTDX3000 | - | - |  |
| Yaesu FTDX-5000 | FTDX5000 | - | - |  |
| Yaesu FTDX-9000 | FTDX9000 | - | - |  |
| Yaesu FTX-1F | FTX1F | - | - |  |

_99 registered radios; 5 with a test report._
