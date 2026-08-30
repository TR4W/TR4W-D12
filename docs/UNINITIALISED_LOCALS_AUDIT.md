# Uninitialised local variables — audit for triage

**Status: findings only. Nothing in this document has been changed.**
Raised by NY4I, 2026-08-30, after `ec5f4277` fixed two uninitialised booleans in
`uWSJTX` that had made WSJT-X highlighting work roughly one time in seven.

The ask was to sweep the codebase and sort what turns up into three buckets:
obvious/innocuous, needs testing/checking, and *danger, Will Robinson*. My
proposed bucketing is in [The triage](#the-triage); the evidence is below it so
you can disagree with the sorting rather than take it on trust.

---

## The rule this is all about

FPC initialises **managed** types and nothing else.

| initialised for you | NOT initialised — stack garbage |
|---|---|
| `string`, `AnsiString`, `UnicodeString` | `boolean`, `integer`, `Cardinal`, `Word`, `Byte` |
| interfaces, dynamic arrays, `variant` | `Char`, pointers, `HWND`, `THandle` |
| class fields (zeroed on construction) | enums, sets, `record`, static arrays, `Real` |
| global variables (zeroed at load) | **`ShortString` / `Str10` / `Str20` / `Str80`** |

That last row is worth pausing on. A `ShortString` is a fixed array with a
length byte, not a managed type, so it is **not** initialised — but it is spelt
like a string and sits in var blocks beside real strings.

**And that is exactly the trap that hid the WSJT-X bug for years.** Every other
local in that block was a `string`, genuinely safe, so the two booleans beside
them looked no different.

---

## Why the compiler is not enough

FPC does warn — `Local variable "X" does not seem to be initialized` — and finds
**23** sites in our code. **It did not find `foundCall` or `foundGrid`.**

Its dataflow is conservative in the direction that keeps it quiet: `foundCall`
*is* assigned, inside a loop, on some paths. Seeing a possible initialisation,
it says nothing.

**The cases it misses are the dangerous ones**, because an assignment existing
somewhere is also what makes the code look correct to a reader.

So this audit has two independent parts:

- **Part A** — what the compiler already knows (high confidence, zero effort).
- **Part B** — `tools/audit/uninit_locals.py`, which asks a blunter question the
  compiler does not: *is the first textual use of this unmanaged local a read?*

**Part B is validated against the known bug in both directions:** run against
`ec5f4277~1` it reports `foundCall` and `foundGrid` as DANGER; run against the
fixed tree it reports neither. A tool that cannot find the bug that motivated it
is not evidence of anything.

```
python tools/audit/uninit_locals.py tr4w/src
```

It deliberately over-reports (722 raw candidates) and then filters:

| bucket | count | meaning |
|---|---:|---|
| `LIKELY-OK (out param)` | 564 | `foo(x)` — the call *writes* x |
| `WRITE (false positive)` | 104 | `FillChar(x, …)` — also a write |
| `LIKELY-OK (continuation line)` | 5 | out param on a wrapped call |
| **`CHECK (expr)`** | **45** | read in an expression |
| **`CHECK (cond)`** | **4** | read as a bare operand in a condition |
| **`DANGER`** | **0** | boolean read bare in a condition |

**Zero DANGER in the current tree** — `foundCall`/`foundGrid` were the only ones
of that exact shape, and they are fixed. **49 need human eyes**, not 722.

---

## The theme worth knowing before you read the lists

Three of the highest-confidence findings are the *same defect*, and it is not
carelessness — it is a porting artifact:

```pascal
//{WLI}        Key := ReadKey;                        <- commented out
case Key of                                           <- reads garbage

//      FirstAddress := FindProperPartialCallAddress(PartialCall);
if FirstAddress > 0 then dec(FirstAddress);           <- reads garbage

{  Source := ord(message[1]);  Serial := ord(message[5]); … }
ProcessedMultiMessages[…].Source := Source;           <- stores garbage
```

**Someone commented out the initialisation and left the use behind.** The
variable stays declared, the code still compiles, and the read is now garbage.
Grep for a commented-out assignment next to a live read and you have a candidate
generator that needs no tooling at all.

---

## The triage

### 🔴 Danger, Will Robinson — live code, real consequence

**1. `LOGDUPE.PAS:987,1015` — `FirstAddress` / `LastAddress` (`integer`)**
in `DupeAndMultSheet.TwoLetterCrunchProcess`.

**This routine is LIVE** — called from `LOGEDIT.PAS:1839`, `LOGEDIT.PAS:1896`
and `LOGSUBS2.PAS:1941`, i.e. **while the operator is typing a callsign**.

Both bounds are uninitialised, and the loop that uses them is:

```pascal
for Address := FirstAddress to LastAddress do
   begin
   { …entire body commented out… }
   end;
```

So it is an **empty loop over garbage bounds**. If `FirstAddress > LastAddress`
it runs zero times; otherwise up to ~2×10⁹ iterations of nothing, on the
latency-critical typing path.

*Mitigating, and it needs checking rather than assuming:* the loop has no side
effects, so FPC may eliminate it entirely at `-O`. **Whether it does is the
single question that decides if this is a latent freeze or a no-op.** Check the
generated code, or time the routine with instrumented bounds.

### 🟡 Needs testing / checking

**2. `LOGSUBS1.PAS:1198` — `Key` (`Char`)** in `PacketMemoryRequest`.
`Key := ReadKey` is commented out and `case Key of` runs inside a `repeat`
loop. If no arm matches and nothing else exits, that is a hang. **I could not
find an external caller** — it looks dead, but it is a `function` and I did not
prove the negative. Confirm liveness first; if dead, it is bucket 3.

**3. `LOGSTUFF.PAS:5737-5739` — `Source`, `Serial`, `CheckSum`** in
`WeHaveProcessedThisMessage`. The scariest-looking of the lot — a network
message-dedupe table keyed on three garbage values, which would suppress new
messages or re-process old ones. **`GetMultiPortCommand`, its only caller, has
no callers itself.** Dead today. It is a landmine if anyone revives N6TR network
mode, and it should be deleted or fixed rather than left looking functional.

**4. The remaining 45 `CHECK (expr)` rows** in the table below. Most are
out-parameters on wrapped call lines that my continuation heuristic did not
catch; a minority are real. This is the bucket that wants an hour of reading,
not a decision now.

### 🟢 Obvious / innocuous

**5. The 673 filtered candidates.** Out-parameters and `FillChar` targets. Kept
in `build-out/uninit-locals.json` for audit, not reproduced here.

**6. `Function result variable ... of a managed type` (63 sites).** Managed
types are zero-initialised; these warn about a `Result` never assigned on some
path, which is a different (and much milder) question.

**7. `Some fields coming before "X" were not initialized` (418 sites).** Record
literal warnings — unrelated to this audit despite matching the word.

---

## Part A — what the compiler already reports (23, our code)

Anything here has FPC's own dataflow behind it. Two additional sites in vendored
Indy (`IdStackBSDBase.pas`) are excluded as not ours to fix.

| file | line | variable |
|---|---:|---|
| `CfgCmd.pas` | 177 | `CMD` |
| `LOGDUPE.PAS` | 987 | `FirstAddress` |
| `LOGDUPE.PAS` | 1015 | `LastAddress` |
| `LOGEDIT.PAS` | 1953 | `TempString` |
| `LOGSCP.PAS` | 468 | `BytesRead` |
| `LOGSTUFF.PAS` | 5737 | `Source` |
| `LOGSTUFF.PAS` | 5738 | `Serial` |
| `LOGSTUFF.PAS` | 5739 | `CheckSum` |
| `LOGSUBS1.PAS` | 1198 | `Key` |
| `LOGSUBS2.PAS` | 2803 | `nMultCount` |
| `LOGWIND.PAS` | 2108 | `Hour` |
| `LogCW.pas` | 678 | `Buffer` |
| `PostUnit.PAS` | 1137 | `PreviousQSOTime` |
| `PostUnit.PAS` | 1426 | `LastHourPrinted` |
| `PostUnit.PAS` | 3021 | `PreviousQTHString` |
| `tree.pas` | 3084 | `FirstWordCursor` |
| `tree.pas` | 3134 | `FirstWordCursor` |
| `tree.pas` | 4040 | `TempString` |
| `uADIFExchange.pas` | 258 | `contacts` |
| `uADIFExchange.pas` | 266 | `PreviousQTHString` |
| `uADIFExchange.pas` | 466 | `pnr` |
| `uDialogs.pas` | 657 | `HelpButton` |
| `uDialogs.pas` | 790 | `DisplayName` |

## Part B — first use is a read (49 for review)

Generated by `tools/audit/uninit_locals.py`. Sorted by file. `decl` is the
declaration line, `first read` the line the tool flagged.

| file | routine | variable | type | decl | first read | code |
|---|---|---|---|---:|---:|---|
| `ComPortEnumerator.pas` | `AddDeviceMapPorts` | `key` | `HKEY` | 348 | 361 | `'                             ', 0, KEY_READ, key) <> ER` |
| `MainUnit.pas` | `SeedLayoutFromLegacyPOSFile` | `pNumberOfBytesRead` | `Cardinal` | 2442 | 2454 | `pNumberOfBytesRead, nil);` |
| `MainUnit.pas` | `LoadinLog` | `pNumberOfBytesRead` | `Cardinal` | 6963 | 7002 | `pNumberOfBytesRead, nil);` |
| `MainUnit.pas` | `ReadLogFile` | `lpNumberOfBytesWritten` | `Cardinal` | 8126 | 8129 | `lpNumberOfBytesWritten, nil);` |
| `tr4wserverUnit.pas` | `WriteContestExchangesBufferToServe` | `lpNumberOfBytesWritten` | `Cardinal` | 612 | 623 | `WriteFile(ServerLogHandle, ContestExchangesBuffer[c], Si` |
| `trdos/LOGEDIT.PAS` | `TimeAndDateSet` | `TempString` | `Str80` | 1736 | 1752 | `if TempString = '' then` |
| `trdos/LOGK1EA.PAS` | `OutputBandInfo` | `BandInfoArray` | `array[BandType] of B` | 1604 | 1607 | `Image := BandInfoArray[Band];` |
| `trdos/LOGRADIO.PAS` | `RadioObject.WriteToCATPort` | `lpNumberOfBytesWritten` | `DWORD` | 954 | 1001 | `lpNumberOfBytesWritten, nil);` |
| `trdos/LOGRADIO.PAS` | `InitRadios` | `ra` | `array[1..2] of Radio` | 2343 | 2370 | `TempRadio := ra[i];` |
| `trdos/LOGSTUFF.PAS` | `WeHaveProcessedThisMessage` | `Source` | `Byte` | 5280 | 5291 | `ProcessedMultiMessages[ProcessedMultiMessagesStart].Sour` |
| `trdos/LOGSTUFF.PAS` | `WeHaveProcessedThisMessage` | `Serial` | `Byte` | 5280 | 5292 | `ProcessedMultiMessages[ProcessedMultiMessagesStart].Seri` |
| `trdos/LOGSTUFF.PAS` | `WeHaveProcessedThisMessage` | `CheckSum` | `Word` | 5282 | 5293 | `ProcessedMultiMessages[ProcessedMultiMessagesStart].Chec` |
| `trdos/LOGSUBS1.PAS` | `PacketMemoryRequest` | `Key` | `Char` | 1093 | 1128 | `case Key of` |
| `trdos/LOGSUBS2.PAS` | `SendScoreToUDP` | `GetScoresModesArray` | `array[ModeType] of P` | 2367 | 2413 | `if GetScoresModesArray[TempMode] <> '   ' then` |
| `trdos/LOGSUBS2.PAS` | `SendScoreToUDP` | `GetScoresMults` | `array[RemainingMulti` | 2364 | 2424 | `'        ' +  GetScoresMults[m] + '  ' + IntToStr(mo.MTo` |
| `trdos/LOGSUBS2.PAS` | `SendScoreToUDP` | `GetScoresMultsWRTC` | `array[RemainingMulti` | 2366 | 2435 | `'        ' + GetScoresMultsWRTC[m] + '  ' +` |
| `trdos/LOGWIND.PAS` | `RefreshMainWindowColors` | `e` | `TMainWindowElement` | 3755 | 3778 | `for e in ListViewElements do` |
| `trdos/PostUnit.PAS` | `ContinentReport` | `UnknownCalls` | `array [ BandType, 0 ` | 1575 | 1646 | `UnknownCalls[ TempRXData.Band, ContTotals[ TempRXData.Ba` |
| `trdos/PostUnit.PAS` | `ExportToEDIByBand` | `EDI_ModeCodes` | `array [ ModeType ] o` | 1888 | 1983 | `EDI_ModeCodes[ TempRXData.Mode ], TempRXData.RSTSent,` |
| `trdos/tree.pas` | `FoundDirectory` | `TempString` | `Str80` | 3573 | 3593 | `while TempString[length(TempString)] <> ' ' do` |
| `uADIFExchange.pas` | `FormatADIFMyExchange` | `PreviousQTHString` | `Str10` | 85 | 167 | `[ TempRXData.RSTSent, PreviousQTHString ] );` |
| `uDialogs.pas` | `SelectColor` | `custColors` | `array[0..15] of COLO` | 548 | 560 | `CC.lpCustColors := @custColors[0];` |
| `uDialogs.pas` | `SelectFolder` | `DisplayName` | `array[0..MAX_PATH] o` | 703 | 719 | `BrowseInfo.pszDisplayName := DisplayName;` |
| `uEditQSO.pas` | `LoadQSOIntoEditForm` | `lpNumberOfBytesRead` | `Cardinal` | 127 | 143 | `lpNumberOfBytesRead, nil);` |
| `uGetScores.pas` | `BuildDynamicResultsXml` | `RTCModeStr` | `array[ModeType] of s` | 279 | 445 | `[BandStr, RTCModeStr[TempMode], nQSOs]));` |
| `uGetScores.pas` | `BuildDynamicResultsXml` | `RTCMultStr` | `array[RemainingMulti` | 278 | 472 | `[BandStr, RTCModeStr[TempMode], RTCMultStr[m],` |
| `uLPTPortEnumerator.pas` | `PresentViaRegistry` | `key` | `HKEY` | 38 | 48 | `0, KEY_READ, key) <> ERROR_SUCCESS then` |
| `uNet.pas` | `ConnectToTR4WServer` | `wrongPassword` | `boolean` | 776 | 786 | `AnsiString(ServerPassword), err, wrongPassword);` |
| `uWebSocketClient.pas` | `TWSReaderThread.Execute` | `frame` | `TWSFrame` | 90 | 98 | `WS_DEFAULT_MAX_PAYLOAD, frame, errText);` |
| `ui/lcl/backup/uNewContestForm.pas` | `TfrmNewContest.PopulateFiles` | `found` | `TSearchRec` | 194 | 203 | `faAnyFile, found) = 0 then` |
| `ui/lcl/backup/uPanadapterForm.pas` | `PanadapterWasOpen` | `saved` | `TRect` | 1982 | 1999 | `saved, visible) then` |
| `ui/lcl/backup/uPanadapterForm.pas` | `PanadapterWasOpen` | `visible` | `boolean` | 1983 | 1999 | `saved, visible) then` |
| `ui/lcl/backup/uPrefsForm.pas` | `TPrefsForm.AddGeneratedRows` | `s` | `TSettingBase` | 2774 | 2780 | `for s in AllSettings do` |
| `ui/lcl/backup/uPrefsForm.pas` | `TPrefsForm.AddStationFieldsToSearc` | `f` | `TStationField` | 3091 | 3093 | `for f in StationFields do` |
| `ui/lcl/backup/uPrefsForm.pas` | `TPrefsForm.ControlForCommand` | `f` | `TStationField` | 3473 | 3478 | `for f in StationFields do` |
| `ui/lcl/backup/uPrefsForm.pas` | `TPrefsForm.LoadStationPanel` | `f` | `TStationField` | 5985 | 5988 | `for f in StationFields do` |
| `ui/lcl/backup/uPrefsForm.pas` | `TPrefsForm.SaveStationPanel` | `f` | `TStationField` | 6019 | 6077 | `for f in StationFields do` |
| `ui/lcl/uNewContestForm.pas` | `TfrmNewContest.PopulateFiles` | `found` | `TSearchRec` | 194 | 203 | `faAnyFile, found) = 0 then` |
| `ui/lcl/uPanadapterForm.pas` | `PanadapterWasOpen` | `saved` | `TRect` | 1982 | 1999 | `saved, visible) then` |
| `ui/lcl/uPanadapterForm.pas` | `PanadapterWasOpen` | `visible` | `boolean` | 1983 | 1999 | `saved, visible) then` |
| `ui/lcl/uPrefsForm.pas` | `TPrefsForm.AddGeneratedRows` | `s` | `TSettingBase` | 3023 | 3029 | `for s in AllSettings do` |
| `ui/lcl/uPrefsForm.pas` | `TPrefsForm.AddStationFieldsToSearc` | `f` | `TStationField` | 3340 | 3342 | `for f in StationFields do` |
| `ui/lcl/uPrefsForm.pas` | `TPrefsForm.ControlForCommand` | `f` | `TStationField` | 3722 | 3727 | `for f in StationFields do` |
| `ui/lcl/uPrefsForm.pas` | `TPrefsForm.LoadStationPanel` | `f` | `TStationField` | 6254 | 6257 | `for f in StationFields do` |
| `ui/lcl/uPrefsForm.pas` | `TPrefsForm.SaveStationPanel` | `f` | `TStationField` | 6288 | 6346 | `for f in StationFields do` |
| `ui/lcl/uSettingsBinding.pas` | `TSettingBindings.LoadAll` | `b` | `TSettingBinding` | 271 | 273 | `for b in FItems do` |
| `ui/lcl/uSettingsBinding.pas` | `TSettingBindings.SaveAll` | `b` | `TSettingBinding` | 281 | 291 | `for b in FItems do` |
| `utils/utils_file.pas` | `sWriteFileFromString` | `lpNumberOfBytesWritten` | `DWORD` | 66 | 74 | `lpNumberOfBytesWritten, nil);` |
| `utils/utils_text.pas` | `BinToHexStr` | `bytes` | `array[0..MaxInt - 1]` | 377 | 389 | `Result[(i * 2) + 1] := HexDigits[bytes[i] shr 4];` |

---

## What this audit does NOT cover

Stated so nobody reads a clean run as a clean codebase — the mistake that let
the stations-window race survive eight bench sessions.

- **Only `tr4w/src`.** Not `tr4wserver`, not the test harnesses.
- **Only locals.** Class fields are zeroed at construction and globals at load,
  so both are genuinely safe; **records passed by `var` are not** — a caller's
  uninitialised record is invisible here.
- **First *textual* use, not first *executed* use.** A read inside an early
  `if` that the code guarantees cannot run before an assignment is a false
  positive, and there is no dataflow here to tell the difference.
- **Multi-line calls.** Partly handled; the remainder is the main noise source
  left in `CHECK (expr)`.
- **`with` blocks and nested routines** are not resolved.

## Suggested order of work

1. Answer the one question in finding 1 — does FPC elide that empty loop? It is
   the only finding that is both live and potentially operator-visible.
2. Decide dead-or-fix on findings 2 and 3. Both are dead code carrying a live
   trap; deleting them is cheaper than fixing them.
3. Clear Part A. 23 sites with compiler backing is an afternoon.
4. Read the 45 `CHECK (expr)` rows and feed the false-positive shapes back into
   the tool, so the next run is quieter than this one.

A lint gate is deliberately **not** proposed yet. The right threshold is not
knowable until the list above has been read once by someone who knows what the
code is for.
