# Adding a radio to the TR4W radio factory

A working guide for the developer adding support for a new rig. Keep it current —
**every time you add a flag or a seam, add it to the tables below.** The point is
that the next person can find out what a base class already handles without
reading the base class.

---

## 1. The one rule that matters

**A base class must NEVER ask which radio model it is.**

```pascal
// NO -- this is the bug this whole design exists to prevent
if RadioModel in [FT857, FT897] then ...

// YES -- the model declares a trait; the base reads it
if FDefersWrites then ...
```

The subclass sets flags in its constructor; the base guards on flags. This is not
style. Three separate defects were found in one afternoon (2026-07-28) that all
had the same shape: a model was folded into a sibling's `case` branch and
inherited commands it does not implement.

- **FT-847** — inherited the FT-817's `Split` and clarifier. Its opcode chart has
  no SPLIT row and no CLAR rows at all.
- **FTX-1F** — inherited the FTDX-10's `FT3;`/`FT2;` split. Its `FT` defines only
  `0` and `1`, so split never engaged.
- **FT-2000** — same, via LOGRADIO Issue #166, which moved the whole rtYaesu2
  group from `FT1;/FT0;` to `FT3;/FT2;`. Correct for the FT-950 and FTDX-9000
  (whose `0`/`1` are *toggles*), undefined on the FT-2000.

### Why one class per model, even when two models are identical today

The FT-950, FT-2000 and FTDX-9000 look like one group. They are not:

| | FT-950 | FT-2000 | FTDX-9000 |
|---|---|---|---|
| `FT` (split) | 0,1 toggle + **2,3** absolute | **0,1 only** | 0,1 toggle + **2,3** absolute |
| `FR` (RX VFO) | 0,1,**4**,5 | 0,1,**2,3** | 0,1,**2,3** |

By `FT` the odd one out is the FT-2000. By `FR` it is the FT-950. **No class
hierarchy expresses that** — only independent flags do. If you find yourself
wanting to merge two model classes because they are currently identical, don't:
the next command you implement may divide them differently.

---

## 2. How to add a radio

1. **Find the closest existing MODEL file** (`uRadioYaesuFTDX10.pas`,
   `uRadioIcom7300.pas`, …) and copy it. Not the family base — a model file.
2. **Read the manufacturer's CAT manual for the new radio.** Do not assume it
   matches the model you copied, even for one command. That is exactly how the
   three bugs above happened.
3. Set the identity (`radioModel`, CI-V address, etc.) and **only** the flags
   that genuinely differ.
4. If a difference has no flag yet, **add one to the family base** with a safe
   default that preserves existing behaviour, and document it in §3 below.
5. `RegisterRadio` — **one entry per model an operator can buy**, with its own
   display name. A duplicate display name makes a model invisible in the radio
   list.
6. Add the unit to `tr4w.dpr` **and** to `test/unit/tr4w_unit_tests.dpr`.
   ⚠ List it explicitly in both. Radios self-register from unit initialization,
   so a unit reached only through another unit's `uses` clause silently vanishes
   — with no compile error — the moment that chain changes.
7. **Write tests with paired opposites** (§5).
8. Add a row to `RADIO_MIGRATION_ASSUMPTIONS.md` for anything not verified.

---

## 3. Flags and seams available today

### Capabilities — `TRadioCapability` (`uFactoryRadioBase.pas`)

Declared per radio in `DefineCapabilities`, a virtual called from the base
constructor. Callers ask `radio.Supports(rcX)`.

| flag | meaning |
|---|---|
| `rcReadVFOB` | can read the UNSELECTED VFO's freq+mode (Icom `$25`/`$26`) |
| `rcReadRIT` | can read RIT/XIT state and offset back |
| `rcReadSplit` | reports split back, vs set-only |
| `rcReadTXStatus` | can read TX/RX (PTT) state over CAT |
| `rcDataMode` | has a data sub-mode (Icom `$1A06`); NOT plain RTTY |
| `rcCWByCAT` | can key CW over CAT — DECLARATION ONLY today |
| `rcSharedRITXITOffset` | ONE offset register shared by RIT and XIT |

Ranged traits are fields, not flags: `CWSpeedMin` / `CWSpeedMax`.

> **State capabilities honestly.** A missing flag means *TR4W does not read it*,
> which is not the same as *the radio cannot report it*. Three unit headers
> claimed the latter from evidence that only supported the former (FT-736R,
> FT-2000, rtYaesu2 generation). If TR4W simply never polls it, say so — that is
> a driver gap and a future improvement, not a hardware limit.

### Yaesu — old binary, `TYaesuFT817Radio` (`uRadioYaesuFT817.pas`)

| flag | default | set it when |
|---|---|---|
| `FCATEnableOnConnect` | `False` | radio ignores CAT until an enable frame (FT-847) |
| `FModeDIGU` | `$0A` | `$FF` if the radio has no DIG mode |
| `FModeDIGL` | `$0C` | `$FF` if no DIG-L / PKT (FT-847, FT-857, FT-897) |
| `FHasSplit` | `True` | `False` if the chart has no SPLIT command (FT-847) |
| `FHasClarifier` | `True` | `False` if the chart has no CLAR command (FT-847) |

`$FF` = "the radio does not have this mode", matching the legacy
`RadioParametersArray` `DIGL`/`DIGU` convention.

### Yaesu — ASCII legacy / rtYaesu2 (`uRadioYaesuASCIILegacy.pas`)

| flag | default | set it when |
|---|---|---|
| `FReadsActiveVFO` | `False` | radio answers `FR;` (FT-950, FT-2000, FTDX-9000) |
| `FSplitAbsoluteTwoThree` | `True` | `False` for the FT-2000 — its `FT` has only 0/1 |
| `FVFOBReceivingChars` | `['4']` | `['4','5']` FT-950; `['3']` FT-2000 / FTDX-9000 |

### Yaesu — ASCII modern (`uRadioYaesuASCII.pas`)

| seam | kind | notes |
|---|---|---|
| `FModeCharE` | field, default `rmPSK` | mode char `E`: PSK on most, C4FM (→ `rmFM`) on Fusion radios |
| `ParseIFResponse` | virtual | override when the `IF` layout moves (FTX-1F is +2 with a 30-byte frame) |
| `ModeCharToMode` | virtual | override to ADD chars; call `inherited` for the rest |
| `ModeToYaesuDigit` | virtual | |
| `ProcessMessage` | virtual | handle your command, `inherited` for the rest (FT-891 `ST`) |
| `Split` | virtual | override for a different dialect (FT-710 / FTX-1F `FT1;`/`FT0;`; FT-891 `ST1;`/`ST0;`) |

### Icom (`uRadioIcomBase.pas`, `uRadioIcomLegacy.pas`)

| trait | notes |
|---|---|
| `RadioAddress` | CI-V address — **must** match `RadioParametersArray`; a test enforces this |
| `FDirectFreqRoute` | skip the `$07 $D2` active-VFO query |
| `FModeSetIncludesFilter` | `False` when `$06` takes the mode byte only (IC-718) |

Two profiles exist and choosing wrongly is a silent regression:

- `TIcomRadio` — full modern profile.
- `TIcomReadLimitedRadio` — full **minus** `rcReadVFOB` and `rcReadRIT`, for
  radios absent from `IcomRadiosThatSupportVFOB` / `...RIT`.
- `TIcomLegacyRadio` — the **bench-proven** minimal profile for the IC-706 family
  and IC-7000 only. Do not attach a radio to it without hardware: it also
  withholds split read, TX-status read and the set-mode filter byte, which D7
  performs for every Icom except the IC-718.

---

## 4. Where the truth lives

In this order:

1. **The manufacturer's CAT manual** for *that* model.
2. **An independent implementation** — hamlib, or the D7 tree at `C:\TR4W`.
3. **TR4W's own code** — authoritative for "what does TR4W do?", which is the
   question a migration must answer. Grep D12 and D7 before opening a manual for
   behaviour the working program already demonstrates.
4. **`tools/radiosim`** — evidence about TR4W only, never about a radio.

A bench report beats code that contradicts it. Record such divergences explicitly
(see `BenchProvenDivergences` in `uTestIcomRegistry.pas`) rather than weakening a
test.

Two traps worth naming:

- **Grep case-insensitively.** Pascal identifiers are case-insensitive and TR4W
  spells the same one several ways (`HamLibONLYRadios` / `HAMLibONLYRadios`). A
  case-sensitive search produced a false "dead code" conclusion.
- **A one-element deny-list is an EXCEPTION, not a whitelist.**
  `IcomRadiosSplitSetOnly := [IC718]` means *every other* Icom reads split. Reading
  it as "only the IC-718 is proven" withheld the capability from 25 radios.

---

## 5. Testing

Two layers, both runnable without hardware:

- `test/unit/` — no transport. Subclass the radio, override `SendToRadio` to
  capture, assert the exact bytes. CI-able.
- `test/integration/` — real serial pair against `tools/radiosim`
  (`run-bench.ps1`). Proves framing and timing.

**Always pair a negative assertion with a positive one on a sibling.** A test
that only says "the FT-847 sends nothing for Split" passes just as happily when
`Split` is broken for every radio:

```pascal
CheckEquals('', ft847.sent);      // FT-847 has no split command
CheckTrue(Length(ft817.sent) = 5); // ...but the FT-817 still sends one
```

Same for anything you deliberately keep different between models — assert both
sides, so a later "cleanup" that re-merges them fails loudly.

Notes:
- `uTR4WTestFramework` calls `TearDown` after **every assertion**, so build and
  free the probe inside each test rather than sharing fixture state.
- Assert modes via `ModeToString`, not ordinals — `Ord(TRadioMode)` values look
  like Yaesu MD codes and read as nonsense in failure output.
- A standalone EXE must assign MainUnit's global `logger` or the factory base
  access-violates.

---

## 6. Before you call it done

- [ ] Manual read for **this** model, not a sibling
- [ ] Only flags set; no model test added to any base class
- [ ] `RegisterRadio` with a unique display name
- [ ] Unit listed explicitly in `tr4w.dpr` **and** `tr4w_unit_tests.dpr`
- [ ] Tests with paired opposites
- [ ] `Lint-RadioRegistry.ps1` clean (no display-name collisions)
- [ ] Marked **NOT BENCH-VALIDATED** in the unit header until someone runs it on
      the real radio, with specific things for the tester to check
- [ ] Anything unverified recorded in `RADIO_MIGRATION_ASSUMPTIONS.md`
