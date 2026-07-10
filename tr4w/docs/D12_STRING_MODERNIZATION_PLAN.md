# TR4W — Delphi 12 String Modernization Plan

Status: **v2, post architecture-review** (2026-07-05). Branch: `delphi12`.
Verdict from independent adversarial review: **GO-WITH-CHANGES** — phases re-drawn, three
pre-start decisions added, two blind spots (wire==disk==DTO; CP1251 source literals) folded in.

---

## Progress — as of 2026-07-09

The plan below is the design; this section is **where we actually are**. Every item
here landed with a clean Win32 build + golden-master corpus (22 pass / 0 fail / 4
known-divergence) and was committed on `delphi12`.

**Done**

- **Phase 0/1 — running D12 build + oracle.** Compiles under D12 command-line
  (`msbuild /t:Make`) and IDE. The golden-master corpus (`tr4w.exe "<cfg>" /EXPORT`
  → byte-diff ADIF + Cabrillo + CLAIMED-SCORE vs frozen D7 refs) is the regression
  oracle for every change; fail-loud (`GOLDEN_STRICT`) so a stale/aborted export
  can't mask a gap.
- **Radio byte-path (CI-V).** Icom network + serial CI-V made byte-faithful
  (`AnsiString` framing, `Char(byte)`/`AnsiChar(Ord())` at edges, never CP1252).
  Hardware-validated (freq/mode/RIT/XIT/split).
- **Leaf-first interior `string` flips (Phase 4).** utils_text, uCabrilloFormat,
  uCallSignRoutines, uMults, uCallsigns, uSpots, uSSL, uCTYDAT (param + return),
  uFreqTimeFormat (killed a shared-static-buffer aliasing bug class), and the
  tree.pas string producers (GetLogEntry*String, GetFirst/LastString,
  Number/Bracketed/BigExpandedString, MinutesToTimeString, …), InitialExchangeEntry,
  GetSunriseSunsetString, ProperSalutation, GetVEInitialExchange, SACDistrict,
  FindDirectory, GetInitialExchangeStringFromContestExchange.
- **Win32 A→W display chain.** freq/time formatters → `string` + `SetWindowTextW`/
  `SetDlgItemTextW`; `SetMainWindowText`, `ShowMessage`/`ShowMessage2`/`ShowMessageParent`
  (→ `MessageBoxW`), `QuickDisplay`/`QuickDisplayError`, `showwarning`, `TotalTextOut`,
  `AddStringToTelnetConsole`, window-creation helpers (`tCreateStaticWindow`/
  `tCreateButtonWindow` → `CreateWindowExW`), `tCB_ADDSTRING(_PCHAR)` → W.
- **ListView A→W (Unicode).** New `uCommctrl` string helpers `tLVInsertRow`/`tLVSetText`
  (single `PWideChar` boundary isolated inside; TRACE-log each value for UI-less
  validation) — and fixed 3 latent bugs where `ListView_SetItemW/InsertItemW/SetItemTextW`
  sent the **A** messages with wide structs. Converted: **uLogCompare, uNet, uOption**.
  (uMultsFrequencies was dead.)
- **Duplicative-TF-shim elimination** (RTL now used directly): `IntToStr`, `RealToStr`,
  `SysErrorMessage`, and the `StrPos` indirection removed; `StrToInt` → `StrToIntDef(x,0)`
  (behavior-preserving); `inttopcharHEX` deleted. `showwarning`/`UnableToFindFileMessage`
  flipped to `string`.
- **Done-criterion census.** `PAnsiChar(AnsiString(...))` double-casts reduced to genuine,
  tagged boundaries (`inet_addr`, `rig_set_conf`, `msvcrt_fopen`, `lstrcpyA`, INI files,
  the raw telnet socket buffer).
- **Housekeeping.** ~1,400 lines of dead code removed (compiler-verified); 8
  transitively-compiled units added to `tr4w.dpr` for project-search visibility.

**Deferred / queued (intentional)**

- **MainUnit editable-log renderer** (`tAddContestExchangeToLog`) — the one ListView
  deeply entangled with ~15 ANSI `ContestExchange` DTO reads. Left on the A-path
  (renders fine on the Unicode control); to be converted **with** the SQLite /
  `ContestExchange`-as-object work so `RXData` is already `string`s. Consequence:
  `inttopchar` keeps a few consumers and one tagged freq-column cast until then.
- **Telnet socket I/O** — centralize byte↔string at the socket layer (one decode after
  `recv`, one encode before send) and make `ProcessTelnetString`/`ProcessDX` string-based.
  A parser rewrite (byte-offset/`PInteger` DX-spot matching), not a cast tweak.
- **`ContestExchange` → object + SQLite** (Phase 5). The frozen v1.7 DTO stays the
  save/send boundary until then.
- **Vendored-RTL replacement** — bundled Indy tree and `src\MMSystem.pas` still shadow
  the D12 RTL (search-path wins). Needs live network/SSL testing to swap; own effort.
- **Lower-value shims** — `StrComp_JOH_IA32_6` (clamps to −1/0/1, semantic diff),
  `BooleanToStr`, `RealToStr2`, `tCreateEditWindow`, file-op `CopyFileA`/`FileExists`.

## 1. Goal & guiding principle

Standard Delphi **`string` (UTF-16 `UnicodeString`) is the default** for all text in the
logic / UI / in-memory layer. Any `Char`/`AnsiChar`/`PChar`/`PAnsiChar`/`ShortString`/byte-array is a
**boundary claim** — "I am at an explicit edge, here is my documented reason." A byte-typed site that
can't back that claim is a defect to convert. End state: the ANSI-vs-wide ambiguity that produced the
D12 invisible-bug stream cannot exist in the logic layer; it exists only at explicit, compiler-checked
boundaries. The prior "ANSI-now" phase was the correct on-ramp — it got the app running and mapped
every boundary.

## 2. Encoding policy (the strongest part; unchanged by review)

- **Internal:** `string` = UTF-16 everywhere in the logic layer.
- **No no-op boundary** (unlike CQRLOG's FPC/UTF-8 `AnsiString` model): every edge converts with
  explicit `TEncoding`:
  - Files / ADIF / cluster-out: **UTF-8, no BOM**.
  - Legacy ANSI ingest (CTY.DAT, TRMASTER, `.dat`, old `.cfg`): decode at ingest (data is implicit
    system-ANSI). ASCII fast-path; CP1252/Latin-1 for CTY names; system-ANSI for operator free-text.
  - SQLite: UTF-8 native (full Unicode; avoid CQRLOG's MySQL 3-byte `utf8` wart). Own the UTF-16<->UTF-8
    at the driver boundary — verify the wrapper doesn't double-encode.
  - Wire / radio / CW: byte streams; convert at pack/unpack and at the radio factory.
  - Win32: **W-APIs** natively.
- **ADIF `_INTL`** (from CQRLOG, adapted): plain tags ASCII byte-count; non-ASCII fields emit `*_INTL`
  with **UTF-8 byte length** = `Length(TEncoding.UTF8.GetBytes(s))`, never `Length(s)`.
- **Callsign/dupe comparisons stay ordinal/ASCII** — never locale-aware `AnsiCompareStr` (would shift
  dupe/sort semantics). ASCII `c in ['A'..'Z']` filters remain valid.

## 3. Boundary allowlist (legitimate non-`string`) — corrected

1. **The `ContestExchange` struct = ONE boundary, not two.** Wire payload, on-disk record, and DTO are
   the *same* `packed record` (`VC.pas` byte-offset layout; `TNetQSOInformation` embeds it;
   `sWriteFile(..., SizeOf(ContestExchange))`; versioned `ContestExchangev1_6`/`v1_5` prove the layout
   is an evolving compatibility contract). It stays **frozen** as the DTO. **Consequence the review
   surfaced:** the DTO is a *lossy* target for our own Unicode goal — any field carrying a codepoint the
   legacy ANSI record can't represent must be **down-mapped (lossy)** when saved to a v1.6 log or sent
   to a legacy peer. This rule must be explicit before any interior field goes Unicode.
2. **Other wire buffers / packed structs** (server control messages, UDP) — byte-exact.
3. **Hardware byte streams** — radio CAT, CW keyer, DVK.
4. **External-file ingest buffers** — mmap of CTY.DAT/TRMASTER before decode.
5. **Win32 fixed-buffer calls.**
6. **Measured hot paths** (rare, profile-justified).
7. **Compile-time codepage boundary (NEW):** the CP1251 `src/lang/tr4w_consts_*.pas` literals. Not a
   runtime edge — the *compiler* transcodes them. Needs an explicit codepage strategy (see §5, Phase 2)
   and likely a one-time exception to the "don't edit lang files" rule (add BOM or `{$CODEPAGE 1251}`).

Each surviving site tagged `// boundary: <reason>`; lint (`Lint-PCharAnsi.ps1`) flags unmarked
non-`string` in the logic layer.

## 4. Structural changes — corrected

- **`ContestExchange` record -> object is inseparable from the interior conversion.** It is NOT a
  standalone seam (747 sites, no choke point). The class is introduced **per-module, during Phase 4**,
  as each module's interior flips to `string`; the frozen record remains the DTO at save/send.
- **Genuinely isolable seams (these *are* Phase-3 work):** the **single log reader/writer**
  (`sWriteFile`/`BlockRead` is a real choke point), the **wire pack/unpack**, the **radio factory**
  byte-ownership, and **external-file decode-at-ingest**.
- **Win32 -> W-APIs.** Larger than a footnote: **284 A-API sites across 65 files**, including
  `GetWindowTextA` reading the operator callsign *into the network path* — a W read of a CP1251-sourced
  field would re-encode it. Treat as its own tracked surface with a data-path check, not mechanical.

## 5. Phased sequence (re-drawn per review)

- **Phase 0 — Baseline.** Commit the running ANSI build. Freeze the PChar->PAnsiChar audit
  (logic-layer conversions superseded; keep boundary fixes).
- **Phase 1 — Golden-master oracle (prerequisite).** NOT "unit-test ProcessExchange" (un-callable
  without global state). Instead: capture a **corpus of real historical `.dat` logs**, and lock
  **byte-exact ADIF + Cabrillo output + score summary** through the exporters that already have
  regression tests (`uTestADIFRegression.pas`, `uTestCabrilloFormat.pas`). This exercises the TRDOS
  core (parse/scoring/dupe) through its real entry points and becomes the oracle for every later change.
- **Phase 2 — Decisions (resolve before any mass edit).**
  (a) CP1251 source-literal compile-time strategy + the lang-file edit exception;
  (b) the frozen DTO layout + the documented **lossy down-map** rule for Unicode-bearing fields;
  (c) SQLite wrapper selected + verified (UTF-8, no double-encode);
  (d) finalize the legacy-ingest codepage policy against real fixtures.
- **Phase 2.5 — Proof-of-concept slice (do FIRST, before mass edits).** Pick one leaf, ASCII-only
  module already under test (the callsign/exchange parsing behind `uTestCallSignRoutines`). Flip *only
  its* interior to `string`, cross the DTO boundary exactly once, and prove the Phase-1 golden master is
  byte-identical. Validates the entire pattern on ~1% of the surface before committing to it.
- **Phase 3 — Isolable boundary seams.** Log reader/writer, wire pack/unpack, radio-factory bytes,
  external-file decode, Win32->W. Behavior unchanged (Phase-1 oracle proves it). **Record->object is NOT
  here.**
- **Phase 4 — Interior to `string`, per-module, LEAF-FIRST, type-flip terminal.** Convert one module at
  a time, innermost/leaf modules first; the type flip is the *last* move on each already-tested module,
  so a regression is always localized to the module just touched. `ContestExchange` becomes an object
  incrementally here, DTO-mapped at the frozen boundary. TRDOS core refactored behind the oracle as
  needed. This is the bulk.
- **Phase 5 — SQLite.** Swap binary record for DB insert/select once the persistence boundary is clean;
  ship a `.dat`->SQLite importer for historical logs.

## 6. Risk register (updated)

| Risk | Sev | Mitigation |
|---|---|---|
| Contest-logic regression | Highest | Phase-1 golden-master oracle from real `.dat` corpora; per-module leaf-first flip localizes any regression |
| **CP1251 source literals silently mangled at compile time** | **High** | Explicit compile-time codepage strategy (Phase 2a) + lang-file exception; verify non-English UI renders correctly early |
| `ContestExchange` interior/wire/disk coupling | High | Frozen DTO; record->object done per-module in Phase 4, not as a pre-seam |
| DTO is a lossy Unicode target (legacy peers/logs) | Med | Documented lossy down-map rule (Phase 2b); most fields ASCII |
| `UnicodeString` in a `packed record` (corruption) | High | Allowlist + lint + DTO discipline forbid it |
| Win32 A->W data-path (284 sites; callsign->network) | Med | Tracked surface; data-path check on each text read that feeds wire/disk |
| Fixed-width log-grid (LOGWIND) column math vs code units | Low-Med | ASCII fine; add measure for CJK/Cyrillic widths in the log window |
| SQLite wrapper double-encoding | Med | Verify at Phase 2c with round-trip test |
| CW/keyer/DVK timing regression | Low-Med | Verify char->element path untouched by the flip; no test coverage |
| Scope/time | Med | Larger than all work to date; per-module + oracle keeps each step shippable/reversible |

## 7. The 3 things to fix before starting

1. **Re-phase:** stop treating record->object as a pre-interior seam — merge it into per-module Phase 4.
2. **CP1251 compile-time codepage plan** for `src/lang/*.pas` (edit-forbidden, no BOM) — or non-English
   UI corrupts under UTF-16.
3. **Build the golden-master oracle** from real `.dat` corpora through the existing ADIF/Cabrillo/score
   outputs — before touching TRDOS.

## 8. Definition of done

Zero unjustified non-`string` in the logic layer (lint-enforced; boundaries tagged). Contest-critical
behavior byte-identical to the oracle. SQLite persistence + historical `.dat` importer. Win32 via
W-APIs. Non-English UI verified intact.

## Appendix A — CQRLOG reference

Copy the **policy** (ADIF `_INTL`; UTF-8 no-BOM; force DB charset; per-field international allowlist).
Do NOT copy the **mechanism** (FPC UTF-8 `AnsiString`, byte-based `Length`/`UTF8Copy`, no boundary
conversions) — it inverts under Delphi UTF-16. CQRLOG uses embedded MySQL (`utf8` 3-byte); our SQLite
allows full UTF-8.
