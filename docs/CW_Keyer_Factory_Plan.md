# CW Keyer Factory/Strategy Refactor — Implementation Plan

Repo: `c:\tr4w-d12`, branch `delphi12`, Delphi 12, raw Win32 (no VCL). Build: `call rsvars.bat` (Studio 23.0) → `msbuild tr4w.lproj /t:Build /p:Config=Debug /p:Platform=Win32`. Follow the user's Pascal style: 3-space indent, `begin` on its own line indented from the control statement, code at the same level as `begin`/`end`, no single-line ifs. Pascal identifiers are case-insensitive — every verification grep must use `-i`.

> **Status (2026-07-31): PHASES A AND B ARE COMPLETE.**
> A1 `7ceb884` (base + four adapters + T1-T3,T8) · A2 `b939c7f` (LogCW facade
> rewire + conflict warning + T4-T7) · B1 `aad5265` (six busy predicates) ·
> B2-B5 `a540e61` (autosend, direct CPUKeyer calls, tune, Escape CAT stop) ·
> Q9 `369630a` (CW-by-CAT eligibility asks the registry everywhere).
> Every commit gated on a full `/t:Build` of both projects with no W1020, the
> unit suite (now 1335), and the golden corpus at 22/0/4.
> **No consumer outside the factory branches on keyer type any more.**
>
> **CAT REPOINT — step 1 done (`898c53d`), the rest is bench-gated.**
> The per-model length/padding rules are extracted into `uCWFraming`
> (`CWFrameRuleFor` + pure chunking helpers) and unit-tested offline —
> `uTestCWFraming`, 29 checks pinning the Kenwood 24/pad split and the TS-890
> exception, the Elecraft 22 with K2-no-pad vs K3/KX3/K4-pad, Flex differing by
> transport, chunk boundaries, and the Issue 153 unpadded-element-count rule.
> LOGRADIO now *calls* that unit instead of carrying its own copy, so the legacy
> path and the factory drivers cannot drift while the migration is half-done.
> **What remains for the repoint:** move the chunking LOOP and the send itself
> (busy timer, active/inactive interlock, inline `ControlF`/`ControlS` speed
> handling) into the factory drivers, then point `TCWKeyerCAT` at
> `tFactoryObject`. That is live CW timing code — bench with a K3/K4.
>
> **NOT in scope, decided 2026-07-31:** implementing Yaesu CW-by-CAT. Yaesu's
> `KY <n>;` plays a *preset memory slot*, not free text, so HamLib's
> `newcat_send_morse` has to program a memory before each send — impractical
> when the text changes every call. TR4W correctly reports no CW-by-CAT for
> Yaesu; see Section A2 of `docs/HAMLIB_CAPS_CROSSCHECK.md`.
>
> **OPEN DESIGN QUESTION (NY4I, 2026-07-31): explicit CW-interface selection.**
> `ActiveCWKeyer`'s precedence chain (CAT → WinKeyer → YCCC → CPU) is an
> ARTIFACT — it reproduces the order the original `if/else` arms happened to be
> written in, not a decision anyone made. An explicit "CW INTERFACE" setting
> would make `ActiveCWKeyer` a lookup, delete `WarnIfKeyerConfigsConflict`
> outright (no conflict is possible when you pick one), and deliberately end
> the one real fallback in today's behaviour — test T2's case, where an enabled
> WinKeyer that fails to open silently drops to keying DTR/RTS. That silent
> downgrade becomes a reported error instead. The per-keyer capability set
> (`ckTune`, `ckDeleteLastChar`, `ckMessageChaining`) already supports greying
> what the chosen interface cannot do, exactly as the radio dialog does.
> TR4QT's keyer design is the likely reference. Note this is a config-surface
> change (new command + dialog), so it is a designed change, not a refactor.
>
> **THE CAT REPOINT IS DONE (2026-08-03).** The paragraph below is kept because
> its diagnosis was right and explains the shape of the result; only its status
> has changed. It ran in three steps, not one:
>
> 1. `edc9cbf2` moved the send itself out of `RadioObject.SendCW` into
>    `uCWKeyerCAT.CWByCATSend`, and DELETED `RadioObject.SendCW`. The framing
>    came along as `uCWFraming`, still keyed on `InterfacedRadioType` —
>    a deliberate staging step, not the destination.
> 2. `a9e77155` repointed the capability GATES at the radio object
>    (`RadioObject.HasCapability`). The model-keyed form could not see a
>    string-id radio, so TCI silently got no CW at all.
> 3. `4a7f9833` moved the DATA to where this plan said it belonged: the frame
>    rule and prosign dialect are now `TRadioCapabilities.CWFrame` /
>    `.CWProsignDialect`, declared by each family base. `uCWFraming` keeps only
>    the mechanism and no longer knows what a radio model is.
>
> Two defects surfaced on the way, neither visible to the compiler: the TS-850
> was never in the model table despite declaring `rcCWByCAT` (unchunked in D12,
> undefined in D7 — an uninitialised `maxLen`), and the Icom values were first
> written into `DefineCapabilities`, which every Icom subclass replaces
> wholesale, leaving all fourteen keying Icoms with "no limit". Both were caught
> by the exhaustive pin test in `test/unit/uTestCWFraming.pas`, which now fails
> if any radio declares `rcCWByCAT` without stating its frame rule.
>
> **The original diagnosis, 2026-07-31:**
> This plan assumed `TCWKeyerCAT` could later be repointed from
> `RadioObject.SendCW` to the factory radio object. Inspection on 2026-07-31
> shows the two are NOT equivalent: `RadioObject.SendCW` carries per-model
> length limits and padding (24 bytes Kenwood/TS-890/Flex-serial, 22 for
> K3/KX3/K4), CHUNKING of the message into those sizes, the bench-derived
> K3/K4 padding quirk (a short `KY` goes silent when it follows the
> keyer-abort — NY4I 2026-06-18), inline `ControlF`/`ControlS` speed changes,
> and the `tmrCWByCAT` busy timer that `CWByCAT_Sending` depends on. The
> factory drivers' `BufferCW`/`SendCW` implement none of it — the K4 driver is
> `SendToRadio('KY ' + buffer + ';')`. Repointing today would regress CW-by-CAT
> on exactly the radios in use, intermittently, in a way that looks like a
> radio fault. **That framing is radio-protocol knowledge and belongs in the
> drivers: move it there first (naturally part of the legacy radio removal),
> then repoint.**
>
> **BENCH STILL OWED** for what is committed — plan items 1-5: CPU keyer,
> WinKeyer (including the enabled-but-unplugged fallback), CW-by-CAT (chaining,
> Escape in both swap states), YCCC, and the B1 SO2R paths (SwitchNext CQ
> advance, CheckInactiveRigCallingCQ, bandmap same-band spot tune).
>
> Plan reviewed and still current, with two
> post-plan updates from the 2026-07-30 session:
> 1. **Line-number drift:** `LOGRADIO.PAS`, `LOGSUBS1/2.PAS`, and `uCAT.pas` were
>    edited after this plan's references were taken (taxonomy-set retirement,
>    serial-format work, parity conversion helpers). Anchors like
>    `LOGRADIO.PAS:2379/2398-2404` have shifted — re-grep (`-i`) every cited line
>    before editing; the surrounding code is unchanged, only positions moved.
> 2. **The LOGSUBS1 flush guard now actually works:** the deferred item
>    "`rcCWFlushDisruptsTiming` flush guard → future dynamic capability" assumed
>    the flag was set; it was being wiped by a constructor-ordering bug until
>    fixed on 2026-07-30 (`3376a47`) and is now test-pinned. The deferred design
>    stands; only the baseline behavior changed (Icoms once again skip the
>    mid-message flush during CW-by-CAT).
> Also note the radio factory now lives in `tr4w/src/radioFactory/` — the plan's
> `uFactoryRadioBase.pas`/`uRadioRegistry.pas` references resolve there.

## Context

TR4W has four mutually-exclusive ways to key CW: CW-by-CAT (radio `SendCW` over the CAT link), a WinKeyer device (`uWinKey.pas`), the YCCC SO2R+ box (`uYCCCSO2R.pas`), and the CPU keyer toggling DTR/RTS/LPT (`K1EAKeyer` object in `LOGK1EA.PAS`, driven from `LogCW.pas`). `LogCW.pas` is already the de-facto facade (~200 call sites go through it), but internally each facade procedure re-implements the same 4-way `if/else` dispatch, and the copies have drifted: `FlushCWBuffer` never flushes the WinKeyer, `SetSpeed`'s YCCC arm is commented out, `DeleteLastCharacter` returns garbage on the WinKeyer path. There is no keyer-type enum — selection is three independent booleans (`wkActive`, `ycccActive`, per-radio `CWByCAT`) with precedence that differs between functions. ~12 consumer sites bypass the facade and branch on keyer type themselves.

This refactor introduces a `TCWKeyer` strategy class with four concrete keyers behind a single explicit selection function, collapsing the drifting dispatch chains into one. It mirrors the strangler pattern already proven on the radio factory (`uFactoryRadioBase.pas` / `uRadioRegistry.pas`).

**End-state trajectory (user-confirmed):** Phase A's thin adapters are scaffolding, not the destination. After the seam is proven on hardware, later effort moves the implementations *into* the keyer classes — `uCWKeyerCPU` absorbs the dit/dah engine and DTR/RTS toggling from LOGK1EA, `uCWKeyerWinKey` absorbs the WinKeyer protocol/thread from uWinKey, `uCWKeyerCAT` gets repointed when the legacy LOGRADIO CW path is removed. At that point LogCW shrinks to a compatibility facade. This plan delivers Phases A and B only.

**Decided constraints (do not relitigate):** scope = send path only (PTT and SO2R switching excluded this pass); thin adapters (behavior-identical, no internals rewrite); explicit + exclusive active keyer with precedence CAT → WinKeyer → YCCC → CPU; phased delivery with bypass-site migration in Phase B.

## Design decisions

### D1. Class with virtual methods and default bodies
`TCWKeyer = class(TObject)`. NOTE (corrects the design draft): `uFactoryRadioBase.pas` actually uses `Virtual; Abstract;` extensively (29 occurrences, e.g. :410-437) alongside plain virtuals — the house style is mixed. For `TCWKeyer` use **virtual with default bodies** anyway: several operations are legitimately optional per keyer (`ToggleTune`, `StopSending`, `SetSpeed` no-ops), and default bodies avoid the known trap where `/t:Make` hides W1020 missing-abstract warnings. Still run one full `/t:Build` at commit A1.

### D2. Selection is a per-call pure function, not a cached object
`function ActiveCWKeyer: TCWKeyer` in `uCWKeyerBase` re-evaluates per call: `IsCWByCATActive` → `wkActive` → `ycccActive` → CPU. This resolves the two hard correctness points with zero hook infrastructure:
- **WinKeyer async open:** `wkActive` only goes True inside the read thread after a successful echo test (`tr4w.lpr:969-974` starts `wkOpen` on a thread). Today a WinKeyer that never opens falls through to YCCC/CPU; a static selection on `wksWinKey2Enable` would break that. Testing `wkActive` live preserves it exactly.
- **Per-radio CW-by-CAT:** `IsCWByCATActive` (`MainUnit.pas:9247-9271`) follows `ActiveRadioPtr` (config AND `rcCWByCAT` capability), so radio swaps/model changes need no re-selection events. The CAT adapter resolves `KeyersSwapped ? InactiveRadioPtr : ActiveRadioPtr` per call, exactly as `LogCW.pas:236-243` does today.

Exclusivity: exactly one keyer handles any call (one documented exception, quirk Q4). `ActiveCWKeyer` logs `logger.Info('Active CW keyer is now %s', ...)` only on change (unit-level `LastLoggedKeyer`; benign race). Config-conflict warnings run once post-config-load (D5).

### D3. Route vs. broadcast — preserved from today
- **Routed** via `ActiveCWKeyer`: `SendString`, `SendChar` (Phase B), `StillBeingSent`, `DeleteLastChar`.
- **Broadcast** in today's exact order: `Flush`, `SetSpeed` (today these are unions across backends, not routed).
- **Pinned**: `ToggleTune` → `KeyerWinKey` (tune always talks to the WinKeyer today, even under CAT); Escape CAT stop → `KeyerCAT.StopSending`.

### D4. Tone stays on the interface; radio speed-sync stays in the facade
`SendString(const Msg: Str160; Tone: integer)` — only the CPU adapter consumes Tone (`CPUKeyer.AddStringToCWBuffer(Msg, Tone)`); others ignore it. The `if ActiveRadioPtr.CWSpeedSync then ActiveRadioPtr.SetRadioCWSpeed(Speed)` block (`LogCW.pas:604-607`) stays in facade `SetSpeed` — speed-sync is orthogonal to which keyer keys (fires even when WinKeyer keys).

### D5. Units: selection folded into the base; no closure registry
New units in `tr4w\src\` (NOT `src\trdos\`):
- `uCWKeyerBase.pas` — `TCWKeyer`, capability set, four singleton slots, `ActiveCWKeyer`, `WarnIfKeyerConfigsConflict`.
- `uCWKeyerCAT.pas`, `uCWKeyerWinKey.pas`, `uCWKeyerYCCC.pas`, `uCWKeyerCPU.pas`.

Deviation from `uRadioRegistry`'s closure registry, justified: the radio set is open (~90 models); the keyer set is closed (four) with fixed precedence — a priority registry would only add init-order hazard. Keep the essence: base + derived units, capability flags, self-installation from `initialization` sections (`KeyerCPU := TCWKeyerCPU.Create;` into named slots; `finalization` frees). Per the lesson at `tr4w_unit_tests.lpr:103-108`, list all five units **explicitly** in both `tr4w.lpr` and the test dpr.

### D6. Uses-clause rules (no new interface-level edges into legacy code)
- `uCWKeyerBase` interface uses `VC` only (`Str160` at `VC.pas:1483`). Implementation uses `SysUtils, MainUnit` (IsCWByCATActive, logger), `uWinKey`, `uYCCCSO2R`, `LogRadio`, `uRadioRegistry`.
- Adapters: interface uses `VC, uCWKeyerBase`; all legacy units (`LogK1EA, uWinKey, uYCCCSO2R, LogRadio, LogCW, MainUnit, TF, Windows`) in **implementation** uses only. Implementation-level cycles are legal.
- `LogCW.pas` implementation uses (at :183) gains `uCWKeyerBase` + the four adapters (guarantees initialization linkage).

## Interface sketch

```pascal
unit uCWKeyerBase;

{ CW Keyer factory -- send path only (this pass).
  PTT (MainUnit PTTOn/PTTOff) and SO2R output switching
  (SetUpToSendOn*Radio / wkSetKeyerOutput / SetRelayForActiveRadio /
  YCCCSetActiveRadio) are OUT of scope; when they migrate they become
  virtuals here (e.g. PTTOn/PTTOff, SetKeyerOutput(radio)). }

interface

uses
   VC;   // Str160

type
   TCWKeyerCapability = (
      ckTune,             // key-down tune (WinKeyer KEYIMMEDIATE only today)
      ckDeleteLastChar,   // can retract the last unsent buffered character
      ckMessageChaining   // messages buffered until a terminator closes them
      );
   TCWKeyerCapabilitySet = set of TCWKeyerCapability;

   TCWKeyer = class(TObject)
   protected
      FName: string;
      FCapabilities: TCWKeyerCapabilitySet;
   public
      procedure SendString(const Msg: Str160; Tone: integer); virtual;
      procedure SendChar(ch: Char); virtual;            // autosend, one char now
      function StillBeingSent: boolean; virtual;        // default False
      function DeleteLastChar: boolean; virtual;        // default False
      procedure Flush; virtual;                         // this keyer's arm of FlushCWBuffer
      procedure StopSending; virtual;                   // Escape stop; default no-op
      procedure SetSpeed(wpm: integer); virtual;
      procedure ToggleTune; virtual;                    // default no-op
      function Supports(cap: TCWKeyerCapability): boolean;
      property Name: string read FName;
      property Capabilities: TCWKeyerCapabilitySet read FCapabilities;
   end;

var
   KeyerCAT: TCWKeyer = nil;
   KeyerWinKey: TCWKeyer = nil;
   KeyerYCCC: TCWKeyer = nil;
   KeyerCPU: TCWKeyer = nil;

function ActiveCWKeyer: TCWKeyer;
procedure WarnIfKeyerConfigsConflict;   // call once after config load
```

`ActiveCWKeyer` body (precedence pins today's `AddStringToBuffer` order, LogCW.pas:232/289/297/303):

```pascal
   if IsCWByCATActive then
      begin
      Result := KeyerCAT;
      end
   else if wkActive then
      begin
      Result := KeyerWinKey;
      end
   else if ycccActive then
      begin
      Result := KeyerYCCC;
      end
   else
      begin
      Result := KeyerCPU;
      end;
   // + log-on-change via LastLoggedKeyer
```

`WarnIfKeyerConfigsConflict`: Warn if `WinKeySettings.wksWinKey2Enable and YCCCSo2rEnable`; Warn if any radio has effective CW-by-CAT (`RadioN.CWByCAT and uRadioRegistry.SupportsFor(RadioN.RadioModel, rcCWByCAT)`) together with WK/YCCC enabled.

## Adapter contents (thin delegation, verbatim semantics)

**`TCWKeyerCAT`** (`'CW-by-CAT'`, `[ckDeleteLastChar, ckMessageChaining]`)
- `SendString`: `if KeyersSwapped then InactiveRadioPtr.SendCW(Msg) else ActiveRadioPtr.SendCW(Msg)` (from LogCW.pas:236-243; Tone ignored). `ActiveRadioPtr/InActiveRadioPtr` are typed consts `@Radio1`/`@Radio2` at `LOGRADIO.PAS:413-414`.
- `SendChar` (from MainUnit.pas:4520-4529 — **ActiveRadioPtr, no swap resolution, no UpCase** — preserved): `ActiveRadioPtr.SendCW(ch); ActiveRadioPtr.SendCW(CWByCATBufferTerminator);` (`CWByCATBufferTerminator = Chr(242)`, MainUnit.pas:480).
- `StillBeingSent`: `Result := ActiveRadioPtr.CWByCAT_Sending;` (LogCW.pas:382)
- `DeleteLastChar`: `Result := ActiveRadioPtr.DeleteLastCWCharacter;` (LogCW.pas:402)
- `Flush`: verbatim LogCW.pas:421-434 — both radios, each gated by `CurrentStatus.Mode = CW` and `IsCWByCATActive(ptr)`, clears `CWByCATBuffer`, calls `StopSendingCW`, keeps DebugMsg lines.
- `StopSending`: verbatim MainUnit.pas:858-863 (active-if-CAT-active else inactive-if-CAT-active).
- `SetSpeed`: no-op (D4).
- Calls `RadioObject` methods only — do NOT bypass into `tFactoryObject`; the commented kludge at `LOGRADIO.PAS:2398-2404` stays until legacy radio removal; this adapter is the future single repoint.

**`TCWKeyerWinKey`** (`'WinKeyer'`, `[ckTune, ckDeleteLastChar]`)
- `SendString`: `wkAddCWMessageToInternalBuffer(Msg);` (uWinKey.pas:931)
- `SendChar`: `wkSendByte(Ord(UpCase(ch)));` (MainUnit.pas:4540)
- `StillBeingSent`: `Result := wkBUSY;`
- `DeleteLastChar`: `wkSendByte(wkCMD_BACKSPACE); Result := True;` — defines a previously-undefined return (today LogCW.pas:406 exits without setting Result; de facto EAX = wkSendByte's return = 1 when written, so True matches). Flag in commit message (Q3).
- `Flush`: `WKBusy := False;` ONLY — `wkClearBuffer` deliberately NOT called (preserves LogCW.pas:438-439 drift, Q1).
- `SetSpeed`: `wkSetSpeed(wpm);` unconditional (LogCW.pas:609 quirk Q5; handle-guarded internally).
- `ToggleTune` — reproduce the `scWK_SWAPTUNE` body from uProcessCommand.pas:672-676, NOT `uWinKey.wkSwapTune:1073` (which sends `not wkBUSY` — divergent, pre-existing):
  `if wkSendTwoBytes(wkCMD_KEYIMMEDIATE, Byte(not wkTune)) = 2 then` invert `wkTune` via `TF.InvertBoolean`.

**`TCWKeyerYCCC`** (`'YCCC SO2R+'`, `[ckDeleteLastChar]`)
- `SendString`: `YCCCAddCWMessageToBuffer(Msg);`
- `SendChar`: `KeyerCPU.SendChar(ch);` — preserved oddity Q4: today's autosend has no YCCC arm; chars go to the CPU keyer.
- `StillBeingSent`: `Result := YCCCCWBusy;`  `DeleteLastChar`: `Result := YCCCDeleteLastChar;`
- `Flush`: `if ycccActive then YCCCFlushCWBuffer;` (guard kept, LogCW.pas:440-441)
- `SetSpeed`: no-op — `YCCCSetSpeed` is commented out today (LogCW.pas:610, Q2).

**`TCWKeyerCPU`** (`'CPU keyer'`, `[ckDeleteLastChar]`)
- `SendString`: verbatim move of LogCW.pas:303-333 — PTTOn if `ActiveRadioPtr.tPTTStatus = PTT_OFF`; `CPUKeyer.AddStringToCWBuffer(Msg, Tone)`; if `CWThreadID = 0` then `wkBusy := False` (4.90.5 quirk Q8), spawn `tCreateThread(@CWThreadProc, CWThreadID)`, `SetThreadPriority(CWThreadHandle, THREAD_PRIORITY_TIME_CRITICAL)` (Issue #997 comment preserved), `{$IF OZCR2008}` timer block.
- `SendChar`: `CPUKeyer.AddCharacterToCWBuffer(ch);` (MainUnit.pas:4548 — no PTTOn, no thread spawn — preserved).
- `StillBeingSent`/`DeleteLastChar`/`Flush`/`SetSpeed`: delegate to `CPUKeyer` methods 1:1.
- No tune (`TuneWithDits` functionally dead — out of scope).

Adapters are **stateless** (no fields beyond Name/Capabilities); all mutable state stays in today's globals — no new locking anywhere.

## Phase A — factory behind the LogCW facade (zero consumer-visible change)

### Commit A1 — new units + selection tests (no facade change)
1. Create the five units.
2. Add to `tr4w\tr4w.lpr` uses: `uCWKeyerBase in 'src\uCWKeyerBase.pas'` + four adapters (explicit, style of `uYCCCSO2R` entry near dpr:199).
3. Add the same five to `tr4w\test\unit\tr4w_unit_tests.lpr` (`in '..\..\src\...'`) + `uTestCWKeyer in 'uTestCWKeyer.pas'` + `RegisterSuite(TCWKeyerTests.Create('CWKeyer'));` near dpr:222.
4. New `tr4w\test\unit\uTestCWKeyer.pas` with tests T1-T3, T8 (below).

Gate: full `/t:Build` both projects; `tr4w_unit_tests.exe` passes; corpus `bash tr4w/test/corpus/export-d12-corpus.sh` = 22/0/4 (guard `Get-Process -Name tr4w` first).

### Commit A2 — rewire LogCW internals (LogCW public interface unchanged; zero consumer edits)
All edits in `tr4w\src\trdos\LogCW.pas`; add the five units to implementation uses at :183.

1. **`AddStringToBuffer` :217** — keep logger.Debug, CW-capture block, gate expressions and the inline MMTTY branch (:259-281, `MMTTYMODE = True` at VC.pas:37) verbatim; replace arm bodies: CAT arm (:232-257) → `KeyerCAT.SendString(Msg, Tone); Exit;`; post-MMTTY block → `if CWEnable and CWEnabled then` { `{$IF OZCR2008}` net-message line; `ActiveCWKeyer.SendString(Msg, Tone);` }. (`ActiveCWKeyer` cannot return `KeyerCAT` here in practice — IsCWByCATActive just tested False; a mid-call flip harmlessly routes to the CAT adapter.)
2. **`CWStillBeingSent` :378** → `Result := ActiveCWKeyer.StillBeingSent;` (chain :380-394 is identical precedence).
3. **`DeleteLastCharacter` :398** → `Result := ActiveCWKeyer.DeleteLastChar;`
4. **`FlushCWBuffer` :417** — broadcast in today's exact order: `KeyerCAT.Flush; tAutoSendMode := False; KeyerCPU.Flush; KeyerWinKey.Flush; KeyerYCCC.Flush;`
5. **`SetSpeed` :594** — keep globals and order: set `DisplayedCodeSpeed`; if Speed > 0: `CodeSpeed := Speed; KeyerCPU.SetSpeed(Speed);` speed-sync block verbatim; `tSetPaddleElementLength; KeyerWinKey.SetSpeed(Speed); KeyerYCCC.SetSpeed(Speed);` (YCCC adapter no-op ⇒ :610 stays dead).
6. **`InitializeKeyer` :2001** — append `WarnIfKeyerConfigsConflict;` (runs post-config-load via `LogCfg.pas:402`).
7. **`SendStringAndStop` :538 — NOT rewired**: its terminator arm (:550-553) sends on `ActiveRadioPtr` without swap resolution, unlike AddStringToBuffer — leave verbatim (Q7).
8. Optional dead-code removal (grep -i first): `KeyerBeingUsed` var LogCW.pas:93 (never read/written; enum `KeyerType` at LOGWIND.PAS:220 stays), commented `NEWCW: TCW` :199, no-op `SetPTT` :614 (zero callers). If any doubt, defer.
9. Add facade tests T4-T7.

Gate: full build both, unit tests, corpus 22/0/4, bench checklist items 1-4 minimum (this is the commit that could regress keying).

### Preserved quirks (deliberate — do NOT "fix" in this pass)
- **Q1** WinKeyer flush gap: `Flush` sets `WKBusy := False` only; `wkClearBuffer` not called (LogCW.pas:438-439). Future one-liner.
- **Q2** `YCCCSetSpeed` never called (LogCW.pas:610). Future one-liner.
- **Q3** WinKeyer `DeleteLastChar` previously returned garbage; adapter returns True (de-facto value). Flagged.
- **Q4** YCCC autosend chars go to the CPU keyer (no YCCC arm in MainUnit.pas:4520-4549).
- **Q5** `wkSetSpeed` called even when WinKeyer inactive (handle-guarded).
- **Q6** CAT eligibility tests the ACTIVE radio, message keying targets the swap-resolved radio; autosend CAT chars always target the active radio.
- **Q7** `SendStringAndStop` terminator → `ActiveRadioPtr` (not swap-resolved) — untouched.
- **Q8** CPU `SendString` still clears `wkBusy` on thread spawn (4.90.5).
- **Q9** `RadioObject.SendCW` guard (LOGRADIO.PAS:2379) still uses legacy `RadioSupportsCWByCAT` set, inconsistent with registry-based `IsCWByCATActive` — untouched until legacy radio removal.
- **Q10** CAT busy is timer-guessed (`tmrCWByCAT`, LOGRADIO.PAS:2272), not read back — untouched.

## Phase B — migrate bypass call sites (ordered, independently committable)

Each commit: full build both projects, unit tests, corpus; bench items per group.

### Commit B1 — busy predicates → `CWStillBeingSent` (the only commit with intended semantic deltas)

| # | Site | Today | After | Delta |
|---|------|-------|-------|-------|
| 1 | `MainUnit.pas:906-908` (Escape) | `(CWThreadID<>0) or wkBUSY or pRadio.CWByCAT_Sending` (pRadio swap-resolved :890-897) | `CWStillBeingSent` inside the CW-mode arm | OR-of-all → exclusive; CAT arm now ActiveRadioPtr (matches Q6); YCCC added. If pRadio's only use was this predicate, delete :888-904 (grep -i pRadio in proc first) |
| 2 | `MainUnit.pas:4382` | `(WKBusy) or (CWThreadID <> 0)` | `CWStillBeingSent` | adds CAT+YCCC; exclusive vs OR. SwitchNext CQ advance |
| 3 | `MainUnit.pas:4554-4555` | `(CWThreadID<>0) or wkBUSY or ActiveRadioPtr.CWByCAT_Sending` | `CWStillBeingSent` | exclusive vs OR, +YCCC |
| 4 | `MainUnit.pas:4568` | same | `CWStillBeingSent` | same |
| 5 | `MainUnit.pas:7709-7710` | `(not WKBusy) and (not (CWThreadID<>0))` | `not CWStillBeingSent` | adds CAT/YCCC. CheckInactiveRigCallingCQ |
| 6 | `uBandmap.pas:550` | `not WKBusy` | `not CWStillBeingSent` | largest widening: CPU/CAT/YCCC busy now blocks SO2R same-band spot-tune. Verify uBandmap uses LogCW (add if missing) |

Exclusive-vs-OR deltas matter only in cross-keyer windows (e.g. `wkBUSY` latched while CAT selected); document in commit message, bench SO2R + Escape.

### Commit B2 — autosend → `ActiveCWKeyer.SendChar`
`MainUnit.pas:4518-4550`: replace the three-way branch with `if Key <> StartSendingNowKey then ActiveCWKeyer.SendChar(Key);` (proper begin/end style); keep `EditingCallsignSent := False;`. Add `uCWKeyerBase` to MainUnit uses. Outcome-identical per arm (adapters preserve CAT terminator, WK UpCase, CPU raw; YCCC via Q4). Add test T9. Bench autosend on all keyer types.

### Commit B3 — direct CPUKeyer calls
- `uSendKeyboard.pas:188`: `CPUKeyer.FlushCWBuffer;` → `KeyerCPU.Flush;` (identical; do NOT "upgrade" to facade `FlushCWBuffer` — that would add CAT stop + WKBusy reset + YCCC flush). Note: `uSendKeyboard.pas:134` is inside a comment block (127-136) — no change.
- `JCTRL2.PAS:687` (`CPUKeyer.SetSpeed(PaddleSpeed)`): **stays direct** + comment: paddle speed is CPU-keyer-only; facade `SetSpeed` would clobber `CodeSpeed`/`DisplayedCodeSpeed`. Future `SetPaddleSpeed` virtual when paddles join the factory.

### Commit B4 — tune
`uProcessCommand.pas:672-676` `scWK_SWAPTUNE` body → `KeyerWinKey.ToggleTune;` (pinned, NOT `ActiveCWKeyer` — today tune reaches the WinKeyer even when CAT is selected). `scWk_Reset` (:655) stays. Bench SWAPTUNE toggle.

### Commit B5 — Escape CAT stop
`MainUnit.pas:855-864`: keep the `if (ActiveMode = CW)` shell; inner if/else → `KeyerCAT.StopSending;` (adapter body is verbatim :858-863). Behavior identical. Bench Escape during CAT send, both swap states.

### Deferred (documented, NOT this pass)
- `LOGSUBS1.PAS:309-314` (`rcCWFlushDisruptsTiming` flush guard) → future dynamic capability on `KeyerCAT`.
- `LOGSUBS1.PAS:536-540` — checks inactive radio, stops active radio (pre-existing oddity) — leave alone.
- `LOGSUBS2.PAS:1716-1720` + LogSend terminator appends → future `ckMessageChaining`-gated facade helper (`EndCWMessage`).
- `LOGK1EA.PAS:1325` commented wkActive branch — dead, ignore.

## Test plan

New `tr4w\test\unit\uTestCWKeyer.pas`, suite `TCWKeyerTests` (framework `uTR4WTestFramework`, style of `uTestRadioSupportsCaps.pas`). **Flags only — no hardware opens.** Fixture facts: `ActiveRadioPtr = @Radio1` / `InActiveRadioPtr = @Radio2` typed consts work without app startup; `SupportsFor` works instance-free. Every test saves/restores in `try..finally`: `wkActive, ycccActive, WinKeySettings.wksWinKey2Enable, Radio1.CWByCAT, Radio1.RadioModel, Radio1.CWSpeedSync, CWEnable, CWEnabled, ActiveMode, KeyersSwapped, CodeSpeed, DisplayedCodeSpeed, tAutoSendMode` + the four keyer slots.

Spy: `TSpyKeyer = class(TCWKeyer)` appending to shared `SpyLog: string` (e.g. `'CPU.SendString(TEST,700);'`), settable `FBusyResult`; installed by swapping slot vars.

- **T1 SelectionPrecedence** — all off → CPU; `ycccActive` → YCCC; `+wkActive` → WinKey; `+Radio1.CWByCAT + K3 model` → CAT.
- **T2 WinKeyerAsyncFallback** — `wksWinKey2Enable=True, wkActive=False, ycccActive=True` → YCCC (pins failed-open fallback — the trickiest correctness point).
- **T3 CATNeedsCapabilityAndConfig** — CWByCAT=True + non-CWByCAT model (FT747) → not CAT; CWByCAT=False + K3 → not CAT.
- **T4 FacadeSendRouting** (A2) — spies in slots; CW mode + enables; `AddStringToBuffer('TEST',700)` → CPU spy; `wkActive` → WK spy; terminator with `CWEnabled=False` → CAT spy (terminator bypasses gates); plain msg with `CWEnabled=False` → nothing.
- **T5 FacadeBusyAndDeleteRouting** — hit exactly the selected spy.
- **T6 FlushOrderAndBroadcast** — SpyLog = `'CAT.Flush;CPU.Flush;WK.Flush;YCCC.Flush;'` and `tAutoSendMode=False`.
- **T7 SetSpeedBroadcast** — `SetSpeed(28)` → `CodeSpeed=28`, `DisplayedCodeSpeed=28`, SpyLog `'CPU.SetSpeed(28);WK.SetSpeed(28);YCCC.SetSpeed(28);'`, CAT untouched; `SetSpeed(0)` → only `DisplayedCodeSpeed`.
- **T8 CapabilityPins** — WK has ckTune; CAT has ckMessageChaining; CPU/YCCC lack ckTune; all four have ckDeleteLastChar.
- **T9 SendCharRouting** (B2) — per-arm dispatch incl. YCCC→CPU delegation (real KeyerYCCC + spy in CPU slot).

Golden corpus after every commit: `bash tr4w/test/corpus/export-d12-corpus.sh` — baseline 22 passed / 0 failed / 4 known-divergence.

## Bench-test checklist (user, physical hardware)

1. **CPU keyer (DTR/RTS or LPT):** F1 CQ; typed autosend; Escape mid-message; backspace during autosend; `^F`/`^S` in-message speed; PgUp/PgDn; keyboard-CW dialog send + close while sending.
2. **WinKeyer:** same list; speed pot (read-thread → SetSpeed); SWAPTUNE (after B4); **WK ENABLE=TRUE with device unplugged** → confirm fallback to YCCC/CPU exactly as before.
3. **CW-by-CAT (K3/K4 or Kenwood):** message send + chaining (Enter during send); Escape stops the radio (both swap states, after B5); flush during Icom send (LOGSUBS1 guard unchanged); model change + per-radio CW BY CAT with SO2R swap; CWSpeedSync push.
4. **YCCC SO2R+:** message send, Escape/flush, busy gating, autosend (chars via CPU keyer — Q4).
5. **SO2R paths (after B1):** SwitchNext CQ advance (MainUnit:4382), CheckInactiveRigCallingCQ (:7709), bandmap SO2R spot tune (uBandmap:550), Escape while inactive-radio CAT sending.
6. **Conflict warning:** WK + YCCC enabled together → single Warn in `tr4w.log` at startup.

## Out of scope / known issues (listed for the record)

- **PTT**: MainUnit PTTOn/PTTOff 4-way branch (MainUnit.pas:9014+). Future `PTTOn/PTTOff` virtuals.
- **SO2R switching**: `SetUpToSendOnActiveRadio/Inactive` (LogCW.pas:2015+), `wkSetKeyerOutput` (uWinKey.pas:976), `SetRelayForActiveRadio`, `YCCCSetActiveRadio`. Future `SetKeyerOutput(radio)` virtual.
- **WinKeyer internal bugs** (known, NOT fixed here): thread-ID collision (`tr4w.lpr:969-974` and `uWinKey.pas:323` both write `wkThreadID`); read thread calling UI/QSO-flow code and `LogCW.SetSpeed` (uWinKey.pas:768-796); dead `wkReadThreadProc1`.
- **Drift fixes deferred** (one-liners when user opts in): Q1 wkClearBuffer in WK Flush; Q2 YCCCSetSpeed; Q4 YCCC autosend via YCCC buffer.
- **MMTTY branch** stays inline (mode dispatch, not a keyer). **DVK/DVP** separate domain. **Paddle** separate. **Legacy LOGRADIO CW protocol case** (:2405-2752) + legacy set guard (:2379) + commented kludge (:2398-2404) stay until legacy radio removal — the CAT adapter is the single future repoint.
- `wkSwapTune` (uWinKey.pas:1073) divergence from scWK_SWAPTUNE — pre-existing, untouched.

## CW-by-CAT does not stream, and that shapes two features (2026-08-18)

**The mechanism.** `CWByCATSend` (`uCWKeyerCAT.pas`) does not transmit as it is
called. It appends to `radio.CWByCATBuffer` and sends **nothing** until
`CWByCATBufferTerminator` arrives, at which point the accumulated text is framed
into one or more `KY` commands. Every other keyer streams: a WinKeyer takes a
byte into its own hardware buffer and its read thread drains it continuously;
the CPU keyer buffers and plays.

So "send this text now" and "send these characters as they arrive" are the same
operation for every keyer except this one.

**Where it shows, both confirmed on NY4I's K4:**

| feature | on a WinKeyer | on CW-by-CAT |
|---|---|---|
| Send-from-keyboard (Ctrl+A) | keys as you type | **kept silent until the box closed** until `1344701e` |
| Autosend (`'` then typing the rest of a call) | smooth | **staccato** -- one `KY` per character |

`1344701e` fixed the first by sending a terminator after each character, which is
the pairing `MainUnit`'s autosend already used (`MainUnit.pas:4905`). That makes
CAT behave like the WinKeyer *in timing* -- and it is worth noting this is now
**better than D7**, which sent nothing at all from that box until Enter (NY4I
checked, 2026-08-18).

**The residue: `TEST` goes out as `KY T` `KY E` `KY S` `KY T`.** Four commands,
four keying starts, a gap between each. Audible, and it is the same staccato as
the autosend case because it is the same cause.

**DELIBERATELY NOT GATED.** The obvious "fix" -- refusing keyboard CW on a
CAT-keyed radio -- was considered and rejected (NY4I: *"let's not gate that just
yet"*). Chopped keying beats no keying, and gating would remove a feature that
does work.

**Directions if this is picked up later**, none of them tried:

- **Batch on a short timer.** Hold characters for ~100 ms and flush, so a normal
  typing burst becomes one `KY`. Trades a little latency for continuity, and the
  operator types faster than one character per keying period anyway.
- **Keep the radio's buffer fed.** Elecraft's `TB` command reports how many
  characters remain unsent; top the buffer up before it drains rather than
  waiting for empty. Radio-specific, and the `CWFrame` capability is already the
  place a radio states how its command must be cut up.
- **A streaming capability on the keyer base.** Let a keyer declare whether it
  streams, and have the callers that send character-at-a-time ask, rather than
  each site rediscovering this.

Until then: **the standing advice for SO2R is a WinKeyer** (NY4I), and this is a
second concrete reason for it rather than only the SO2R interlock.

## Risks and mitigations

- **Threading:** UI thread drives the facade; WinKeyer read thread calls `SetSpeed`; CWThreadProc+timeSetEvent do CPU timing. Adapters are stateless singletons created in unit initialization (before any thread starts) — no new shared mutable state, no locks. `LastLoggedKeyer` race is log-only.
- **Nil slot AV** if an adapter unit drops out of a dpr: explicit dpr listing (both EXEs) + LogCW implementation-uses; optionally assert non-nil in `ActiveCWKeyer` under debug.
- **Semantic deltas concentrated in B1** — one commit, own bench pass, trivially revertable.
- **W1020**: default bodies avoid abstracts; full `/t:Build` on A1 regardless.
- **Case-insensitive identifiers**: grep -i always.

## Commit sequence and gates

| # | Commit | Gates |
|---|--------|-------|
| A1 | uCWKeyerBase + 4 adapters + dpr/test-dpr listings + T1-T3,T8 | full /t:Build both; tests; corpus 22/0/4 |
| A2 | LogCW facade rewire + conflict warning + T4-T7 (+ optional dead-code removal) | build, tests, corpus; bench items 1-4 |
| B1 | 6 busy-predicate sites | build, tests, corpus; bench item 5 + Escape |
| B2 | autosend → SendChar + T9 | build, tests, corpus; bench autosend all keyers |
| B3 | uSendKeyboard:188 → KeyerCPU.Flush; JCTRL2 comment | build, tests, corpus; keyboard-CW bench |
| B4 | tune → KeyerWinKey.ToggleTune | build, tests, corpus; SWAPTUNE bench |
| B5 | Escape CAT stop → KeyerCAT.StopSending | build, tests, corpus; Escape bench both swap states |

Git: every command as `git -C /c/tr4w-d12 <subcommand>`, never a leading `cd`.

## Critical files

- `c:\tr4w-d12\tr4w\src\trdos\LogCW.pas` — facade; every Phase A edit point
- `c:\tr4w-d12\tr4w\src\MainUnit.pas` — IsCWByCATActive, autosend, busy predicates, Escape; most Phase B edits
- `c:\tr4w-d12\tr4w\src\uFactoryRadioBase.pas` — house style reference (note: it DOES use Virtual;Abstract; TCWKeyer deliberately uses default bodies instead)
- `c:\tr4w-d12\tr4w\src\uWinKey.pas` — WinKeyer procedural API the adapter wraps; async wkActive
- `c:\tr4w-d12\tr4w\src\trdos\LOGK1EA.PAS` — CPUKeyer object the CPU adapter wraps
- `c:\tr4w-d12\tr4w\src\uYCCCSO2R.pas` — YCCC procs the adapter wraps
- `c:\tr4w-d12\tr4w\test\unit\tr4w_unit_tests.lpr` — unit listing + RegisterSuite pattern
