# GUI documentation exercise — November 11, 2026

## Live-radio follow-up: harness corrected, radio and cluster connected

NY4I supplied an Elecraft K4 at 192.168.73.108:9200 and DX cluster dxc.nc7j.com:7373, login NY4I-2, to improve connected-radio/main-window/band-map illustrations. TCP reachability from the VM succeeded for both. No tuning/keying was requested, and the radio was to remain in its current text mode.

A separate radio-live-001 fixture was started. While selecting Elecraft K4 and the Network tab in Add Radio, the application showed an access violation; its log confirms a main-thread EAccessViolation with top frames in comctl32.dll. The exact failing call is not isolated. This occurred before connection details were saved, before a radio profile was activated and before any cluster connection. That failed initial fixture produced no connected-radio or populated-band-map screenshot.

[Issue #283](https://github.com/TR4W/TR4W-D12/issues/283) contains the fatal stack and subsequent harness findings. Logs and exact scripts were copied by SCP to C:\tr4w-d12\build-out\gui-radio-crash-20261111. Inspection of the installed pywinauto implementation established that tab selection writes the caller's TCITEMW layout into the target: 40 bytes under Python x64 versus 28 under x86. The original test mixed x64 Python and the x86 application. The historical stack cannot prove the exact corrupting call, but this supplies a concrete harness defect. The operator's manual attempt worked; three matching-x86 model/Network selections passed without an application change. The issue is now closed.

The retry uses a separate x86 Python environment and certified application root C:\TR4W-Test\certified-7668. Before launch, the worker checks PE/Python bitness, matching debug-link CRC, clean-source provenance and an immutable executable/symbol archive. SHA256 of the retry executable is c3fdf16800cde51e1fe8da333bd4b076c765b8357032cbe05d6bdb332db91408; debug-link CRC is 4005CFA3. Source revision recorded before compilation is 7668d44aee32f57c5376e045cd8591a0ae8db3b8. Every radio action has a flushed before/after/error journal. Crash dump collection is configured but has not been exercised against a new crash.

The NY4I K4 documentation profile was activated, its confirmation acknowledged, and Preferences saved and closed. The live Radio 1 display reads VFO A 14020.00 CW and VFO B 14030.00 DATA; the main window reflects 20 CW and the Elecraft K4 name. No tuning or keying was requested. NC7J accepted login NY4I-2 and SH/50 returned recent spots. The already-open cluster console initially retained an empty host selection; reopening it and selecting the named NC7J entry allowed connection. This needs a separate reproducibility check before calling it an application defect. The first bandmap capture was empty. After additional connected time, the operator reported it populated; the radio-bandmap Python phase confirmed received 20-meter spots and captured the display without selecting a spot or tuning. The elapsed time alone does not establish precisely which cluster response populated it.

Retry artifacts and screenshots: build-out/radio-matching-bitness in the cwops-guide worktree. Connected radio, main-window, cluster-settings, cluster-console and populated-bandmap images are suitable evidence. The later bandmap image is copied to user-guide/assets/cwops/nc7j-bandmap.png and included in the CWOPS walkthrough; the earlier empty image remains diagnostic evidence.

## Deliverables

### Foreground screenshot framing

The operator confirmed that the open file is the worktree's TR4W-for-CWOPS.md. To eliminate reuse of the previous image paths by its preview, all 20 references now use foreground/ filenames containing the image's SHA256 prefix. Each file was verified against a fresh VM capture; the full hashes and capture sources are recorded in image-manifest.json. The canonical shared assets remain available to existing site pages. The old displayed 18:16 capture differs from the verified replacement's 01:06 capture; preview caching was a suspected cause, not independently proven.

Follow-up: all 20 image references in TR4W-for-CWOPS.md now point to refreshed foreground-frame captures. The guide-cwo and guide-cwt phases reopened their saved logs and verified all 27 expected message entries per event without rewriting them; these passes confirm persistence across the earlier normal exits. The radio/profile/network and NC7J settings dialogs were inspected and canceled. Setup dialogs were captured in a separate fixture. No additional practice contact was inserted. The current populated-bandmap illustration temporarily shows All Bands and All Modes; both check states were read back and restored to their originals after capture. No spot was used to tune the radio. Assets were checked by SHA256 against the fresh VM artifact files; the 20-entry manifest is build-out/guide-clean-captures/image-manifest.json.

The operator walkthrough's file explanation was simplified to one .db log file per session, closing before renaming, selecting the correct session log and keeping backups. SQLite, WAL and sidecar-file implementation details were removed from that narrative. Historical reproduction details below remain as test evidence.

The operator identified strips of the underlying window in screenshots. Inspection of installed pywinauto confirmed capture_as_image crops the desktop using the outer window rectangle, including invisible resize margins. The shared capture routine now focuses and verifies the intended HWND and uses the DWM visible-frame bounds instead. The capture-check scenario passed against both the CWOPS main window and message chooser at the VM's 96 DPI; both images were visually reviewed with title/menu preserved and the surrounding strips removed. Evidence is under build-out/window-capture-check/capture-check. Direct Pillow HWND capture omitted title/menu, and PrintWindow redrew title-bar styling; those trial paths were rejected. Existing historical screenshots have not all been regenerated.

### Programmed-message correction

The D7 Markdown and its original MarkText-linked images were inspected directly. The CQ image shows F1 `CQ CWO \ \ CWO` and F2 `CWO \`, not CWT or generic TEST. Its conclusion explicitly directs CWT users to select CWOPS and change CWO to CWT. The replacement screenshots now show programmed examples rather than untouched default messages.

`message_workflow.py` drives the actual chooser/list/editor and reads back all 27 changed entries per event across CQ, S&P and Other messages. CWO uses the D7 layout with TOM in place of MARV and the `# TOM` exchange. It preserves special S&P F1/F2 and F10, and uses the D7 QRL? fill consistently. A separate CWOPS practice fixture uses CQ CWT and the non-member exchange TOM FL, including repeat memories and F12 location fills. Both runs passed UI readback and closed through the normal exit confirmation. No function-key message was sent. These checks do not certify RF output or post-restart message persistence.

The CWT setup labels MY NAME and MY STATE and visibly explains the member-number alternative. The revised narrative states the supplied rule: first name plus CWops member number for members; first name plus state, province or DX country prefix for non-members. Practice/practise and acknowledgment spellings were standardized to US English in the updated walkthrough. The D7 original remains unchanged.

Evidence: build-out/message-review-cwo/radio-messages and build-out/message-review-cwt/cwt-messages. These contain verified-messages.json, before/after journals and screenshots. Initial harness failures (attempting to edit a disabled Caption field, the MY GRID startup prompt and exit confirmation) were inspected and handled according to their visible UI; they are not reported as application defects. The reusable message and normal-close helpers replace duplicate capture/close routines. The current VM has no test application left running after this exercise.

### Files

- [CW Open/CWT walkthrough](TR4W-for-CWOPS.md): new narrative, portable images and retained N5AW/NY4I attribution. The D7 original is unchanged.
- [Screenshot inventory](GUI_SCREENSHOT_INVENTORY.csv): all 55 local MkDocs pages, existing illustrations and proposed high-priority UI states. Generated by `tools/gui_test/screenshot_plan.py`.
- [Preferences capture index](GUI_PREFERENCES_AUDIT.md): 47 saved page screenshots and the observed focus-cycle summary.
- Python-only UI scenarios and SSH orchestration under [tools/gui_test](../tools/gui_test/README.md). PowerShell is used only as the Windows Scheduled Task bootstrap; application interaction and assertions/captures are Python.

## Method and isolation

The primary evidence is the running application: its visible windows, menu captions, keyboard behavior, screenshots and accessibility metadata. Source reading was initially used to locate controls and reconcile old documentation; after NY4I's clarification the scenarios were revised to inspect the actual program and consult source only for diagnosis. A need for implementation knowledge can itself indicate a missing UI explanation or accessibility gap.

VM alias: tr4w-gui-test; user GUI-TEST in interactive console session 1. One SSH connection/job at a time; ConnectTimeout=60. Desktop 1280 × 800, 96 DPI. Physical radios and real logger/submission accounts were not connected.

Tested executable: local 32-bit TR4W 5.0.37, November 10 at 23:49. SHA-256: `1b7643ed905d071b94f72e9cc9a8f16bdad07ba9b0fb9b6e1bbf535584129c80`. The staging checkout was fdaf208a, but an exact source/build correspondence was not independently certified. These are staged-build tests, not installer acceptance tests.

Python 3.15.2; pywinauto 0.6.9, Pillow 13.0.0, pytest 9.2.0, comtypes 1.5.0 and pywin32 312. GUI-TEST has its own virtual environment. The Microsoft-signed x64 C++ runtime was required for win32ui. An English help catalogue was staged and runtime logs confirmed it loaded.

## Observed results

| Exercise | Result | Boundary |
| --- | --- | --- |
| Initial Preferences pilot | Open practice database, Ctrl+J, expected controls and Escape close passed | No Save/persistence or every-page validation inferred |
| CW Open setup | Selected the actual CW Open row, entered call/name and opened its database | Example station data, not an event log |
| Message programming | Observed Settings > Program messages; Alt+P list, row selection and editor captured | Messages were inspected, not transmitted on hardware |
| Preferences navigation | 47 distinct page tags observed and captured; 45 panel reports and two placeholder reports | A panel report does not prove every control is correct |
| Keyboard cycles | All 47 forward cycles returned; reverse cycles matched; no observed hidden/disabled focus | Semantic grouping/order, populated libraries, conditional states and other languages remain open |
| One CW Open practice QSO | Screenshot shows K6RB / received 1 ROB, next serial 2, one point | A human reviewed the screenshot; the capture script alone is not a full scoring assertion |
| Same-day session creation | Reproduced existing-database overwrite prompt; selected No | No destructive overwrite exercised |
| Tooltip/accessibility | Many fields have empty UIA names/help; focused Grid square hover showed no tooltip despite loaded help | Empty UIA help alone was not classified as absent hover help; full setting-by-setting hover coverage remains incomplete |

The Web Server leaf is an actual placeholder telling the user to use an unspecified existing screen. The External Software parent also reports placeholder internally but presents working child navigation; it was not incorrectly filed as another empty-leaf defect.

## Issues filed and updated

| Issue | Finding |
| --- | --- |
| [#276](https://github.com/TR4W/TR4W-D12/issues/276) | CW Open same-day sessions collide with the default log name; existing-log prompt calls the database a folder |
| [#277](https://github.com/TR4W/TR4W-D12/issues/277) | CW Open multiplier labels say Prefixes/Zones instead of distinct callsigns; one-QSO score was correct |
| [#278](https://github.com/TR4W/TR4W-D12/issues/278) | Preferences inputs lack useful accessible names/help metadata |
| [#279](https://github.com/TR4W/TR4W-D12/issues/279) | Web Server leaf has a placeholder and no concrete route to settings |
| [#280](https://github.com/TR4W/TR4W-D12/issues/280) | Grid square hover tooltip absent with loaded English help |
| [#151](https://github.com/TR4W/TR4W-D12/issues/151#issuecomment-6789091493) | Added the mechanical focus-cycle results to the existing Tab-order audit; left open for semantic/state coverage |

These are reproduction-based findings. No application fix is included. Existing #245 covers missing staged help files and was not duplicated as another package issue.

## Harness/staging failures, not TR4W defects

- Country data initially went beside the executable rather than in the Windows working directory; a dialog correctly reported the missing file. Corrected staging resolved it.
- A stale guide route used Tools > Program message. The actual menu inventory showed Settings > Program messages, and the narrative/site page were corrected.
- An immediate capture caught dialog animation. The shared capture helper now waits for consecutive matching images and fails rather than accepting an unsettled window.
- The first focus helper assumed a pywin32 convenience API that was not provided. It now calls the documented Windows GUI-thread API through ctypes.
- Ctrl+A in the main entry window invokes keyboard CW. The typing script stopped using it as a universal select-all shortcut; no application bug was filed for the documented command.
- Page selection initially raced field population. The targeted scenario now waits for the observed fixture field instead of assuming visible means fully loaded.

## Where evidence lives

- Portable walkthrough figures: `user-guide/assets/cwops/`.
- Saved Preferences page captures: `docs/gui-test/preferences/`, indexed in GUI_PREFERENCES_AUDIT.md.
- VM artifacts: `C:\TR4W-Test\artifacts\<scenario>\`; readiness scripts in `C:\TR4W-Test\readiness\`.
- Retrieved full audit: `build-out/cwops-captures/preferences-audit/` in the cwops-guide worktree, including 47 page PNGs and forward/reverse focus records.
- The current result JSON and timestamps determine which run an image belongs to. A passing retry does not make an older failure image current evidence.

## Next coverage

Review logical Tab order against the screenshots, then test nonempty radio/keyer/logger libraries and conditionally enabled controls. Expand hover checks into a setting-by-setting list without equating inaccessible metadata with missing visible help. Verify Save/Cancel and normal-close persistence, and add modal radio/keyer editors. Hardware keying, sponsor export acceptance and complete on-air CQ/S&P operation require separate checks.

The screenshot inventory guides further documentation work; it does not claim every listed screenshot has already been taken. Publishing the guide remains an explicit separate operation.
