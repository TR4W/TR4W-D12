# Python documentation scenarios

## Bench-queue checks

See [GUI_BENCH_TEST_PLAN.md](../../docs/GUI_BENCH_TEST_PLAN.md) for actionable UI batches and equipment limits, and [GUI_BENCH_RESULTS.md](../../docs/GUI_BENCH_RESULTS.md) for the first evidence. Refresh BENCH_QUEUE from the non-worktree file before triage; do not replace another agent's later queue edits with a stale copy.

`bench_queue.py` parses all checkbox states and multiline requirements into an ignored artifact index. Signals overlap and are only search aids. `stage_main_build.py` snapshots the exact user-selected main executable and matching symbols/runtime files; it rejects mixed symbol/runtime snapshots and explicitly marks unknown source provenance. `bench_ui.py` uses the shared session, journal, foreground capture and no-CW entry helpers. It locates the two main inputs by their observed top-to-bottom order; it never assumes equal-left fields are ordered.

Run `python tools/gui_test/stage_main_build.py` before a new batch. Stage its app.zip under the returned VM root using SSH, then prepare a **fresh** run directory with disposable settings, CTY.DAT and dom, no radios/loggers and no existing contest database. `python tools/gui_test/vm_run.py bench-basic --root <that VM root> --run <fresh run> --output <new evidence folder>` captures the new-contest label matrix and logs the three CW Open score fixtures using Ctrl+Enter. It then reads menu states and closes normally. A retry needs a new disposable run directory; never resolve an unexpected filename collision by approving a replacement.

`bench-catalog` reads the visible list, including inactive entries, without creating a contest. This established that KVP is displayed as KV PRVENSTVO ZRS and Locust is inactive with no setup inputs. `bench-basic` records Locust as NOT RUN and continues; it does not silently pass that source item. A successful task is still pending semantic screenshot review until the results document supplies the verdicts. Fatal-log/timeout diagnostics use bench-workflow.json to find the owned process for dump collection; ordinary harness assertion failures preserve diagnostics and stop only their own application.

Run the nine portable guard/parser/staging tests with `python -m unittest discover -s tools/gui_test -p "test_*.py"`. They do not replace live checks, certify other operating systems or prove physical radio/keyer behavior.

## Guide scenarios

The application-facing work is Python. `vm_run.py` uploads the Python modules, creates a temporary limited-privilege Interactive Scheduled Task for GUI-TEST over SSH, polls its outcome, retrieves artifacts and removes the completed task. Its PowerShell bootstrap is only a Windows scheduling bridge, not a second UI driver.

The test user must already be logged in. Do not run a second GUI job or operate the same desktop during a scenario. The runner refuses an existing TR4W process or an existing named scenario task. It uses sequential SSH commands with ConnectTimeout=60. It does not install a service, enable automatic login or require the test account password.

From a workstation with Python and working SSH/SCP:

```text
python tools/gui_test/vm_run.py preferences --output build-out/cwops-captures
python tools/gui_test/vm_run.py preferences-audit --output build-out/cwops-captures
python tools/gui_test/vm_run.py station-hints --output build-out/cwops-captures
python tools/gui_test/vm_run.py new-contest --run cwops-001 --output build-out/cwops-captures
python tools/gui_test/vm_run.py cw-open --run cwops-001 --output build-out/cwops-captures
python tools/gui_test/vm_run.py cw-open-qso --run cwops-001 --output build-out/cwops-captures
python tools/gui_test/vm_run.py cw-open-collision --run cwops-001 --output build-out/cwops-captures
python tools/gui_test/vm_run.py cwt-messages --root C:\TR4W-Test\certified-7668 --run cwt-messages-001 --output build-out/message-review-cwt
```

The root defaults to C:\TR4W-Test. The fixtures must already be staged as described in README.md. `new-contest` and the first `cw-open` run use a run directory with no saved last-log shortcut; `cw-open` subsequently opens the existing single CWOPEN database. The QSO scenario **writes a practice contact**; use it only in disposable data. Its current known example is K6RB / 1 ROB. Repeating it can encounter a dupe; a screenshot-only outcome is explicitly marked for human review, not claimed as a comprehensive logging/scoring test.

Message captures now program the actual memories instead of photographing generic defaults. `message_workflow.py` is shared by the CW Open and CWT scenarios. It follows the D7 guide's CWO F1/F2 and fill-key layout, substitutes TOM for MARV, edits CQ/S&P/Other banks and reads back every changed Message column. It preserves the special S&P F1/F2 and F10 entries. Caption fields are cleared only when enabled; Other-message captions are disabled in the observed UI. No function-key message is transmitted.

`cwt-messages` requires a separate disposable run directory with CTY.DAT, dom and fresh settings; it creates CWops Test (CWT), or reopens the one existing CWOPS database. It uses W1AW/TOM/FL as demonstration values, programs CQ CWT and the non-member TOM FL exchange (no serial), captures all three banks and closes normally. The exact MY GRID startup prompt may be declined in this message-only fixture; any unexpected modal fails. Both message scenarios close through the application's exit confirmation to preserve changes. The matching-x86 certified build/symbol safeguards in README.md apply before launch.

The incremental `radio-messages` phase uses the same message routine against the previously owned CWOPEN PID. `radio-finish` closes that owned log normally. These attach phases are the explicit exception to the runner's existing-process guard; do not use them against an operator session.

To refresh the walkthrough's screenshots, use `guide-cwo` with the disposable radio-retry-001 fixture and `guide-cwt` with cwt-messages-001, both under the certified root. They reopen the saved logs, verify all 27 expected message values without rewriting them, capture the editor/banks using the foreground visible frame, and close normally. Reopening thus also checks that the programmed examples persisted. `new-contest` and `cwt-setup` capture their setup dialogs in the separate guide-setup-001 directory without creating contacts.

`guide_capture.py` centralizes the saved radio/profile/network and cluster illustrations. It reads the existing K4/NC7J definitions and cancels inspection dialogs; it neither activates a different profile nor tunes/keys the radio. Cluster capture connects the saved NY4I-2 host and requests recent spots. The bandmap illustration temporarily enables All Bands and All Modes to expose received traffic, then restores the observed check states in a finally block. `guide-bandmap` refreshes only this cluster/bandmap portion. All phases use one VM worker at a time.

`cw-open-collision` requires the existing same-date CWOPEN fixture, opens the current setup dialog, reproduces the collision and selects No. It does not exercise a destructive Yes path.

`preferences-audit` navigates by real keys in the visible left-hand region. It identifies selected pages using the running application's section diagnostics, not a source-derived list. It captures actual forward/reverse focus and Windows UI Automation HelpText. Stable page tags let captures be correlated, but this does not prove every designed page exists. A lack of page diagnostics fails the test rather than inventing names from geometry. Windows UI Automation's missing Name/HelpText is recorded as an accessibility observation; tooltip absence requires a hover check.

The initial Station hover case uses the fixture's displayed FN31 to identify Grid square, waits for it, moves outside and into its center, and captures the result. This is a targeted check, not full hover coverage. The semantic field name came from the visible page. `session.py` centralizes launch, full control dumps and settled screenshot capture for all callers, including the original pilot.

Artifacts live under C:\TR4W-Test\artifacts\<scenario>. Archive one run before repeating a scenario, since filenames are reused. On failure inspect result.json, windows.json, failure.png if present, the scoped application log and C:\TR4W-Test\readiness\scenario-runner.log. A timeout leaves the named task for diagnosis; do not blindly delete a running task or kill unrelated application processes.

Generate the site work list separately:

```text
python tools/gui_test/screenshot_plan.py
```

This inventories the current local MkDocs source and writes docs/GUI_SCREENSHOT_INVENTORY.csv. It does not launch the UI or claim pending captures are complete. No new dependencies are added for inventory generation.

## Bench queue scenarios

`bench_preferences.py` drives visible searches, three-page Cancel/Save/restart and cleanup phases, and per-button overview navigation. Station and contest storage are checked after normal application exit. Failed navigation is retained per action rather than masked by later successes. `bench_log_names.py` tests startup collisions and physical title-bar cancellation; `bench_entry_errors.py` checks refused and corrected CW Open exchanges with Ctrl+Enter to avoid CW. `contest_forms.py` and `qso_entry.py` hold shared form/entry operations.

Use `prepare_fixture.py` for a new isolated run; SQLite backup makes a consistent clone and `--database-name` allows the guest's current local date for collision tests. `session.py` records each owned PID in owned-process.json, including relaunches, so failure collection targets the correct process. `vm_run.py` uses one interactive GUI task and sequential SSH, collects logs and artifacts, and captures fatal dumps before stopping owned workers. Use the pinned main executable and matching symbols, not a worktree build.

See [bench results](../../docs/GUI_BENCH_RESULTS.md) for exact phases, snapshot hashes, evidence and unresolved requirements. A successful task does not replace screenshot review; background/page-selection mistakes can invalidate an individual assertion.


Licence-year cases bench-year-euhfc and bench-year-kvp use fresh fixtures, create year 64, inspect the closed SQLite config and reopen Preferences via visible search. bench_years.py reuses contest_forms and bench_preferences; it records saved and reopened observations before asserting. A failure never accepts a queue item. bench-county-inspect only gathers form discovery evidence; it accepts no county behavior requirements.


County validation now uses bench-county-check and bench-county-texas. bench_county.py checks Florida states, Colorado name retention, unchanged parties, 7QP and county selection; final creation verifies the closed database. Native combo item_texts supplies list indices, and the displayed county code is asserted before creation. bench_switch.py checks File > Open Log cancellation and an already-open name, reusing the shared collision helpers from bench_log_names.py. bench-prefs-audit reuses preferences_audit.py to record actual forward/reverse focus cycles; it accepts no semantic Tab-order requirement without review.


Current e1e4 unattended batch completed the 47-page focus audit and reviewed Station, Appearance, Operating and search-cycle sequences. Detailed results, accepted scope and issues #300, #301 and #304 are in docs/GUI_BENCH_RESULTS.md. All scoped GUI processes closed and original mutable Preferences fixture values were restored. Pending semantic page reviews, hover help and exports remain explicit queue work.


bench_exports.py drives real ADIF/Cabrillo export, the station-summary form, internal file viewer and post-viewer optional upload question. It answers No to uploads using session.answer_question, which validates the complete prompt context before selecting an explicit Yes/No answer. Contact-edit tests reuse qso_entry.open_contact_editor and verify Cancel/No and Save/Yes by reopening the contact. EUHFC/KVP sent-year tests and an IARU captured-zone comparison use isolated one-contact logs; CW Open uses a fresh three-contact log. evidence.preserve_generated_file rejects a stale export and records timestamp/digest for rewritten output. The shared entry driver replaces an existing suggested exchange when a full test exchange is supplied. Detailed expected/actual results and scope are in docs/GUI_BENCH_RESULTS.md.
