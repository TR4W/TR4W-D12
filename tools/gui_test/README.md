# Windows GUI pilot

For the expanded Python-driven walkthrough captures and Preferences audit, see [SCENARIOS.md](SCENARIOS.md) and the [November 11 results/issues](../../docs/GUI_DOCUMENTATION_TEST_REPORT.md). The original pilot described below remains the initial baseline, not the full extent of current coverage.

`pilot.py` is a Windows-only pywinauto smoke test of a staged TR4W build. It was first run successfully on November 11, 2026 in the Proxmox guest `tr4w-gui-test`, as `GUI-TEST` in interactive console session 1.

## Scope and architecture

SSH stages files and requests execution. A temporary Scheduled Task with an Interactive principal starts the worker in the already logged-in test user's desktop. Running Python directly in the SSH service session is not the test setup. No password was needed to register/run the task while that user was logged in.

The script launches one process, scopes controls to that PID, waits for the main window, opens Preferences with Ctrl+J, checks its Save/Cancel controls, captures screenshots, and verifies Escape closes Preferences. It then terminates only the launched application and writes a pass/fail result. This is a navigation/capture smoke test, not a graceful-shutdown, settings-persistence, or QSO-entry test. It does not certify every custom control or translated label.

The older `tr4w/test/ui/Test-PreferencesSections.ps1` explicitly documents its obsolete menu-ID opening step. This pilot uses real keyboard navigation instead of copying that mechanism or modifying the application to restore obsolete IDs. Reuse the existing inspection/text-fit tools where their assumptions remain valid; do not infer that this pilot replaces their coverage.

## Validated VM environment

- Python 3.15.2 x64 installed for GUI-TEST, with a virtual environment at `%LOCALAPPDATA%\TR4W-Test\.venv`.
- pywinauto 0.6.9, Pillow 13.0.0, pytest 9.2.0, comtypes 1.5.0, pywin32 312.
- Official Microsoft Visual C++ x64 runtime. Without it, `import win32ui` failed because native runtime DLLs were missing. The Microsoft-signed redistributable fixed this; no arbitrary DLL copying or package patching was used.
- Desktop 1280 × 800, 96 DPI. The homelab agent will address the larger documentation baseline separately.

A virtual environment created from Python inside toms's private profile failed under GUI-TEST. Use the test account's interpreter or a properly installed shared runtime. Do not grant the worker access to another user's profile as a workaround.

## Staged layout

```text
C:\TR4W-Test\
   app\tr4w_fpc.exe              identified executable and matching runtime DLLs
   build-info.json               SHA-256 and known build/fixture provenance
   runs\pilot-001\practice.db    disposable database snapshot
   runs\pilot-001\tr4w.json      disposable settings
   runs\pilot-001\CTY.DAT        Windows data lookup uses the working folder
   runs\pilot-001\dom\           applicable shipped multiplier definitions
   artifacts\pilot-001\         screenshots, control tree and result
```

Stage the application's required package assets, not just its executable. The initial attempt stopped at the missing-country-file prompt because CTY.DAT was beside the executable instead of in the working folder. Screenshot inspection identified the prompt; placing the data in the run directory resolved it. This was a staging error, not an application regression. Installer behavior remains a separate test.

The first fixture was copied from `tr4w/test/corpus/cqww_ssb_2025_ny4i/log.db` using SQLite's backup API, preserving the source. No live operator settings or credentials were copied. The captured main title reported `TR4W v.5.0.37 - 2026 CQ-WW-SSB NY4I`; the older fixture folder name alone is not authoritative for its displayed contest year.

The first tested executable SHA-256 was:

```text
1b7643ed905d071b94f72e9cc9a8f16bdad07ba9b0fb9b6e1bbf535584129c80
```

It was an existing local 32-bit build dated November 10 at 23:49. The checkout revision at staging was fdaf208a; that is not independent proof that the executable was compiled from exactly that revision. A future release test should use an installer/build artifact with certified provenance.

## Execute

From GUI-TEST's interactive desktop, after staging a fresh disposable fixture:

```cmd
"%LOCALAPPDATA%\TR4W-Test\.venv\Scripts\python.exe" C:\TR4W-Test\readiness\pilot.py
```

The copy of `pilot.py` can live elsewhere; `--root` overrides the default `C:\TR4W-Test`. Use one GUI job per desktop. Before starting, ensure no other TR4W session is running in the test guest. The SSH orchestration performed that preflight; it is not a substitute for protecting the guest against concurrent operators.

For SSH-triggered runs, register an interactive, limited-privilege Scheduled Task for GUI-TEST that runs the same command through a small PowerShell launcher, redirects its output, and returns Python's exit code. Poll the task's state/result with a bounded timeout, collect artifacts, and remove the temporary task once complete. Do not treat a task still running (267009) as a final failure or success. Use `ConnectTimeout=60` and sequential SSH connections while the homelab clone is placing pressure on I/O.

The script returns zero only when the checks and cleanup succeed. On failure, inspect `result.json`, `windows.json`, `failure.png` if captured, the runner log and the run's `tr4w.log`. A later passing run does not delete an earlier failure screenshot, so use the current result and timestamps to distinguish them. Archive each run before reusing these pilot paths.

## First result and remaining work

The retry passed all three checks: practice log opened, Ctrl+J exposed Preferences with expected controls, and Escape closed it. `main.png` and `preferences.png` were retrieved and the Preferences capture was visually reviewed. The temporary task was removed.

Next tests should verify Save versus Cancel persistence, select different Preferences pages, inspect the logger grid with live delivery disabled, and log/reopen one practice QSO. Add these only after defining meaningful observable results and preserving isolation. No real radio, logger account, multi-station server or sponsor submission was exercised by this pilot.
