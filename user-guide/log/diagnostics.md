# Diagnostic logging: INFO, DEBUG, and TRACE

`tr4w.log` is the diagnostic log, not the SQLite contest database or a Cabrillo submission. Changing its verbosity changes the detail recorded about program activity; it does not change the number of contacts saved.

## Change the log level

1. Open Preferences with **Ctrl+J** and select **Logging**.
2. Choose the required **Log level:**.
3. Apply/save the change. The running logger updates without a restart. Merely selecting a value marks the form as changed; canceling it does not apply that selection.
4. Reproduce the issue and note its time and the steps you took.
5. Use **Open log file** on the same panel to open the active file. Return the level to **INFO** after gathering the needed detail.

| Level | Intended use |
| --- | --- |
| NONE | Disable ordinary diagnostic output. |
| FATAL | Only the most severe failures. |
| ERROR | Errors and more severe messages. |
| WARN | Warnings, errors, and fatal messages. |
| INFO | Normal operating information; the panel's recommended everyday level. |
| DEBUG | More diagnostic detail for investigating a problem. |
| TRACE | The most detailed tracing; can produce a much larger file. |

The current setting name is [DEBUG LOG LEVEL](../reference/commands/a-d.md#debug-log-level). Despite its name, its allowed values include all seven levels above.

## Trace a particular subsystem

The Logging panel also provides separate controls:

| Control | Purpose |
| --- | --- |
| DX cluster — log all telnet traffic | More detail about cluster traffic. |
| TCI server — log every command, both directions | Trace server-side TCI exchanges. |
| HamLib — debug logging | Hamlib-related diagnostics. |
| HamLib — internal trace to hamlib_trace.log | Write a separate detailed Hamlib trace. |
| HamLib — async callbacks only, no heartbeat (testing) | A test mode that changes behavior; it is not simply another verbosity level. |

The form says the three Hamlib settings take effect on the next TR4W start. This differs from the main log level, which takes effect when applied without restarting. Turn on the detail appropriate to the problem rather than selecting every test option.

## Where diagnostic files go

| Platform | Default main diagnostic log |
| --- | --- |
| Windows | `tr4w.log` in the working folder |
| macOS | `~/Library/Logs/TR4W/tr4w.log` |
| Linux | `~/.local/state/tr4w/tr4w.log`, or under the configured XDG state root |

The Hamlib trace uses the same diagnostic-log root with filename `hamlib_trace.log`. The panel's active path and **Open log file** command are useful when several installations or launch profiles exist. [Files and folders](../start/files.md) shows directory trees, contest databases, and reference-data locations.

For a useful diagnostic report, retain the relevant log together with the TR4W version, platform, radio or integration involved, reproduction steps, and approximate time. The Logging panel also offers **Warn when the log file grows unexpectedly**; this is a warning control, not a backup or retention policy.

??? info "Source check"
    Levels: `uSettingsModel.pas`, `LOG_LEVEL_SPELLINGS`. UI and apply behavior: `ui/lcl/uPrefsForm.lfm` and `.pas`, including `SaveLoggingPanel` and `cbxLogLevelChange`. Main log path: `uProgramMain.pas`. Hamlib trace path: `radioFactory/uRadioHamLibDirect.pas`. This guide has not exercised the panel in a running application.
