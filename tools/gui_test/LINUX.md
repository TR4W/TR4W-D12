# Linux GTK2 GUI tests

## November 16 update: passing smoke and persistence case

The identified Linux workflow artifact at source revision
`4547b9117f4d5c23a3606bd4de9477d5eb4b5019` passes the smoke test, including
exit 0. It comes from workflow run `43776700899`, Linux job `133014282739`,
artifact `tr4w-linux-5.0.40` (ID `14187842099`). The checkout SHA was verified
in that job's log; the version string alone is not its identity. Its executable
SHA256 is `c405fc3bf0e5388446af7a0aae1ab4cc9ca8ba51a68dd741cfceb9959d8a5d5f`.
The older failing release and its original evidence below remain preserved.

The new `--case preferences-persistence` case found generated Preferences
controls losing dirty handlers after Cancel, and a hidden rebuilt page leading
to a nil dereference in a focus-timeout warning. A small patch in uPrefsForm
fixes those reload paths. The full persistence case passes on a private native
build of the same source revision plus that patch:

- Run: `linux-prefs-persistence-006`, on `debian`.
- Binary SHA256: `04bc8e10e7ae24df1256b653260bc0fa09750db27af6d23bdaf7c65d797514f1`.
- Cancel discards an edit in both UI and JSON storage.
- Save commits the edited value, clears dirty state and survives restart.
- Save and close restores the original value; a second restart verifies it.
- Three independently owned application PIDs exit 0; all 101 original contacts
  retain their original fields. Default contest files remain unchanged.

The same complete case also passes under GDB, with three distinct inferiors
exiting 0, no SIGSEGV stops and no access-violation markers:
[debugger result](../../docs/gui-test/linux-prefs-persistence-20261116/gdb-result.json).

The final cross-platform patch additionally disables selection-as-click on the
search overlay, after Mac typing was observed activating a result too early.
It passes the complete Linux scenario again under GDB as
`linux-prefs-search-gdb-001`: three exits 0, zero SIGSEGV stops and zero
access-violation markers. Final Linux executable SHA256:
`65b038b6cbd3c7864d31691792a2188fdb7faa9627d063f66ff1d5551e63c87c`.
Its source patch SHA256 is
`c6e9acbb7f8dd2eaa15353638711abf01fc0976dfe898ea21f1080c8b1d4d0d2`.
[Final result](../../docs/gui-test/linux-prefs-persistence-20261116/final-gdb-result.json),
[final application patch](../../docs/gui-test/linux-prefs-persistence-20261116/application-search.patch).
Mac now passes the same shared scenario too; see [MACOS.md](MACOS.md).

The setting is RADIUS OF EARTH, stored at `settings.GridMap.RadiusOfEarth` in
the disposable run's JSON. It is expressed in kilometres and accepts
0–6553.5; zero uses the application's default. The test uses 6371/6372, selects
different values if either equals the observed baseline, then restores that
baseline. It does not use hardware, change contacts or edit operator settings.

This is a passing scoped case, not Windows suite parity. The application fix
is uncommitted in this worktree and has not been integrated into main. See
[reload review](../../docs/PREFERENCES_RELOAD_GUI_REVIEW.md),
[passing persistence evidence](../../docs/gui-test/linux-prefs-persistence-20261116/result.json),
[workflow smoke](../../docs/gui-test/linux-prefs-persistence-20261116/workflow-smoke-result.json).

### Run the new case

The tested candidate, scripts and digest-matched build record are staged on
Debian. Use a fresh automatic run name:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/linux_pilot.py" \
   --database-template "$HOME/tr4w-gui-test/practice-source.db" \
   --settings-template "$HOME/tr4w-gui-test/tr4w.json" \
   --build-record "$HOME/tr4w-gui-test/artifacts/linux-prefs-search-build.json" \
   --case preferences-persistence
```

Omit `--case` for the smoke test. Append `--gdb` for the existing debugger
diagnostic. The worker receives the same selected case and build record.
The workflow artifact is archived by hash; the original staged package remains
at `~/tr4w-gui-test/app-before-4547b911/`. The active test slot contains the
identified patched candidate, not the original release.

### Shared scenario and Linux driver

[preferences_roundtrip.py](preferences_roundtrip.py) contains the scenario,
numeric comparison and independent JSON persistence checks. Both native
coordinators call it. A small driver contract supplies open/select/read/write,
footer state and activation; coordinators retain process ownership, normal
exit, restart and contact checks. It does not import pywinauto or platform APIs.

`LinuxPreferences` in [linux_pilot.py](linux_pilot.py) implements the contract
with AT-SPI and real X11 input. It scopes controls to the owned PID and actual
Preferences frame, selects the named search table cell using its current
AT-SPI bounds, verifies focus and displayed edits, and waits for visible
outcomes. The initial Enter-based attempt did not activate the GTK search
result; named-row clicking is used for this persistence scenario, which does
not certify keyboard search behavior. Pointer location is checked explicitly:
xdotool mousemove --sync can wait forever when the cursor is already there.
No fixed screen click positions are acceptance criteria.

`evidence.native_build_identity` checks that an optional build record matches
the exact executable before attributing its source. Missing records retain
unknown source revision. The same helper is used by macOS. Nineteen portable
harness tests pass, including mismatch and native-permission guard failures.

## Historical November 15 pilot

The native Linux tester is feasible: on November 15, 2026, it opened a real
practice log, captured the main window, opened Preferences with Ctrl+J,
read its footer through AT-SPI, and dismissed it with Escape. The overall
smoke test **FAILS** because confirming normal application exit returns **217**.
This is not a green Linux regression suite.

The proposed shared shutdown review and request for another agent's concurrence
are in [SHUTDOWN_LIFECYCLE_REVIEW.md](../../docs/SHUTDOWN_LIFECYCLE_REVIEW.md).

## Established result

Host: SSH alias `debian`, `toms@findaclub-staging`, Debian 13 x86_64.
Application: user-staged v5.0.40 Linux release, SHA256
`f775c35156cc45bda4c4fa5b2ce7a60d2215fda17a99ea37830f12fb0f48d806`.
The exact build-time source revision is unknown; the current local checkout
must not be substituted for it. The executable carries embedded debug symbols;
its startup log reports successful symbol resolution.

Final run: `linux-pilot-009`. Application PID 106469, test exit 1,
application exit 217, `navigation_passed: true`, `passed: false`.

| Observation | Result |
| --- | --- |
| Practice log opened | PASS: title names CQ-WW-SSB / NY4I, 101 contacts |
| Main and Preferences captures | PASS, reviewed at 1280x800 |
| PID-scoped accessibility tree | PASS, actual GTK2 AT-SPI controls |
| Clean Preferences footer | PASS: Save disabled; Save and close / Cancel enabled |
| Escape dismisses Preferences | PASS |
| Original contact fields unchanged on exit | PASS, all 101 records and original columns |
| Default contest files unchanged | PASS, before/after size/mtime inventory |
| Normal application exit | FAIL, exit 217 |

The old corpus log migrates from schema 2 to 7 when opened. Ten new station/year
columns are recorded separately in the result. The contact comparison includes
every original column and rowid; it does not mistake added migration columns
for edits or ignore changes to existing values.

Reviewed evidence: [result](../../docs/gui-test/linux-pilot-20261115/result.json),
[main](../../docs/gui-test/linux-pilot-20261115/main.png),
[Preferences](../../docs/gui-test/linux-pilot-20261115/preferences.png),
[AT-SPI tree](../../docs/gui-test/linux-pilot-20261115/preferences-tree.json),
[steps](../../docs/gui-test/linux-pilot-20261115/steps.jsonl).
Full runtime logs and earlier failures remain on Debian in
`~/tr4w-gui-test/artifacts/` and in this worktree's
`build-out/linux-gui-pilot/`. The original immutable executable is retained on
Debian under `~/tr4w-gui-test/evidence/<SHA256>/tr4w`.

Exit 217 repeated in runs 007, 008 and 009 after confirming the observed exit
question. The runtime log reaches program shutdown and factory finalization.
Run 008 also had a driver assertion that incorrectly compared schemas of
different ages; 009 corrects that assertion and still reproduces exit 217.

### GDB follow-up: first shutdown fault located

After GDB 16.3 was installed, `linux-gdb-002` reproduced exit 217 with the same
executable. The first SIGSEGV is:

```text
TApplication.RemoveAsyncCalls(this=nil)
TCustomForm.Destroy
TPrefsForm.Destroy
uPrefsForm unit finalization
```

The retained Preferences form is freed during unit finalization after the LCL
Application object is already nil. Its inherited form destructor calls
`Application.RemoveAsyncCalls` and dereferences nil. The current source still
creates `gPrefsForm` with no component owner, hides it on close, and frees it
from the unit's finalization section. Binary source lines differ from the
current checkout; the embedded symbols identify the crashing code, not an
inferred source revision.

Later faults involve finalization logging and thread-local/critical-section
machinery. They occur after this first fault and must not be used to blame
HamLib, the radio factory or NTP for the initial failure. Logging is itself
failing during teardown, explaining why the ordinary runtime log is not a
reliable record of these exceptions.

The durable fix should destroy retained UI forms while the LCL Application
is still alive, clear cached references, and audit other UI singletons for
the same lifetime mistake. Do not suppress the exception or skip freeing the
form as a substitute for correcting shutdown order. The application code has
not been changed; a fix still requires a fresh native build and rerun.

Debugger evidence: [complete transcript](../../docs/gui-test/linux-pilot-20261115/shutdown-gdb.txt),
[result](../../docs/gui-test/linux-pilot-20261115/shutdown-gdb-result.json).
The first debugger run, `linux-gdb-001`, stopped at SIGSEGV and GDB returned
255; that is a debugger-stop result, not a new application exit code. The
second run captures and passes the signal through Pascal handling, preserving
the original exit 217.

## Debian preparation

These names were checked against this host's Debian 13 package index:

```bash
sudo apt update
sudo apt install --no-install-recommends \
   xvfb xauth openbox xdotool wmctrl \
   at-spi2-core libatk-adaptor libgail-common libgtk2.0-0t64 \
   python3 python3-gi python3-pyatspi python3-pil \
   gir1.2-atspi-2.0 fonts-dejavu-core
mkdir -p "$HOME/tr4w-gui-test"/{app,runs,artifacts}
```

Extract the **complete** native Linux tarball into `app/`, removing its one
top-level directory. For example, the tested release is:

```bash
cd "$HOME/tr4w-gui-test"
curl --fail --location --output tr4w-5.0.40-x86_64-linux.tar.gz \
   https://github.com/TR4W/TR4W-D12/releases/download/v5.0.40/tr4w-5.0.40-x86_64-linux.tar.gz
tar -xzf tr4w-5.0.40-x86_64-linux.tar.gz --strip-components=1 -C app
ldd app/tr4w
```

Resolve any `not found` library before running. This host already resolves all
linked libraries. GTK2, SQLite and OpenSSL runtime requirements are described
in [INSTALL_LINUX.md](../../docs/INSTALL_LINUX.md). No compiler, VNC server,
GNOME login, Windows scheduled task or pywinauto installation is required.

## Stage and run

Run these staging commands from a repository checkout on the workstation.
`snapshot_corpus_log` requires a stopped fixture; do not point it at a live log.
Use a new destination filename for a new source snapshot.

```powershell
New-Item -ItemType Directory -Force build-out/linux-gui-pilot | Out-Null
python -c "import sys; from pathlib import Path; sys.path.insert(0,'tools/gui_test'); from fixture_data import snapshot_corpus_log; snapshot_corpus_log(Path('tr4w/test/corpus/cqww_ssb_2025_ny4i/log.db'),Path('build-out/linux-gui-pilot/practice-source.db'))"
scp tools/gui_test/linux_pilot.py tools/gui_test/fixture_data.py tools/gui_test/evidence.py tools/gui_test/fixtures/tr4w.json build-out/linux-gui-pilot/practice-source.db debian:tr4w-gui-test/
```

The above files are already staged on `debian`. Start another run there with:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/linux_pilot.py" \
   --database-template "$HOME/tr4w-gui-test/practice-source.db" \
   --settings-template "$HOME/tr4w-gui-test/tr4w.json"
```

An automatic UTC/unique run name prevents overwriting evidence. `--run` can
name a fresh run explicitly. The runner rejects existing run directories and
holds a nonblocking file lock to prevent overlapping pilot runs.

For a shutdown diagnostic, install `gdb` and append `--gdb` to that command.
This option currently supports Linux x86_64. It launches the application under
GDB and records Pascal raises and SIGSEGV stacks in `processes.log`. The
debugger's controller PID is kept separate from the application's inferior
PID, so all UI observation still targets TR4W. GDB passes signals onward and
uses `--return-child-result`; it does not turn the application failure green.

Exit 0 means every assertion, including application exit, passed. Exit 1 means
the worker failed; inspect `result.json` rather than interpreting screenshots
as acceptance. An outer timeout/interruption returns 2 and writes
`timeout.json`. Early setup errors also terminate with a traceback; do not
infer a verdict when no result exists.

## Architecture and ownership

`linux_pilot.py` is a small coordinator plus a native Linux worker. The
coordinator makes a fresh fixture through the shared `snapshot_corpus_log`,
then starts `xvfb-run` -> `dbus-run-session` -> the worker. Each run has a
1280x800 24-bit X11 screen at 96 DPI, a private session bus and separate XDG
configuration/data/state/cache directories. `HOME` is not changed.

The worker owns one Openbox process and one TR4W process. It uses wmctrl's PID
and window inventory, real xdotool keyboard input, foreground-checked stable
Pillow screen captures, and a bounded AT-SPI walk scoped to the application
PID. The Preferences footer assertion is further scoped to its actual frame.
These are full virtual-desktop captures, not Windows DWM frame crops, and have
their own appearance. Windows image baselines must not be reused.

`evidence.StepLog` supplies the existing flushed before/after/error journal;
`fixture_data` supplies shared snapshot and contact observations. The Windows
suite now imports the same snapshot routine instead of keeping a second copy.
The worker records the executable hash and archives that executable before UI
actions. It preserves process output, window/control inventories, screenshots
and application runtime logs on failures. Only its owned PIDs are stopped;
the outer timeout stops the process group it created. Xvfb and D-Bus wrappers
clean up their own services. No blanket process-name kills are used.

The fixture has no radios, profiles, keyers, clusters, rotators or external
loggers. Automatic connection, CW/PTT, WSJT-X, country-update and score-posting
flags are disabled for this disposable run. The application still performs its
normal automatic NTP check against pool.ntp.org; this is **not** a network or
filesystem sandbox.

Secret Service is deliberately unavailable in the private test session. A
run-local D-Bus activation entry executes `/usr/bin/false` for
`org.freedesktop.secrets`. This avoids trying to activate the real desktop's
keyring on the private bus, which otherwise caused 25-second startup waits.
The application's resulting unavailable-keychain warnings are expected for
this fixture. The real desktop's configuration and keyring are not modified.
This pilot does not certify credential storage.

Linux's default contest directory remains `~/tr4w`; XDG paths and `--settings`
do not relocate it. The pilot opens only its own supplied database and performs
no New Contest/export actions. A before/after file inventory checks that the
default folder's files are unchanged; this is an observation, not enforcement.

## Startup path defect and remaining work

The release's `uProgramMain.FirstNonSwitchArgument` treats every argument
starting with `/` as a switch, including `/home/toms/.../practice.db`. Runs 001
and 002 therefore opened New Contest. The pilot uses `./practice.db` with its
unique run directory as the working directory as an explicit **workaround**.
It rejects the New Contest title instead of reporting that screen as a log.
Run 001 additionally had window-inventory and AT-SPI binding mistakes; neither
001 nor 002 is a passing navigation test.

The application fix belongs in argument parsing: distinguish supported legacy
slash switches from Unix absolute paths, preserve switch-value consumption,
and test absolute/relative contest paths alongside `--settings`, `--lang` and
legacy `/EXPORT`. No application Pascal sources were changed for this pilot.

Next: correct the retained-form shutdown lifetime and validate exit 0. Then add a
harmless Preferences edit with Cancel, Save, restart and a persisted-value
assertion. Current coverage verifies the clean footer and Escape only; it does
not certify Save/Cancel persistence, every Preferences page, custom-grid
accessibility, real hardware, credentials, other Linux desktops or macOS.

Validation: 15 portable harness tests passed on Windows; the four shared
fixture tests also passed on Debian. Live Linux navigation is established;
the complete pilot remains failed on the shutdown result.
