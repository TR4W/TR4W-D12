# Radio factory migration — open assumptions

Every row is something the migration currently **assumes** and has **not proven**.
NY4I confirms or rejects; nothing here is settled by the code agreeing with itself.

Status values:
- **OPEN** — awaiting NY4I's ruling or a bench report
- **CONFIRMED** — NY4I confirmed, or a bench/manual/hamlib source settled it
- **REJECTED** — wrong; the fix is noted in the row

Grounding rank used throughout (best first):
1. Manufacturer CAT manual
2. Independent implementation — hamlib, or the D7 tree at `C:\TR4W`
3. TR4W's own driver (circular when used to justify a TR4W change)
4. `tools/radiosim` (evidence about TR4W only, never about a radio)

---

## A. Yaesu FT-817 group — FT-847 / FT-857 / FT-897 (in progress, uncommitted)

| # | Assumption | Basis | Risk if wrong | Status |
|---|---|---|---|---|
| A1 | FT-847 needs the `$00` CAT-enable frame **once at connect** | FT-847 manual p.92 chart: `CAT ON/OFF, P1=00 CAT ON` | Radio ignores all CAT | **CONFIRMED** — NY4I + manual |
| A2 | FT-847 has **no** DIG/data modes | FT-847 manual p.92 mode chart has no DIG/PKT; LOGRADIO row agrees (`DIGL/DIGU $FF`) | Operator cannot select a mode the rig has | **CONFIRMED** — NY4I + manual |
| A3 | FT-857/897 still need **deferred writes** in the factory | — | needless 100 ms stall per write | **REJECTED** — NY4I; FT-857D manual pp.115-118 show protocol identical to FT-817 with nothing on write timing. Machinery removed; bench watch-item kept in `uRadioYaesuFT857` |
| A4 | Last-write-wins for a superseded queued QSY | — | — | **MOOT** — A3 rejected |
| A5 | Queued mode emitted before frequency | — | — | **MOOT** — A3 rejected |
| A6 | FT-857/897 otherwise identical to the FT-817 | FT-857D manual: same 5-byte block, same opcodes `01/07/03/F7/02/82/05/85/F5/08/88`, same TX-status bits | Wrong freq/mode decode | **CONFIRMED** — manual |
| A7 | FT-857/897 offer DIG (`$0A`) but **not** PKT-as-RTTY (`$0C`) | LOGRADIO rows `DIGU $0A, DIGL $FF`; manual confirms `$0C` = PKT exists on the radio | TR4W withholds a mode the rig has — a deliberate match to D7, not a hardware limit | OPEN — low risk |
| A8 | FT-847 has **no split** and **no clarifier** over CAT | FT-847 manual p.92: no SPLIT row, no CLAR rows | Sending `$02`/`$05` would be undefined opcodes | **CONFIRMED** — manual |
| A9 | FT-847 satellite VFOs (`$11/$21`, `$17/$27`, `$13/$23`) are out of scope | TR4W has no satellite-VFO concept; legacy drove MAIN only | Satellite ops unsupported — same as D7 | OPEN — scope call, not a defect |

## B. Icom CI-V batch (committed `d3f0237`, none bench-tested)

| # | Assumption | Basis | Risk if wrong | Status |
|---|---|---|---|---|
| B1 | The 26 legacy Icoms read frequency via `$03` **only** — no `$25`/`$26` | `IcomRadiosThatSupportVFOB` | Under-featured: no VFO-B readout on rigs that support it | **CONFIRMED** — NY4I: the list is accurate. My earlier suspicion that IC-746PRO / IC-756PROIII / IC-9100 were under-declared was wrong |
| B2 | Split is **set-only** on all 26 | — | Split indicator never updates from the rig | **REJECTED — was a regression.** `IcomRadiosSplitSetOnly = [IC718]` only, and the set does not exist in D7 at all (D7 polls `$0F` for every Icom). Fixed: `TIcomReadLimitedRadio` keeps `rcReadSplit` |
| B3 | TX status (`$1C`) is **unreadable** on all 26 | — | No PTT state from CAT | **REJECTED — was a regression.** `IcomRadiosTXStatusUnreadable = [IC718]` only; absent from D7 entirely. NY4I: IC-9700 manual documents `1C 00` read (00=RX, 01=TX). Fixed: `rcReadTXStatus` kept |
| B5 | `$06` set-mode sends **mode byte only** on all 26 | — | Mode set differs from D7 on the write path | **REJECTED — same regression.** `IcomRadiosModeSetNoFilter = [IC718]` only. Fixed by dropping `TIcomLegacyRadio` (which sets `FModeSetIncludesFilter := False`) |
| B6 | `rcDataMode` should be withheld from the 26 | — | `$1A06` never sent; USB-D unavailable | **REJECTED — same regression.** D7 does not gate `$1A06` on a list; it PROBES (`icomHasDataMode`, LOGRADIO:283/:1565) and sends it to every Icom. Fixed |
| B4 | CI-V addresses match the legacy table | **TESTED** — `uTestIcomRegistry`, 44 radios, mutation-verified | Radio never answers; looks like a cable fault | CONFIRMED (vs D7 only — not vs the real radios) |

## C. Yaesu ASCII + rtYaesu2 (committed, none bench-tested)

| # | Assumption | Basis | Risk if wrong | Status |
|---|---|---|---|---|
| C1 | rtYaesu2 `IF` is 27 bytes, 8-digit freq, every field one earlier than the newer sets | `pFTDX9000` reads exactly 27; `GetVFOInfoForFT2000` = freq `(6,8)`, clar `(14,5)`, RIT `19`, XIT `20`, mode `21`; `GetVFOInfoForYaesuType3` is each one later | Silently wrong frequency | **CONFIRMED** — code, field by field |
| C5 | rtYaesu2 is an **ASCII** protocol (FA/IF/OI/FR/FT/MD/TX/KS/ID), not binary; only rtYaesu1 is binary | NY4I; `pFTDX9000` sends `'IF;'`/`'OI;'`/`'FR;'`; `KS%003u;` for rtYaesu2/3/4 (LOGRADIO :3266) | — | **CONFIRMED** — factory already implements it as ASCII via `TYaesuSerial`; MD/TX/KS inherited |
| C6 | FT-2000 `ID` returns **0251** | NY4I | — | **CONFIRMED** — recorded in `uRadioYaesuFT2000Models`; ident check not wired (would be new behaviour vs D7) |
| C7 | rtYaesu2 has no split/TX readback **because the radio cannot** | — | Withholds a capability the rig has | **REJECTED** — the FT-2000 does support `TX` (NY4I). TR4W simply never polls them (`pFTDX9000` sends only `IF;`/`OI;`/`FR;`). Comment corrected: this is a DRIVER gap, not a hardware limit. Adding the reads = improvement over D7, wants a bench |
| C2 | FT-991 mode char `'E'` = FM | NY4I supplied the MD table | Wrong mode in the log | CONFIRMED by NY4I |
| C3 | FTX-1F `IF` is 30 bytes — all offsets +2 vs the FTDX-10 | NY4I's manual IF/FA tables **and** `GetVFOInfoForYaesuFTX1`: freq `(8,9)`, clar `(17,5)`, RIT `22`, XIT `23`, mode `24`, `ReadFromCOMPort(30)` | Wrong frequency | **CONFIRMED** — manual + code agree field for field. Cause of the +2: P1 is a 5-byte VFO/memory field where the FTDX-10's is 3. FA is `FA` + 9 digits + `;` = 12 chars, matching `Format('%s%.9d;')` |
| C8 | FTX-1F mode chars `H`/`I` (C4FM-DN / C4FM-VW) map to `rmFM` | manual P6 table; `TRadioMode` has no digital-voice member | C4FM QSOs log as FM | **CONFIRMED** — NY4I: C4FM should map as FM. Applies to the FT-991's `E` too (`FModeCharE := rmFM`) |
| C9 | FTX-1F split is set with `FT3;`/`FT2;` | legacy `LOGRADIO:2109/:2173` grouped FTX1F with FTDX10/101/FT991 | **Split never engaged** — the radio was sent an undefined P1 | **REJECTED — PRE-EXISTING BUG, NOW FIXED.** NY4I: the FTX-1F documents only `FT0;` (main) and `FT1;` (sub = split). Fixed in `uRadioYaesuFTX1F.Split` (`FT1;`/`FT0;`) **and** in the legacy fallback (`FTX1F` moved to the `FT710` branch at `LOGRADIO:2109/:2173`). Pinned by `Test_FTX1F_Split_Uses_FT1_FT0`, which also asserts the FTDX-10 still uses `FT3;` so the fix is not applied family-wide. **First defect this migration found in shipping D7/D12 behaviour rather than introduced.** |
| C10 | FTX-1F `ID` returns **0840** | NY4I | — | **CONFIRMED** — recorded in `uRadioYaesuFTX1F`; ident check not wired |
| C11 | FTX-1F `TX;` answer: `1`/`2` = transmitting | manual TX table (0=both off, 1=CAT TX on, 2=RADIO TX on) | Wrong PTT state | **CONFIRMED** — base parses `in ['1','2']`, matches legacy `pFTX1F` |
| C4 | `FR` reports the receive VFO and is **not** a split indicator; `FT` is what indicates split | NY4I + FTDX-9000 manual (FT answer P2: 0=Main, 1=Sub) | Split indicator lights when the operator merely selects VFO B | **CONFIRMED** — `Test_Y2_FR4_SelectsVFOB` asserts `FR4` sets VFO B *and* leaves `IsSplitEnabled` false |
| C12 | FT-950, FT-2000 and FTDX-9000 share one `FR` meaning, so one class serves all three | legacy `pFTDX9000` guards the `FR;` read with `RadioModel in [FT950, FT2000, FTDX9000]` and tests `tBuf[3] = '4'` | On the FTDX-9000 the VFO-B branch may never fire | **OPEN — GROUPING, not a coding error.** The `'4'` logic itself is correct and faithfully ported: `tBuf` is `array[1..512]` (1-based) so `tBuf[3]` is P1, and the factory's `sMessage[3]` is the same character after the reading thread strips the terminator. It has evidently been working on the radios that motivated it. The open point is narrower: legacy's own comment distinguishes `FT950/FT2000 - FUNCTION RX` from `FT9000 - RECEIVER STATUS`, and the FTDX-9000 manual shows `FR` P1 = 0..3 describing TWO INDEPENDENT receivers (both can be RX at once), where `'4'` would not occur. **NY4I verifying whether the FTDX-9000 belongs in this class at all** — it has true dual receive, so "which VFO is receiving" may not be a single answer there. My earlier "can never fire / pre-existing bug" framing overstated it |
| C13 | rtYaesu2 "genuinely cannot" report split or TX status | — | Withholds a capability the rigs have | **REJECTED** — same error as C7. The FTDX-9000 `FT` Read form is documented. TR4W just never polls it (`pFTDX9000` sends `IF;OI;FR;`). Comment corrected in `uRadioYaesuASCIILegacy`; the flags stay absent because the *driver* does not read them, and adding an `FT;` poll would be an improvement over D7 |
| C14 | rtYaesu2 split **set** `FR0;FT3;` / `FR0;FT2;` | FTDX-9000 manual FT Set: P1 `2` = TX on Main (VFO-A), `3` = TX on Sub (VFO-B) | Split never engages | **CONFIRMED** — manual matches the shipped commands (unlike the FTX-1F, C9) |

## D. FT-736R (committed `6dc2cb9`)

| # | Assumption | Basis | Risk if wrong | Status |
|---|---|---|---|---|
| D1 | TR4W never had a working read path for it | `pFT736R` has no `ReadFromCOMPort` and no `repeat` loop; identical in D7 | — | CONFIRMED (code-verified both trees) |
| D2 | The **HamLib** path works for this radio | hamlibID 1010 present; never exercised | Radio still does not work, now via a different route | OPEN — needs an operator with an FT-736R |

## F. FlexRadio (bench: NY4I has a FLEX-6000 on SmartSDR CAT, 2026-07-28)

Source: SmartSDR CAT User Guide v4.1.5 (proprietary — cite sections, do not copy tables).

| # | Finding | Basis | Status |
|---|---|---|---|
| F1 | The `ZZxx` command set works on the **serial** CAT port, not only TCP | §2.2.2.1 — the CAT port speaks Kenwood 2-char **plus** Flex 4-char `ZZxx` | **CONFIRMED** — so ONE driver serves serial and TCP 5002; no protocol branching by transport. My earlier "serial = TS-2000 emulation only" was wrong |
| F2 | SmartSDR CAT exposes **TCP 5002** speaking the same CAT protocol; **4992** is the separate Ethernet API | §2.2 / existing `TFlexRadio6000` registration | **CONFIRMED** — matches NY4I's rule: one radio type, CAT Port setting picks transport |
| F3 | VFO B reads blank | §1.2 — a Split Slice does not exist until a **CAT** split (`FT1;`/`ZZSW1;`) creates it; earlier VFO B commands return `?;`. A split made in the SmartSDR UI does not count. `?;` is 2 bytes where `pKenwood2` demands 14, so it is discarded | **CONFIRMED — NOT A TR4W BUG** |
| F4 | Only one RIT/XIT offset is displayed | The Kenwood subset has `RT`/`XT` states and `RC`/`RD`/`RU`, but **no command to read either offset**; the only offset over Kenwood is the single `IF;` field. Separate offsets need `ZZRG` (A RIT), `ZZXG` (A XIT), `ZZRW` (B RIT) | **CONFIRMED** — the two-offset display needs the `ZZ` commands |
| F5 | `TFlexRadioCAT` on the `ZZ` set should replace the Kenwood path for Flex | `ZZFB`, `ZZRG`/`ZZXG`, `ZZIF` have no Kenwood-subset equivalent | OPEN — next session's first task |

## E. Design / cross-cutting

| # | Assumption | Basis | Risk if wrong | Status |
|---|---|---|---|---|
| E1 | `rcSharedRITXITOffset` has **no** hamlib equivalent | my expectation only — NOT verified | Mapping is needlessly partial | OPEN — NY4I checking the hamlib repo |
| E2 | `RIG_FUNC_RIT` = bit 24, `RIG_FUNC_XIT` = bit 31 | `uHamLibDirect.pas:363-364` — **its own block comment at :355 says bits 5 and 6** | Silently reads some other function's state as RIT | OPEN — contradiction inside our own source |
| E3 | Permissive capability default (`TIcomRadio` full set, legacy subtracts) is acceptable | current structure | A new Icom unit that omits `DefineCapabilities` silently claims reads it cannot do | OPEN — task #9, NY4I's call |

---

## Corrected assumptions (kept as a record of failure modes)

| Was assumed | Reality | Root cause |
|---|---|---|
| TS-890 had no D7 implementation | It does — `C:\TR4W\tr4w\src\uRadioKenwoodTS890.pas` | Inferred from a unit header without checking the D7 tree |
| `IcomRadiosThatSupportRIT` amounts to IC-7700 + IC-7800 | It names **thirteen** radios; eleven were already migrated | Summarized a table in prose; the summary became load-bearing |
| `HamLibONLYRadios` is dead code | It is the live wiring (`uCAT:1253`, `:1452`) | **Case-sensitive grep** — Pascal identifiers are not case-sensitive |
| FT-736R is a "write-only rig" | TR4W never implemented a read path; the *radio's* capability is unknown | Described the hardware when the evidence only covered the code |
| 26 Icoms cannot read split / TX status, and set mode without a filter byte | D7 and D12 both do all three for every Icom except the IC-718 | **Misread one-element deny-lists.** `[IC718]` means one EXCEPTION, not "only this one is proven, withhold from the rest". Compounded by reusing `TIcomLegacyRadio`, a profile bench-derived from four *other* radios (IC-706 family / IC-7000) whose header explicitly said siblings should fan out "once these validate" |
| The registry test was sufficient | It checked 2 of the 4 capability sets, so it passed while 26 radios were wrong | Wrote the test against the assumptions I had already made, rather than against every available source |
