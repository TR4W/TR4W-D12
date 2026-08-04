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
| Elecraft K3 | K3 | 2026-07-31 | NY4I | CW-by-CAT send verified (KY padded to 22). Escape-stops-CW failed, fixed 163723a, RETESTED OK. WinKeyer keying verified same day; function-key latency 383 ms -> 25 ms after 3b93fb6. 2026-08-01: StopCW moved out of LOGRADIO into TElecraftSerial ('KY <04>;RX;') and re-verified, Escape included. 2026-08-01: interrupting CW VERIFIED WORKING -- a function key pressed during a message now aborts and the new message keys, including a 1-character one (F9 '?'). Needed three separate fixes: the TX/PTT sighting latch (a poll declared the message finished 168-272 ms in), the CWByCAT_Sending guard on the abort (an idle radio was aborted before every message), and a 75 ms settle delay after 'RX;'. NOTE the RX is REQUIRED -- ^D alone does not stop plain CW ("use with CW-to-DATA") -- and padding does NOT substitute for the delay, because the K3 trims trailing fill rather than keying it. 2026-08-01: re-verified after the CAT repoint (edc9cbf) moved the whole CW-by-CAT send out of RadioObject.SendCW into uCWKeyerCAT.CWByCATSend -- function keys still key correctly. 2026-08-01: startup command VERIFIED across all three cases -- at TR4W start, on Reset Radio Ports, and after a radio POWER CYCLE. The power-cycle case needed 92eebec: the command was going out 153 ms after the rig's first CAT byte, which the radio accepted on the port and silently dropped. A rig that answers IF; is not yet a rig that will act on anything, so the send now waits STARTUP_COMMAND_SETTLE_MS (2000) after the link comes up. 2000 ms is unmeasured but sufficient on this K3.  2026-08-04 (K3S, USB serial): CW-by-CAT and CW SPEED SYNC both VERIFIED after the capability/framing rework. This is the bench evidence for 4a7f9833, which moved the frame rule (22 chars, padded) and the prosign dialect off uCWFraming's InterfacedRadioType table and onto TElecraftSerial as declared capabilities -- the K3 pad-to-22 is the bench-derived quirk that rework most risked losing, and it survived. Also covers a9e77155, which repointed the rcCWByCAT / rcCWSpeedSync gates at the radio object (RadioObject.HasCapability) instead of a model-keyed registry lookup. Tested on a K3S, which uses the K3 registration. |
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
| Icom IC-7100 | IC7100 | - | - |  |
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
| Icom IC-7700 | IC7700 | - | - |  |
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
| Yaesu FT-1000MP | FT1000MP | - | - |  |
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
