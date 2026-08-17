# TR4W Dialog Inventory — Code-Built vs Resource-Based

## How TR4W Creates Windows

TR4W uses two parallel systems to create its windows:

1. **Resource-based** (`MAKEINTRESOURCE(N)`) — dialog template stored in the `.RES` file,  
   loaded via `DialogBox()` or `CreateDialogParam()`.  
   These appear in the `.RES` files and can be decompiled directly.

2. **`MAINTR4WDLGTEMPLATE`** — a single hard-coded `TR4WDLGTEMPLATE` struct defined in  
   `VC.pas` at compile time. The main window and all persistent modeless tool windows  
   are created from this single in-memory template via `CreateDialogIndirectParam()`.  
   **These have no entry in any `.RES` file at all.**

3. **`tDialogBox(N, @Proc)`** — TR4W's wrapper around `DialogBox()`. Uses the same  
   resource ID scheme but routed through the `tr4w_WindowsArray[]` dispatch table.

---

## The `tw_` Window Index Enum  
*(defined in `VC.pas`, lines 1947–1968)*

These are the indices into `tr4w_WindowsArray[]`. The numeric value IS the resource ID  
used in `CreateDialogParam(hInstance, MAKEINTRESOURCE(tw_INDEX), ...)`.

| Index | Value | tw_ Constant                    | DlgProc                     | Source Unit         | In .RES? |
|-------|-------|---------------------------------|-----------------------------|---------------------|----------|
| 00    | 0     | tw_MAINWINDOW_INDEX             | (MAINTR4WDLGTEMPLATE)       | MainUnit.pas        | No — inline template |
| 01    | 1     | tw_BANDMAPWINDOW_INDEX          | BandmapDlgProc              | uBandmap.pas        | No — ID=1, ENG missing |
| 02    | 2     | tw_DUPESHEETWINDOW1_INDEX       | DupesheetDlgProc            | uDupesheet.pas      | No — not in any .RES |
| 03    | 3     | tw_FUNCTIONKEYSWINDOW_INDEX     | FunctionKeysWindowDlgProc   | uFunctionKeys.pas   | No — ID=3, ENG missing |
| 04    | 4     | tw_MASTERWINDOW_INDEX           | MasterDlgProc               | uMaster.pas         | No — ID=4, ENG missing |
| 05    | 5     | tw_REMMULTSWINDOW_INDEX         | RemainingMultsDlgProc       | uRemMults.pas       | No — ID=5, ENG missing |
| 06    | 6     | tw_RADIOINTERFACEWINDOW1_INDEX  | RadioInterfaceDlgProc       | uRadio12.pas        | No — not in any .RES |
| 07    | 7     | tw_RADIOINTERFACEWINDOW2_INDEX  | RadioInterfaceDlgProc       | uRadio12.pas        | No — not in any .RES |
| 08    | 8     | tw_TELNETWINDOW_INDEX           | TelnetWndDlgProc            | uTelnet.pas         | No — ID=8, ENG missing |
| 09    | 9     | tw_NETWINDOW_INDEX              | NetDlgProc                  | uNet.pas            | No — ID=9, ENG missing |
| 10    | 10    | tw_MMTTYWINDOW_INDEX            | MMTTYDlgProc                | uMMTTY.pas          | CHN only |
| 11    | 11    | tw_INTERCOMWINDOW_INDEX         | IntercomDlgProc             | uIntercom.pas       | No — ID=11, ENG missing |
| 12    | 12    | tw_POSTSCORESWINDOW_INDEX       | GetScoresDlgProc            | uGetScores.pas      | No — ID=12, ENG missing |
| 13    | 13    | tw_STATIONS_INDEX               | StationsDlgProc             | uStations.pas       | No — ID=13, ENG missing |
| 14    | 14    | tw_STATIONS_RM_DX               | RemainingMultsDlgProc       | uRemMults_DX.pas    | Not in .RES |
| 15    | 15    | tw_STATIONS_RM_DOM              | RemainingMultsDlgProc       | uRemMults_DOM.pas   | Not in .RES |
| 16    | 16    | tw_STATIONS_RM_ZONE             | RemainingMultsDlgProc       | uRemMults_Zone.pas  | Not in .RES |
| 17    | 17    | tw_MP3RECORDER                  | MP3RecDlgProc               | uMP3Recorder.pas    | No — ID=17, ENG missing |
| 18    | 18    | tw_STATIONS_RM_PREFIX           | RemainingMultsDlgProc       | uRemMults.pas       | Not in .RES |
| 19    | 19    | tw_DUPESHEETWINDOW2_INDEX       | DupesheetDlgProc            | uDupesheet.pas      | Not in .RES |
| 20    | 20    | tw_Dummy10                      | —                           | —                   | — |
| 21    | 21    | tw_Dummy11                      | —                           | —                   | — |

---

## Modal/Utility Dialogs (tDialogBox / DialogBox calls)

These are shown modally and reference `.RES` dialog IDs directly.  
English `.RES` is missing most of these — they exist only in non-English `.RES` files.

| Res ID | Function             | DlgProc                    | Source Unit          | In ENG .RES? | Notes |
|--------|----------------------|----------------------------|----------------------|--------------|-------|
| 40     | CT1BOH info          | ct1bohDlgProc              | uCT1BOH.pas          | No           | |
| 41     | CT1BOH info (alt)    | (commented out)            | LOGWIND.PAS          | No           | Commented out |
| 42     | About TR4W           | AboutDlgProc               | uAbout.pas           | No           | |
| 43     | List of messages     | MessagesListDlgProc        | uMessagesList.pas    | No           | |
| 44     | Band plan            | BMCFDlgProc                | uBMCF.pas            | No           | Commented out in uOption.pas |
| 46     | Edit QSO             | EditQSODlgProc             | uEditQSO.pas         | **Yes**      | Only one in ENG |
| 47     | Log Search           | LogSearchDlgProc           | uLogSearch.pas       | No           | |
| 48     | Sync PC Time         | SynchronizeTimeDlgProc     | uSynTime.pas         | No           | |
| 49     | Beacon Monitor       | BeaconsMonitorDlgProc      | uBeacons.pas         | No           | |
| 50     | Erma report          | ErmakDlgProc               | uErmak.pas           | No           | Cyrillic caption in non-RUS files |
| 54     | Dupe on inactive     | (inline)                   | MainUnit.pas         | No           | |
| 57     | Window control       | WindowsManagerDlgProc      | uWinManager.pas      | No           | |
| 58     | Station info         | (inline)                   | uCFG.pas             | No           | |
| 59     | Send spot            | SendSpotDlgProc            | uSendSpot.pas        | No           | |
| 60     | Send CW keyboard     | SendKeyboardCWDlgProc      | uSendKeyboard.pas    | No           | Commented out in MainUnit |
| 61     | Config commands      | SettingsDlgProc            | uOption.pas/uCFG.pas | No           | Commented out |
| 62     | Receiving QTCs       | QTCRDlgProc                | uQTCR.pas            | No           | |
| 63     | Send QTCs            | QTCSDlgProc                | uQTCS.pas            | No           | |
| 64     | LPT                  | LPTDlgProc                 | LPT.pas              | No           | |
| 66     | Radio/CAT setup      | CATDlgProc                 | uCAT.pas             | **Yes**      | |
| 68     | About (alt)          | AboutDlgProc               | MainUnit.pas         | No           | Different ID from 42 |
| 69     | Winkeyer settings    | WinKeyer2SettingsDlgProc   | uWinKey.pas          | No           | |
| 70     | Auto-CQ              | AutoCQDlgProc              | uAutoCQ.pas          | No           | |
| 71     | Memory functions     | FunctionKeysWindowDlgProc  | uFunctionKeys.pas    | No           | Commented out |
| 73     | Synchronize log      | GetServerLogDlgProc        | uLogCompare.pas      | **Yes**      | |
| 74     | View/Edit log        | MissingMultsReportProc     | MainUnit.pas         | No           | Note: ID reused (was 45) |
| 75     | Log diff             | LogCompareDlgProc          | uLogCompare.pas      | No           | Commented out — uses uNet? |
| 76     | Program message      | MESDlgProc                 | uMessages.pas        | No           | |
| 77     | Select file          | SelectFileDlgProc          | MainUnit.pas         | No           | Not in any .RES |

---

## Main Window — Inline Template (MAINTR4WDLGTEMPLATE)

The TR4W main window is NOT from any `.RES` file. It is built entirely from  
`MAINTR4WDLGTEMPLATE` — a `TR4WDLGTEMPLATE` record hardcoded in `VC.pas` (line 133).  
This is a raw `DLGTEMPLATE` binary struct with all controls defined as Pascal record fields.

**Key controls defined in the template:**
- Main callsign entry field
- Exchange/received field  
- Multiplier status area
- Band/mode display
- Score display
- Status bar

This is the most complex piece to refactor — it would need to become a proper  
Delphi `TForm` with manually placed controls matching the binary template layout.

---

## Summary by Track

### Track 1 — In `.RES` (extractable now)
3 dialogs in English `.RES`: **Edit QSO (46)**, **Radio/CAT Setup (66)**, **Sync Log (73)**  
38 dialogs in all other language `.RES` files — ready to decompile

### Track 2 — Code-built (require source analysis)
- **22 tw_ modeless windows** created via `CreateDialogParam` or `CreateDialogIndirectParam`  
  — templates are in the non-English `.RES` (IDs 1–19), except main window (inline template)
- **~25 modal dialogs** called via `tDialogBox()` / `DialogBox()`  
  — templates in non-English `.RES`, English is missing them
- **1 main window** (`MAINTR4WDLGTEMPLATE`) — fully inline, no `.RES` entry anywhere

### ~~Refactor Approach~~ — WRONG, corrected 2026-08-17

> The three steps that stood here said: the non-English `.RES` files have the templates for
> almost everything, only the main window and the `tw_RADIO*` windows lack a `.RES` entry, and
> the migration should extract Russian/Spanish templates and generate `.dfm` skeletons.
>
> **Do not do that.** All three premises were measured and are false.

1. **The templates are empty.** `TF.CreateModalDialog` (`TF.pas:1099`) zeroes a `DLGTEMPLATE`,
   sets only X/Y/cx/cy/Style and creates **zero controls**; every control is built in the
   `DlgProc`'s `WM_INITDIALOG` from the `TF.pas` factories. Same for the 21 child panels via
   `MAINTR4WDLGTEMPLATE`. So for ~44 of ~47 surfaces there is **no resource layout to extract** —
   the `.RES` cannot be a source for something it does not contain.
2. **The 38 dialogs that do carry layouts exist only in the nine non-English files** and describe
   a UI generation the English build has never instantiated. Reviving them would re-create
   dialogs no operator has seen. Layout also differs per language (`#ifdef RUSSIANVERSION` adds
   controls; dialog 66 is 910 B in `ger` vs 1268 B in `eng`), so there is no single "the" layout.
3. **`.dfm` is the wrong target anyway** — the toolchain is FPC + Lazarus since 2026-08-13, so
   designed forms are `.lfm` under `src/ui/lcl/`.

**The layout source is the hand-coded builder** — each `DlgProc`'s `WM_INITDIALOG`. The one place
the `.RES` earns a role is dialogs **46, 66 and 73**, where the English template *is* the shipping
layout: decompile those as a *measurement reference* for positions and tab order, not as a
generator. Full reasoning and the phased plan:
`~/.claude/plans/this-project-has-windows-binary-hammock.md`.

The inventory tables above are accurate and still worth reading.
