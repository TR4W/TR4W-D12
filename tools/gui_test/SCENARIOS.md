# Python documentation scenarios

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
```

The root defaults to C:\TR4W-Test. The fixtures must already be staged as described in README.md. `new-contest` and the first `cw-open` run use a run directory with no saved last-log shortcut; `cw-open` subsequently opens the existing single CWOPEN database. The QSO scenario **writes a practice contact**; use it only in disposable data. Its current known example is K6RB / 1 ROB. Repeating it can encounter a dupe; a screenshot-only outcome is explicitly marked for human review, not claimed as a comprehensive logging/scoring test.

`cw-open-collision` requires the existing same-date CWOPEN fixture, opens the current setup dialog, reproduces the collision and selects No. It does not exercise a destructive Yes path.

`preferences-audit` navigates by real keys in the visible left-hand region. It identifies selected pages using the running application's section diagnostics, not a source-derived list. It captures actual forward/reverse focus and Windows UI Automation HelpText. Stable page tags let captures be correlated, but this does not prove every designed page exists. A lack of page diagnostics fails the test rather than inventing names from geometry. Windows UI Automation's missing Name/HelpText is recorded as an accessibility observation; tooltip absence requires a hover check.

The initial Station hover case uses the fixture's displayed FN31 to identify Grid square, waits for it, moves outside and into its center, and captures the result. This is a targeted check, not full hover coverage. The semantic field name came from the visible page. `session.py` centralizes launch, full control dumps and settled screenshot capture for all callers, including the original pilot.

Artifacts live under C:\TR4W-Test\artifacts\<scenario>. Archive one run before repeating a scenario, since filenames are reused. On failure inspect result.json, windows.json, failure.png if present, the scoped application log and C:\TR4W-Test\readiness\scenario-runner.log. A timeout leaves the named task for diagnosis; do not blindly delete a running task or kill unrelated application processes.

Generate the site work list separately:

```text
python tools/gui_test/screenshot_plan.py
```

This inventories the current local MkDocs source and writes docs/GUI_SCREENSHOT_INVENTORY.csv. It does not launch the UI or claim pending captures are complete. No new dependencies are added for inventory generation.
