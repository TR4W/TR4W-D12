# Windows GUI testing and CWOPS guide turnover

Prepared November 12, 2026 for the agent continuing on `main`. This covers the `codex/cwops-guide` worktree: guide updates, screenshot automation, Preferences checks, BENCH_QUEUE triage and the reusable Python regression suite. Application Pascal sources were not changed by this work.

Integration completed locally: work committed as `795ce663`, current main merged into the handoff as `595ed469`, and main fast-forwarded to that merge. The worktree and its merged local branch were removed after evidence preservation. Nothing was pushed. The final SSH check reported no TR4W processes and no `TR4W-GuiScenario` task. Main's unrelated working changes were preserved.

## Follow-up: 64-bit guest Python launcher repaired

After the harness default moved to the x64 application, `.venv` failed under GUI-TEST: its `pyvenv.cfg` still referenced `C:\Users\toms\AppData\Local\Programs\Python\Python315`, whose ACL did not grant GUI-TEST access. The earlier `.venv-x86` remains the historical x86 environment and must not drive the new x64 application.

A separate **`C:\TR4W-Test\.venv-x64`** was created from GUI-TEST's own working Python 3.15.2 x64 installation. An interactive, limited GUI-TEST scheduled-task preflight successfully ran its `Scripts\pythonw.exe` and imported pywinauto 0.6.9, Pillow 13.0.0, pywin32 312 and comtypes 1.5.0 (six 1.17.0 also installed). Task exit code was 0; the diagnostic task was removed. Guest proof: `C:\TR4W-Test\readiness\gui-python-preflight.json`. No TR4W test was launched during this repair.

The central `GUEST_PYTHON` default in `tools/gui_test/stage_main_build.py` now names `C:\TR4W-Test\.venv-x64\Scripts\python.exe` (2026-11-12), so no `--python` override is needed. The first x64 run through it passed: suite `20261113T022346-7e86bc`, `--case import` (seed PASS, import PASS) against x64 exe SHA256 `af52e1445acb4cc8b6bd1c096f67de1aa763f48c19c8d5615484eb6fe555e266`, debug CRC `99C94B0C`.

The old `.venv` (broken under GUI-TEST) and `.venv-x86` (the historical x86 environment) were left on the guest unchanged. The per-case results table below records the original x86 turnover and remains historical evidence; [GUI_BENCH_RESULTS.md](GUI_BENCH_RESULTS.md) holds the x64 results.

## Start here

1. Read this document, [the results ledger](GUI_REMAINING_TESTS.md), [detailed bench results](GUI_BENCH_RESULTS.md) and [the test plan](GUI_BENCH_TEST_PLAN.md).
2. Use the executable Tom selected: `C:\tr4w-d12\build-out\app-x86_64-win64\tr4w_fpc.exe` (64-bit; Windows TR4W is x64 only since 2026-11-12, and the i386 build no longer exists). The suite snapshots that executable, its matching `.dbg` and runtime assets before running. Main changes frequently; an old passing result does not certify a new executable.
3. Continue Search Log first. Its script is implemented but has a known fixture error and no approved result baselines. Do not describe the suite as fully passing.
4. Run selected cases before a full suite. Fix confirmed application defects in a separate application worktree; do not weaken assertions to obtain green results. File reproducible defects as GitHub issues, as Tom requested.

## What was delivered

- [TR4W-for-CWOPS.md](TR4W-for-CWOPS.md) rewrites Marv's older [D7 guide](TR4W-for-CWOPS-D7.md) for the current Preferences and radio-profile UI. It distinguishes CW Open from CWT, uses CQ CWT and the CWT name/member-number or non-member exchange, uses US spelling “practice”, and explains a contest `.db` as one log without exposing unnecessary database internals. Historical screenshots and observations identify their tested build; later UI fixes may require new captures.
- Updated CW message, first-contest, keyboard and radio pages under `user-guide`; guide screenshots under `user-guide/assets/cwops/`, including the reviewed `foreground/` captures.
- Python scripts under `tools/gui_test` drive the actual application, collect control trees and screenshots, enter disposable contacts without CW, verify persistence, inspect exports and return explicit results. Screenshots alone and discovery phases are not regression acceptance.
- [GUI_PREFERENCES_AUDIT.md](GUI_PREFERENCES_AUDIT.md), [GUI_SCREENSHOT_INVENTORY.csv](GUI_SCREENSHOT_INVENTORY.csv) and [GUI_DOCUMENTATION_TEST_REPORT.md](GUI_DOCUMENTATION_TEST_REPORT.md) record the initial audit and documentation exercise.
- [BENCH_QUEUE.md](BENCH_QUEUE.md) retains scoped, dated evidence and checked standalone requirements. Requirements involving other platforms, 150% DPI, live services or additional equipment remain open. The queue was refreshed from current main before handoff; main's new license-year and schema-7 requirements were retained alongside historical results.

## Running the regression suite

From the repository root on the workstation:

```powershell
python tools/gui_test/run_suite.py --list
python tools/gui_test/run_suite.py --case import --case locked
python tools/gui_test/run_suite.py
python -m unittest discover -s tools/gui_test -p "test_*.py"
```

The host runner uses Python's standard library plus the existing SSH/SCP commands. Defaults are the main executable above, SSH alias `tr4w-gui-test`, guest Python `C:\TR4W-Test\.venv-x64\Scripts\python.exe`, and local `build-out/gui-regression/<UTC timestamp>-<unique id>/`. `--exe`, `--data-root`, `--host`, `--python`, `--output` and repeatable `--case` are available. The country-data default is main's `tr4w/target` (`CTY.DAT` and `dom`).

The runner always creates a fresh three-contact CW Open seed, validates 4 then 6 points and backs up the closed SQLite seed into each fresh case. Repository-owned settings start with no radios, profiles, keyers, clusters or active external loggers. Online tests contact only their own loopback HTTP server; radio/editor tests create an inactive definition. No historical VM fixture is needed for the suite.

Exit codes: **0** all selected cases pass; **1** one or more assertions fail; **2** setup/driver errors prevent a reliable verdict. `summary.json` includes requested cases, exact build identity and each completed case's status/result path. A seed failure stops dependent cases. Check `runner.log`, per-case `result.json`, `steps.jsonl`, `windows.json`, screenshots and runtime logs. A nonzero result must be investigated; do not ignore it because a screenshot looks plausible.

## Current verified status

These are separate live runs, sometimes on different pinned snapshots. There has not yet been one complete run of every case using the final script versions.

| Case | Last established result | Evidence suite under the archived gui-regression directory |
| --- | --- | --- |
| seed | PASS, focused three-contact seed | `20261112T144826-bb589e` |
| hints | PASS: six actual hover/dismissal/help cases | `20261112T091420-9e54d0` |
| focus | PASS: 47 pages, forward/reverse cycles, visible/enabled controls and semantic reading order | `20261112T142924-c855a4` |
| online | PASS: form geometry, certificate state, Cancel, isolated Test routing/no credentials, Save/restart | `20261112T092001-c7d2a2` |
| loggers | PASS: five provider field sets, token masking/reveal, inactive order/restart, reviewed empty-grid image | `20261112T142924-c855a4` |
| radio | PASS: inactive K4 polling limits, last Tab/tooltip, HamLib toggle, blank default/restart | `20261112T140847-1ce4bc` |
| import | PASS: invalid rollback/warning, later manual entry, good import and six-record ADIF re-export | `20261112T143807-876920` |
| messages | PASS: Standard/Control/Alt edits and caption persist across restart; no transmission | `20261112T092001-c7d2a2` |
| switch | FAIL: invalid `.db` restarts the app; valid numbered-new-log/back round trip passes | `20261112T143807-876920`, [issue #306](https://github.com/TR4W/TR4W-D12/issues/306) |
| locked | PASS: real SQLite writer, Retry held/released, later logging, read-only export/refusal, one warning, Quit/Escape/Close with exit 1 | `20261112T144826-bb589e` |
| search | INCOMPLETE: filters exercised; erroneous 20 m entry fails the new-10-m assertion; baselines/column restart not accepted | `20261112T144826-bb589e` |

The last snapshot above is SHA256 `363a9b550b17f8b93ac815fa894c706e9853620c8862bfc2e055d81f0155f75c`, debug CRC32 `3A9DF67B`, guest root `C:\TR4W-Test\bench-main-363a9b550b17`. Build-time source revision is unknown: the identity explicitly records a user-selected existing binary, not a revision inferred later from main. Other suites carry their own hashes. Portable evidence/parser/staging tests: **11 passed** before turnover.

## First continuation tasks and known limitations

1. **Correct Search setup from observed UI.** `bench_search.py` uses three Alt+B presses assuming a 40 m starting state. The restarted fixture actually starts at 160 m: the log explicitly shows K3GUI on **20 m**, so “new 10 m missing” is a driver error, not an application issue. Select the intended band by observing the main window before entry; verify the saved contact and then the Search drop-down. Band captions have leading spaces, already normalized by the driver. It imports two mixed-mode contacts for four bands/two modes.
2. **Review Search rendering before accepting baselines.** The planned fixed-DPI crops check actual Band and Callsign cells while excluding changing date/time columns. No `search-*.png` baselines have been approved or installed. Review complete screenshots and crop boundaries against expected calls/bands, then commit explicit baseline files under `tools/gui_test/fixtures/ui-baselines`. Never automatically accept a newly captured image. The existing logger-empty baseline was manually reviewed. Column-drag/restart checks are implemented but were not reached in the latest Search run.
3. **Rerun the whole suite.** A shared image comparison was extracted after the last logger PASS. Modal text handling and hang preservation also changed. Syntax checks and portable tests passed, but those changes still need one complete live run. Keep switch FAIL until #306 is fixed. Message chooser selected-row/bank retention, some Cancel variants, MY_ import Yes/No choices, 150% DPI and translations are additional requirements, not implied by the scoped PASS rows above.
4. **Recheck recent main fixes.** New license-year settings and schema-7 work postdate much of the evidence. In particular, historical #300/#305 results must not be treated as proof that those defects persist after the new implementation. The queue's new license-year section is untested by this suite.
5. **Investigate the one startup stall if it recurs.** Suite `20261112T144518-a17473` lost readable startup captions after clicking Show inactive contests in the old `bench-basic` catalog walkthrough. No fatal marker was recorded and screenshot stabilization failed. Cause is unresolved; do not call it a confirmed application crash. The focused suite seed now uses `bench-seed`; the catalog walkthrough remains separately available. `bench_ui.py` now preserves a detected hung process for the runner to dump. That recovery branch has not been deliberately induced and certified.

## VM, isolation and hardware

The Proxmox Windows guest is reachable with `ssh tr4w-gui-test` as `toms`. The **GUI-TEST** console session must already be logged in, unlocked, at **1280×800, 96 DPI**. SSH runs scheduling/staging commands; the actual UI worker runs in that interactive desktop through limited Scheduled Task `TR4W-GuiScenario`, using `pythonw.exe` and `bootstrap.py`. RDP or the Proxmox console is not required by the driver. Do not operate the console or run another GUI job while it is testing. Use sequential SSH calls and `ConnectTimeout=60`.

Guest environment: Python **3.15.2 x64** in `C:\TR4W-Test\.venv-x64` (based on GUI-TEST's own installation), pywinauto **0.6.9**, Pillow **13**, pywin32 and comtypes. **Match interpreter and application bitness.** The initial radio-editor AV in [#283](https://github.com/TR4W/TR4W-D12/issues/283) exposed a concrete x64-Python/x86-common-controls structure mismatch; three matching-x86 retries worked. The app is now x64 only, so drive it with `.venv-x64`; `.venv-x86` only drove the retired x86 builds, and `.venv` is broken under GUI-TEST (its base interpreter is in another user's profile). `evidence.require_matching_bitness` refuses a mismatch.

Available hardware is limited to the Elecraft K4 at `192.168.73.108:9200` and cluster `dxc.nc7j.com:7373`, login `NY4I-2`. Earlier guide captures show the connected K4 and populated bandmap. Tom said the radio was in text mode and would not key. Do not tune/key it or assume any other hardware exists. The current suite does not use either endpoint. Existing incremental `radio-*` scenarios require their documented earlier fixture/state; they are not a fresh, unattended radio suite.

## Architecture and failure handling

`run_suite.py` → `stage_main_build.py`/`prepare_fixture.py` → sequential `vm_run.py` → interactive `bootstrap.py`/`scenarios.py` → `bench_ui.py` → focused `bench_*.py` cases. Shared modules provide PID ownership and restart adoption (`session.py`), no-CW entry (`qso_entry.py`), settings/message/radio workflows, read-only fixture observations (`fixture_data.py`), independent ADIF fixtures, visual comparison and build/evidence guards. Extend shared helpers rather than cloning drivers.

Controls are scoped to owned PIDs. Restart adoption checks the exact executable and unique settings path before recording the successor. Never kill all TR4W or Python processes. A fatal log marker, timeout or detected hang triggers a ProcDump attempt before owned-process cleanup; dumps require the exact archived executable and symbols. ProcDump is `C:\TR4W-Test\tools\procdump\procdump.exe`. Failed dump collection needs manual investigation, not indiscriminate cleanup.

Screenshots use `session.capture` → `window_capture.capture_window`: focus the actual HWND, require foreground/restored state, use DWM visible frame bounds and stable frames. This removed background strips caused by invisible resize borders; Tom verified the corrected guide images. Optional control crops must remain fully inside the foreground frame. Keep one implementation for guide and test captures.

Native UI calls can return transient/empty text during modal transitions. `notice_text` prefers real Static labels and falls back to UI Automation; question handling checks the complete expected context before clicking Yes/No. File pickers locate their visible filename Edit; context-menu actions read actual menu captions and item rectangles. Avoid guessing button positions. Hover uses absolute screen coordinates and verifies the resulting cursor location.

## Issues and evidence retention

Read [GUI_BENCH_RESULTS.md](GUI_BENCH_RESULTS.md) and [GUI_DOCUMENTATION_TEST_REPORT.md](GUI_DOCUMENTATION_TEST_REPORT.md) for scoped findings and links. Bench issues include #295 (Radius Of Earth), #296 (error notice), #297 (overview Enter), #300 (historical license-year edits), #301 (Ontario clipping), #304 (bandmap label), #305 (historical CQ-zone metadata), and #306 (invalid log switch). Check each issue's latest discussion before retesting; some main changes supersede old failures.

Committed evidence is under `docs/gui-test/` and `user-guide/assets/cwops/`. Large executable/symbol archives, full runtime logs, exploratory screenshots and suite runs remain local. On worktree closure its entire roughly **4.8 GB** `build-out` directory is preserved at **`C:\tr4w-d12\build-out\gui-worktree-handoff-20261112`**. Thus an older reference to worktree `build-out/gui-regression/...` is found under that archive's `gui-regression/...`; similarly for `bench-ui`, radio retries and guide captures. Guest snapshots and fixtures remain under `C:\TR4W-Test`.

Main's pre-existing overlapping guide/pilot files and its modified documentation map were preserved under **`C:\tr4w-d12\.worktree-backups\cwops-guide-integration-20261112`** before integration. Its manifest records hashes and the pre-integration status. Additional ignored exports/logs and the generated resource are preserved in the archive's `worktree-ignored/`; referenced ADIF evidence was also copied to main's `docs/gui-test/`. Unrelated main edits must remain untouched. Verify the guest has no test-owned TR4W process or scenario task before restarting work.
