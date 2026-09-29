# Send contacts to an external logger

Use TR4W for the contest and forward contacts to another logging application when its integration is implemented. This is separate from importing or exporting a file and separate from using another application as a radio-control bridge.

## Which integrations are implemented?

| Choice | Status in this source snapshot |
| --- | --- |
| `NONE` | No external logger. |
| `DXKEEPER` | QSO delivery implementation is present, with a queued TCP sender. Operator verification is still needed. |
| `ACLOG` | Selectable, but the QSO-send method reports “not yet implemented.” |
| `HRD` | Selectable, but the QSO-send method reports “not yet implemented.” |

The **N3FJP ACLog (HamLib bridge)** entry in the radio factory is a different integration. Its presence does not establish contact forwarding to ACLog.

## Set up DXKeeper forwarding

1. Configure the receiving logger to accept its supported TCP logging interface, and note its listening address and port.
2. In TR4W, open settings with **Ctrl+J**, then **External Software → External Logger**.
3. Select `DXKEEPER` in **Program:**.
4. Enter **Address:** and **Port:** to match the receiving service. When both programs run on the same computer, use the local address for that service.
5. Select **Send QSOs to it as they are logged**, apply the settings, and restart TR4W. The panel explicitly says these settings take effect on the next start.
6. In a practice contest, log one contact and verify it appears once in DXKeeper with the expected call, date/time, band, mode, and reports.

## Check edits and delivery failures

The sender queues operations away from the main operating window and retries connections. QSO replacement uses a delete followed by a re-log; this is not an atomic transaction in the external logger. Check the receiving log after an edit, especially if a connection failed during it.

Do not assume that a contact visible in TR4W has already reached the external logger. Compare the two logs and inspect the diagnostic log for delivery errors. The source describes a persistent replay queue as deferred, so do not promise delivery across an application restart.

## Command reference

- [EXTERNAL LOGGER](../reference/commands/e-l.md#external-logger)
- [EXTERNAL LOGGER ENABLED](../reference/commands/e-l.md#external-logger-enabled)
- [EXTERNAL LOGGER ADDRESS](../reference/commands/e-l.md#external-logger-address)
- [EXTERNAL LOGGER PORT](../reference/commands/e-l.md#external-logger-port)

??? info "Evidence and review status"
    `uExternalLoggerFactory.pas` supplies the choices and flags incomplete integrations; `uExternalLogger.pas` contains the actual sender methods; `uExternalLoggerBase.pas` describes queue and replacement semantics. UI labels and restart instructions come from `ui/lcl/uPrefsForm.lfm` and `.pas`. This page does not report a live DXKeeper test.
