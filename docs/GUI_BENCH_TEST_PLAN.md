# Bench queue: checks the Windows UI tester can take over

Reviewed November 11, 2026. Source: the updated `C:\tr4w-d12\docs\BENCH_QUEUE.md`, copied into this worktree before editing. Source SHA256: `be55e8fc19acaa74da54fffe9c8dae5a9c80915fb07f5e6b8c78a183c184f19d`. Line references below refer to that snapshot; match the heading and item text if the queue changes.

The queue contains **894 unchecked items** and 122 checked/withdrawn items, including one indented checkbox. Its introduction's old count of 423 is stale. A mechanical index found 476 open items mentioning screen/form behavior and 274 mentioning local data entry, saving, importing or exporting. These counts overlap; neither is a count of ready or completed tests. Full item text, stable content IDs and requirement signals are in `build-out/bench-ui/queue-index.json`. Rebuild that index with `python tools/gui_test/bench_queue.py`.

A refresh before result annotations read SHA256 `1832e9fdf3c5be207816ce1c784ab798cc160e18ef4576a9b3da92305780504f`: **895 open items**, **477 screen/form signals**. It adds Preferences > Station information: License year versus CQ zone, searching MY ZONE and label fit. Add that to UI-01/UI-06. The table's original snapshot line references are retained to make the reviewed source unambiguous; heading/item text takes precedence in the refreshed file.

The queue's August statement that an agent cannot inspect geometry, colors or a visible caret is outdated for this setup. Python can drive the actual application; screenshots can be reviewed here. A window appearing, an accessible control name or a unit test still does not prove that the screen is correct.

## Test build and available equipment

Use **C:\tr4w-d12\build-out\app-i386-win32\tr4w_fpc.exe**, as NY4I requested. Copy its exact executable, matching `.dbg`, runtime DLLs and help before a batch. Check the debug-link CRC and bitness, record the executable SHA256, and archive the pair. Do not substitute a worktree build. The source revision at build time is unknown unless a build-time record supplies it; the current checkout revision is not that record.

The first selected snapshot is SHA256 `1ee7a69d9c09991ea4067a73832e906a5217283ec3ed3e2039a5f7f14d6b5927`. It is staged on `tr4w-gui-test` under `C:\TR4W-Test\bench-main-1ee7a69d9c09`. Python is x86. The interactive GUI-TEST desktop is 1280×800 at 100%/96 DPI. A newer main executable means a new snapshot and a new result record, not overwriting the evidence.

Main changed while preparing the first tests. The completed entry/score batch uses the newer SHA256 `98db42069823905e263b1313d68dbb0d43d0e388ed685d77557082998ae3acb1`, debug CRC `51ADCB58`, staged under `C:\TR4W-Test\bench-main-98db42069823`. See the result record for exact scope and screenshots.

Available hardware/services are **the Elecraft K4** at `192.168.73.108:9200` and **the DX cluster** at `dxc.nc7j.com:7373`, login `NY4I-2`. Other radios, keyers, rotators, external logger programs/accounts and multi-station setups are unavailable. Definition editors can often be tested without their devices. A definition-editor pass is not a working-device pass.

Use disposable settings and logs, with no radio or external delivery definitions for the screen/form batches. Enter contacts using Ctrl+Enter so no CW is sent. K4 tests are a separate batch; do not mix them with form-validation fixtures. Do not send scores, upload logs, request real external logger deliveries or repeatedly download call history to exercise a layout check.

## First batches: screen and form checks, no hardware

The following are selected actionable groups, not an assertion that every requirement in their source sections is covered. Each result must identify the exact source checkbox and any untested remainder.

| Batch | Queue snapshot lines | What the Python UI scenario should do and verify |
| --- | --- | --- |
| UI-01: New Contest labels | 6314–6326 | Select EUHFC and KVP: MY LICENSE YEAR, no MY ZONE, readable label; enter 64 and reopen the resulting log to verify its year. CWT: MY NAME / MY QTH OR MEMBER NO, enter name and 1234, verify the saved value. Compare NAQP, Locust and NCCC rows. Keep Linux/macOS checks separate. |
| UI-02: New Contest county forms | 6080–6087; 1563, 1599 | Florida in/out-of-state checkbox, required county and disabled OK, accepted/rejected state codes; Texas code/name list and scrolling; name survives toggling; 7QP choices; unchanged parties. Capture the actual list/notice, not only enabled controls. |
| UI-03: Taken log names | 6304–6308; 6366–6369 | Startup collision has Create new log / Open existing / Cancel; default Enter creates the numbered file; Escape/close preserves inputs and creates nothing. From an open same-name log, only Create new log and Cancel. Compare before/after files and original contacts. File > Open Log can relaunch: follow the owned replacement PID. |
| UI-04: CW Open labels and score | 6357–6360; 6375–6379 | Apply the later **COUNTS NO ZONES** section: QSOs/Calls only. Two different calls on one band yield 4; repeat one on another band yields 6. Remaining multipliers are calls, not a zone list. ADIF has no CQZ. Existing-log rescore is a separate fixture. |
| UI-05: Entry refusals | 6332–6335; 6276; 6280–6291; 37–39 | Enter the listed valid/invalid CWO, CQ WW RTTY, EUHFC/KVP and IOTA exchanges. Assert the exact visible notice, unchanged contact count and cleared/retained fields as specified. Then log a valid exchange and check the old error disappears. No need for a connected radio. |
| UI-06: Preferences leaves and search | 107–111; 266–297; 4322–4334 | Walk task leaves, confirm no More settings, inspect new sections and disabled contest-owned rows. Search the named commands and verify the focused control and destination leaf. External Software overview buttons work once, without duplicates. Save/Cancel round trips use copies of settings and logs. |
| UI-07: Tab and tooltip behavior | 937–946; 960–976 | Record actual focus sequence, visibility/enabled state and reading-order review on each page. Hover named bound/hand-wired controls; check wrapping, truncation, dismissal and no empty hint. Repeat Spanish/English fallback separately. The existing 47-page mechanical Tab audit is useful evidence, not a semantic pass for this build. |
| UI-08: Online scoring layout | 52–54; 6155–6156 | Three URL/Test rows, certificate checkboxes, wrapped notices, fresh/old defaults, Save arming, Cancel rollback, https/http enablement and warning visibility. Use no live credentials. A local test server can later test button routing; real certificate acceptance remains separate. |
| UI-09: External logger editor, offline | 57; 68; 228, 236; 379–382 | Add inactive definitions, switch providers, verify required fields, ACLog port 1100, masking/eye positions, warning layout and retained host/port values. Do not Refresh real logbooks or enable delivery. Split provider-field checks from the source items' end-to-end delivery requirements. |
| UI-10: External logger grid | 361; 6105–6116 | Empty-library placeholder, readable columns, centered Enabled box, drag boundaries, fixed Order column, fill to right edge and resizing. Inactive dummy definitions suffice for much of this. Idle/Sending/Retrying semantics need an actual service or a separately specified local stub. |
| UI-11: Edit QSO | 254–260; 5364–5376 | Inspect all fields/drop-downs/labels/flags/buttons and position; edit a known fixture record, Cancel versus Save, check a long log and a search result. Reopen and compare values. Windows 100% does not close macOS or 150% items. |
| UI-12: Messages | 509–515; 596; 4373; 5759 | Edit Standard/Control/Alt banks, CQ and exchange banks, command-list insertion, ampersand captions, saved content after restart, correct selected row. Inspect S&P F1/F2 special behavior without transmitting. Reuse message_workflow rather than duplicate the editor routine. |
| UI-13: Grids and search | 317, 321–323; 476–492; 4553–4636 | Search filters follow logged bands/modes, no literal placeholder text, SCP/dupe/multiplier cell fit, correct titles after reopen, erase/highlight behavior and column-width persistence. Use a mixed-band/mode local log. Server-log live contents remain unavailable. |
| UI-14: Main/tool-window behavior | 997–1011; 4844–4854; 5805–5837; 6051–6054 | Escape stays in the dialog, Tab does not reach the main log, shortcuts from modeless tools, focus return, modal stays above main, restore/minimize behavior. Startup flash/flicker requires timed capture/focus evidence, not one final PNG. |
| UI-15: File > Open Log | 6060–6074 | Title and hidden Last Contest button, Cancel, already-open log notice, invalid-file refusal, switching to another saved/new log, restored contacts/serial/settings/language. Reconnect checks are separate, and no simultaneous GUI jobs. |
| UI-16: Locked log / read-only | 5906–5923 | Hold an exclusive SQLite lock on a disposable log from another Python process, then drive Retry, unlock/Retry, read-only and Quit. Assert file preservation, refused logging and allowed export. Do not lock an operator log. WRL watchdog behavior is not covered. |
| UI-17: Import and local export | 2171–2183; 2574–2588; 2652–2657; 6272–6273 | Controlled ADIF fixtures, Yes/No MY_ prompt, bad import rollback, subsequent hand entry, alias section display/count, re-export resolved tags and state. Inspect files plus UI, without submitting them. |
| UI-18: Contest displays and reports | 171–173; 1710; 1917–1944; 2892–2957; 6165–6167 | Florida/ARRL10 band headings and needs strips; generated exchange values; X-QSO rows; local summary, hour-by-hour, Cabrillo and ADIF filenames/content. Sponsor acceptance, HamScore and 3830 website checks remain open. |
| UI-19: Radio/keyer/rotator definition forms | 211–214; 303, 305–306; 3650–3655; 6339 | Inactive library definitions, numeric validation, saved row selections, rename/profile references, per-radio poll-rate range and disabled controls. No port must be opened to inspect a form. Serial polling timing, sidetone and actual device behavior are not covered. |
| UI-20: Backup and migrations | 1862–1891; 4163–4190; 4278–4294; 5218–5229 | Local-only temporary backups, status/path, settings conversion, Cancel/default No, permission/error cases and reopen persistence. Remote shares and their timeout/exit behavior need separate resources. |

Most of UI-01 through UI-20 can be driven by Python. The first wave should prioritize UI-01, UI-03, UI-04, UI-05 and UI-06: they address recent changes, exercise operator entry and improve the guide's evidence directly.

## K4 and DX-cluster batches

| Batch | Queue areas | Available portion |
| --- | --- | --- |
| K4-01 | 1685; 1778–1796; 1841–1851; 6007–6022 | Read K4 status/link-up reports and render frequency/mode/panadapter. Front-panel actions need coordination and timestamped evidence. Serial-only poll claims are not proved by LAN. Power-cycle/cable-loss cases are not part of the passive batch. |
| K4-02 | 819–917; 4863–4884 | Compare actual spectrum/axis/waterfall and displayed state with the K4; inspect local palette/scale controls and panel position/Escape. Do not count a static screenshot as proof of averaging, jitter or history continuity. VFO/ split/PTT/keying changes are distinct operator-coordinated tests. |
| K4-03 | 6340–6343 | Test profile Connect at startup ON/OFF on an isolated K4 profile, observe thread/connect logs and status, then test explicit activation/reset. An empty library only covers the disabled-checkbox layout. |
| DX-01 | 450–466; 2289–2303; 3663; 4508 | Real cluster login, incoming line rendering, clipboard/edit keys in its command box, close/Escape, scrollback and clean exit. Do not broadcast synthetic spots to the public cluster to build fixtures. |
| DX-02 | 195–203; 5999; 6171–6175 | Live spots and local display filters: Hide digital spots, All Bands/Modes, resize/item geometry applying on Save and persistence. Worked-count/section/year colors need a controlled local spot fixture and known QSOs, not arbitrary public traffic. |

No unavailable hardware is replaced by a claim that an editor looked right. TS-890/990, Icom, Flex, serial K4, WinKeyer, CPU DTR/RTS keying, rotators, TNC, audio/beeps, a second radio and multi-op stay outside this equipment scope. Real WRL/Club Log/Cloudlog/Wavelog/ACLog/DXKeeper/DXLab/WSJT-X end-to-end items also remain outside it.

## Queue cleanup and contradictory instructions

- The CWO **MULTIPLIER ROW SAYS CALLS** section is superseded in part by **CW OPEN COUNTS NO ZONES**. Do not test the older demand for a Zones row as the current expected result.
- The older EUHFC New Contest item around line 2744 expects MY ZONE; the later license-year label replaces that expectation.
- The crossed-out Contest-page item around line 291 is superseded by the Contest-leaves section. It should not become a new test failure.
- External logger restart statements are superseded in part by **APPLY ENABLED AND ORDER ON SAVE, NO RESTART**. Field/credential changes and delivery binding behavior are separate.
- Several checked items explicitly cite only unit tests, and the checked View/Edit Log width item around line 314 says “Not retained after restart.” Preserve their existing status while flagging the conflicting evidence; do not count them as established UI passes.
- Rulings about Station Tab direction, wording, Field Day's submission portal, desired colors, county rules or sponsor acceptance are not closed by clicking the UI.
- Real 150% scaling, translated layouts and Linux/macOS remain distinct checks. Do not simulate a larger font and label it a DPI pass.

## Recording a result

Record source item heading/text/content ID, queue snapshot hash, exact executable SHA256 and debug CRC, VM/Python/display/language, fixture, steps, expected and observed values, screenshot paths and log/data evidence. Use **PASS**, **FAIL**, **PARTIAL** or **NOT RUN** with a reason. A completed Python task without semantic assertions or screenshot review is not a PASS.

A complete standalone checkbox may be checked with its evidence reference. For mixed items, add a Windows sub-result and leave the original open until its other requirements are satisfied. Do not delete operator confirmations or silently replace the living queue with an old copy. Changes made here can be merged by the queue's other agent.

Results of the initial executable snapshot are recorded in [GUI_BENCH_RESULTS.md](GUI_BENCH_RESULTS.md). Application defects get an issue with reproduction and evidence; framework/staging errors are recorded separately and corrected before judging TR4W.
